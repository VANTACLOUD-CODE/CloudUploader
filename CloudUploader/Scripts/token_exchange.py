#!/usr/bin/env python3
import os
import sys
import json
import urllib.request
import urllib.parse
import urllib.error
from datetime import datetime, timezone, timedelta

def exchange_code(auth_code):
    try:
        # Get credentials path
        script_dir = os.path.dirname(os.path.abspath(__file__))
        credentials_path = os.path.abspath(os.path.join(script_dir, "../Resources/credentials.json"))
        token_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/token.json"
        
        with open(credentials_path, 'r') as f:
            creds = json.load(f)
            client_id = creds['installed']['client_id']
            client_secret = creds['installed']['client_secret']
        
        data = urllib.parse.urlencode({
            'client_id': client_id,
            'client_secret': client_secret,
            'code': auth_code,
            'redirect_uri': 'http://localhost',
            'grant_type': 'authorization_code'
        }).encode('utf-8')
        
        req = urllib.request.Request(
            'https://oauth2.googleapis.com/token',
            data=data,
            headers={'Content-Type': 'application/x-www-form-urlencoded'}
        )
        
        with urllib.request.urlopen(req) as response:
            token_info = json.loads(response.read().decode())
            
            # Calculate expiry time (3600 seconds from now)
            expiry_time = datetime.now(timezone.utc) + timedelta(seconds=token_info.get('expires_in', 900))
            
            # Ensure token directory exists
            os.makedirs(os.path.dirname(token_path), exist_ok=True)
            
            token_data = {
                'access_token': token_info['access_token'],
                'refresh_token': token_info.get('refresh_token'),
                'expiry': expiry_time.isoformat(),
                'token_type': token_info['token_type'],
                'client_id': client_id,
                'client_secret': client_secret
            }
            
            with open(token_path, 'w') as f:
                json.dump(token_data, f)
            
            print("success")
            return 0
            
    except Exception as e:
        print(f"error: {str(e)}")
        return 1

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("error: Authorization code required")
        sys.exit(1)
    
    auth_code = sys.argv[1]
    sys.exit(exchange_code(auth_code))
