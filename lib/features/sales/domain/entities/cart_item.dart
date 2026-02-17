import 'package:equatable/equatable.dart';
import '../../../products/domain/entities/product.dart';

class CartItem extends Equatable {
  final Product product;
  final int quantity;
  final double discount;
  final double? customPrice; // Allow custom price override

  const CartItem({
    required this.product,
    this.quantity = 1,
    this.discount = 0,
    this.customPrice,
  });

  /// The effective unit price (custom price or product price)
  double get unitPrice => customPrice ?? product.price;
  
  double get totalPrice => unitPrice * quantity;
  double get totalCost => product.costPrice * quantity;
  double get discountedPrice => totalPrice - discount;
  double get profit => discountedPrice - totalCost;

  CartItem copyWith({
    Product? product,
    int? quantity,
    double? discount,
    double? customPrice,
    bool clearCustomPrice = false,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      customPrice: clearCustomPrice ? null : (customPrice ?? this.customPrice),
    );
  }

  @override
  List<Object?> get props => [product, quantity, discount, customPrice];
}
