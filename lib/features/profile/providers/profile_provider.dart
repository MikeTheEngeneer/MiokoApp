import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../models/user.dart';
import '../../pearls/models/billing.dart';

final profileProvider = FutureProvider<User>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/auth/me', queryParameters: {'lite': '1'});
  return User.fromJson(resp.data['user'] as Map<String, dynamic>);
});

class ProfileStats {
  final int followers;
  final int following;
  final int interactions;

  const ProfileStats({
    required this.followers,
    required this.following,
    required this.interactions,
  });

  factory ProfileStats.fromJson(Map<String, dynamic> json) => ProfileStats(
    followers: json['followers'] as int? ?? 0,
    following: json['following'] as int? ?? 0,
    interactions: json['interactions'] as int? ?? 0,
  );
}

// Статистика берётся из публичного профиля автора; autoDispose — свежая при каждом заходе
final profileStatsProvider = FutureProvider.autoDispose<ProfileStats>((
  ref,
) async {
  final user = await ref.watch(profileProvider.future);
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/authors/${user.id}');
  return ProfileStats.fromJson(resp.data['stats'] as Map<String, dynamic>);
});

// Данные подписки и жемчужин
class PaymentInfo {
  final int pearls;
  final DateTime? waveUntil;

  const PaymentInfo({required this.pearls, this.waveUntil});

  bool get hasWave => waveUntil != null && waveUntil!.isAfter(DateTime.now());

  factory PaymentInfo.fromJson(Map<String, dynamic> json) => PaymentInfo(
    pearls: json['pearls'] as int? ?? 0,
    waveUntil: json['wave_until'] != null
        ? DateTime.parse(json['wave_until'] as String)
        : null,
  );
}

final billingConfigProvider = FutureProvider<BillingConfig>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/payments/config');
  return BillingConfig.fromJson(resp.data as Map<String, dynamic>);
});

final paymentProvider = FutureProvider<PaymentInfo>((ref) async {
  final dio = ref.read(apiClientProvider);
  final resp = await dio.get('/api/payments/me');
  return PaymentInfo.fromJson(resp.data as Map<String, dynamic>);
});
