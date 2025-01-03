#!/usr/bin/env python3
import os
import json
import sys
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

# Define the required scopes - must match authenticate.py
SCOPES = [
    'https://www.googleapis.com/auth/photoslibrary',
    'https://www.googleapis.com/auth/photoslibrary.sharing',
    'https://www.googleapis.com/auth/photoslibrary.edit',
    'https://www.googleapis.com/auth/photoslibrary.readonly',
    'https://www.googleapis.com/auth/photoslibrary.appendonly'
]

def create_album(album_name):
    token_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"

    try:
        with open(token_path, 'r') as token_file:
            token_data = json.load(token_file)
        
        creds = Credentials(
            token=token_data.get('token'),
            refresh_token=token_data.get('refresh_token'),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=token_data.get('client_id'),
            client_secret=token_data.get('client_secret'),
            scopes=SCOPES
        )

        if not creds.valid:
            if creds.refresh_token:
                creds.refresh(Request())
                token_data['token'] = creds.token
                with open(token_path, 'w') as token_file:
                    json.dump(token_data, token_file)
            else:
                print(json.dumps({"error": "Invalid credentials - please re-authenticate"}))
                return

        service = build('photoslibrary', 'v1', credentials=creds, static_discovery=False)
        
        album_body = {
            'album': {'title': album_name}
        }
        response = service.albums().create(body=album_body).execute()
        
        album_id = response.get('id')
        album_title = response.get('title')
        
        share_response = service.albums().share(albumId=album_id).execute()
        
        output = {
            "albums": [{
                "id": album_id,
                "title": album_title,
                "shareableUrl": share_response.get('shareInfo', {}).get('shareableUrl', '')
            }]
        }
        print(json.dumps(output))

    except HttpError as e:
        error_content = json.loads(e.content.decode())
        error_message = error_content.get('error', {}).get('message', str(e))
        print(json.dumps({"error": error_message}))
    except Exception as e:
        print(json.dumps({"error": str(e)}))

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(json.dumps({"error": "Album name required"}))
    else:
        create_album(sys.argv[1])
