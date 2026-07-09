class CompleteResetPasswordRequest {
  const CompleteResetPasswordRequest({
    required this.email,
    required this.newPassword,
  });

  final String email;
  final String newPassword;

  Map<String, dynamic> toJson() => {
    'email': email,
    'new_password': newPassword,
  };
}
