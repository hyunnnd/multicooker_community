import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new chef slime sprite sheet is bundled', () {
    final bytes = File(
      'assets/images/pet/tangerine_chef.webp',
    ).readAsBytesSync();
    final data = ByteData.sublistView(bytes);

    expect(data.getUint32(0), 0x52494646); // RIFF
    expect(data.getUint32(8), 0x57454250); // WEBP
  });
}
