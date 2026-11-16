import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

Future<String> uploadImage(Dio dio, File file) async {
  final bytes = await file.readAsBytes();
  final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
  final resp = await dio.post('/api/images/upload', data: {'dataUrl': dataUrl});
  return resp.data['url'] as String;
}
