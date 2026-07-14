import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const frames = {
    'idle': 4,
    'searching': 6,
    'connecting': 6,
    'connected': 4,
    'thinking': 6,
    'cooking': 8,
    'waiting': 4,
    'success': 6,
    'error': 4,
    'sleeping': 6,
    'tapped': 4,
  };

  test('pet sprite sheets use transparent 96px frames', () {
    for (final entry in frames.entries) {
      final bytes = File(
        'assets/images/pet/${entry.key}.png',
      ).readAsBytesSync();
      final data = ByteData.sublistView(bytes);

      expect(bytes.sublist(1, 4), [80, 78, 71]);
      expect(data.getUint32(16), 96 * entry.value);
      expect(data.getUint32(20), 96);
      expect(bytes[25], 6); // PNG RGBA color type.
    }
  });
}
