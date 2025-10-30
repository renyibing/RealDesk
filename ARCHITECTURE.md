# RealDesk Architecture Documentation

## Overview

RealDesk is a cross-platform remote control client based on Flutter and WebRTC. This document describes the project's overall architecture and design decisions.

## Architecture Diagram

```

┌─────────────────────────────────────────────────────┐

│ UI Layer │

│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │

│ │ ConnectPage │ │ SessionPage │ │ Widgets │ │

│ └──────────────┘ └──────────────┘ └──────────────┘ │

└─────────────────────────────────────────────────────┘ 

▼
┌─────────────────────────────────────────────────────────┐
│Controller Layer│
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Mouse │ │ Keyboard │ │ Touch │ │
│ │ Controller │ │ Controller │ │ Controller │ │
│ └──────────────┘ └──────────────┘ └───────────────┘ │
└─────────────────────────────────────────────────────────┘ 
▼
┌─────────────────────────────────────────────────────────┐
│ WebRTC Layer │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ │
│ │ Peer │ │ Data │ │ Media │ │
│ │ Manager │ │ Channel │ │ Renderer │ │
│ └──────────────┘ └──────────────┘ └───────────────┘ │
└─────────────────────────────────────────────────────────┘ 
▼
┌─────────────────────────────────────────────────────────┐
│ Signaling Layer │
│ ┌──────────────┐ ┌──────────────┐ │
│ │ Signaling │ │ Messages │ │
│ │ Client │ │ Models │ │
│ └──────────────┘ └───────────────┘ │
└─────────────────────────────────────────────────────────┘ 
▼
┌─────────────────────────────────────────────────────────┐
│ Network Layer │
│WebSocket/WebRTC Connections │

└───────────────────────────────────────────────────────┘
```

## Layer Description

### 1. UI Layer

Responsible for displaying the user interface and handling user interactions.

**Components:**

- `ConnectPage`: Connection configuration page

- `SessionPage`: Remote session page

- `ControlBar`: Control bar component

- `MetricsOverlay`: Statistics overlay

- `MediaRenderer`: Video rendering component

**Responsibilities:**

- Receive user input

- Display remote video stream

- Display connection status and statistics

- Route navigation

### 2. Controller Layer

Handles events from various input devices and translates them into remote control commands.

**Components:**

- `MouseController`: Handles mouse events (click, move, scroll wheel)

- `KeyboardController`: Handles keyboard events

- `TouchController`: Handles touch events

- `GamepadController`: Handles gamepad events (reserved)

**Responsibilities:**

- Listen for input events

- Transform coordinate systems (screen coordinates → normalized coordinates)

- Construct input messages

- Send messages via DataChannel

### 3. WebRTC Layer

Manages WebRTC connections and data channels.

**Components:**

- `PeerManager`: Manages the RTCPeerConnection lifecycle

- `DataChannelManager`: Manages RTCDataChannel and sends input events

- `MediaRenderer`: Renders remote media streams

**Responsibilities:**

- Creates and manages peer connections

- Handles ICE candidates

- Creates offer/answer

- Manages data channels

- Receives and renders media streams

Collects WebRTC statistics

### 4. Signaling Layer

Handles WebSocket signaling communication.

**Components:**

- `SignalingClient`: WebSocket client

- `SignalingMessages`: Signaling message model

**Responsibilities:**

- Establishes WebSocket connections

- Sends/receives signaling messages

- Heartbeat keep-alive

Automatic reconnection

Parses signaling messages

### 5. Metrics Layer

Collects and analyzes connection quality metrics.

**Components:**

- `StatsCollector`: Statistics collector

- `QoSMetrics`: Quality metric model

**Responsibilities:**

- Regularly collect WebRTC statistics

- Calculate metrics such as FPS, bitrate, and RTT

- Evaluate connection quality levels

- Provide real-time statistics stream

## Data Flow

### Connection Establishment Process

```
User Input

↓
ConnectPage

↓
SignalingClient.connect()

↓
WebSocket Connection

↓
SignalingClient.sendJoin()

↓
PeerManager.createPeerConnection()

↓
PeerManager.createDataChannel()

↓
Wait for Offer/Answer

↓
ICE Negotiation

↓
Connection Established

↓
SessionPage (Show Video)

```

### Input Event Flow

```
User Input (Mouse/Keyboard/Touch)

↓
Input Controller

↓
Transform & Normalize

↓
DataChannelManager

↓
RTCDataChannel

↓
Network

↓
Remote Host

```

### Video Stream Reception Process

```
Remote Host

↓
Network

↓
RTCPeerConnection

↓
onTrack Event

↓
MediaStream

↓
RTCVideoRenderer

↓
Display on Screen

```

## Design Patterns

### 1. Manager Pattern

Use the Manager class to encapsulate complex WebRTC and signaling logic:

- `PeerManager`: Manages peer connections

- `DataChannelManager`: Manages data channels

- `StatsCollector`: Manages statistics collection

### 2. Controller Pattern

Use the Controller class to handle specific types of input:

- Each input type has an independent controller

- The Controller is responsible for event transformation and message construction

- Decouples the UI Business Logic

### 3. Stream Pattern

Using Dart Streams for event propagation:

- Signaling message stream

- Connection state stream

- Statistics stream

- Media stream

### 4. Dependency Injection

Simple Service Locator Pattern:

- `ServiceLocator`: Manages global services

- Loosely coupled component dependencies

## Concurrency Model

### Single-Threaded UI

Flutter uses a single-threaded UI model:

- All UI updates are performed on the main thread (isolate)

- Asynchronous operations are handled using Streams and Futures

WebRTC callbacks are automatically scheduled to the main thread

### Background Tasks

- Statistics collection is performed periodically using Timer

WebSocket heartbeats are sent periodically using Timer

Asynchronous network I/O processing

## Error Handling

### Connection Errors

- WebSocket connection failure → Automatic reconnection

- WebRTC connection failure → Display error message

- ICE Connection failed → Attempt TURN relay

### Runtime Errors

- Data channel not ready → Log warning, discard message

- Statistics collection failed → Log error, continue running

- Parsing error → Log error, ignore message

## Performance Optimizations

### Rendering Optimizations

- Use hardware-accelerated `RTCVideoView`

- Avoid unnecessary widget rebuilds

- Use `const` constructors

### Network Optimizations

- Use unreliable, unordered data channels to reduce latency

- Batch send input events (if needed)

- Adaptive bitrate control

### Memory Optimizations

- Release WebRTC resources promptly

- Close unused Streams

- Avoid memory leaks

## Security Considerations
### Network Security

- Supports WSS (WebSocket Secure)

- Supports DTLS (DataChannel Encryption)

- Optional access token authentication

### Input Security

- Validate input coordinate range

- Limit message sending rate

- Filter malicious input

## Test Strategy

### Unit Testing

- Input controller logic testing

- Message serialization/deserialization testing

- Statistical calculation testing

### Integration Testing

- Signaling flow testing

- WebRTC connection testing

- End-to-end latency testing

### UI Testing

- Widget testing

- Navigation testing

- User interaction testing

## Extension Points

### Custom Signaling Server

Implement a subclass of `SignalingClient` or modify an existing implementation.

### Custom Input Handling

Add a new Controller class to handle specific input devices.

### Custom Codecs

Modify codec preferences via WebRTC SDP.

### Platform-Specific Features

Implement native features using the Flutter platform channel.

## Future Improvements

1. **State Management**: Introduce Riverpod or Bloc for better state management.

2. **Internationalization**: Support multiple languages.

3. **Theme Customization**: More UI theme options.

4. **Performance Analysis**: Built-in performance analysis tools.

5. **Recording Functionality**: Support session recording and playback.

6. **Multi-Connection**: Support simultaneous connections to multiple hosts.