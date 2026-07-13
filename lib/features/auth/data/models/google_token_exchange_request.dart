class GoogleTokenExchangeRequest {
  const GoogleTokenExchangeRequest(this.code);

  final String code;

  Map<String, dynamic> toJson() => {'code': code};
}
