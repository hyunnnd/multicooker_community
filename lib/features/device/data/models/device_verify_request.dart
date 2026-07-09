class DeviceVerifyRequest {
  const DeviceVerifyRequest(this.macAddress);

  final String macAddress;

  Map<String, dynamic> toJson() => {'mac_address': macAddress};
}
