import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

class PickedImage {
  const PickedImage({required this.bytes, required this.contentType});

  final Uint8List bytes;
  final String contentType;
}

/// Opens the device gallery / file chooser. Injectable for tests.
typedef PickImage = Future<PickedImage?> Function();

Future<PickedImage?> pickImageFromGallery() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
  );
  if (file == null) return null;
  final name = file.name.toLowerCase();
  final contentType =
      file.mimeType ??
      (name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg');
  return PickedImage(bytes: await file.readAsBytes(), contentType: contentType);
}
