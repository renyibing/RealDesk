import 'dart:async';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';

import 'qos_models.dart';

/// WebRTC statistics collector
class StatsCollector {
  StatsCollector({
    required this.peerConnection,
    this.collectInterval = const Duration(seconds: 1),
  }) : _logger = Logger();

  final RTCPeerConnection peerConnection;
  final Duration collectInterval;
  final Logger _logger;

  Timer? _collectTimer;
  QoSMetrics _lastMetrics = const QoSMetrics();
  int _lastBytesReceived = 0;
  int _lastFramesReceived = 0;
  int _lastTimestamp = 0;
  int _lastAudioBytesReceived = 0;
  int _lastAudioTimestamp = 0;

  final _metricsController = StreamController<QoSMetrics>.broadcast();
  Stream<QoSMetrics> get metricsStream => _metricsController.stream;
  QoSMetrics get lastMetrics => _lastMetrics;

  /// Start collecting statistics
  void start() {
    if (_collectTimer != null) {
      _logger.w('Stats collector already started');
      return;
    }

    _logger.i('Starting stats collection');
    _collectTimer = Timer.periodic(collectInterval, (_) {
      _collectStats();
    });
  }

  /// Stop collecting statistics
  void stop() {
    _collectTimer?.cancel();
    _collectTimer = null;
    _logger.i('Stopped stats collection');
  }

  /// Collect statistics from peer connection
  Future<void> _collectStats() async {
    try {
      final stats = await peerConnection.getStats();
      final metrics = _parseStats(stats);
      _lastMetrics = metrics;
      _metricsController.add(metrics);
    } catch (e) {
      _logger.e('Failed to collect stats: $e');
    }
  }

  /// Parse raw stats into QoS metrics
  QoSMetrics _parseStats(List<StatsReport> stats) {
    double fps = 0.0;
    int videoBitrate = 0;
    int audioBitrate = 0;
    int rtt = 0;
    double jitter = 0.0;
    double packetLoss = 0.0;
    int framesReceived = 0;
    int framesDropped = 0;

    for (final report in stats) {
      final values = report.values;
      final type = report.type.toString();

      switch (type) {
        case 'inbound-rtp':
          final mediaType = (values['mediaType'] ?? values['kind'])?.toString();

          if (mediaType == 'video') {
            final currentTimestamp = (report.timestamp as num?)?.toInt() ?? 0;

            framesReceived = _parseInt(values['framesReceived']);
            framesDropped = _parseInt(values['framesDropped']);
            final bytesReceived = _parseInt(values['bytesReceived']);

            if (_lastTimestamp > 0 && currentTimestamp > _lastTimestamp) {
              final timeDiffSeconds =
                  (currentTimestamp - _lastTimestamp) / 1000.0;
              if (timeDiffSeconds > 0) {
                final framesDiff = framesReceived - _lastFramesReceived;
                fps = framesDiff / timeDiffSeconds;

                final bytesDiff = bytesReceived - _lastBytesReceived;
                videoBitrate = ((bytesDiff * 8) / timeDiffSeconds).round();
              }
            }
            _lastTimestamp = currentTimestamp;
            _lastFramesReceived = framesReceived;
            _lastBytesReceived = bytesReceived;

            jitter = _parseDouble(values['jitter']) * 1000; // seconds -> ms

            final packetsLost = _parseInt(values['packetsLost']);
            final packetsReceived = _parseInt(values['packetsReceived']);
            final totalPackets = packetsReceived + packetsLost;
            if (totalPackets > 0) {
              packetLoss = (packetsLost / totalPackets) * 100;
            }
          } else if (mediaType == 'audio') {
            final currentTimestamp = (report.timestamp as num?)?.toInt() ?? 0;
            final bytesReceived = _parseInt(values['bytesReceived']);
            if (_lastAudioTimestamp > 0 &&
                currentTimestamp > _lastAudioTimestamp) {
              final timeDiffSeconds =
                  (currentTimestamp - _lastAudioTimestamp) / 1000.0;
              if (timeDiffSeconds > 0) {
                final bytesDiff = bytesReceived - _lastAudioBytesReceived;
                audioBitrate = ((bytesDiff * 8) / timeDiffSeconds).round();
              }
            }
            _lastAudioTimestamp = currentTimestamp;
            _lastAudioBytesReceived = bytesReceived;
          }
          break;

        case 'candidate-pair':
          final state = values['state'] as String?;
          if (state == 'succeeded') {
            rtt = (_parseDouble(values['currentRoundTripTime']) * 1000).round();
          }
          break;

        default:
          break;
      }
    }

    return QoSMetrics(
      fps: fps,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      rtt: rtt,
      jitter: jitter,
      packetLoss: packetLoss,
      framesReceived: framesReceived,
      framesDropped: framesDropped,
    );
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Dispose resources
  void dispose() {
    stop();
    _metricsController.close();
  }
}
