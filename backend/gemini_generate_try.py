import os
import sys
import json
import requests
from dotenv import load_dotenv

load_dotenv()

KEY = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
if not KEY:
    print('No API key found')
    sys.exit(2)

MODELS = [
    'gemini-3.7-flash',
    'gemini-3.5',
    'gemini-1.0',
    'text-bison-001',
    'chat-bison-001',
]

def try_model(model):
    url = f'https://generativelanguage.googleapis.com/v1beta2/models/{model}:generate?key={KEY}'
    payload = {
        'prompt': { 'text': 'Explain in one sentence: what is AI?' },
        'maxOutputTokens': 64
    }
    try:
        r = requests.post(url, json=payload, timeout=15)
    except Exception as e:
        return {'model': model, 'error': str(e)}

    result = {'model': model, 'status': r.status_code}
    try:
        result['body'] = r.json()
    except Exception:
        result['body_text'] = r.text[:1000]
    return result

def main():
    results = []
    for m in MODELS:
        print('Trying', m)
        r = try_model(m)
        print(json.dumps(r, indent=2))
        results.append(r)
    return 0

if __name__ == '__main__':
    sys.exit(main())
