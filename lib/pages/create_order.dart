import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/helpers/SizeConfig.dart';
import 'package:krpos/helpers/otherHelpers.dart';
import 'package:krpos/models/contact_model.dart';
import 'package:krpos/models/sell.dart';
import 'package:krpos/models/sellDatabase.dart';
import 'package:krpos/models/system.dart';
import 'package:krpos/models/variations.dart';
import 'package:krpos/locale/MyLocalizations.dart';
import 'package:krpos/models/paymentDatabase.dart';

class CreateOrderPage extends StatefulWidget {
  const CreateOrderPage({super.key});

  @override
  State<CreateOrderPage> createState() => _CreateOrderPageState();
}

class _CreateOrderPageState extends State<CreateOrderPage> {
  final searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  List products = [];
  List cartItems = [];
  List contacts = [];
  List locationListMap = [];
  
  int selectedLocationId = 0;
  int? selectedContactId;
  int offset = 0;
  bool isLoading = false;
  bool isProcessing = false;
  String symbol = '';
  
  double discountAmount = 0.0;
  String discountType = 'percentage';

  ThemeData themeData = AppTheme.getThemeFromThemeMode(1);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!isLoading) {
        productList();
      }
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => isLoading = true);
    await Future.wait([
      _loadLocations(),
      _loadContacts(),
      Helper().getFormattedBusinessDetails().then((v) => symbol = v['symbol']),
    ]);
    await productList();
    setState(() => isLoading = false);
  }

  Future<void> _loadLocations() async {
    locationListMap = await System().get('location');
    if (locationListMap.isNotEmpty) {
      selectedLocationId = int.parse(locationListMap[0]['id'].toString());
    }
  }

  Future<void> _loadContacts() async {
    contacts = await Contact().get();
  }

  Future<void> productList() async {
    setState(() => isLoading = true);
    final results = await Variations().get(
      locationId: selectedLocationId,
      searchTerm: searchController.text,
      offset: offset,
      inStock: true,
    );
    
    if (results.isNotEmpty) {
      setState(() {
        products.addAll(results);
        offset++;
      });
    }
    setState(() => isLoading = false);
  }

  void addToCart(Map product) {
    setState(() {
      int index = cartItems.indexWhere((item) => item['variation_id'] == product['variation_id']);
      if (index >= 0) {
        cartItems[index]['quantity']++;
      } else {
        cartItems.add({
          'product_id': product['product_id'],
          'variation_id': product['variation_id'],
          'display_name': product['display_name'],
          'unit_price': product['sell_price_inc_tax'],
          'quantity': 1.0,
        });
      }
    });
  }

  void removeFromCart(int index) {
    setState(() {
      cartItems.removeAt(index);
    });
  }

  double getCartSubtotal() {
    double total = 0;
    for (var item in cartItems) {
      total += (double.parse(item['unit_price'].toString()) * item['quantity']);
    }
    return total;
  }

  double getCartTotal() {
    double subtotal = getCartSubtotal();
    if (discountType == 'fixed') {
      return subtotal - discountAmount;
    } else {
      return subtotal - (subtotal * discountAmount / 100);
    }
  }

  bool get hasValidCustomerSelection =>
      selectedContactId != null &&
      contacts.any((contact) =>
          int.tryParse(contact['id'].toString()) == selectedContactId);

  bool _requireCustomerSelection() {
    if (hasValidCustomerSelection) return true;
    Helper().showNotification(context, 'Select a customer', isError: true);
    return false;
  }

  Future<void> submitDraft() async {
    if (cartItems.isEmpty) return;
    if (!_requireCustomerSelection()) return;
    setState(() => isProcessing = true);
    try {
      String invoiceNo = await Helper().generateRefNumber('sell', locationId: selectedLocationId);
      Map<String, dynamic> sellData = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now()),
        contactId: selectedContactId,
        locId: selectedLocationId,
        discountAmount: discountAmount,
        discountType: discountType,
        invoiceAmount: getCartTotal(),
        pending: getCartTotal(),
        saleStatus: 'draft',
        isQuotation: 1,
      );

      int sellId = await SellDatabase().storeSell(sellData);
      for (var item in cartItems) {
        await SellDatabase().store({
          'sell_id': sellId,
          'product_id': item['product_id'],
          'variation_id': item['variation_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'is_completed': 1,
        });
      }
      
      if (await Helper().checkConnectivity()) {
        await Sell().createApiSell(sellId: sellId);
      }
      
      Helper().showNotification(context, "Order saved as draft");
      _clearCart();
    } catch (e) {
      Helper().showNotification(context, "Error: $e", isError: true);
    }
    setState(() => isProcessing = false);
  }

  Future<void> submitOrder(List payments) async {
    if (cartItems.isEmpty) return;
    if (!_requireCustomerSelection()) return;
    setState(() => isProcessing = true);
    try {
      String invoiceNo = await Helper().generateRefNumber('sell', locationId: selectedLocationId);
      Map<String, dynamic> sellData = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss").format(DateTime.now()),
        contactId: selectedContactId,
        locId: selectedLocationId,
        discountAmount: discountAmount,
        discountType: discountType,
        invoiceAmount: getCartTotal(),
        pending: 0.0,
        saleStatus: 'final',
      );

      int sellId = await SellDatabase().storeSell(sellData);
      for (var item in cartItems) {
        await SellDatabase().store({
          'sell_id': sellId,
          'product_id': item['product_id'],
          'variation_id': item['variation_id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'is_completed': 1,
        });
      }

      await Sell().makePayment(payments, sellId);
      
      if (await Helper().checkConnectivity()) {
        await Sell().createApiSell(sellId: sellId);
      }

      Helper().showNotification(context, "Order finalized successfully");
      _clearCart();
    } catch (e) {
      Helper().showNotification(context, "Error: $e", isError: true);
    }
    setState(() => isProcessing = false);
  }

  void _clearCart() {
    setState(() {
      cartItems = [];
      discountAmount = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    themeData = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Order'),
        backgroundColor: const Color(0xff732a13),
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 800) {
            return Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildLocationAndSearch(),
                      Expanded(child: _buildProductGrid(crossAxisCount: 3)),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(flex: 1, child: _buildCartPanel()),
              ],
            );
          }
          return Column(
            children: [
              _buildLocationAndSearch(),
              Expanded(child: _buildProductGrid(crossAxisCount: 2)),
              _buildMobileFooter(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLocationAndSearch() {
    return Padding(
      padding: EdgeInsets.all(MySize.size12!),
      child: Column(
        children: [
          DropdownButton<int>(
            isExpanded: true,
            value: locationListMap.any((l) => int.parse(l['id'].toString()) == selectedLocationId)
                ? selectedLocationId
                : (locationListMap.isNotEmpty ? int.parse(locationListMap[0]['id'].toString()) : 0),
            items: locationListMap.map<DropdownMenuItem<int>>((location) {
              return DropdownMenuItem<int>(
                value: int.parse(location['id'].toString()),
                child: Text(location['name']),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedLocationId = value ?? 0;
                products = [];
                offset = 0;
                productList();
              });
            },
          ),
          SizedBox(height: MySize.size12!),
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: hasValidCustomerSelection ? selectedContactId : null,
            decoration: const InputDecoration(
              labelText: 'Customer',
              border: OutlineInputBorder(),
            ),
            hint: Text(
              contacts.isEmpty ? 'No customers available' : 'Select customer',
            ),
            items: contacts
                .where((contact) =>
                    int.tryParse(contact['id'].toString()) != null)
                .map<DropdownMenuItem<int>>((contact) {
              return DropdownMenuItem<int>(
                value: int.parse(contact['id'].toString()),
                child: Text(
                  (contact['name'] ?? 'Unnamed customer').toString(),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: contacts.isEmpty
                ? null
                : (value) => setState(() => selectedContactId = value),
          ),
          SizedBox(height: MySize.size12!),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search products...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onSubmitted: (_) {
              setState(() {
                products = [];
                offset = 0;
                productList();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid({required int crossAxisCount}) {
    if (isLoading && products.isEmpty) {
      return Center(child: Helper().loadingIndicator(context));
    }
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(MySize.size12!),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final p = products[index];
        return InkWell(
          onTap: () => addToCart(p),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey[200],
                    child: p['product_image_url'] != null
                        ? Image.network(p['product_image_url'], fit: BoxFit.cover)
                        : const Icon(Icons.image, size: 40),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['display_name'], maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('$symbol${p['sell_price_inc_tax']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartPanel() {
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView.builder(
                itemCount: cartItems.length,
                itemBuilder: (context, index) {
                  final it = cartItems[index];
                  return ListTile(
                    title: Text(it['display_name']),
                    subtitle: Text('Qty: ${it['quantity']} x ${it['unit_price']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                      onPressed: () => removeFromCart(index),
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('$symbol${getCartTotal().toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isProcessing ? null : submitDraft,
                          child: const Text('Draft'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isProcessing ? null : () => submitOrder([{'method': 'cash', 'amount': getCartTotal(), 'note': ''}]),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff732a13), foregroundColor: Colors.white),
                          child: const Text('Finalize'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (isProcessing) Helper().loadingIndicator(context, subTitle: 'PROCESSING...'),
      ],
    );
  }

  Widget _buildMobileFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Items: ${cartItems.length}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => _buildCartPanel(),
              );
            },
            child: const Text('View Cart'),
          ),
        ],
      ),
    );
  }
}
