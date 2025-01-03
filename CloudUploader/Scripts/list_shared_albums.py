#!/usr/bin/env python3
import os
import json
import sys
from google.oauth2.credentials import Credentials
from googleapiclient.discovery import build

def get_albums():
    try:
        token_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
        
        with open(token_path, 'r') as token_file:
            token_data = json.load(token_file)
        
        creds = Credentials(
            token=token_data.get('token'),
            refresh_token=token_data.get('refresh_token'),
            token_uri="https://oauth2.googleapis.com/token",
            client_id=token_data.get('client_id'),
            client_secret=token_data.get('client_secret')
        )
        
        service = build('photoslibrary', 'v1', credentials=creds, static_discovery=False)
        
        try:
            # Get all albums first
            response = service.albums().list(pageSize=50).execute()
            all_albums = response.get('albums', [])
            
            # Get shared albums
            shared_response = service.sharedAlbums().list(pageSize=50).execute()
            shared_albums = shared_response.get('sharedAlbums', [])
            
            album_info = []
            
            # Process all albums that have shareInfo
            for album in all_albums + shared_albums:
                if 'shareInfo' in album and 'shareableUrl' in album['shareInfo']:
                    if not any(a['id'] == album['id'] for a in album_info):
                        album_info.append({
                            "title": album.get('title', ''),
                            "id": album.get('id', ''),
                            "shareableUrl": album['shareInfo']['shareableUrl']
                        })
            
            print(json.dumps({"albums": album_info, "count": len(album_info)}))
            
        except Exception as e:
            print(json.dumps({"error": str(e)}))
            
    except Exception as e:
        print(json.dumps({"error": str(e)}))

if __name__ == '__main__':
    get_albums()