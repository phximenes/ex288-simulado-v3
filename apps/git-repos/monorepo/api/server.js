const http = require('http');
http.createServer((req, res) => {
  if (req.url === '/healthz') { res.writeHead(200); return res.end('ok\n'); }
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ app: 'monorepo-api', message: process.env.APP_MESSAGE || 'hello' }) + '\n');
}).listen(process.env.PORT || 8080);
