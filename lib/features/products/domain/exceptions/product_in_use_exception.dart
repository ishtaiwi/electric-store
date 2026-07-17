class ProductInUseException implements Exception {
  final int salesCount;
  final int cancelledSalesCount;

  const ProductInUseException({
    required this.salesCount,
    required this.cancelledSalesCount,
  });
}
