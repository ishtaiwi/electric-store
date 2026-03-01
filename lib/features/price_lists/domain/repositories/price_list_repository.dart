import '../entities/price_list.dart';
import '../entities/price_list_item.dart';

abstract class PriceListRepository {
  Future<List<PriceList>> getAllPriceLists();
  Future<PriceList?> getPriceListById(int id);
  Future<List<PriceList>> getPriceListsByCustomer(int customerId);
  Future<List<PriceListItem>> getPriceListItems(int priceListId);
  Future<int> createPriceList(PriceList priceList, List<PriceListItem> items);
  Future<int> updatePriceList(PriceList priceList, List<PriceListItem> items);
  Future<int> deletePriceList(int id);
  Future<List<PriceList>> searchPriceLists(String query);
}
