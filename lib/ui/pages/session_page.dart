import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:window_manager/window_manager.dart';

import '../../input/keyboard_controller.dart';
import '../../input/mouse_controller.dart';
import '../../input/schema/input_messages.dart';
import '../../metrics/stats_collector.dart';
import '../../signaling/signaling_client.dart';
import '../../signaling/models/signaling_messages.dart' as signaling;
import '../../webrtc/data_channel.dart';
import '../../webrtc/media_renderer.dart';
import '../../webrtc/peer_manager.dart';
import '../../settings/settings_model.dart';
import '../../settings/settings_store.dart';
import '../widgets/control_bar.dart';
import '../widgets/metrics_overlay.dart';

/// Remote session page with video stream and input handling
class SessionPage extends StatefulWidget {
  const SessionPage({
    required this.signalingUrl,
    required this.roomId,
    this.token,
    Key? key,
  }) : super(key: key);

  final String signalingUrl;
  final String roomId;
  final String? token;

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  final _logger = Logger();
  final _videoKey = GlobalKey();

  late SignalingClient _signalingClient;
  late PeerManager _peerManager;

  DataChannelManager? _dataChannelManager;
  MouseController? _mouseController;
  KeyboardController? _keyboardController;
  StatsCollector? _statsCollector;

  MediaStream? _remoteStream;
  bool _isConnected = false;
  bool _showMetrics = false;
  MouseMode _mouseMode = MouseMode.absolute;
  String _statusMessage = '正在连接...';
  RealDeskSettings _settings = RealDeskSettings();
  bool _isFullScreen = false;

  StreamSubscription<RTCDataChannelMessage>? _dataChannelSubscription;
  ui.Image? _remoteCursorImage;
  bool _remoteCursorVisible = false;
  Offset _cursorHotspot = Offset.zero;
  Offset _pointerPosition = Offset.zero;
  bool _isPointerInsideVideo = false;
  int _cursorImageVersion = 0;
  Size _remoteVideoSize = Size.zero;

  bool get _shouldShowRemoteCursor =>
      _remoteCursorImage != null &&
      _remoteCursorVisible &&
      _isPointerInsideVideo;

  bool get _supportsNativeFullScreen =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _logger.i('Initializing session');

    // Load settings
    _settings = await SettingsStore.load();

    // Create signaling client with settings
    _signalingClient = SignalingClient(
      signalingUrl: widget.signalingUrl,
      reconnectDelay: Duration(seconds: _settings.reconnectDelaySeconds),
      maxReconnectAttempts: _settings.maxReconnectAttempts,
    );
    _signalingClient.messageStream.listen(_onSignalingMessage);
    _signalingClient.stateStream.listen(_onSignalingStateChanged);

    // Create peer manager (ICE will be set after accept)
    _peerManager = PeerManager();
    _peerManager.remoteStream.listen(_onRemoteStream);
    _peerManager.iceCandidate.listen(_onIceCandidate);
    _peerManager.connectionState.listen(_onConnectionStateChanged);
    _peerManager.dataChannelState.listen(_onDataChannelStateChanged);

    // Connect WS and send Ayame register
    await _signalingClient.connect();
    _signalingClient.sendRegister(
      roomId: widget.roomId,
      clientId: null,
      key: widget.token,
    );

    // apply defaults
    _showMetrics = _settings.defaultShowMetrics;
    _mouseMode = _settings.defaultMouseRelative
        ? MouseMode.relative
        : MouseMode.absolute;
  }

  void _onSignalingMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    _logger.d('Signaling message: $type');

    switch (type) {
      case 'accept':
        _handleAccept(message);
        break;
      case 'offer':
        _handleOffer(message);
        break;
      case 'answer':
        _handleAnswer(message);
        break;
      case 'candidate':
        _handleCandidate(message);
        break;
      case 'error':
        _handleError(message);
        break;
    }
  }

  Future<void> _handleAccept(Map<String, dynamic> message) async {
    final seen = <String>{};
    final effectiveIceServers = <Map<String, dynamic>>[];

    void addServer(dynamic server) {
      final normalized = _normalizeIceServer(server);
      if (normalized == null) return;
      if (_settings.noGoogleStun && _isGoogleStunServer(normalized)) return;
      final key = _iceServerKey(normalized);
      if (seen.add(key)) {
        effectiveIceServers.add(normalized);
      }
    }

    if (_settings.overrideIce) {
      try {
        final parsed = _settings.iceServersJson.trim().isEmpty
            ? const []
            : (jsonDecode(_settings.iceServersJson) as List);
        for (final server in parsed) {
          addServer(server);
        }
      } catch (e) {
        _logger.w('解析自定义 ICE 配置失败: $e');
      }
    } else {
      for (final server in RealDeskSettings.defaultIceServers) {
        addServer(server);
      }
      final ayameServers = (message['iceServers'] as List?) ?? const [];
      for (final server in ayameServers) {
        addServer(server);
      }
    }

    if (effectiveIceServers.isEmpty) {
      for (final server in RealDeskSettings.defaultIceServers) {
        addServer(server);
      }
    }

    await _peerManager.initializePeerConnectionWithIceServers(
      effectiveIceServers,
    );
    await _peerManager.createInputChannels();

    _dataChannelManager = DataChannelManager(
      rtChannel: _peerManager.rtChannel,
      reliableChannel: _peerManager.reliableChannel,
    );

    // Initialize input controllers
    _mouseController = MouseController(
      dataChannelManager: _dataChannelManager!,
      mode: _mouseMode,
    );
    if (_remoteVideoSize.width > 0 && _remoteVideoSize.height > 0) {
      _mouseController!.updateRemoteVideoSize(_remoteVideoSize);
    }
    _keyboardController = KeyboardController(
      dataChannelManager: _dataChannelManager!,
    );

    _dataChannelSubscription?.cancel();
    _dataChannelSubscription = _peerManager.dataChannelMessage.listen(
      _onDataChannelMessage,
    );

    // If peer already exists, create offer
    final isExistUser = message['isExistUser'] == true;
    if (isExistUser) {
      final offer = await _peerManager.createOffer();
      _signalingClient.sendOffer(offer.sdp!);
    }
  }

  Future<void> _handleOffer(Map<String, dynamic> message) async {
    final sdp = message['sdp'] as String;
    await _peerManager.setRemoteDescription(
      RTCSessionDescription(sdp, 'offer'),
    );

    final answer = await _peerManager.createAnswer();
    _signalingClient.sendAnswer(answer.sdp!);
  }

  Future<void> _handleAnswer(Map<String, dynamic> message) async {
    final sdp = message['sdp'] as String;
    await _peerManager.setRemoteDescription(
      RTCSessionDescription(sdp, 'answer'),
    );
  }

  Future<void> _handleCandidate(Map<String, dynamic> message) async {
    // Ayame nested ice object
    final ice = message['ice'] as Map<String, dynamic>?;
    if (ice == null) return;
    final candidate = ice['candidate'] as String;
    final sdpMid = ice['sdpMid'] as String;
    final sdpMLineIndex = (ice['sdpMLineIndex'] as num).toInt();
    await _peerManager.addIceCandidate(
      RTCIceCandidate(candidate, sdpMid, sdpMLineIndex),
    );
  }

  void _handleError(Map<String, dynamic> message) {
    final errorMessage = message['message'] as String?;
    _logger.e('Signaling error: $errorMessage');
    setState(() {
      _statusMessage = '错误: $errorMessage';
    });
  }

  void _onSignalingStateChanged(signaling.ConnectionState state) {
    _logger.i('Signaling state: $state');
    setState(() {
      _statusMessage = _getStateMessage(state);
    });
  }

  void _onRemoteStream(MediaStream stream) {
    _logger.i('Received remote stream');
    setState(() {
      _remoteStream = stream;
    });

    // Start stats collection
    if (_peerManager.peerConnection != null) {
      _statsCollector = StatsCollector(
        peerConnection: _peerManager.peerConnection!,
      );
      _statsCollector!.start();
    }
  }

  void _onIceCandidate(RTCIceCandidate candidate) {
    _signalingClient.sendCandidate(
      candidate.candidate!,
      candidate.sdpMid!,
      candidate.sdpMLineIndex!,
    );
  }

  void _onConnectionStateChanged(RTCPeerConnectionState state) {
    _logger.i('Connection state: $state');
    setState(() {
      _isConnected =
          state == RTCPeerConnectionState.RTCPeerConnectionStateConnected;
      _statusMessage = _getConnectionStateMessage(state);
    });
  }

  void _onDataChannelStateChanged(RTCDataChannelState state) {
    _logger.i('Data channel state: $state');
  }

  void _onDataChannelMessage(RTCDataChannelMessage message) {
    if (message.isBinary) {
      // 当前版本主要处理 JSON 文本消息
      return;
    }

    final text = message.text;
    if (text.isEmpty) {
      return;
    }

    Map<String, dynamic>? payload;
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        payload = decoded;
      }
    } catch (e) {
      _logger.w('解析 DataChannel 文本消息失败: $e');
      return;
    }

    if (payload == null) {
      return;
    }

    final type = payload['type'] as String?;
    if (type == null) {
      return;
    }

    switch (type) {
      case 'cursorImage':
        _handleCursorImageMessage(payload);
        break;
      default:
        break;
    }
  }

  void _handleCursorImageMessage(Map<String, dynamic> payload) {
    final width = (payload['w'] as num?)?.toInt();
    final height = (payload['h'] as num?)?.toInt();
    final data = payload['data'] as String?;

    if (width == null ||
        height == null ||
        width <= 0 ||
        height <= 0 ||
        data == null) {
      _logger.w('收到的 cursorImage 消息字段缺失或非法');
      return;
    }

    final format = payload['fmt']?.toString();
    if (format != null && format.toUpperCase() != 'BGRA') {
      _logger.w('收到不支持的 cursorImage 格式: $format');
      return;
    }

    Uint8List raw;
    try {
      raw = base64Decode(data);
    } catch (e) {
      _logger.w('cursorImage 数据 base64 解码失败: $e');
      return;
    }

    final expectedLength = width * height * 4;
    if (raw.length < expectedLength) {
      _logger.w('cursorImage 数据长度不足: 实际 ${raw.length} 字节, 期望 $expectedLength');
      return;
    }

    final hotspotX = (payload['hotspotX'] as num?)?.toDouble() ?? 0;
    final hotspotY = (payload['hotspotY'] as num?)?.toDouble() ?? 0;
    final visible = payload['visible'] != false;

    final version = ++_cursorImageVersion;

    try {
      ui.decodeImageFromPixels(raw, width, height, ui.PixelFormat.bgra8888, (
        ui.Image image,
      ) {
        if (!mounted) {
          image.dispose();
          return;
        }

        if (version != _cursorImageVersion) {
          image.dispose();
          return;
        }

        final previous = _remoteCursorImage;

        setState(() {
          _remoteCursorImage = image;
          _cursorHotspot = Offset(hotspotX, hotspotY);
          _remoteCursorVisible = visible;
        });

        previous?.dispose();
      }, rowBytes: width * 4);
    } catch (e) {
      _logger.w('cursorImage 像素解码失败: $e');
    }
  }

  void _handleVideoSizeChanged(int width, int height) {
    if (width <= 0 || height <= 0) {
      return;
    }
    final newSize = Size(width.toDouble(), height.toDouble());
    if (_remoteVideoSize == newSize) {
      return;
    }
    _mouseController?.updateRemoteVideoSize(newSize);
    if (!mounted) {
      return;
    }
    setState(() {
      _remoteVideoSize = newSize;
    });
    _logger.i(
      'Remote video size updated: ${newSize.width.toInt()}x${newSize.height.toInt()}',
    );
  }

  void _updatePointerInside(bool inside) {
    if (_isPointerInsideVideo == inside) {
      return;
    }
    setState(() {
      _isPointerInsideVideo = inside;
    });
  }

  void _recordPointerPosition(PointerEvent event, [Size? viewSize]) {
    final effectiveViewSize = viewSize ?? _getVideoSize();
    if (effectiveViewSize.isEmpty) {
      return;
    }
    final adjusted = _clampPointerToVideo(
      event.localPosition,
      effectiveViewSize,
    );

    if (_shouldShowRemoteCursor) {
      final dx = adjusted.dx - _pointerPosition.dx;
      final dy = adjusted.dy - _pointerPosition.dy;
      if ((dx * dx + dy * dy) < 0.25) {
        return;
      }
      setState(() {
        _pointerPosition = adjusted;
      });
    } else {
      if (_pointerPosition != adjusted) {
        setState(() {
          _pointerPosition = adjusted;
        });
      }
    }
  }

  Offset _clampPointerToVideo(Offset local, Size viewSize) {
    if (_remoteVideoSize.width <= 0 || _remoteVideoSize.height <= 0) {
      final double x = (local.dx).clamp(0.0, viewSize.width);
      final double y = (local.dy).clamp(0.0, viewSize.height);
      return Offset(x, y);
    }

    final videoAspect = _remoteVideoSize.width / _remoteVideoSize.height;
    final viewAspect = viewSize.width / viewSize.height;

    double contentWidth;
    double contentHeight;
    double offsetX;
    double offsetY;

    if (videoAspect > viewAspect) {
      contentWidth = viewSize.width;
      contentHeight = contentWidth / videoAspect;
      offsetX = 0;
      offsetY = (viewSize.height - contentHeight) / 2;
    } else {
      contentHeight = viewSize.height;
      contentWidth = contentHeight * videoAspect;
      offsetY = 0;
      offsetX = (viewSize.width - contentWidth) / 2;
    }

    final double clampedX = (local.dx - offsetX).clamp(0.0, contentWidth);
    final double clampedY = (local.dy - offsetY).clamp(0.0, contentHeight);

    return Offset(offsetX + clampedX, offsetY + clampedY);
  }

  String _getStateMessage(signaling.ConnectionState state) {
    switch (state) {
      case signaling.ConnectionState.connecting:
        return '正在连接...';
      case signaling.ConnectionState.connected:
        return '已连接';
      case signaling.ConnectionState.reconnecting:
        return '正在重连...';
      case signaling.ConnectionState.disconnected:
        return '已断开';
      case signaling.ConnectionState.failed:
        return '连接失败';
    }
  }

  String _getConnectionStateMessage(RTCPeerConnectionState state) {
    switch (state) {
      case RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return '准备中...';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return '正在建立连接...';
      case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return '已连接';
      case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return '连接中断';
      case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return '连接失败';
      case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return '连接已关闭';
    }
  }

  void _toggleMetrics() {
    setState(() {
      _showMetrics = !_showMetrics;
    });
  }

  void _toggleMouseMode() {
    setState(() {
      _mouseMode = _mouseMode == MouseMode.absolute
          ? MouseMode.relative
          : MouseMode.absolute;
      _mouseController?.toggleMode();
    });
  }

  Future<void> _setFullScreen(bool enable) async {
    if (_isFullScreen == enable) {
      return;
    }

    if (mounted) {
      setState(() {
        _isFullScreen = enable;
      });
    } else {
      _isFullScreen = enable;
    }

    if (_supportsNativeFullScreen) {
      try {
        await windowManager.setFullScreen(enable);
      } catch (e, stackTrace) {
        _logger.w('切换原生全屏失败: $e\n$stackTrace');
        if (enable) {
          await SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.immersiveSticky,
          );
        } else {
          await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
        return;
      }
      if (!enable) {
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      return;
    }

    if (enable) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  void _toggleFullScreen() {
    _setFullScreen(!_isFullScreen);
  }

  void _disconnect() {
    Navigator.of(context).pop();
  }

  Size _getVideoSize() {
    final renderBox =
        _videoKey.currentContext?.findRenderObject() as RenderBox?;
    return renderBox?.size ?? Size.zero;
  }

  Map<String, dynamic>? _normalizeIceServer(dynamic server) {
    if (server is! Map) return null;
    final urls = _extractUrlsFrom(server['urls']);
    if (urls.isEmpty) return null;

    final normalized = <String, dynamic>{
      'urls': urls.length == 1 ? urls.first : urls,
    };

    if (server.containsKey('username') && server['username'] != null) {
      normalized['username'] = server['username'].toString();
    }
    if (server.containsKey('credential') && server['credential'] != null) {
      normalized['credential'] = server['credential'].toString();
    }
    if (server.containsKey('credentialType') &&
        server['credentialType'] != null) {
      normalized['credentialType'] = server['credentialType'].toString();
    }

    return normalized;
  }

  List<String> _extractUrlsFrom(dynamic urls) {
    if (urls is String) {
      return [urls];
    }
    if (urls is Iterable) {
      return urls
          .map((e) => e.toString())
          .where((value) => value.isNotEmpty)
          .toList();
    }
    return [];
  }

  bool _isGoogleStunServer(Map<String, dynamic> server) {
    final urls = _extractUrlsFrom(server['urls']);
    return urls.any((url) => url.contains('stun.l.google.com'));
  }

  String _iceServerKey(Map<String, dynamic> server) {
    final urls = _extractUrlsFrom(server['urls'])..sort();
    final username = server['username']?.toString() ?? '';
    final credential = server['credential']?.toString() ?? '';
    final credentialType = server['credentialType']?.toString() ?? '';
    return jsonEncode({
      'urls': urls,
      'username': username,
      'credential': credential,
      'credentialType': credentialType,
    });
  }

  @override
  void dispose() {
    _dataChannelSubscription?.cancel();
    _remoteCursorImage?.dispose();
    _statsCollector?.dispose();
    _peerManager.dispose();
    _signalingClient.dispose();
    if (_isFullScreen) {
      if (_supportsNativeFullScreen) {
        unawaited(windowManager.setFullScreen(false));
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(child: _buildRemoteSurface()),
              if (!_isFullScreen)
                SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    child: ControlBar(
                      isConnected: _isConnected,
                      showMetrics: _showMetrics,
                      mouseMode: _mouseMode,
                      onToggleMetrics: _toggleMetrics,
                      onToggleMouseMode: _toggleMouseMode,
                      onToggleFullScreen: _toggleFullScreen,
                      onDisconnect: _disconnect,
                      isFullScreen: _isFullScreen,
                    ),
                  ),
                ),
            ],
          ),
          if (_isFullScreen)
            Positioned(
              top: 16,
              right: 16,
              child: SafeArea(
                child: Material(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(24),
                  child: IconButton(
                    icon: const Icon(
                      Icons.fullscreen_exit,
                      color: Colors.white,
                    ),
                    tooltip: '退出全屏',
                    onPressed: _toggleFullScreen,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRemoteSurface() {
    final Widget content;

    if (_remoteStream != null) {
      content = Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          final viewSize = _getVideoSize();
          _updatePointerInside(true);
          _recordPointerPosition(event, viewSize);
          _mouseController?.onPointerDown(event, viewSize);
        },
        onPointerUp: (event) {
          final viewSize = _getVideoSize();
          _recordPointerPosition(event, viewSize);
          _mouseController?.onPointerUp(event, viewSize);
        },
        onPointerMove: (event) {
          final viewSize = _getVideoSize();
          _recordPointerPosition(event, viewSize);
          _mouseController?.onPointerMove(event, viewSize);
        },
        onPointerHover: (event) {
          final viewSize = _getVideoSize();
          _updatePointerInside(true);
          _recordPointerPosition(event, viewSize);
          _mouseController?.onPointerHover(event, viewSize);
        },
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _mouseController?.onPointerScroll(event);
          }
        },
        onPointerCancel: (event) {
          _mouseController?.onPointerCancel(event);
        },
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            final handled = _keyboardController?.handleKeyEvent(event) ?? false;
            return handled ? KeyEventResult.handled : KeyEventResult.ignored;
          },
          child: MouseRegion(
            onEnter: (event) {
              final viewSize = _getVideoSize();
              _updatePointerInside(true);
              _recordPointerPosition(event, viewSize);
            },
            onExit: (event) {
              _updatePointerInside(false);
            },
            cursor: _shouldShowRemoteCursor
                ? SystemMouseCursors.none
                : MouseCursor.defer,
            child: Container(
              key: _videoKey,
              color: Colors.black,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: RemoteMediaRenderer(
                      stream: _remoteStream,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      onVideoSizeChanged: _handleVideoSizeChanged,
                    ),
                  ),
                  if (_shouldShowRemoteCursor && _remoteCursorImage != null)
                    Positioned(
                      left: _pointerPosition.dx - _cursorHotspot.dx,
                      top: _pointerPosition.dy - _cursorHotspot.dy,
                      child: RawImage(
                        image: _remoteCursorImage,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    } else {
      content = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_statusMessage, style: const TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: content),
        if (_showMetrics && _statsCollector != null)
          Positioned(
            top: 16,
            left: 16,
            child: MetricsOverlay(statsCollector: _statsCollector!),
          ),
      ],
    );
  }
}
