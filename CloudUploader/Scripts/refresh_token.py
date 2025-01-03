#!/usr/bin/env python3
import os
import json
import sys
import urllib.request
import urllib.parse
from datetime import datetime, timezone, timedelta

# Must match authenticate.py
SCOPES = [
    'https://www.googleapis.com/auth/photoslibrary',
    'https://www.googleapis.com/auth/photoslibrary.sharing',
    'https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata'
]

def refresh_token():
    try:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        token_path = os.path.join(os.path.dirname(script_dir), "Resources", "token.json")
        credentials_path = os.path.join(os.path.dirname(script_dir), "Resources", "credentials.json")
        
        # Load existing token data
        with open(token_path, "r", encoding="utf-8") as token_file:
            token_data = json.load(token_file)
        
        # Load credentials
        with open(credentials_path, "r", encoding="utf-8") as cred_file:
            credentials = json.load(cred_file)

        refresh_token_val = token_data.get("refresh_token")
        client_id = credentials.get("installed", {}).get("client_id")
        client_secret = credentials.get("installed", {}).get("client_secret")

        if not all([refresh_token_val, client_id, client_secret]):
            raise Exception("Missing required credentials")

        # Prepare request data with scopes
        data = urllib.parse.urlencode({
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token_val,
            "grant_type": "refresh_token",
            "scope": " ".join(SCOPES)
        }).encode('utf-8')

        # Make request
        req = urllib.request.Request(
            "https://oauth2.googleapis.com/token",
            data=data,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )

        with urllib.request.urlopen(req) as response:
            new_token_data = json.loads(response.read().decode())
            
            # Update token data while preserving refresh_token
            token_data.update({
                "token": new_token_data["access_token"],
                "scopes": SCOPES,
                "expiry": (datetime.now(timezone.utc) + 
                          timedelta(seconds=new_token_data["expires_in"])).isoformat()
            })
            
            with open(token_path, "w", encoding="utf-8") as token_file:
                json.dump(token_data, token_file)
            
            print(json.dumps({"status": "success"}))
            sys.stdout.flush()

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.stdout.flush()

if __name__ == '__main__':
    refresh_token()
