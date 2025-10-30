# 远程主机设置指南

本文档介绍如何设置 RealDesk 的远程主机端。

## 使用 remotecontrol 作为主机

remotecontrol 是一个基于 C++ 和 WebRTC 的远程控制主机程序。

### 编译 remotecontrol

```bash
cd d:/WorkSpaces/momo-project/remotecontrol/remotecontrol
python3 run.py build windows_x86_64
```

### 配置参数

```bash
# 基本配置
./remotecontrol \
  --use-ayame \
  --ayame-signaling-url ws://localhost:3000/signaling \
  --ayame-room-id test-room \
  --video-device 0 \
  --resolution 1920x1080 \
  --framerate 60 \
  --video-codec VP8 \
  --video-bitrate 5000
```

### 完整参数说明

#### 信令配置
- `--use-ayame`: 使用 Ayame 信令服务器
- `--ayame-signaling-url <url>`: 信令服务器 WebSocket URL
- `--ayame-room-id <id>`: 房间 ID
- `--ayame-client-id <id>`: 客户端 ID（可选）
- `--ayame-signaling-key <key>`: 信令密钥（可选）

#### 视频配置
- `--video-device <id>`: 视频设备 ID（0 表示屏幕捕获）
- `--resolution <WxH>`: 分辨率，如 1920x1080
- `--framerate <fps>`: 帧率，如 30 或 60
- `--video-codec <codec>`: 编解码器 (H264, VP8, VP9)
- `--video-bitrate <kbps>`: 视频码率（kbps）

#### 音频配置
- `--no-audio`: 禁用音频
- `--audio-codec <codec>`: 音频编解码器 (OPUS, PCMU, PCMA)
- `--audio-bitrate <kbps>`: 音频码率（kbps）

#### 性能配置
- `--hw-mjpeg-decoder`: 启用硬件 MJPEG 解码
- `--use-native`: 使用原生编码器
- `--force-i420`: 强制使用 I420 格式

### 示例配置

#### 低延迟游戏配置
```bash
./remotecontrol \
  --use-ayame \
  --ayame-signaling-url ws://localhost:3000/signaling \
  --ayame-room-id gaming-room \
  --resolution 1920x1080 \
  --framerate 60 \
  --video-codec H264 \
  --video-bitrate 8000 \
  --hw-mjpeg-decoder \
  --use-native
```

#### 低带宽办公配置
```bash
./remotecontrol \
  --use-ayame \
  --ayame-signaling-url ws://localhost:3000/signaling \
  --ayame-room-id office-room \
  --resolution 1280x720 \
  --framerate 30 \
  --video-codec VP8 \
  --video-bitrate 2000
```

#### 高质量设计配置
```bash
./remotecontrol \
  --use-ayame \
  --ayame-signaling-url ws://localhost:3000/signaling \
  --ayame-room-id design-room \
  --resolution 2560x1440 \
  --framerate 30 \
  --video-codec H264 \
  --video-bitrate 10000
```

## 使用 OBS + WebRTC 插件

### 安装 OBS

下载并安装 OBS Studio：https://obsproject.com/

### 安装 WebRTC 插件

```bash
# 下载 obs-webrtc 插件
# https://github.com/CoSMoSoftware/obs-webrtc

# 将插件复制到 OBS 插件目录
# Windows: C:\Program Files\obs-studio\obs-plugins\64bit\
# macOS: /Library/Application Support/obs-studio/plugins/
# Linux: ~/.config/obs-studio/plugins/
```

### 配置 OBS

1. **添加源**
   - 显示器捕获
   - 窗口捕获
   - 游戏捕获

2. **设置输出**
   - 工具 → WebRTC 设置
   - 信令服务器：`ws://localhost:3000/signaling`
   - 房间 ID：`obs-room`

3. **开始推流**
   - 点击"开始流式传输"

## 使用 GStreamer + WebRTC

### 安装 GStreamer

```bash
# Ubuntu/Debian
sudo apt-get install gstreamer1.0-tools \
  gstreamer1.0-plugins-base \
  gstreamer1.0-plugins-good \
  gstreamer1.0-plugins-bad \
  gstreamer1.0-plugins-ugly \
  gstreamer1.0-libav

# 安装 WebRTC 插件
sudo apt-get install gstreamer1.0-nice \
  gstreamer1.0-plugins-bad-apps
```

### GStreamer Pipeline 示例

```bash
# 屏幕捕获 + WebRTC
gst-launch-1.0 \
  ximagesrc use-damage=0 \
  ! video/x-raw,framerate=30/1 \
  ! videoconvert \
  ! vp8enc deadline=1 \
  ! rtpvp8pay \
  ! webrtcbin name=sendrecv \
  ! fakesink
```

## 使用 FFmpeg + WebRTC

### 安装 FFmpeg

```bash
# Ubuntu/Debian
sudo apt-get install ffmpeg

# Windows
# 下载预编译版本: https://ffmpeg.org/download.html
```

### FFmpeg 推流示例

```bash
# 屏幕捕获
ffmpeg -f gdigrab -framerate 30 -i desktop \
  -vcodec libvpx -quality realtime -cpu-used 0 \
  -b:v 2M -qmin 10 -qmax 42 \
  -maxrate 2M -bufsize 4M \
  -an -f rtp rtp://localhost:5004

# 需要配合 WebRTC 网关使用
```

## 自定义远程主机

### Node.js 示例

```javascript
// host.js
const { RTCPeerConnection, RTCSessionDescription } = require('wrtc');
const WebSocket = require('ws');

const signalingUrl = 'ws://localhost:3000/signaling';
const roomId = 'custom-room';

let ws;
let pc;

// 连接信令服务器
function connectSignaling() {
  ws = new WebSocket(signalingUrl);
  
  ws.on('open', () => {
    console.log('Connected to signaling server');
    ws.send(JSON.stringify({
      type: 'join',
      roomId: roomId
    }));
  });
  
  ws.on('message', async (data) => {
    const message = JSON.parse(data);
    await handleSignalingMessage(message);
  });
}

// 创建 PeerConnection
function createPeerConnection() {
  pc = new RTCPeerConnection({
    iceServers: [
      { urls: 'stun:stun.l.google.com:19302' }
    ]
  });
  
  pc.onicecandidate = (event) => {
    if (event.candidate) {
      ws.send(JSON.stringify({
        type: 'candidate',
        candidate: event.candidate.candidate,
        sdpMid: event.candidate.sdpMid,
        sdpMLineIndex: event.candidate.sdpMLineIndex
      }));
    }
  };
  
  // 添加视频轨道（这里需要实现屏幕捕获）
  // const stream = await getDisplayMedia();
  // stream.getTracks().forEach(track => pc.addTrack(track, stream));
}

// 处理信令消息
async function handleSignalingMessage(message) {
  switch (message.type) {
    case 'offer':
      await pc.setRemoteDescription(new RTCSessionDescription({
        type: 'offer',
        sdp: message.sdp
      }));
      const answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      ws.send(JSON.stringify({
        type: 'answer',
        sdp: answer.sdp
      }));
      break;
    
    case 'candidate':
      await pc.addIceCandidate({
        candidate: message.candidate,
        sdpMid: message.sdpMid,
        sdpMLineIndex: message.sdpMLineIndex
      });
      break;
  }
}

connectSignaling();
createPeerConnection();
```

### Python 示例

```python
# host.py
import asyncio
import json
from aiortc import RTCPeerConnection, RTCSessionDescription, VideoStreamTrack
from aiortc.contrib.media import MediaPlayer
import websockets

class ScreenCaptureTrack(VideoStreamTrack):
    """自定义屏幕捕获轨道"""
    def __init__(self):
        super().__init__()
        # 实现屏幕捕获逻辑
        
    async def recv(self):
        # 返回视频帧
        pass

async def run():
    # 连接信令服务器
    async with websockets.connect('ws://localhost:3000/signaling') as ws:
        # 发送 join
        await ws.send(json.dumps({
            'type': 'join',
            'roomId': 'python-room'
        }))
        
        # 创建 PeerConnection
        pc = RTCPeerConnection()
        
        # 添加视频轨道
        screen_track = ScreenCaptureTrack()
        pc.addTrack(screen_track)
        
        # 处理 ICE 候选
        @pc.on("icecandidate")
        async def on_icecandidate(candidate):
            if candidate:
                await ws.send(json.dumps({
                    'type': 'candidate',
                    'candidate': candidate.candidate,
                    'sdpMid': candidate.sdpMid,
                    'sdpMLineIndex': candidate.sdpMLineIndex
                }))
        
        # 处理消息
        async for message in ws:
            data = json.loads(message)
            
            if data['type'] == 'offer':
                await pc.setRemoteDescription(RTCSessionDescription(
                    sdp=data['sdp'],
                    type='offer'
                ))
                answer = await pc.createAnswer()
                await pc.setLocalDescription(answer)
                await ws.send(json.dumps({
                    'type': 'answer',
                    'sdp': pc.localDescription.sdp
                }))

if __name__ == '__main__':
    asyncio.run(run())
```

## 性能优化建议

### 1. 视频编码优化

- **使用硬件编码器**：H.264/H.265 硬件编码
- **调整编码参数**：平衡质量和延迟
- **适应网络带宽**：动态调整码率

### 2. 网络优化

- **使用 UDP**：低延迟传输
- **启用 TURN 中继**：穿透 NAT
- **QoS 标记**：优先处理实时流量

### 3. 系统优化

- **提高进程优先级**：确保实时性能
- **禁用不必要服务**：减少 CPU 占用
- **使用高性能电源模式**：最大化性能

## 故障排除

### 视频不流畅

1. 降低分辨率和帧率
2. 检查 CPU 和 GPU 使用率
3. 优化编码器设置
4. 检查网络带宽

### 连接失败

1. 检查防火墙设置
2. 确认信令服务器可达
3. 配置 TURN 服务器
4. 查看错误日志

### 输入延迟

1. 减少视频缓冲
2. 使用相对鼠标模式
3. 优化数据通道设置
4. 检查网络延迟

## 监控和日志

### 启用详细日志

```bash
# remotecontrol
./remotecontrol --log-level debug ...
```

### 监控系统资源

```bash
# Linux
htop

# Windows
perfmon
```

### WebRTC 内部统计

访问 `chrome://webrtc-internals/` 查看详细的 WebRTC 统计信息。

