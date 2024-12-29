import json
import os
import datetime
from googleapiclient.discovery import build
from google.oauth2.credentials import Credentials

# Paths to token and resource files
TOKEN_FILE = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
ALBUM_ID_FILE = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_id.txt"
ALBUM_INFO_FILE = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_info.txt"

# Check if token is valid
def is_token_valid():
    if not os.path.exists(TOKEN_FILE):
        return False

    with open(TOKEN_FILE, "r") as token_file:
        token_data = json.load(token_file)

    expiry_time = token_data.get("expiry")
    if not expiry_time:
        return False

    # Check if token has expired
    expiry_datetime = datetime.datetime.fromisoformat(expiry_time)
    if datetime.datetime.now() >= expiry_datetime:
        return False

    return True

# Authenticate with Google Photos API using token
def authenticate_with_token():
    with open(TOKEN_FILE, "r") as token_file:
        token_data = json.load(token_file)

    return Credentials(
        token=token_data["access_token"],
        refresh_token=token_data.get("refresh_token"),
        token_uri="https://oauth2.googleapis.com/token",
        client_id=token_data.get("client_id"),
        client_secret=token_data.get("client_secret"),
        expiry=datetime.datetime.fromisoformat(token_data["expiry"])
    )

# Fetch all shared albums
def get_shared_albums(service):
    shared_albums = []
    next_page_token = None

    while True:
        response = service.albums().list(
            pageSize=50, pageToken=next_page_token
        ).execute()

        albums = response.get("albums", [])
        shared_albums.extend([
            {"id": album["id"], "name": album["title"], "link": album.get("productUrl", "")}
            for album in albums
        ])
        
        next_page_token = response.get("nextPageToken")
        if not next_page_token:
            break

    return shared_albums

# Save albums to files
def save_album_data(shared_albums):
    if not shared_albums:
        print("No shared albums found.")
        return

    # Write the first album's ID to album_id.txt
    with open(ALBUM_ID_FILE, "w") as album_id_file:
        album_id_file.write(shared_albums[0]["id"])

    # Write the first album's Name and Shareable Link to album_info.txt
    with open(ALBUM_INFO_FILE, "w") as album_info_file:
        album_info_file.write(f"{shared_albums[0]['name']}\n{shared_albums[0]['link']}")

    print("Album data saved successfully.")

# Main function
def main():
    if not is_token_valid():
        print(json.dumps({"error": "Authentication required"}))
        return

    # Authenticate and initialize the API
    credentials = authenticate_with_token()
    service = build("photoslibrary", "v1", credentials=credentials)

    # Fetch shared albums
    shared_albums = get_shared_albums(service)

    # Save album data
    save_album_data(shared_albums)

    # Output shared albums as JSON
    print(json.dumps(shared_albums, indent=2))

if __name__ == "__main__":
    main()
