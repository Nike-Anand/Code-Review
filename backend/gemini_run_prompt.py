import os
import sys
from dotenv import load_dotenv

load_dotenv()

def main():
    try:
        from google import genai
    except Exception as e:
        print('SDK_MISSING:' + str(e))
        return 2

    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    model = os.environ.get('GEMINI_MODEL', 'gemini-3.6-flash')
    # debug print to help diagnose model selection
    print('MODEL:' + str(model))
    if key:
        try:
            client = genai.Client(api_key=key)
        except TypeError:
            client = genai.Client()
    else:
        client = genai.Client()

    if len(sys.argv) > 1:
        prompt = sys.argv[1]
    else:
        prompt = sys.stdin.read()

    try:
        interaction = client.interactions.create(model=model, input=prompt)
        out = interaction.output_text or ''
        # Ensure single-line output for easy parsing
        print(out)
        return 0
    except Exception as e:
        print('ERROR:' + str(e))
        return 1

if __name__ == '__main__':
    sys.exit(main())
