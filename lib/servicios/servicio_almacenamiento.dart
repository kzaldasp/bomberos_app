import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

/// Subida de archivos adjuntos (croquis, PDFs, fotos) a Cloudinary,
/// usando el plan gratuito con un "unsigned upload preset".
class ServicioAlmacenamiento {
  static const String _cloudName = "dprutnjty";
  static const String _uploadPreset = "bomberos_preset";

  /// Abre el explorador nativo y permite elegir un PDF o imagen.
  Future<File?> seleccionarArchivo() async {
    try {
      FilePickerResult? resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (resultado != null && resultado.files.single.path != null) {
        return File(resultado.files.single.path!);
      }
      return null;
    } catch (e) {
      debugPrint("Error al seleccionar archivo: $e");
      return null;
    }
  }

  /// Sube el archivo a Cloudinary y retorna su URL pública, o null si falla.
  Future<String?> subirArchivoAdjunto(File archivo) async {
    try {
      // 'auto' hace que Cloudinary detecte solo si es imagen o PDF
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/auto/upload");

      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', archivo.path));

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['secure_url'] as String?;
      }
      debugPrint("Cloudinary rechazó la subida (${response.statusCode}): ${response.body}");
      return null;
    } catch (e) {
      debugPrint("Error de red al subir archivo: $e");
      return null;
    }
  }
}