enum AssetBucket { liquid, savings, investments }

/// savings ke Savings, investment ke Investments, sisanya Liquid.
/// Case-insensitive, null dan tak dikenal ke Liquid.
AssetBucket bucketOf(String? type) {
  final t = (type ?? '').trim().toLowerCase();
  if (t == 'savings') return AssetBucket.savings;
  if (t == 'investment' || t == 'investments') return AssetBucket.investments;
  return AssetBucket.liquid;
}

class Composition {
  final double liquid;
  final double savings;
  final double investments;
  const Composition({required this.liquid, required this.savings, required this.investments});

  double get total => liquid + savings + investments;
  double get liquidPct => total <= 0 ? 0 : liquid / total;
  double get savingsPct => total <= 0 ? 0 : savings / total;
  double get investmentsPct => total <= 0 ? 0 : investments / total;
  int get filledBuckets =>
      (liquid > 0 ? 1 : 0) + (savings > 0 ? 1 : 0) + (investments > 0 ? 1 : 0);
  bool get showStrip => filledBuckets >= 2;
}

Composition composeComposition(
  Map<String, double> balances,
  Map<String, String> types,
) {
  var l = 0.0;
  var s = 0.0;
  var v = 0.0;
  balances.forEach((id, bal) {
    switch (bucketOf(types[id])) {
      case AssetBucket.savings:
        s += bal;
        break;
      case AssetBucket.investments:
        v += bal;
        break;
      case AssetBucket.liquid:
        l += bal;
        break;
    }
  });
  return Composition(liquid: l, savings: s, investments: v);
}
