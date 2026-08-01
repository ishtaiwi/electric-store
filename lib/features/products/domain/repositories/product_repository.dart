import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByBarcode(String barcode);
  Future<List<Product>> searchProducts(String query, {String? brand, String? category});
  Future<List<Product>> getLowStockProducts({String? brand, String? category});
  Future<int> createProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<int> updateStock(int productId, int quantity);
  Future<int> adjustStock(int productId, int adjustment, String type, String? reason, int? userId);

  /// Managed brand list (النوع) for product form dropdowns.
  Future<List<String>> getBrands();
  Future<int> addBrand(String name);
  Future<int> deleteBrand(String name);

  /// Managed category list (الصنف) for product form dropdowns.
  Future<List<String>> getCategories();
  Future<int> addCategory(String name);
  Future<int> deleteCategory(String name);
  
  // Pagination support
  Future<List<Product>> getProductsPaginated({
    int limit = 50,
    int offset = 0,
    String? brand,
    String? category,
  });
  Future<List<Product>> searchProductsPaginated(
    String query, {
    int limit = 50,
    int offset = 0,
    String? brand,
    String? category,
  });
  Future<int> getProductsCount({String? brand, String? category});
}
