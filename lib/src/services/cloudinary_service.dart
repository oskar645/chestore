import 'dart:io';
import 'package:dio/dio.dart';

class CloudinaryService {
  final _dio = Dio();

  // 👉 ВСТАВИ СВОИ ДАННЫЕ
  final String cloudName = 'djea2n2a9';
  final String uploadPreset = 'chestore';

  Future<String?> uploadImage(File file) async {
    final url = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(file.path),
      'upload_preset': uploadPreset,
    });

    try {
      final res = await _dio.post(url, data: formData);
      return res.data['secure_url'] as String?;
    } on DioException catch (e) {
      // ✅ покажет точную причину от Cloudinary
      final data = e.response?.data;
      throw Exception('Cloudinary upload failed: status=${e.response?.statusCode} body=$data');
    }
  }
}
