/// The type of the grantee.
enum GranteeType {
  /// The grantee type is unspecified.
  unspecified('GRANTEE_TYPE_UNSPECIFIED'),

  /// The grantee is a user.
  user('USER'),

  /// The grantee is a group.
  group('GROUP'),

  /// The grantee is everyone.
  everyone('EVERYONE');

  const GranteeType(this.value);
  final String value;
}

/// Defines the role of a user.
enum Role {
  /// The role is unspecified.
  unspecified('ROLE_UNSPECIFIED'),

  /// The user is an owner.
  owner('OWNER'),

  /// The user is a writer.
  writer('WRITER'),

  /// The user is a reader.
  reader('READER');

  const Role(this.value);
  final String value;
}

/// Information about a permission to a resource.
class Permission {
  /// The resource name of the permission.
  final String? name;

  /// The type of the grantee.
  final GranteeType granteeType;

  /// The email address of the grantee.
  final String? emailAddress;

  /// The role granted to the grantee.
  final Role role;

  /// Default constructor.
  Permission({
    this.name,
    required this.granteeType,
    this.emailAddress,
    required this.role,
  });

  /// Creates a [Permission] from a JSON object.
  factory Permission.fromJson(Map<String, dynamic> json) {
    return Permission(
      name: json['name'],
      granteeType: GranteeType.values.firstWhere(
        (e) => e.value == json['granteeType'],
        orElse: () => GranteeType.unspecified,
      ),
      emailAddress: json['emailAddress'],
      role: Role.values.firstWhere(
        (e) => e.value == json['role'],
        orElse: () => Role.unspecified,
      ),
    );
  }

  /// Converts a [Permission] to a JSON object.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'granteeType': granteeType.value,
      'role': role.value,
    };
    if (name != null) {
      json['name'] = name;
    }
    if (emailAddress != null) {
      json['emailAddress'] = emailAddress;
    }
    return json;
  }
}