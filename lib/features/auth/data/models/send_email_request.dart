class SendEmailRequest {
  const SendEmailRequest(this.email);

  final String email;

  Map<String, dynamic> toJson() => {'email': email};
}
