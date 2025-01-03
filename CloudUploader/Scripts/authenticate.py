#!/usr/bin/env python3
import os
import json
import sys
from datetime import datetime, timezone, timedelta
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials

# Define paths
script_dir = os.path.dirname(os.path.abspath(__file__))
credentials_path = os.path.abspath(os.path.join(script_dir, "../Resources/credentials.json"))
token_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"

# Define the required scopes for Google Photos API
SCOPES = [
    'https://www.googleapis.com/auth/photoslibrary',
    'https://www.googleapis.com/auth/photoslibrary.sharing',
    'https://www.googleapis.com/auth/photoslibrary.edit',
    'https://www.googleapis.com/auth/photoslibrary.readonly',
    'https://www.googleapis.com/auth/photoslibrary.appendonly'
]

def authenticate():
    try:
        if not os.path.exists(credentials_path):
            raise FileNotFoundError(f"Credentials file not found at {credentials_path}")

        flow = InstalledAppFlow.from_client_secrets_file(credentials_path, SCOPES)
        creds = flow.run_local_server(port=0, access_type="offline", prompt="consent")

        # Calculate expiry time
        expiry_time = datetime.now(timezone.utc) + timedelta(seconds=3600)
        
        # Get client details from credentials file
        with open(credentials_path, 'r') as f:
            client_config = json.load(f)['installed']

        token_data = {
            'token': creds.token,
            'refresh_token': creds.refresh_token,
            'expiry': expiry_time.isoformat(),
            'token_type': 'Bearer',
            'client_id': client_config['client_id'],
            'client_secret': client_config['client_secret'],
            'scopes': SCOPES
        }

        os.makedirs(os.path.dirname(token_path), exist_ok=True)
        
        with open(token_path, 'w') as f:
            json.dump(token_data, f)

        print(json.dumps({"status": "success", "token": creds.token}))
        return 0

    except Exception as e:
        print(json.dumps({"status": "error", "error": str(e)}))
        return 1

if __name__ == '__main__':
    sys.exit(authenticate())
