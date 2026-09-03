const axios = require('axios');

async function run() {
  try {
    const health = await axios.get('http://localhost:3000/health');
    console.log('health:', health.data);

    // Use a non-GitHub/GitLab URL to trigger the mock fetcher (avoids API tokens)
    const analyze = await axios.post('http://localhost:3000/api/analyze-pr', {
      pr_link: 'https://example.com/mock-pr/1'
    }, { headers: { 'Content-Type': 'application/json' }, timeout: 10000 });

    console.log('analyze:', analyze.data);
  } catch (err) {
    console.error('smoke test error:', err.message);
    if (err.response) console.error('status:', err.response.status, 'data:', err.response.data);
    process.exit(1);
  }
}

run();
