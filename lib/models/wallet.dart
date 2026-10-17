class Wallet {
  final String id;
  final String orgId;
  final String name;
  final String type;
  final String currency;
  Wallet({required this.id, required this.orgId, required this.name, required this.type, this.currency = 'IDR'});
  factory Wallet.fromMap(Map<String, dynamic> m) => Wallet(
        id: m['id'].toString(),
        orgId: m['org_id'].toString(),
        name: (m['name'] ?? '').toString(),
        type: (m['type'] ?? 'cash').toString(),
        currency: (m['currency'] ?? 'IDR').toString().toUpperCase(),
      );
}
