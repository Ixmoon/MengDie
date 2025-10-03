
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

/// A generic class for paginated API responses.
class PaginatedResponse<T> {
  /// The list of items on the current page.
  final List<T> items;

  /// A token that can be used to retrieve the next page of results.
  /// If null, there are no more pages.
  final String? nextPageToken;

  /// Creates a new paginated response.
  const PaginatedResponse({
    required this.items,
    this.nextPageToken,
  });

  /// Creates a new paginated response from a JSON object.
  factory PaginatedResponse.fromJson(
      Map<String, dynamic> json, String itemsKey, T Function(Map<String, dynamic>) fromJsonT) {
    return PaginatedResponse<T>(
      items: (json[itemsKey] as List<dynamic>? ?? [])
          .map((item) => fromJsonT(item as Map<String, dynamic>))
          .toList(),
      nextPageToken: json['nextPageToken'] as String?,
    );
  }
}