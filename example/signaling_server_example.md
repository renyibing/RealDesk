# 信令服务器配置示例

本文档提供了几种常见的信令服务器配置示例。

## Ayame 信令服务器

Ayame 是一个简单的 WebRTC 信令服务器，适合用于测试和小型部署。

### 安装

```bash
# 使用 Go 安装
go install github.com/OpenAyame/ayame/cmd/ayame@latest

# 或下载预编译二进制文件
# https://github.com/OpenAyame/ayame/releases
```

### 配置文件 (config.ini)

```ini
[ayame]
# 监听地址
listen_addr = 0.0.0.0

# 监听端口
listen_port = 3000

# 日志级别 (debug, info, warn, error)
log_level = info

# CORS 允许的来源
# allow_origin = *

# 认证 Webhook URL（可选）
# authn_webhook_url = http://localhost:8080/authn

# 断开连接 Webhook URL（可选）
# disconnect_webhook_url = http://localhost:8080/disconnect
```

### 启动

```bash
ayame --config config.ini
```

### 在 RealDesk 中使用

```
信令服务器地址: ws://localhost:3000/signaling
房间 ID: your-room-id
访问令牌: (留空或根据配置提供)
```

## 自定义信令服务器

### Node.js + Socket.IO 示例

```javascript
// server.js
const express = require('express');
const http = require('http');
const socketIO = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIO(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

const rooms = new Map();

io.on('connection', (socket) => {
  console.log('Client connected:', socket.id);

  socket.on('join', (data) => {
    const { roomId, clientCaps } = data;
    socket.join(roomId);
    
    if (!rooms.has(roomId)) {
      rooms.set(roomId, new Set());
    }
    rooms.get(roomId).add(socket.id);
    
    console.log(`Client ${socket.id} joined room ${roomId}`);
    
    // Broadcast to other clients in room
    socket.to(roomId).emit('user-joined', {
      clientId: socket.id,
      clientCaps
    });
  });

  socket.on('offer', (data) => {
    socket.to(data.roomId).emit('offer', {
      sdp: data.sdp,
      from: socket.id
    });
  });

  socket.on('answer', (data) => {
    socket.to(data.roomId).emit('answer', {
      sdp: data.sdp,
      from: socket.id
    });
  });

  socket.on('candidate', (data) => {
    socket.to(data.roomId).emit('candidate', {
      candidate: data.candidate,
      sdpMid: data.sdpMid,
      sdpMLineIndex: data.sdpMLineIndex,
      from: socket.id
    });
  });

  socket.on('disconnect', () => {
    console.log('Client disconnected:', socket.id);
    // Cleanup rooms
    rooms.forEach((clients, roomId) => {
      if (clients.has(socket.id)) {
        clients.delete(socket.id);
        socket.to(roomId).emit('user-left', { clientId: socket.id });
        if (clients.size === 0) {
          rooms.delete(roomId);
        }
      }
    });
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Signaling server running on port ${PORT}`);
});
```

### Python + WebSockets 示例

```python
# server.py
import asyncio
import json
import websockets
from collections import defaultdict

rooms = defaultdict(set)

async def handler(websocket, path):
    room_id = None
    try:
        async for message in websocket:
            data = json.loads(message)
            msg_type = data.get('type')
            
            if msg_type == 'join':
                room_id = data.get('roomId')
                rooms[room_id].add(websocket)
                print(f"Client joined room {room_id}")
                
            elif msg_type in ['offer', 'answer', 'candidate']:
                # Broadcast to other clients in the room
                if room_id:
                    for client in rooms[room_id]:
                        if client != websocket:
                            await client.send(message)
                            
            elif msg_type == 'ping':
                await websocket.send(json.dumps({'type': 'pong'}))
                
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        if room_id and websocket in rooms[room_id]:
            rooms[room_id].remove(websocket)
            print(f"Client left room {room_id}")

async def main():
    async with websockets.serve(handler, "0.0.0.0", 3000):
        print("Signaling server running on ws://0.0.0.0:3000")
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())
```

## ICE 服务器配置

### 公共 STUN 服务器

```dart
final iceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
  {'urls': 'stun:stun2.l.google.com:19302'},
  {'urls': 'stun:stun.stunprotocol.org:3478'},
];
```

### TURN 服务器配置

```dart
final iceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {
    'urls': 'turn:turn.example.com:3478',
    'username': 'your-username',
    'credential': 'your-password',
  },
  {
    'urls': 'turns:turn.example.com:5349',
    'username': 'your-username',
    'credential': 'your-password',
  },
];
```

### 使用 Coturn 搭建 TURN 服务器

```bash
# 安装 Coturn (Ubuntu)
sudo apt-get install coturn

# 编辑配置文件 /etc/turnserver.conf
listening-port=3478
tls-listening-port=5349
listening-ip=0.0.0.0
relay-ip=YOUR_SERVER_IP
external-ip=YOUR_PUBLIC_IP
realm=example.com
server-name=turn.example.com
lt-cred-mech
user=username:password
no-multicast-peers
no-cli
no-loopback-peers

# 启动服务
sudo systemctl start coturn
sudo systemctl enable coturn
```

## 完整部署示例

### Docker Compose 配置

```yaml
version: '3.8'

services:
  # Ayame 信令服务器
  signaling:
    image: openayame/ayame:latest
    ports:
      - "3000:3000"
    volumes:
      - ./config.ini:/app/config.ini
    command: ["--config", "/app/config.ini"]

  # Coturn TURN 服务器
  turn:
    image: coturn/coturn:latest
    network_mode: host
    volumes:
      - ./turnserver.conf:/etc/coturn/turnserver.conf
    command: ["-c", "/etc/coturn/turnserver.conf"]

  # RemoteControl 主机
  remote-host:
    build:
      context: ../remotecontrol
    depends_on:
      - signaling
    environment:
      - AYAME_SIGNALING_URL=ws://signaling:3000/signaling
      - AYAME_ROOM_ID=default-room
    command: >
      ./remotecontrol
      --use-ayame
      --ayame-signaling-url ws://signaling:3000/signaling
      --ayame-room-id default-room
      --video-codec VP8
```

### Nginx 反向代理

```nginx
# /etc/nginx/sites-available/realdesk
upstream signaling {
    server localhost:3000;
}

server {
    listen 80;
    server_name realdesk.example.com;

    # WebSocket 代理
    location /signaling {
        proxy_pass http://signaling;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # Timeouts
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}
```

### HTTPS 配置 (Let's Encrypt)

```bash
# 安装 Certbot
sudo apt-get install certbot python3-certbot-nginx

# 获取证书
sudo certbot --nginx -d realdesk.example.com

# 自动续期
sudo certbot renew --dry-run
```

更新后的 Nginx 配置会自动支持 WSS (WebSocket Secure)。

## 测试信令服务器

### 使用 websocat 测试

```bash
# 安装 websocat
cargo install websocat

# 连接到服务器
websocat ws://localhost:3000/signaling

# 发送 join 消息
{"type":"join","roomId":"test-room","clientCaps":{}}

# 发送 ping
{"type":"ping"}

# 应该收到 pong
{"type":"pong"}
```

### 使用 JavaScript 测试

```html
<!DOCTYPE html>
<html>
<head>
  <title>Signaling Test</title>
</head>
<body>
  <h1>Signaling Server Test</h1>
  <div id="status">Disconnected</div>
  <script>
    const ws = new WebSocket('ws://localhost:3000/signaling');
    
    ws.onopen = () => {
      document.getElementById('status').textContent = 'Connected';
      ws.send(JSON.stringify({
        type: 'join',
        roomId: 'test-room',
        clientCaps: {}
      }));
    };
    
    ws.onmessage = (event) => {
      console.log('Received:', event.data);
    };
    
    ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };
    
    ws.onclose = () => {
      document.getElementById('status').textContent = 'Disconnected';
    };
  </script>
</body>
</html>
```

## 安全建议

1. **使用 WSS (WebSocket Secure)**
   - 在生产环境中始终使用加密连接

2. **实现身份验证**
   - 使用访问令牌或 JWT
   - 配置 Webhook 进行用户验证

3. **限制连接数**
   - 防止 DoS 攻击
   - 设置每个房间的最大用户数

4. **启用 CORS**
   - 仅允许受信任的来源

5. **监控和日志**
   - 记录所有连接和错误
   - 设置告警机制

6. **定期更新**
   - 保持软件最新版本
   - 应用安全补丁

