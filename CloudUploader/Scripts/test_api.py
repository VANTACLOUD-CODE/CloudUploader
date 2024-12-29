#!/usr/bin/env python3
import os
import json
import sys
import requests
from google.oauth2.credentials import Credentials
from google.auth.transport.requests import Request

def check_api():
    """Check if Google Photos API is reachable."""
    try:
        # Simple reachability check using Google's API endpoint
        response = requests.get("https://photoslibrary.googleapis.com/v1/albums", timeout=5)
        if response.status_code == 200 or response.status_code == 401:
            # 200 OK indicates API is reachable
            # 401 Unauthorized indicates API is reachable but requires authentication
            output = {
                "status": "API reachable"
            }
        else:
            output = {
                "status": "API not reachable",
                "error": f"Status Code: {response.status_code}"
            }
        print(json.dumps(output))
    except Exception as e:
        output = {
            "status": "API not reachable",
            "error": str(e)
        }
        print(json.dumps(output))
        sys.exit(1)

def check_token():
    """Check if the token is valid, expired, or missing."""
    try:
        app_support_dir = os.path.expanduser("~/Library/Application Support/CloudUploader")
        token_path = os.path.join(app_support_dir, "token.json")

        if not os.path.exists(token_path):
            output = {
                "status": "TOKEN_MISSING"
            }
            print(json.dumps(output))
            sys.exit(0)

        creds = Credentials.from_authorized_user_file(token_path)

        if creds and creds.valid:
            if creds.expired and creds.refresh_token:
                creds.refresh(Request())
                # Save the refreshed token
                with open(token_path, 'w') as token_file:
                    token_file.write(creds.to_json())
                output = {
                    "status": "TOKEN_VALID",
                    "time_remaining": int((creds.expiry - creds.now).total_seconds() / 60)
                }
            else:
                output = {
                    "status": "TOKEN_VALID",
                    "time_remaining": int((creds.expiry - creds.now).total_seconds() / 60)
                }
        else:
            output = {
                "status": "TOKEN_EXPIRED"
            }

        print(json.dumps(output))

    except Exception as e:
        output = {
            "status": "ERROR",
            "error": str(e)
        }
        print(json.dumps(output))
        sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        # If no arguments, assume API status check
        check_api()
    else:
        command = sys.argv[1]
        if command == "check_token":
            check_token()
        else:
            print("Error: Unknown command.")
            sys.exit(1)
