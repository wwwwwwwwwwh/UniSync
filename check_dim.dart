
import 'dart:io';
import 'dart:typed_data';

void main() {
  final file = File('assets/images/school_library_bg.png');
  final bytes = file.readAsBytesSync();
  // PNG signature
  if (bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71) {
    // IHDR chunk starts at byte 8
    // Width at byte 16 (4 bytes), Height at byte 20 (4 bytes)
    final width = _toInt(bytes, 16);
    final height = _toInt(bytes, 20);
    print('Width: $width, Height: $height');
  } else {
    print('Not a valid PNG');
  }
}

int _toInt(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) + (bytes[offset + 1] << 16) + (bytes[offset + 2] << 8) + bytes[offset + 3];
}
