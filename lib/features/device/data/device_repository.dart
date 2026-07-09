import 'package:dio/dio.dart';

import 'models/device_verify_request.dart';
import 'models/device_verify_response.dart';

class DeviceRepository {
  DeviceRepository(this._dio);

  final Dio _dio;

  Future<DeviceVerifyResponse> verifyDevice(String macAddress) async {
    final response = await _dio.post(
      '/device/verify',
      data: DeviceVerifyRequest(macAddress).toJson(),
    );
    return DeviceVerifyResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<void> unregisterDevice(String macAddress) async {
    await _dio.post(
      '/device/unregister',
      data: DeviceVerifyRequest(macAddress).toJson(),
    );
  }
}
