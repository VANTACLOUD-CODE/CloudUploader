#!/usr/bin/env python3
import os
import json
import sys
import warnings
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build_from_document

# Suppress all warnings
warnings.filterwarnings("ignore", category=Warning)

def get_albums():
    try:
        token_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
        discovery_url = "https://photoslibrary.googleapis.com/$discovery/rest?version=v1"
        
        with open(token_path, 'r') as token_file:
            token_data = json.load(token_file)
        
        creds = Credentials(
            token=token_data.get('token'),
            refresh_token=token_data.get('refresh_token'),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=token_data.get('client_id'),
            client_secret=token_data.get('client_secret'),
            scopes=['https://www.googleapis.com/auth/photoslibrary',
                   'https://www.googleapis.com/auth/photoslibrary.sharing']
        )
        
        if not creds.valid:
            if creds.refresh_token:
                creds.refresh(Request())
                token_data['token'] = creds.token
                with open(token_path, 'w') as token_file:
                    json.dump(token_data, token_file)
            else:
                print(json.dumps({"error": "Invalid credentials - please re-authenticate"}), flush=True)
                return
        
        service = build_from_document(discovery_url, credentials=creds)
        
        try:
            shared_response = service.sharedAlbums().list(pageSize=50).execute()
            shared_albums = shared_response.get('sharedAlbums', [])
            
            album_info = []
            for album in shared_albums:
                if 'shareInfo' in album and 'shareableUrl' in album['shareInfo']:
                    album_info.append({
                        "title": album.get('title', ''),
                        "id": album.get('id', ''),
                        "shareableUrl": album['shareInfo']['shareableUrl']
                    })
            
            print(json.dumps({"albums": album_info}), flush=True)
            
        except Exception as e:
            print(json.dumps({"error": str(e)}), flush=True)
            
    except Exception as e:
        print(json.dumps({"error": f"Script Error: {str(e)}"}), flush=True)

if __name__ == '__main__':
    get_albums()