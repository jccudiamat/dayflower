import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

Uint8List normalizeBoothPhoto(Uint8List bytes) {
  if (bytes.length < 12) throw const FormatException('Unsupported image');
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Unsupported image');
  return Uint8List.fromList(
      img.encodeJpg(img.bakeOrientation(decoded), quality: 88));
}

final boothPhotoPickerProvider =
    Provider<Future<Uint8List?> Function(ImageSource)>((ref) => (source) async {
          final photo = await ImagePicker().pickImage(
              source: source,
              maxWidth: 1600,
              maxHeight: 1600,
              imageQuality: 88);
          if (photo == null) return null;
          return compute(normalizeBoothPhoto, await photo.readAsBytes());
        });

