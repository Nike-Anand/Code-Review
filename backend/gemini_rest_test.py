import os
import sys
import json
import requests
from dotenv import load_dotenv

load_dotenv()

def main():
    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not key:
        print('No GEMINI_API_KEY or GOOGLE_API_KEY found')
        return 2

    url = f'https://generativelanguage.googleapis.com/v1beta2/models?key={key}'
    try:
        r = requests.get(url, timeout=15)
    except Exception as e:
        print('Request failed:', e)
        return 1

    print('HTTP', r.status_code)
    try:
        data = r.json()
    except Exception:
        print('Non-JSON response:')
        print(r.text[:1000])
        return 1

    print(json.dumps(data, indent=2))
    return 0

if __name__ == '__main__':
    sys.exit(main())
