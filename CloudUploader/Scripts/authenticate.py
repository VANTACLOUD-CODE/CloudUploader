#!/usr/bin/env python3
import os
import json
import sys
from google_auth_oauthlib.flow import InstalledAppFlow
from google.oauth2.credentials import Credentials

# Define the Application Support path
app_support_dir = os.path.expanduser("~/Library/Application Support/CloudUploader")

# Ensure Application Support directory exists
os.makedirs(app_support_dir, exist_ok=True)

# Paths
credentials_path = os.path.join(app_support_dir, "credentials.json")
token_path = os.path.join(app_support_dir, "token.json")

# Define the required scopes for Google Photos API
SCOPES = [
    'https://www.googleapis.com/auth/photoslibrary',
    'https://www.googleapis.com/auth/photoslibrary.sharing',
    'https://www.googleapis.com/auth/photoslibrary.appendonly'
]

def authenticate():
    """Authenticate and save the token."""
    try:
        # Ensure credentials file exists
        if not os.path.exists(credentials_path):
            raise FileNotFoundError(f"Credentials file not found at {credentials_path}. Please ensure it exists.")

        # Set up the OAuth flow
        flow = InstalledAppFlow.from_client_secrets_file(credentials_path, SCOPES)

        # Use a local server to handle the authentication flow automatically
        creds = flow.run_local_server(port=0, access_type="offline", prompt="consent")

        # Save the token after successful authentication
        with open(token_path, 'w') as token_file:
            token_file.write(creds.to_json())

        # Output JSON for Swift to parse
        output = {
            "status": "Authentication successful",
            "token": creds.token
        }
        print(json.dumps(output))

    except Exception as e:
        error_output = {
            "status": "Authentication failed",
            "error": str(e)
        }
        print(json.dumps(error_output))
        sys.exit(1)

if __name__ == '__main__':
    authenticate()
