#!/usr/bin/env python3
import os
import json
import sys
import requests
import warnings

# Suppress urllib3 warnings
warnings.filterwarnings("ignore", category=Warning)

def verify_album():
    try:
        album_info_path = "/Volumes/CloudUploader/CloudUploader/CloudUploader/Resources/album_info.txt"
        
        # Check if file exists
        if not os.path.exists(album_info_path):
            print(json.dumps({"status": "error", "message": "Album info file not found"}))
            return
            
        # Read album info
        with open(album_info_path, 'r') as f:
            lines = f.read().strip().split('\n')
            if len(lines) < 2:
                print(json.dumps({"status": "error", "message": "Invalid album info format"}))
                return
            album_title = lines[0].strip()
            shareable_url = lines[1].strip()
        
        # Verify the shareable URL is accessible
        response = requests.head(shareable_url, allow_redirects=True, timeout=10)
        
        if response.status_code == 200:
            # Print to stderr for debugging
            print("Debug - URL check successful", file=sys.stderr)
            # Print JSON response to stdout
            print(json.dumps({"status": "success", "message": "Album is valid and accessible"}))
        else:
            print(json.dumps({"status": "error", "message": f"Album URL returned status code: {response.status_code}"}))
            
    except requests.RequestException as e:
        print(json.dumps({"status": "error", "message": f"Failed to verify album URL: {str(e)}"}))
    except Exception as e:
        print(json.dumps({"status": "error", "message": str(e)}))

if __name__ == '__main__':
    verify_album()
