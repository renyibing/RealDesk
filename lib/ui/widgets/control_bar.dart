import 'package:flutter/material.dart';

import '../../input/schema/input_messages.dart';

/// Control bar widget with connection controls
class ControlBar extends StatelessWidget {
  const ControlBar({
    required this.isConnected,
    required this.showMetrics,
    required this.mouseMode,
    required this.onToggleMetrics,
    required this.onToggleMouseMode,
    required this.onDisconnect,
    required this.onToggleFullScreen,
    required this.isFullScreen,
    Key? key,
  }) : super(key: key);

  final bool isConnected;
  final bool showMetrics;
  final MouseMode mouseMode;
  final VoidCallback onToggleMetrics;
  final VoidCallback onToggleMouseMode;
  final VoidCallback onDisconnect;
  final VoidCallback onToggleFullScreen;
  final bool isFullScreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Connection status
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isConnected ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isConnected ? '已连接' : '未连接',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),

          // Control buttons
          Row(
            children: [
              // Metrics toggle
              IconButton(
                icon: Icon(
                  showMetrics ? Icons.analytics : Icons.analytics_outlined,
                  color: Colors.white,
                ),
                tooltip: showMetrics ? '隐藏统计' : '显示统计',
                onPressed: onToggleMetrics,
              ),
              const SizedBox(width: 8),

              // Mouse mode toggle
              IconButton(
                icon: Icon(
                  mouseMode == MouseMode.absolute
                      ? Icons.touch_app
                      : Icons.mouse,
                  color: Colors.white,
                ),
                tooltip: mouseMode == MouseMode.absolute
                    ? '切换到相对模式'
                    : '切换到绝对模式',
                onPressed: onToggleMouseMode,
              ),
              const SizedBox(width: 8),

              // Fullscreen toggle
              IconButton(
                icon: Icon(
                  isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white,
                ),
                tooltip: isFullScreen ? '退出全屏' : '进入全屏',
                onPressed: onToggleFullScreen,
              ),
              const SizedBox(width: 8),

              // Disconnect button
              ElevatedButton.icon(
                icon: const Icon(Icons.close),
                label: const Text('断开连接'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: onDisconnect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

