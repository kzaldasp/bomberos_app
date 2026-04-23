import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class ServicioAlmacenamiento {
  // Recuerda reemplazar con tus datos reales de Cloudinary
  final String cloudName = "dprutnjty"; 
  final String uploadPreset = "bomberos_preset"; 

  /// Abre el explorador nativo y permite elegir un PDF o Imagen.
  Future<File?> seleccionarArchivo() async {
    try {
      // ✅ CORRECCIÓN PARA VERSIÓN 11.x: Se llama directo a pickFiles()
      FilePickerResult? resultado = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (resultado != null && resultado.files.single.path != null) {
        return File(resultado.files.single.path!);
      }
      return null; 
    } catch (e) {
      print("🚨 Error al seleccionar archivo: $e");
      return null;
    }
  }

  /// Sube el archivo físico a Cloudinary mediante su API REST.
  Future<String?> subirArchivoAdjunto(File archivo) async {
    try {
      // Usamos 'auto' en la URL para que Cloudinary detecte si es Imagen o PDF
      final uri = Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");
      
      var request = http.MultipartRequest('POST', uri);
      
      request.fields['upload_preset'] = uploadPreset;
      
      var multipartFile = await http.MultipartFile.fromPath('file', archivo.path);
      request.files.add(multipartFile);

      var streamResponse = await request.send();
      var response = await http.Response.fromStream(streamResponse);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        
        String urlDescarga = jsonResponse['secure_url'];
        print("✅ Archivo subido con éxito a Cloudinary: $urlDescarga");
        
        return urlDescarga;
      } else {
        print("🚨 Error de Cloudinary. Código: ${response.statusCode}");
        print("Detalle: ${response.body}");
        return null;
      }
    } catch (e) {
      print("🚨 Error grave en la red al subir archivo: $e");
      return null;
    }
  }
}