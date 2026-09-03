const axios = require('axios');
(async ()=> {
  try {
    const r = await axios.post('http://localhost:3000/api/request-changes', { pr_link: 'https://github.com/Nike-Anand/demo-code-review-mtgd0f2d/pull/3', comment: 'please fix' }, { headers: { 'Content-Type': 'application/json' } });
    console.log('STATUS', r.status);
    console.log(JSON.stringify(r.data, null, 2));
  } catch (e) {
    if (e.response) {
      console.log('STATUS', e.response.status);
      console.log(JSON.stringify(e.response.data, null, 2));
    } else {
      console.error('ERROR', e.message);
    }
  }
})();
