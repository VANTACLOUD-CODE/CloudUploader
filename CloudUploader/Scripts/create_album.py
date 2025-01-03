#!/usr/bin/env python3
import os
import json
import sys
import warnings
import requests
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build_from_document

# Suppress all warnings to stderr
warnings.filterwarnings('ignore')

# Fixed token path to match upload_script.py
token_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
discovery_url = "https://photoslibrary.googleapis.com/$discovery/rest?version=v1"

def create_album(album_name):
    try:
        # Load token data
        with open(token_path, 'r') as token_file:
            token_data = json.load(token_file)

        # Create credentials object
        creds = Credentials(
            token=token_data.get('token'),
            refresh_token=token_data.get('refresh_token'),
            token_uri=token_data.get('token_uri'),
            client_id=token_data.get('client_id'),
            client_secret=token_data.get('client_secret'),
            scopes=token_data.get('scopes')
        )

        # Get the discovery document
        response = requests.get(discovery_url)
        if not response.ok:
            print(json.dumps({"error": f"Failed to fetch discovery document: {response.status_code}"}))
            sys.stdout.flush()
            return

        # Build the service
        service = build_from_document(response.json(), credentials=creds)
        
        try:
            # Create the album
            create_response = service.albums().create(
                body={'album': {'title': album_name}}
            ).execute()
            
            album_id = create_response.get('id')
            if not album_id:
                print(json.dumps({"error": "Failed to create album"}))
                sys.stdout.flush()
                return
            
            # Share the album
            share_response = service.albums().share(
                albumId=album_id,
                body={
                    'sharedAlbumOptions': {
                        'isCollaborative': True,
                        'isCommentable': True
                    }
                }
            ).execute()
            
            if 'shareInfo' not in share_response or 'shareableUrl' not in share_response['shareInfo']:
                print(json.dumps({"error": "Failed to share album"}))
                sys.stdout.flush()
                return
            
            output = {
                "albums": [{
                    "id": album_id,
                    "title": create_response.get('title'),
                    "shareableUrl": share_response['shareInfo']['shareableUrl']
                }]
            }
            print(json.dumps(output))
            sys.stdout.flush()
            
        except Exception as e:
            print(json.dumps({"error": f"API Error: {str(e)}"}))
            sys.stdout.flush()
            
    except Exception as e:
        print(json.dumps({"error": f"Script Error: {str(e)}"}))
        sys.stdout.flush()

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print(json.dumps({"error": "Album name required"}))
        sys.exit(1)
    create_album(sys.argv[1])
