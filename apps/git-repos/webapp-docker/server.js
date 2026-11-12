const http = require('http');
const fs = require('fs');
const path = require('path');
const dataDir = process.env.DATA_DIR || '/tmp';
fs.writeFileSync(path.join(dataDir, 'started'), new Date().toISOString());   // falha com EACCES se o diretorio nao for gravavel
http.createServer((req, res) => {
  if (req.url === '/healthz') { res.writeHead(200); return res.end('ok\n'); }
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ app: 'webapp-docker', uid: process.getuid(), dataDir }) + '\n');
}).listen(process.env.PORT || 8080);
