import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;

/// Compresse une photo avant de l'envoyer, avec les mêmes réglages que le
/// site : côté le plus long ramené à 1200 px, JPEG qualité 82.
class PhotoCompressee {
  final String base64;
  final String mediaType;
  PhotoCompressee({required this.base64, required this.mediaType});
}

Future<PhotoCompressee?> compresserPhoto(File fichier) async {
  try {
    final brut = await fichier.readAsBytes();
    final image = img.decodeImage(brut);
    if (image == null) return null;

    const maxCote = 1200;
    final plusGrandCote = image.width > image.height ? image.width : image.height;
    final redimensionnee = plusGrandCote > maxCote
        ? img.copyResize(
            image,
            width: image.width >= image.height ? maxCote : null,
            height: image.height > image.width ? maxCote : null,
            interpolation: img.Interpolation.linear,
          )
        : image;

    final jpeg = img.encodeJpg(redimensionnee, quality: 82);
    return PhotoCompressee(base64: base64Encode(jpeg), mediaType: 'image/jpeg');
  } catch (e) {
    return null;
  }
}
