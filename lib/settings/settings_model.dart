class RealDeskSettings {
  static const List<Map<String, dynamic>> defaultIceServers = [
    {
      'urls': [
        'turn:36.99.188.174:3479?transport=udp',
        'turn:36.99.188.174:3479?transport=tcp',
      ],
      'username': 'comma',
      'credential': 'comma@xrcloud.net',
    },
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
  ];

  static const String defaultIceServersJson =
      '[{"urls":["turn:36.99.188.174:3479?transport=udp","turn:36.99.188.174:3479?transport=tcp"],"username":"yrxt","credential":"yrxt@unionstech.cn"},{"urls":"stun:stun.l.google.com:19302"},{"urls":"stun:stun1.l.google.com:19302"}]';

  RealDeskSettings({
    this.insecure = false,
    this.noGoogleStun = false,
    this.overrideIce = false,
    this.iceServersJson = RealDeskSettings.defaultIceServersJson,
    this.heartbeatSeconds = 5,
    this.reconnectDelaySeconds = 3,
    this.maxReconnectAttempts = 3,
    this.defaultShowMetrics = false,
    this.defaultMouseRelative = false,
  });

  bool insecure;
  bool noGoogleStun;
  bool overrideIce;
  String iceServersJson; // JSON array string of RTCIceServer objects
  int heartbeatSeconds;
  int reconnectDelaySeconds;
  int maxReconnectAttempts;
  bool defaultShowMetrics;
  bool defaultMouseRelative;

  Map<String, dynamic> toMap() => {
    'insecure': insecure,
    'noGoogleStun': noGoogleStun,
    'overrideIce': overrideIce,
    'iceServersJson': iceServersJson,
    'heartbeatSeconds': heartbeatSeconds,
    'reconnectDelaySeconds': reconnectDelaySeconds,
    'maxReconnectAttempts': maxReconnectAttempts,
    'defaultShowMetrics': defaultShowMetrics,
    'defaultMouseRelative': defaultMouseRelative,
  };

  static RealDeskSettings fromMap(Map<String, dynamic> m) {
    return RealDeskSettings(
      insecure: m['insecure'] ?? false,
      noGoogleStun: m['noGoogleStun'] ?? false,
      overrideIce: m['overrideIce'] ?? false,
      iceServersJson:
          (m['iceServersJson'] as String?)?.isNotEmpty == true
              ? m['iceServersJson']
              : RealDeskSettings.defaultIceServersJson,
      heartbeatSeconds: m['heartbeatSeconds'] ?? 5,
      reconnectDelaySeconds: m['reconnectDelaySeconds'] ?? 3,
      maxReconnectAttempts: m['maxReconnectAttempts'] ?? 3,
      defaultShowMetrics: m['defaultShowMetrics'] ?? false,
      defaultMouseRelative: m['defaultMouseRelative'] ?? false,
    );
  }
}
