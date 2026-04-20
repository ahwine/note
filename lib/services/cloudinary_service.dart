import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String _cloudName = 'dyo6a32zm';
  static const String _uploadPreset = 'boenda_kitchen';

  static Future<String?> uploadImage(String filePath) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);

      if (response.statusCode == 200) {
        return json['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadImageBytes(Uint8List bytes) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

      // Convert ke base64 untuk upload
      final base64Data = base64Encode(bytes);
      final dataUri = 'data:image/png;base64,$base64Data';

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'file': dataUri,
          'upload_preset': _uploadPreset,
        }),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> uploadAudio(String filePath) async {
    try {
      final uri = Uri.parse(
          'https://api.cloudinary.com/v1_1/$_cloudName/video/upload');
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      final body = await response.stream.bytesToString();
      final json = jsonDecode(body);

      if (response.statusCode == 200) {
        return json['secure_url'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}