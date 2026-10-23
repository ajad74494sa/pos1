import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import '../apis/product_stock_report.dart';
import '../helpers/AppTheme.dart';
import '../locale/MyLocalizations.dart';
import '../models/product_stock_report_model.dart';

class ProductStockReportScreen extends StatefulWidget {
  static const String routeName = '/ProductStockReport';
  const ProductStockReportScreen({Key? key}) : super(key: key);

  static const int themeType = 1;

  @override
  State<ProductStockReportScreen> createState() =>
      _ProductStockReportScreenState();
}

class _ProductStockReportScreenState extends State<ProductStockReportScreen> {
  final ThemeData themeData =
      AppTheme.getThemeFromThemeMode(ProductStockReportScreen.themeType);

  List<ProductStockReportModel> myProductReportList = [];
  List<ProductStockReportModel> filteredList = [];
  bool loading = true;
  
  TextEditingController searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Future<void> _getProductStockReport() async {
    setState(() {
      loading = true;
      myProductReportList = [];
    });

    try {
      String? currentUrl;
      bool hasNext = true;

      while (hasNext) {
        var result = await ProductStockReportService().getProductStockReport(url: currentUrl);
        if (result != null && result is Map) {
          String? nextUrl = result['next_page_url'];
          setState(() {
            myProductReportList.addAll(result['data']);
            _applyFilter();
          });
          
          if (nextUrl != null) {
            currentUrl = nextUrl;
          } else {
            hasNext = false;
          }
        } else {
          hasNext = false;
        }
      }
    } catch (e) {
      dev.log("Error loading all products: $e");
    } finally {
      setState(() => loading = false);
    }
  }

  void _applyFilter() {
    String query = searchController.text.toLowerCase();
    setState(() {
      filteredList = myProductReportList
          .where((p) =>
              (p.product?.toLowerCase().contains(query) ?? false) ||
              (p.sku?.toLowerCase().contains(query) ?? false))
          .toList();
    });
  }

  @override
  void initState() {
    _getProductStockReport();
    super.initState();
  }

  @override
  void dispose() {
    searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xff732a13),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          AppLocalizations.of(context).translate('products_stock'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xff732a13)))
                : filteredList.isEmpty
                    ? _buildNoData()
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          return _buildProductCard(filteredList[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    double totalStockValue = 0;
    for (var p in filteredList) {
      totalStockValue += double.tryParse(p.stockPrice ?? '0') ?? 0;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      decoration: const BoxDecoration(
        color: Color(0xff732a13),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Text(
            'TOTAL STOCK VALUE'.toUpperCase(),
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            totalStockValue.toStringAsFixed(2),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSummaryItem('Items', filteredList.length.toString()),
              Container(width: 1, height: 20, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 20)),
              _buildSummaryItem('Locations', _getUniqueLocations()),
            ],
          ),
        ],
      ),
    );
  }

  String _getUniqueLocations() {
    return filteredList.map((e) => e.locationName).toSet().length.toString();
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: TextField(
        controller: searchController,
        onChanged: (val) => _applyFilter(),
        decoration: InputDecoration(
          hintText: 'Search product or SKU...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xff732a13), size: 20),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xff732a13)),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(ProductStockReportModel product) {
    double stock = double.tryParse(product.stock ?? '0') ?? 0;
    double alert = double.tryParse(product.alertQuantity ?? '0') ?? 0;
    bool isLowStock = stock <= alert && stock > 0;
    bool isOutOfStock = stock <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.product ?? 'N/A',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueGrey[900]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'SKU: ${product.sku ?? 'N/A'}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              _buildStockBadge(stock, product.unit ?? '', isLowStock, isOutOfStock),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildInfoColumn('Price', '${product.unitPrice}'),
              _buildInfoColumn('Total Value', '${product.stockPrice}'),
              _buildInfoColumn('Sold', '${product.totalSold}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(
                product.locationName ?? 'N/A',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              const Spacer(),
              Text(
                product.categoryName ?? 'Uncategorized',
                style: TextStyle(fontSize: 11, color: Colors.blue[700], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockBadge(double stock, String unit, bool isLow, bool isOut) {
    Color color = Colors.green;
    String text = 'In Stock';
    if (isOut) {
      color = Colors.red;
      text = 'Out of Stock';
    } else if (isLow) {
      color = Colors.orange;
      text = 'Low Stock';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$stock $unit',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          text,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[800])),
      ],
    );
  }

  Widget _buildNoData() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }
}
