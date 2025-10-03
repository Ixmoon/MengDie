// lib/src/gemini/models/url_context.dart


// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// Metadata returned to the user for URL context.
class UrlContextMetadata {
  final List<UrlMetadata> urlMetadata;

  const UrlContextMetadata({required this.urlMetadata});

  factory UrlContextMetadata.fromJson(Map<String, dynamic> json) {
    return UrlContextMetadata(
      urlMetadata: (json['urlMetadata'] as List? ?? [])
          .map((m) => UrlMetadata.fromJson(m))
          .toList(),
    );
  }
}

/// Metadata for a single URL.
class UrlMetadata {
  final String? retrievedUrl;
  final String? urlRetrievalStatus;

  const UrlMetadata({this.retrievedUrl, this.urlRetrievalStatus});

  factory UrlMetadata.fromJson(Map<String, dynamic> json) {
    return UrlMetadata(
      retrievedUrl: json['retrievedUrl'],
      urlRetrievalStatus: json['urlRetrievalStatus'],
    );
  }
}