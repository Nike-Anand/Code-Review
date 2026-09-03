import os
import sys
from dotenv import load_dotenv

load_dotenv()

def main():
    try:
        from google import genai
    except Exception as e:
        print('google-genai SDK not installed:', e)
        return 2

    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    # Some genai package versions accept an api_key in the Client constructor.
    if key:
        try:
            client = genai.Client(api_key=key)
        except TypeError:
            # Fallback: no api_key param, rely on env var or default auth
            client = genai.Client()
    else:
        client = genai.Client()

    model = os.environ.get('GEMINI_MODEL', 'gemini-3.7-flash')
    prompt = 'Explain in one sentence: what is AI?'
    print('Calling Interactions API with model', model)
    try:
        interaction = client.interactions.create(model=model, input=prompt)
        print('Status:', interaction.status)
        print('Output text:')
        print(interaction.output_text)
        return 0
    except Exception as e:
        print('Interaction failed:', type(e), str(e))
        return 1

if __name__ == '__main__':
    sys.exit(main())
