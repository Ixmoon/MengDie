// lib/src/gemini/models/auth_token.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import 'live.dart';

/// An ephemeral authentication token for the Live API.
class AuthToken {
  final String name;
  final DateTime expireTime;

  const AuthToken({required this.name, required this.expireTime});

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    return AuthToken(
      name: json['name'] ?? '',
      expireTime: json['expireTime'] != null
          ? DateTime.parse(json['expireTime'])
          : DateTime.now(),
    );
  }
}

/// Configuration for creating an ephemeral authentication token.
class AuthTokenConfig {
  final int? uses;
  final DateTime? expireTime;
  final DateTime? newSessionExpireTime;
  final LiveConnectConstraints? liveConnectConstraints;
  final List<String>? fieldMask;

  const AuthTokenConfig({
    this.uses,
    this.expireTime,
    this.newSessionExpireTime,
    this.liveConnectConstraints,
    this.fieldMask,
  });

  Map<String, dynamic> toJson() => {
        if (uses != null) 'uses': uses,
        if (expireTime != null)
          'expireTime': expireTime!.toUtc().toIso8601String(),
        if (newSessionExpireTime != null)
          'newSessionExpireTime':
              newSessionExpireTime!.toUtc().toIso8601String(),
        if (liveConnectConstraints != null)
          'bidiGenerateContentSetup': liveConnectConstraints!.toJson(),
        if (fieldMask != null) 'fieldMask': fieldMask,
      };
}

/// Constraints for a Live API session that an AuthToken can be used with.
class LiveConnectConstraints {
  final String model;
  final LiveConnectConfig config;

  const LiveConnectConstraints({required this.model, required this.config});

  Map<String, dynamic> toJson() => {
        'model': 'models/$model',
        'generationConfig': config.toJson(),
      };
}