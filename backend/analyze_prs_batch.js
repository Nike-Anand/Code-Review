require('dotenv').config();
const axios = require('axios');
const PRS = [
  'https://github.com/Nike-Anand/demo-code-review-mtgd0f2d/pull/5',
  'https://github.com/Nike-Anand/demo-code-review-mtgd0f2d/pull/6',
  'https://github.com/Nike-Anand/demo-code-review-mtgd0f2d/pull/7',
  'https://github.com/Nike-Anand/demo-code-review-mtgd0f2d/pull/8',
  'https://github.com/Nike-Anand/demo-code-review-mtgd0f2d/pull/9',
  'https://github.com/Nike-Anand/demo-code-review-mtgd0f2d/pull/10'
];

(async ()=>{
  for (const pr of PRS) {
    try {
      console.log('\nAnalyzing', pr);
      const r = await axios.post('http://localhost:3000/api/analyze-pr', { pr_link: pr }, { timeout: 180000 });
      console.log('STATUS', r.status);
      console.log(JSON.stringify(r.data && { verdict: r.data.verdict, analysisSnippet: (r.data.analysis||'').slice(0,200), provider: r.data.provider, llm: r.data.llm }, null, 2));
    } catch (e) {
      if (e.response) {
        console.error('ERROR', e.response.status, JSON.stringify(e.response.data));
      } else {
        console.error('ERROR', e.message);
      }
    }
  }
})();
