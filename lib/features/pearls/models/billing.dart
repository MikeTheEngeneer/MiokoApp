class BillingOption {
  final String id;
  final String label;
  final int amount;
  final int pearls;

  const BillingOption({
    required this.id,
    required this.label,
    required this.amount,
    required this.pearls,
  });

  // "Mioko Wave · 1 месяц" → "1 месяц"
  String get shortLabel => label.split('·').last.trim();

  factory BillingOption.fromJson(String id, Map<String, dynamic> json) => BillingOption(
        id: id,
        label: json['label'] as String? ?? id,
        amount: json['amount'] as int? ?? 0,
        pearls: json['pearls'] as int? ?? 0,
      );
}

// Тарифы Wave и пакеты жемчужин — с сервера (/api/payments/config), порядок как в ответе
class BillingConfig {
  final String? publicId;
  final List<BillingOption> plans;
  final List<BillingOption> packs;

  const BillingConfig({this.publicId, required this.plans, required this.packs});

  factory BillingConfig.fromJson(Map<String, dynamic> json) {
    List<BillingOption> parse(Object? m) => [
          if (m is Map)
            for (final e in m.entries)
              BillingOption.fromJson(e.key as String, Map<String, dynamic>.from(e.value as Map)),
        ];
    return BillingConfig(
      publicId: json['publicId'] as String?,
      plans: parse(json['plans']),
      packs: parse(json['packs']),
    );
  }
}

String formatRub(int amount) {
  final s = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '$buf ₽';
}
