class RefreshRequest {
  const RefreshRequest(this.refreshToken);

  final String refreshToken;

  Map<String, dynamic> toJson() => {'refresh_token': refreshToken};
}
