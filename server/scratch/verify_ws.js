const WebSocket = require('ws');
const ws = new WebSocket('ws://localhost:8080/ws');

ws.on('open', () => {
  console.log('Connected to WebSocket');
});

ws.on('message', (data) => {
  const msg = JSON.parse(data);
  if (msg.type === 'heartbeat.tick') {
    console.log('Heartbeat:', JSON.stringify(msg.data, null, 2));
    process.exit(0);
  }
});

ws.on('error', (err) => {
  console.error('WS Error:', err);
  process.exit(1);
});

setTimeout(() => {
  console.log('Timeout waiting for heartbeat');
  process.exit(1);
}, 10000);
