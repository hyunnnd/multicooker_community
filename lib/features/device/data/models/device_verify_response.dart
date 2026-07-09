class DeviceVerifyResponse {
  const DeviceVerifyResponse({
    required this.verified,
    this.deviceName,
    this.serialNumber,
  });

  final bool verified;
  final String? deviceName;
  final String? serialNumber;

  factory DeviceVerifyResponse.fromJson(Map<String, dynamic> json) {
    return DeviceVerifyResponse(
      verified: json['verified'] as bool? ?? false,
      deviceName: json['device_name'] as String?,
      serialNumber: json['serial_number'] as String?,
    );
  }
}
