#!/usr/bin/env python3
import os
import json
import requests
import sys
from datetime import datetime, timezone, timedelta
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build_from_document

# Determine the script's directory within the app bundle
script_dir = os.path.dirname(os.path.abspath(__file__))
app_bundle_path = os.path.abspath(os.path.join(script_dir, "../Resources"))

# Paths
token_path = os.path.join(app_bundle_path, "token.json")
album_id_file = os.path.join(app_bundle_path, "album_id.txt")
discovery_url = "https://photoslibrary.googleapis.com/$discovery/rest?version=v1"
upload_url = "https://photoslibrary.googleapis.com/v1/uploads"
token_uri = "https://oauth2.googleapis.com/token"

def time_remaining():
    """Return number of seconds until token expiry."""
    try:
        with open(token_path, "r", encoding="utf-8") as token_file:
            token_data = json.load(token_file)
        expiry_str = token_data.get("expiry", "")
        if not expiry_str:
            return 0
        expiry_dt = datetime.fromisoformat(expiry_str.replace("Z", "+00:00"))
        return (expiry_dt - datetime.now(timezone.utc)).total_seconds()
    except:
        return 0

def is_token_expired():
    return time_remaining() <= 0

def refresh_token():
    """Refresh the access token using the refresh token."""
    try:
        with open(token_path, "r", encoding="utf-8") as token_file:
            token_data = json.load(token_file)

        refresh_token_val = token_data.get("refresh_token")
        client_id = token_data.get("client_id")
        client_secret = token_data.get("client_secret")

        if not refresh_token_val or not client_id or not client_secret:
            raise Exception("Refresh token, client ID, or client secret is missing.")

        payload = {
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token_val,
            "grant_type": "refresh_token",
        }
        response = requests.post(token_uri, data=payload)

        if response.status_code == 200:
            new_token_data = response.json()
            token_data["token"] = new_token_data["access_token"]

            # Calculate and save the new expiry time
            expiry_time = datetime.now(timezone.utc) + timedelta(seconds=new_token_data["expires_in"])
            token_data["expiry"] = expiry_time.isoformat()

            with open(token_path, "w", encoding="utf-8") as token_file:
                json.dump(token_data, token_file)

            print("TOKEN_REFRESHED")
        else:
            raise Exception(f"Failed to refresh token: {response.json()}")

    except Exception as e:
        print(f"TOKEN_REFRESH_FAILED: {e}")
        sys.exit(1)

def ensure_token_valid():
    remaining = time_remaining()
    if remaining < 900:  # 900 seconds = 15 minutes
        print(f"Token expires soon (in {int(remaining/60)} minutes). Refreshing...")
        refresh_token()

def upload_photo(file_path, album_id):
    """Upload a single photo, ensuring token is valid first."""
    ensure_token_valid()

    try:
        # Load the credentials from token.json
        with open(token_path, "r", encoding="utf-8") as token_file:
            token_data = json.load(token_file)
        creds = Credentials(
            token=token_data["token"],
            refresh_token=token_data.get("refresh_token"),
            token_uri=token_uri,
            client_id=token_data.get("client_id"),
            client_secret=token_data.get("client_secret")
        )

        # Build Photos Library API service
        discovery_doc = requests.get(discovery_url).text
        service = build_from_document(discovery_doc, credentials=creds)

        # 1) Upload the file (get upload token)
        headers = {
            'Authorization': f'Bearer {token_data["token"]}',
            'Content-type': 'application/octet-stream',
            'X-Goog-Upload-File-Name': os.path.basename(file_path),
            'X-Goog-Upload-Protocol': 'raw',
        }
        with open(file_path, 'rb') as f:
            file_bytes = f.read()
        upload_response = requests.post(upload_url, headers=headers, data=file_bytes)
        upload_token = upload_response.text

        # 2) Create media item in the album
        media_item_body = {
            "newMediaItems": [{
                "description": "",
                "simpleMediaItem": {
                    "uploadToken": upload_token
                }
            }],
            "albumId": album_id
        }

        creation_response = service.mediaItems().batchCreate(body=media_item_body).execute()
        print(json.dumps({
            "status": "Upload successful",
            "response": creation_response
        }))

    except Exception as e:
        error_output = {
            "status": "Upload failed",
            "error": str(e)
        }
        print(json.dumps(error_output))

if __name__ == "__main__":
    # Usage: python upload_script.py /path/to/image.jpg
    if len(sys.argv) < 2:
        error_output = {
            "status": "Error",
            "error": "File path must be provided as a command-line argument."
        }
        print(json.dumps(error_output))
        sys.exit(1)

    file_to_upload = sys.argv[1]

    # Read album ID from file
    try:
        with open(album_id_file, "r", encoding="utf-8") as f:
            album_id = f.read().strip()
    except:
        error_output = {
            "status": "Error",
            "error": "No album_id.txt found. Please create an album first."
        }
        print(json.dumps(error_output))
        sys.exit(1)

    upload_photo(file_to_upload, album_id)
