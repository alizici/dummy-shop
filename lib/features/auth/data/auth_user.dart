import 'package:equatable/equatable.dart';

import '../../../core/json/json_reader.dart';

/// The signed-in user, as much as the app needs of it.
class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    this.imageUrl,
  });

  factory AuthUser.fromJson(JsonReader json) => AuthUser(
    id: json.integer('id'),
    username: json.string('username'),
    firstName: json.string('firstName'),
    lastName: json.string('lastName'),
    imageUrl: json.stringOrNull('image'),
  );

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String? imageUrl;

  String get displayName => '$firstName $lastName'.trim();

  @override
  List<Object?> get props => [id, username, firstName, lastName, imageUrl];
}
