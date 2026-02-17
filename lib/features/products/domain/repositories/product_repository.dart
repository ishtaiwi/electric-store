import '../entities/product.dart';

abstract class ProductRepository {
  Future<List<Product>> getAllProducts();
  Future<Product?> getProductById(int id);
  Future<Product?> getProductByBarcode(String barcode);
  Future<List<Product>> searchProducts(String query);
  Future<List<Product>> getLowStockProducts();
  Future<int> createProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<int> updateStock(int productId, int quantity);
  Future<int> adjustStock(int productId, int adjustment, String type, String? reason, int? userId);
  
  // Pagination support
  Future<List<Product>> getProductsPaginated({int limit = 50, int offset = 0});
  Future<List<Product>> searchProductsPaginated(String query, {int limit = 50, int offset = 0});
  Future<int> getProductsCount();
}
