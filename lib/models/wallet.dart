class Wallet {
  final String id;
  final String orgId;
  final String name;
  final String type;
  final String currency;
  Wallet({required this.id, required this.orgId, required this.name, required this.type, this.currency = 'IDR'});
  /// Field wajib: field hilang -> ArgumentError (bukan string "null").
  static String _req(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) {
      throw ArgumentError('Wallet.fromMap: field wajib "$key" hilang');
    }
    return v.toString();
  }
  factory Wallet.fromMap(Map<String, dynamic> m) => Wallet(
        id: _req(m, 'id'),
        orgId: _req(m, 'org_id'),
        name: (m['name'] ?? '').toString(),
        type: (m['type'] ?? 'cash').toString(),
        currency: (m['currency'] ?? 'IDR').toString().toUpperCase(),
      );
}
