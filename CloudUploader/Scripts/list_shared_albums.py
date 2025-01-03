#!/usr/bin/env python3
import os
import json
import sys
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

def get_albums():
    output_file = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/albums_cache.json"
    token_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
    
    try:
        if not os.path.exists(token_path):
            save_result({"error": "Token file not found"}, output_file)
            return

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

        if not creds.valid and creds.refresh_token:
            creds.refresh(Request())
            token_data['token'] = creds.token
            with open(token_path, 'w') as token_file:
                json.dump(token_data, token_file)

        service = build('photoslibrary', 'v1', credentials=creds, static_discovery=False)
        
        try:
            print("Debug - Fetching albums...", file=sys.stderr)
            all_albums = []
            page_token = None
            
            while True:
                results = service.sharedAlbums().list(
                    pageSize=50,
                    pageToken=page_token
                ).execute()
                
                if 'sharedAlbums' in results:
                    print(f"Debug - Found {len(results['sharedAlbums'])} albums in current page", file=sys.stderr)
                    all_albums.extend(results['sharedAlbums'])
                
                page_token = results.get('nextPageToken')
                if not page_token:
                    break
            
            print(f"Debug - Total albums found: {len(all_albums)}", file=sys.stderr)
            
            album_info = []
            for album in all_albums:
                album_info.append({
                    "title": album.get('title', ''),
                    "id": album.get('id', ''),
                    "shareableUrl": album.get('shareInfo', {}).get('shareableUrl', ''),
                    "isWriteable": album.get('shareInfo', {}).get('isWriteable', False),
                    "totalMediaItems": album.get('mediaItemsCount', '0')
                })
            
            save_result({"albums": album_info}, output_file)
            
        except HttpError as error:
            save_result({"error": f"API Error: {str(error)}"}, output_file)
            
    except Exception as e:
        save_result({"error": f"Script Error: {str(e)}"}, output_file)

def save_result(data, output_file):
    with open(output_file, 'w') as f:
        json.dump(data, f, indent=2)
        print(f"Debug - Saved results to {output_file}", file=sys.stderr)

if __name__ == "__main__":
    get_albums()