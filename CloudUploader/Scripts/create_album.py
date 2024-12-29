#!/usr/bin/env python3
import os
import json
import sys
import requests
from google.oauth2.credentials import Credentials

def create_album(album_name):
    app_support_dir = os.path.expanduser("~/Library/Application Support/CloudUploader")
    token_path = os.path.join(app_support_dir, "token.json")

    if not os.path.exists(token_path):
        print("Error: Token file not found. Please authenticate first.")
        sys.exit(1)

    creds = Credentials.from_authorized_user_file(token_path)

    if not creds or not creds.valid:
        print("Error: Invalid or expired token.")
        sys.exit(1)

    headers = {
        "Authorization": f"Bearer {creds.token}",
        "Content-Type": "application/json"
    }

    data = {
        "album": {
            "title": album_name
        }
    }

    response = requests.post("https://photoslibrary.googleapis.com/v1/albums", headers=headers, json=data)

    if response.status_code == 200:
        album_info = response.json()
        # Optionally, save album info to album_info.json
        album_info_path = os.path.join(app_support_dir, "album_info.json")
        with open(album_info_path, 'w') as f:
            json.dump({
                "album_name": album_info["album"]["title"],
                "shareable_url": f"https://photos.google.com/lr/photo/{album_info['album']['id']}"
            }, f, indent=4)
        
        output = {
            "status": "All album information saved successfully.",
            "shareable_url": f"https://photos.google.com/lr/photo/{album_info['album']['id']}"
        }
        print(json.dumps(output))
    else:
        try:
            error_info = response.json()
            error_message = error_info.get("error", {}).get("message", "Unknown error.")
        except:
            error_message = "Unknown error."
        print(f"Error: {error_message}")
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Error: No album name provided.")
        sys.exit(1)
    
    album_name = sys.argv[1]
    create_album(album_name)
