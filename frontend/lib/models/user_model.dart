class UserModel {
  final String id;
  final String name;
  final String email;
  final String? userType;
  final String? token;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.userType,
    this.token,
  });

  bool get isBeeKeeper => userType == null || userType == 'Bee Keeper';
  bool get isNormalUser => userType == 'Normal user';

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      userType: json['user_type'] as String? ??
          json['userType'] as String? ??
          'Bee Keeper',
      token: token ?? json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'user_type': userType ?? 'Bee Keeper',
      if (token != null) 'token': token,
    };
  }
}
