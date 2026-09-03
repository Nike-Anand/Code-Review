import { GoogleGenAI } from '@google/genai';
import dotenv from 'dotenv';
dotenv.config();

const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
if (!apiKey) {
  console.error('No GEMINI_API_KEY or GOOGLE_API_KEY found in environment or .env');
  process.exit(1);
}

const client = new GoogleGenAI({ apiKey });

try {
  async function main(){
    const candidates = [process.env.GEMINI_MODEL, 'gemini-3.7-flash', 'gemini-2.0-flash-001', 'text-bison-001', 'chat-bison-001'].filter(Boolean);
    let lastErr = null;
    for (const model of candidates) {
      try {
        console.log('Trying model', model);
        const resp = await client.models.generateContent({ model, contents: 'Explain how AI works in a few words' });
        let out = null;
        if (resp) {
          if (typeof resp.text === 'function') out = await resp.text();
          else if (resp.text) out = resp.text;
          else if (resp.output && typeof resp.output === 'string') out = resp.output;
          else out = JSON.stringify(resp, null, 2);
        }
        console.log('Model output (model=' + model + '):');
        console.log(out);
        return;
      } catch (e) {
        lastErr = e;
        console.warn('Model', model, 'failed:', e?.response?.data || e.message || e);
      }
    }
    console.error('All model attempts failed:', lastErr?.response?.data || lastErr?.message || lastErr);
    process.exit(1);
  }

  await main();
} catch (e) {
  console.error('Gemini SDK call failed:', e?.response?.data || e.message || e);
  process.exit(1);
}
