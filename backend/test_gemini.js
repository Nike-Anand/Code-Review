const axios = require('axios');
require('dotenv').config();

const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-1.0';
const GEMINI_API_URL_BASE = process.env.GEMINI_API_URL || `https://generativelanguage.googleapis.com/v1beta2/models/`;

if (!GEMINI_API_KEY) {
  console.error('GEMINI_API_KEY not set in environment or .env');
  process.exit(1);
}

async function run() {
  const prompt = `You are a concise code reviewer.\nRespond in this format:\nVERDICT: [GREEN|YELLOW|RED]\nREASON: short explanation`;

  const candidates = [GEMINI_MODEL, 'text-bison-001', 'chat-bison-001'];
  let lastErr = null;
  for (const m of candidates) {
    const url = `${GEMINI_API_URL_BASE}${m}:generate`;
    try {
      const resp = await axios.post(`${url}?key=${GEMINI_API_KEY}`, { prompt: { text: prompt } }, { timeout: 120000 });
      const data = resp.data || {};
      const candidate = data.candidates?.[0]?.content || data.output?.[0]?.content || data.result?.content || data.text || JSON.stringify(data).slice(0,1000);
      console.log('Gemini model used:', m);
      console.log('Gemini response snippet:');
      console.log(candidate);
      return;
    } catch (err) {
      lastErr = err;
      const code = err.response ? err.response.status : err.message;
      console.warn(`Model ${m} failed:`, code);
      // try next
    }
  }
  console.error('All model attempts failed:', lastErr ? (lastErr.response ? `${lastErr.response.status} ${JSON.stringify(lastErr.response.data)}` : lastErr.message) : 'no error info');
  process.exit(1);
}
}

run();
