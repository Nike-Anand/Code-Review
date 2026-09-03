import os
import sys
try:
    from google import genai
except Exception as e:
    print('google.generative-ai SDK not installed:', e)
    sys.exit(1)

def main():
    key = os.environ.get('GEMINI_API_KEY') or os.environ.get('GOOGLE_API_KEY')
    if not key:
        print('No GEMINI_API_KEY or GOOGLE_API_KEY found in environment or .env')
        return 2

    try:
        genai.configure(api_key=key)
        client = genai.Client()
        interaction = client.interactions.create(
            model=os.environ.get('GEMINI_MODEL', 'gemini-3.7-flash'),
            input='Explain how AI works in a few words'
        )
        print('Model output:')
        print(interaction.output_text)
        return 0
    except Exception as e:
        print('Gemini call failed:', str(e))
        return 1

if __name__ == '__main__':
    sys.exit(main())
