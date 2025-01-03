#!/usr/bin/env python3
import os
import json
import sys
from google_auth_oauthlib.flow import InstalledAppFlow

# Complete set of scopes
SCOPES = [
    'https://www.googleapis.com/auth/photoslibrary',
    'https://www.googleapis.com/auth/photoslibrary.sharing',
    'https://www.googleapis.com/auth/photoslibrary.readonly',
    'https://www.googleapis.com/auth/photoslibrary.appendonly',
    'https://www.googleapis.com/auth/photoslibrary.readonly.appcreateddata',
    'https://www.googleapis.com/auth/photoslibrary.edit.appcreateddata'
]

def authenticate():
    try:
        # Get the path to the client secrets file
        script_dir = os.path.dirname(os.path.abspath(__file__))
        client_secrets_path = os.path.join(os.path.dirname(script_dir), "Resources", "client_secrets.json")
        token_path = os.path.join(os.path.dirname(script_dir), "Resources", "token.json")

        # Create the flow using the client secrets file
        flow = InstalledAppFlow.from_client_secrets_file(
            client_secrets_path,
            scopes=SCOPES
        )

        # Run the OAuth flow
        creds = flow.run_local_server(port=0)

        # Save the credentials with all scopes
        token_data = {
            'token': creds.token,
            'refresh_token': creds.refresh_token,
            'token_uri': creds.token_uri,
            'client_id': creds.client_id,
            'client_secret': creds.client_secret,
            'scopes': SCOPES,  # Save all requested scopes explicitly
            'expiry': creds.expiry.isoformat() if creds.expiry else None,
            'token_type': 'Bearer'
        }

        with open(token_path, 'w') as token_file:
            json.dump(token_data, token_file)

        print(json.dumps({"status": "success"}))
        sys.stdout.flush()

    except Exception as e:
        print(json.dumps({"error": str(e)}))
        sys.stdout.flush()

if __name__ == '__main__':
    authenticate()
