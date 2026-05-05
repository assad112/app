class GasProduct {
  const GasProduct({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.sizeLabel,
    required this.priceOmr,
    this.deliveryFeeOmr = 1.25,
    this.isAvailable = true,
    required this.subtitleAr,
    required this.subtitleEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;
  final String sizeLabel;
  final double priceOmr;
  final double deliveryFeeOmr;
  final bool isAvailable;
  final String subtitleAr;
  final String subtitleEn;

  String localizedName(bool isRtl) => isRtl ? nameAr : nameEn;

  String localizedSubtitle(bool isRtl) => isRtl ? subtitleAr : subtitleEn;
}
