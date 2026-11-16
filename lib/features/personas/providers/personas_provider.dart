import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/persona.dart';

final personasProvider = FutureProvider<PersonasData>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/personas');
  final list = resp.data['personas'] as List<dynamic>;
  return PersonasData(
    personas: list
        .map((e) => Persona.fromJson(e as Map<String, dynamic>))
        .toList(),
    limit: resp.data['limit'] as int? ?? 10,
  );
});
