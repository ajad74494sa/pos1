import 'dart:convert';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/generators.dart';
import '../helpers/otherHelpers.dart';
import '../helpers/customer_display_service.dart';
import '../locale/MyLocalizations.dart';
import '../models/database.dart';
import '../models/paymentDatabase.dart';
import '../models/product_model.dart';
import '../models/sell.dart';
import '../models/sellDatabase.dart';
import '../models/system.dart';
import '../models/variations.dart';
import '../models/contact_model.dart';
import '../apis/contact.dart';
import '../services/printer_service.dart';
import '../services/whatsapp_service.dart';
import 'checkout.dart';

import '../widgets/windows_menu.dart';

class EditSale extends StatefulWidget {
  const EditSale({Key? key}) : super(key: key);

  @override
  _EditSaleState createState() => _EditSaleState();
}

class _EditSaleState extends State<EditSale> {
  List products = []; 
  List<Map<String, dynamic>> cartItems = [];
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  bool canMakeSell = false,
      inStock = false,
      gridView = true,
      canAddSell = true,
      canViewProducts = true,
      allowOverselling = true;
  bool isLoadingProducts = false, isProcessingSale = false;
  String discountType = 'percentage';
  double discountAmount = 0.0;
  double selectedCustomerDue = 0.0;

  int selectedLocationId = 0,
      categoryId = 0,
      subCategoryId = 0,
      brandId = 0,
      sellingPriceGroupId = 0,
      offset = 0;
  int? byAlphabets = 0, byPrice;

  String symbol = '';
  final searchController = TextEditingController();
  final FocusNode productSearchFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFormKey = GlobalKey<FormState>();
  ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  List customers = [];
  int selectedCustomerId = 1;
  Map? argument;
  List<Map<dynamic, dynamic>> locationListMap = [
    {'id': 0, 'name': 'All'},
  ];
  List<DropdownMenuItem<int>> _categoryMenuItems = [];
  List<DropdownMenuItem<int>> _subCategoryMenuItems = [];
  List<DropdownMenuItem<int>> _brandsMenuItems = [];

  bool _isInit = false;

  @override
  void initState() {
    super.initState();
    getPermission();
    _loadCustomers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        productList();
      }
    });

    setLocationMap();
    categoryList();
    subCategoryList(categoryId);
    brandList();
    Helper().syncCallLogs();
  }

  void _showSafeToast(String msg, {bool isError = false}) {
    if (mounted) {
      Helper().showNotification(context, msg, isError: isError);
    }
  }

  _loadCustomers() async {
    try {
      var list = await Contact().get();
      setState(() {
        customers = list;
      });
      await _updateCustomerDue();
    } catch (e) {}
  }

  _updateCustomerDue() async {
    if (selectedCustomerId != 0) {
      double due = 0.0;
      if (await Helper().checkConnectivity()) {
        try {
          var response = await CustomerApi().getContactDetails(selectedCustomerId);
          if (response != null && response['data'] != null && response['data'].isNotEmpty) {
            var contactData = response['data'][0];
            due = double.tryParse((contactData['sell_due'] ?? 0).toString()) ?? 0.0;
          } else {
            due = await SellDatabase().getCustomerDue(selectedCustomerId);
          }
        } catch (e) {
          due = await SellDatabase().getCustomerDue(selectedCustomerId);
        }
      } else {
        due = await SellDatabase().getCustomerDue(selectedCustomerId);
      }

      setState(() {
        selectedCustomerDue = due;
      });
    } else {
      setState(() {
        selectedCustomerDue = 0.0;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      argument = ModalRoute.of(context)!.settings.arguments as Map?;
      if (argument != null) {
        selectedLocationId = argument!['locationId'] ?? 0;
        if (argument!['customerId'] != null) {
          selectedCustomerId = argument!['customerId'];
        }
        if (argument!['discount_type'] != null) {
          discountType = argument!['discount_type'];
        }
        if (argument!['discount_amount'] != null) {
          discountAmount = double.tryParse(argument!['discount_amount'].toString()) ?? 0.0;
        }
      }
      _initialize();
      _isInit = true;
    }
  }

  _initialize() async {
    await setInitDetails(selectedLocationId);
    await cartList();
  }

  cartList() async {
    List lines = [];
    if (argument != null && argument!['sellId'] != null) {
      int sId = int.tryParse(argument!['sellId'].toString()) ?? 0;
      if (sId != 0) {
        lines = await SellDatabase().get(sellId: sId);
      }
    }

    if (lines.isNotEmpty) {
      setState(() {
        cartItems = lines
            .map((l) {
              return {
                'id': l['variation_id'] ?? l['product_id'],
                'product_id': l['product_id'],
                'display_name': l['name'] ?? 'Product',
                'image': l['product_image_url'],
                'unit_price': double.tryParse((l['unit_price'] ?? '0').toString()) ?? 0.0,
                'quantity': (l['quantity'] != null) ? (l['quantity'] as num).toInt() : 1,
                'discount_amount': double.tryParse((l['line_discount_amount'] ?? '0').toString()) ?? 0.0,
                'discount_type': l['line_discount_type'] ?? 'fixed',
              };
            })
            .toList()
            .cast<Map<String, dynamic>>();
      });
      _updateCustomerDisplay();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _debounce?.cancel();
    searchController.dispose();
    productSearchFocusNode.dispose();
    super.dispose();
  }

  setInitDetails(selectedLocationId) async {
    var activeSubscriptionDetails = await System().get('active-subscription');
    if (activeSubscriptionDetails.length > 0) {
      setState(() {
        canMakeSell = true;
      });
    }
    await Helper().getFormattedBusinessDetails().then((value) {
      symbol = value['symbol'] + ' ';
    });
    
    productList();
  }

  getPermission() async {
    if (await Helper().getPermission("direct_sell.access")) {
      canAddSell = true;
    }
    if (await Helper().getPermission("product.view")) {
      canViewProducts = true;
    }
  }

  productList() async {
    if (isLoadingProducts) return;
    setState(() => isLoadingProducts = true);

    await Variations()
        .get(
          brandId: brandId,
          categoryId: categoryId,
          subCategoryId: subCategoryId,
          inStock: inStock,
          locationId: selectedLocationId,
          searchTerm: searchController.text,
          offset: offset,
          byAlphabets: byAlphabets,
          byPrice: byPrice,
        )
        .then((element) {
      if (element != null && element is List && element.isNotEmpty) {
        offset++;
        List newProducts = [];
        for (var product in element) {
          final p = ProductModel().product(product, null);
          if (p != null) {
            newProducts.add(p);
          }
        }
        setState(() {
          products.addAll(newProducts);
        });
      }
    }).whenComplete(() {
      setState(() {
        isLoadingProducts = false;
      });
    });
  }

  categoryList() async {
    List categories = await System().getCategories();
    List<DropdownMenuItem<int>> tmp = [];
    tmp.add(
      DropdownMenuItem(
        child: Text(AppLocalizations.of(context).translate('select_category')),
        value: 0,
      ),
    );

    for (var category in categories) {
      tmp.add(
        DropdownMenuItem(child: Text(category['name']), value: category['id']),
      );
    }
    setState(() {
      _categoryMenuItems = tmp;
    });
  }

  subCategoryList(parentId) async {
    List subCategories = await System().getSubCategories(parentId);
    List<DropdownMenuItem<int>> tmp = [];
    tmp.add(
      DropdownMenuItem(
        child: Text(
          AppLocalizations.of(context).translate('select_sub_category'),
        ),
        value: 0,
      ),
    );
    subCategories.forEach((element) {
      tmp.add(
        DropdownMenuItem(
          child: Text(jsonDecode(element['value'])['name']),
          value: jsonDecode(element['value'])['id'],
        ),
      );
    });
    setState(() {
      _subCategoryMenuItems = tmp;
    });
  }

  brandList() async {
    List brands = await System().getBrands();
    List<DropdownMenuItem<int>> tmp = [];
    tmp.add(
      DropdownMenuItem(
        child: Text(AppLocalizations.of(context).translate('select_brand')),
        value: 0,
      ),
    );

    for (var brand in brands) {
      tmp.add(DropdownMenuItem(child: Text(brand['name']), value: brand['id']));
    }
    setState(() {
      _brandsMenuItems = tmp;
    });
  }

  double getCartSubTotal() {
    double total = 0;
    for (var item in cartItems) {
      double price = (item['unit_price'] ?? 0);
      double quantity = double.tryParse((item['quantity'] ?? 1).toString()) ?? 1.0;
      double discount = 0;
      if (item['discount_type'] == 'percentage') {
        discount = (price * (item['discount_amount'] ?? 0)) / 100;
      } else {
        discount = (item['discount_amount'] ?? 0);
      }
      total += (price - discount) * quantity;
    }
    return total;
  }

  double getCartDiscountAmount() {
    double subTotal = getCartSubTotal();
    if (discountType == 'percentage') {
      return (subTotal * discountAmount) / 100;
    } else {
      return discountAmount;
    }
  }

  double getCartTotal() {
    double subTotal = getCartSubTotal();
    double discount = getCartDiscountAmount();
    return subTotal - discount;
  }

  @override
  Widget build(BuildContext context) {
    MySize().init(context);
    themeData = Theme.of(context);

    return RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: _handleShortcuts,
      child: SafeArea(
        child: Stack(
          children: [
            Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.white,
            endDrawer: _filterDrawer(),
            appBar: AppBar(
              backgroundColor: const Color(0xff732a13),
              elevation: 0,
              centerTitle: false,
              iconTheme: const IconThemeData(color: Colors.white),
              title: Text(
                "Edit Sale #${argument?['sellId'] ?? ''}",
                style: AppTheme.getTextStyle(
                  themeData.textTheme.titleLarge,
                  fontWeight: 600,
                  color: Colors.white,
                ),
              ),
              actions: <Widget>[
                IconButton(
                  onPressed: () async {
                    if (await Helper().checkConnectivity()) {
                      Helper().showNotification(context, "Refreshing products...");
                      await Variations().refresh();
                      setState(() {
                        products = [];
                        offset = 0;
                      });
                      productList();
                    }
                  },
                  icon: const Icon(Symbols.sync, color: Colors.white),
                ),
              ],
            ),
            body: (canViewProducts)
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      bool isMobile = constraints.maxWidth < 900;
                      
                      if (isMobile) {
                        return Column(
                          children: [
                            _buildMobileProductHeader(),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(MySize.size8!),
                                color: const Color(0xfff5f5f5),
                                child: _productsList(crossAxisCount: constraints.maxWidth > 500 ? 3 : 2),
                              ),
                            ),
                            _buildMobileCartSummary(),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: constraints.maxWidth * (constraints.maxWidth > 1200 ? 0.3 : 0.4),
                            color: Colors.white,
                            padding: EdgeInsets.all(MySize.size16!),
                            child: _buildCartPanel(),
                          ),
                          const VerticalDivider(width: 1),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(MySize.size8!),
                              color: const Color(0xfff5f5f5),
                              child: _productsList(crossAxisCount: constraints.maxWidth > 1200 ? 5 : 4),
                            ),
                          ),
                        ],
                      );
                    }
                  )
                : Center(
                    child: Text(
                      AppLocalizations.of(context).translate('unauthorised'),
                      style: const TextStyle(color: Colors.black),
                    ),
                  ),
          ),
          if (isProcessingSale)
            Positioned.fill(
              child: Helper().loadingIndicator(context, subTitle: 'SAVING CHANGES...'),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildMobileProductHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(child: _buildCustomerPickerButton()),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            icon: const Icon(Icons.filter_alt_outlined),
          )
        ],
      ),
    );
  }

  Widget _buildCustomerPickerButton() {
    return InkWell(
      onTap: () async {
        List<Map<String, dynamic>> options = [];
        options.add({
          'id': 0,
          'name': 'Walk-in Customer',
          'mobile': '',
          'contact_id': ''
        });
        for (var c in customers) {
          options.add({
            'id': c['id'], 
            'name': c['name'],
            'mobile': c['mobile'] ?? '',
            'contact_id': c['contact_id'] ?? ''
          });
        }

        final selected = await showDialog<int>(
          context: context,
          builder: (ctx) {
            String query = '';
            List<Map<String, dynamic>> filtered = List.from(options);

            return StatefulBuilder(
              builder: (ctx, setStateDialog) {
                void doFilter(String q) {
                  query = q.toLowerCase();
                  filtered = options
                      .where(
                        (opt) => 
                            opt['name'].toString().toLowerCase().contains(query) ||
                            opt['mobile'].toString().toLowerCase().contains(query) ||
                            opt['contact_id'].toString().toLowerCase().contains(query),
                      )
                      .toList();
                  setStateDialog(() {});
                }

                return AlertDialog(
                  title: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search Name/Mobile/ID",
                      prefixIcon: const Icon(
                        Icons.search,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: doFilter,
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 320,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, idx) {
                              var opt = filtered[idx];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(
                                    opt['name']
                                        .toString()
                                        .split(' ')
                                        .map(
                                          (e) =>
                                              e.isNotEmpty
                                              ? e[0]
                                              : '',
                                        )
                                        .take(2)
                                        .join(),
                                  ),
                                ),
                                title: Text(
                                  opt['name'].toString(),
                                ),
                                subtitle: Text(
                                  "${opt['mobile']} ${opt['contact_id'] != '' ? ' | ID: ' + opt['contact_id'] : ''}",
                                  style: const TextStyle(fontSize: 12),
                                ),
                                onTap: () {
                                  Navigator.pop(
                                    ctx,
                                    int.tryParse(opt['id'].toString()) ?? 0,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton.icon(
                      icon: const Icon(Icons.person_add_alt_1, size: 20),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showAddCustomerDialog();
                      },
                      label: Text(
                        AppLocalizations.of(context).translate('add') ?? "Add",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        AppLocalizations.of(
                          context,
                        ).translate('close') ?? "Close",
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );

        if (selected != null) {
          setState(() {
            selectedCustomerId = selected;
          });
          await _updateCustomerDue();
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (selectedCustomerId == 0)
                        ? AppLocalizations.of(
                            context,
                          ).translate('walk_in_customer')
                        : (customers.firstWhere(
                                (c) =>
                                    c['id'] ==
                                    selectedCustomerId,
                                orElse: () => {'name': ''},
                              )['name'] ??
                              ''),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (selectedCustomerId != 0 && selectedCustomerDue > 0)
                    Row(
                      children: [
                        Text(
                          "${AppLocalizations.of(context).translate('due')}: $symbol${selectedCustomerDue.toStringAsFixed(2)}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: _updateCustomerDue,
                          child: const Icon(
                            Icons.refresh,
                            size: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: _showAddCustomerDialog,
              icon: const Icon(Icons.person_add_alt_1,
                  color: Color(0xff732a13), size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildCartPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCustomerPickerButton(),
        const SizedBox(height: 8),
        _buildCartHeader(),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(top: MySize.size12!),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: cartItems.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).translate('no_items_added_to_cart'),
                    ),
                  )
                : _buildCartList(),
          ),
        ),
        _buildCartFooter(),
      ],
    );
  }

  Widget _buildCartHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xfffafafa),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              'Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 6,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text(
                      'Qty',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Subtotal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Icon(
                    Icons.close,
                    color: Colors.black,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartList() {
    return ListView.separated(
      padding: const EdgeInsets.all(4),
      itemCount: cartItems.length,
      itemBuilder: (context, idx) {
        var it = cartItems[idx];
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: InkWell(
                  onTap: () => _showEditCartItemDialog(idx),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        it['display_name'],
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xff0088cc),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$symbol${it['unit_price']}' + 
                        (it['discount_amount'] > 0 ? ' (-${it['discount_amount']}${it['discount_type'] == 'percentage' ? '%' : ''})' : ''),
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _buildQtyControl(it, idx),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Builder(
                            builder: (context) {
                              double price = double.tryParse((it['unit_price'] ?? 0).toString()) ?? 0.0;
                              double quantity = double.tryParse((it['quantity'] ?? 1).toString()) ?? 1.0;
                              double discountAmount = double.tryParse((it['discount_amount'] ?? 0).toString()) ?? 0.0;
                              
                              double itemDiscount = 0;
                              if (it['discount_type'] == 'percentage') {
                                itemDiscount = (price * discountAmount) / 100;
                              } else {
                                itemDiscount = discountAmount;
                              }
                              return Text(
                                '${((price - itemDiscount) * quantity).toStringAsFixed(2)} $symbol',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              );
                            }
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 18,
                        ),
                        onPressed: () => _removeItem(idx),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, __) => const Divider(height: 1),
    );
  }

  Widget _buildQtyControl(Map it, int idx) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.grey.shade300,
        ),
        borderRadius:
            BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                num q = it['quantity'] ?? 1;
                if (q > 1) {
                  it['quantity'] = q - 1;
                } else {
                  cartItems.removeAt(idx);
                }
              });
              _updateCustomerDisplay();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
              child: const Icon(
                Icons.remove,
                size: 16,
                color: Colors.redAccent,
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
            constraints:
                const BoxConstraints(
                  minWidth: 30,
                ),
            child: Center(
              child: Text(
                '${it['quantity']}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          InkWell(
            onTap: () {
              setState(() {
                num q = it['quantity'] ?? 1;
                it['quantity'] = q + 1;
              });
              _updateCustomerDisplay();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
              child: const Icon(
                Icons.add,
                size: 16,
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartFooter() {
    double subTotal = getCartSubTotal();
    double discount = getCartDiscountAmount();
    double totalPayable = subTotal - discount;
    return Column(
      children: [
        SizedBox(height: MySize.size12 ?? 12.0),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: EdgeInsets.all(MySize.size12!),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: _buildSummaryItem('Subtotal', Helper().formatCurrency(subTotal) + symbol)),
                Expanded(
                  child: InkWell(
                    onTap: _showDiscountDialog,
                    child: _buildSummaryItem('Discount', Helper().formatCurrency(discount) + symbol, color: Colors.red, icon: Icons.edit),
                  ),
                ),
                Expanded(child: _buildSummaryItem('Total', Helper().formatCurrency(totalPayable) + symbol, color: Colors.green, alignEnd: true)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildCartActions(),
      ],
    );
  }

  Widget _buildSummaryItem(String label, String value, {Color? color, IconData? icon, bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTheme.getTextStyle(
                themeData.textTheme.bodySmall,
                fontWeight: 600,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: 4),
              Icon(icon, size: 12, color: Colors.blue),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTheme.getTextStyle(
            themeData.textTheme.bodyMedium,
            fontWeight: 700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildCartActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Cash',
                color: Colors.green,
                onPressed: () => finalizeExpressSale(method: 'cash'),
                isLoading: isProcessingSale,
              ),
            ),
            SizedBox(width: MySize.size8!),
            Expanded(
              child: _buildActionButton(
                label: 'Card',
                color: Colors.orange,
                onPressed: () => finalizeExpressSale(method: 'card'),
                isLoading: isProcessingSale,
              ),
            ),
          ],
        ),
        SizedBox(height: MySize.size8!),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                label: 'Draft',
                color: Colors.blueGrey,
                onPressed: _saveDraft,
                isLoading: isProcessingSale,
              ),
            ),
            SizedBox(width: MySize.size8!),
            Expanded(
              flex: 2,
              child: _buildActionButton(
                label: 'Pay & Checkout',
                color: const Color(0xff2196f3),
                onPressed: _updateAndOpenCheckout,
                isLoading: isProcessingSale,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        disabledBackgroundColor: color.withOpacity(0.6),
      ),
      child: isLoading
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }

  Widget _buildMobileCartSummary() {
    if (cartItems.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))]
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total: ${Helper().formatCurrency(getCartTotal())} $symbol', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('${cartItems.length} items', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => Container(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildCartPanel(),
                  ),
                ),
              );
            },
            child: const Text('View Cart'),
          ),
        ],
      ),
    );
  }

  Widget _productsList({required int crossAxisCount}) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(MySize.size8!),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Form(
                      key: _searchFormKey,
                      child: TextFormField(
                        focusNode: productSearchFocusNode,
                        style: AppTheme.getTextStyle(
                          themeData.textTheme.titleSmall,
                          letterSpacing: 0,
                          fontWeight: 500,
                        ),
                        decoration: InputDecoration(
                          hintText: AppLocalizations.of(context).translate('search'),
                          hintStyle: AppTheme.getTextStyle(
                            themeData.textTheme.titleSmall,
                            letterSpacing: 0,
                            fontWeight: 500,
                          ),
                          border: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                          ),
                          filled: true,
                          fillColor: const Color(0xfff6f7fb),
                          prefixIcon: Icon(
                            Symbols.search,
                            size: 22,
                            color: themeData.colorScheme.onSurface.withAlpha(150),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.only(right: 16),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        controller: searchController,
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce =
                              Timer(const Duration(milliseconds: 300), () {
                            setState(() {
                              products = [];
                              offset = 0;
                              isLoadingProducts = false;
                            });
                            productList();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () => _scaffoldKey.currentState?.openEndDrawer(),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Symbols.filter_alt,
                        size: 24,
                        color: themeData.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              if (categoryId != 0 || brandId != 0) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (categoryId != 0)
                      Chip(
                        label: Text(
                          _categoryMenuItems
                              .firstWhere((it) => it.value == categoryId)
                              .child
                              .toString(),
                        ),
                      ),
                    if (brandId != 0)
                      Chip(
                        label: Text(
                          _brandsMenuItems
                              .firstWhere((it) => it.value == brandId)
                              .child
                              .toString(),
                        ),
                      ),
                    ActionChip(
                      backgroundColor: const Color(0xff4c53a5),
                      label: Text(
                        AppLocalizations.of(context).translate('clear_filters'),
                        style: const TextStyle(color: Colors.white),
                      ),
                      onPressed: () {
                        setState(() {
                          categoryId = 0;
                          brandId = 0;
                        });
                        products = [];
                        offset = 0;
                        productList();
                      },
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: products.isEmpty
              ? (isLoadingProducts
                  ? Center(child: Helper().loadingIndicator(context))
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_empty, size: 48, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(AppLocalizations.of(context).translate('no_products_found')),
                        ],
                      ),
                    ))
              : Stack(
                  children: [
                    CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (gridView)
                          SliverPadding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.8,
                              ),
                              delegate: SliverChildBuilderDelegate((context, index) {
                                var product = products[index];
                                var effId = product['variation_id'] ?? product['product_id'];
                                String effIdStr = effId?.toString() ?? '';
                                int cartIdx = cartItems.indexWhere(
                                  (item) => (item['id']?.toString() ?? '') == effIdStr,
                                );

                                return InkWell(
                                  onTap: () async => _addToCart(product),
                                  child: Stack(
                                    children: [
                                      _ProductGridWidget(
                                        name: product['display_name'],
                                        image: product['product_image_url'],
                                        qtyAvailable: (product['enable_stock'] != 0)
                                            ? product['stock_available'].toString()
                                            : '-',
                                        price: double.parse(product['unit_price'].toString()),
                                        symbol: symbol,
                                        cardColor: [
                                          Colors.blue.shade50,
                                          Colors.green.shade50,
                                          Colors.orange.shade50,
                                          Colors.pink.shade50,
                                          Colors.purple.shade50,
                                          Colors.teal.shade50,
                                          Colors.amber.shade50,
                                          Colors.cyan.shade50,
                                        ][index % 8],
                                      ),
                                      if (cartIdx >= 0)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: GestureDetector(
                                            onTap: () => _showEditCartDialog(product),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.9),
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.shopping_cart_outlined, size: 16),
                                                  const SizedBox(width: 6),
                                                  Text('${cartItems[cartIdx]['quantity'] ?? 0}'),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }, childCount: products.length),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: isLoadingProducts
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Center(child: Helper().loadingIndicator(context)),
                                )
                              : const SizedBox(height: 100),
                        ),
                      ],
                    ),
                    if (isLoadingProducts && products.isEmpty)
                      Helper().loadingIndicator(context, subTitle: 'LOADING PRODUCTS...'),
                  ],
                ),
        ),
      ],
    );
  }

  void _removeItem(int idx) {
    setState(() => cartItems.removeAt(idx));
    _updateCustomerDisplay();
  }

  void _showEditCartDialog(Map product) async {
    int idx = _getCartIndexForProduct(product);
    if (idx < 0) return;
    TextEditingController qtyController = TextEditingController(text: (cartItems[idx]['quantity'] ?? 1).toString());
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('edit_item') ?? 'Edit item'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [ Text(product['display_name'] ?? ''), const SizedBox(height: 12), TextField(controller: qtyController, onTap: () { qtyController.selection = TextSelection(baseOffset: 0, extentOffset: qtyController.text.length); }, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: AppLocalizations.of(context).translate('quantity') ?? 'Quantity')) ]),
          actions: [
            TextButton(onPressed: () async { Navigator.pop(ctx); setState(() { cartItems.removeAt(idx); }); _updateCustomerDisplay(); }, child: Text(AppLocalizations.of(context).translate('delete') ?? 'Delete', style: const TextStyle(color: Colors.red))),
            TextButton(onPressed: () { Navigator.pop(ctx); }, child: Text(AppLocalizations.of(context).translate('cancel') ?? 'Cancel')),
            ElevatedButton(onPressed: () async { double q = Helper().validateInput(qtyController.text); if (q <= 0) { Helper().showNotification(context, AppLocalizations.of(context).translate('enter_valid_quantity') ?? 'Enter valid quantity', isError: true); return; } setState(() { cartItems[idx]['quantity'] = (q % 1 == 0) ? q.toInt() : q; }); _updateCustomerDisplay(); Navigator.pop(ctx); }, child: Text(AppLocalizations.of(context).translate('update') ?? 'Update'))
          ],
        );
      },
    );
  }

  int _getCartIndexForProduct(Map product) {
    var effId = product['variation_id'] ?? product['product_id'];
    String effIdStr = effId?.toString() ?? '';
    return cartItems.indexWhere((item) => (item['id']?.toString() ?? '') == effIdStr);
  }

  void _addToCart(Map p) {
    var effId = p['variation_id'] ?? p['product_id'];
    int existingIdx = cartItems.indexWhere((it) => it['id'] == effId);
    if (existingIdx >= 0) {
      setState(() => cartItems[existingIdx]['quantity']++);
    } else {
      setState(() => cartItems.add({
        'id': effId,
        'product_id': p['product_id'],
        'display_name': p['display_name'],
        'image': p['product_image_url'],
        'unit_price': double.parse(p['unit_price'].toString()),
        'quantity': 1,
        'discount_amount': 0.0,
        'discount_type': 'fixed',
      }));
    }
    _updateCustomerDisplay();
  }

  void _showDiscountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String tempType = discountType;
        TextEditingController amountController = TextEditingController(text: discountAmount.toString());
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text('Discount Reward', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)), InkWell(onTap: () => Navigator.pop(ctx2), child: const Icon(Icons.close, size: 20, color: Colors.grey))]),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text('Edit Discount:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Discount Type:*', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)), child: Row(children: [ const Icon(Icons.info_outline, size: 18, color: Colors.grey), const SizedBox(width: 10), Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: tempType, isExpanded: true, dropdownColor: Colors.white, items: const [ DropdownMenuItem(child: Text('Percentage'), value: 'percentage'), DropdownMenuItem(child: Text('Fixed'), value: 'fixed') ], onChanged: (val) { setStateDialog(() { tempType = val!; }); }))) ])) ])),
                      const SizedBox(width: 15),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const Text('Discount Amount:*', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), Container(height: 48, decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)), child: Row(children: [ const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Icon(Icons.info_outline, size: 18, color: Colors.grey)), Expanded(child: TextField(controller: amountController, onTap: () { amountController.selection = TextSelection(baseOffset: 0, extentOffset: amountController.text.length); }, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(border: InputBorder.none, isDense: true))) ])) ]))
                    ]),
                    const SizedBox(height: 30),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      ElevatedButton(onPressed: () { setState(() { discountType = tempType; discountAmount = double.tryParse(amountController.text) ?? 0.0; }); _updateCustomerDisplay(); Navigator.pop(ctx2); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff6200ee), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Update', style: TextStyle(color: Colors.white))),
                      const SizedBox(width: 10),
                      ElevatedButton(onPressed: () => Navigator.pop(ctx2), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff2c3e50), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Cancel', style: TextStyle(color: Colors.white)))
                    ])
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showAddCustomerDialog() {
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_rounded, color: Color(0xff732a13), size: 32),
                      const SizedBox(height: 16),
                      const Text("Add New Customer", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xff732a13))),
                      const SizedBox(height: 24),
                      TextFormField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
                      const SizedBox(height: 20),
                      TextFormField(controller: mobileController, decoration: const InputDecoration(labelText: "Mobile Number"), keyboardType: TextInputType.phone),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel"))),
                          const SizedBox(width: 16),
                          Expanded(child: ElevatedButton(onPressed: () async {
                             if (formKey.currentState!.validate()) {
                               setDialogState(() => isSaving = true);
                               try {
                                 final response = await CustomerApi().add({'type': 'customer', 'first_name': nameController.text, 'mobile': mobileController.text});
                                 if (response != null) {
                                   await _loadCustomers();
                                   Navigator.pop(ctx);
                                 }
                               } finally { setDialogState(() => isSaving = false); }
                             }
                          }, child: isSaving ? const CircularProgressIndicator() : const Text("Save"))),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditCartItemDialog(int index) {
    var item = cartItems[index];
    TextEditingController priceController = TextEditingController(text: item['unit_price'].toString());
    TextEditingController discountController = TextEditingController(text: item['discount_amount'].toString());
    String currentDiscountType = item['discount_type'] ?? 'fixed';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(item['display_name']),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Unit Price'), keyboardType: TextInputType.number),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: discountController, decoration: const InputDecoration(labelText: 'Discount'), keyboardType: TextInputType.number)),
                  const SizedBox(width: 10),
                  DropdownButton<String>(value: currentDiscountType, items: const [ DropdownMenuItem(value: 'fixed', child: Text('Fixed')), DropdownMenuItem(value: 'percentage', child: Text('Percentage')) ], onChanged: (val) { if (val != null) { setDialogState(() { currentDiscountType = val; }); } })
                ])
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(onPressed: () { setState(() { cartItems[index]['unit_price'] = double.tryParse(priceController.text) ?? item['unit_price']; cartItems[index]['discount_amount'] = double.tryParse(discountController.text) ?? 0.0; cartItems[index]['discount_type'] = currentDiscountType; }); _updateCustomerDisplay(); Navigator.pop(context); }, child: const Text('Update'))
              ],
            );
          },
        );
      },
    );
  }

  void _handleShortcuts(RawKeyEvent event) async {
    if (event is! RawKeyDownEvent) return;
    bool isControlPressed = event.isControlPressed;
    if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyC) { _quickCheckout('cash'); }
    else if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyB) { _quickCheckout('card'); }
    else if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyM) { _updateAndOpenCheckout(); }
    else if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyD) { _saveDraft(); }
  }

  Map _getCheckoutArgs() {
    return Helper().argument(locId: selectedLocationId, taxId: argument != null ? argument!['taxId'] : null, discountType: discountType, discountAmount: discountAmount, invoiceAmount: getCartTotal(), sellId: argument != null ? argument!['sellId'] : null, isQuotation: argument != null ? argument!['is_quotation'] : 0, customerId: selectedCustomerId);
  }

  Future<void> _quickCheckout(String method) async {
    if (cartItems.isEmpty) return;
    setState(() => isProcessingSale = true);
    try {
      int sellId = argument!['sellId'];
      double total = getCartTotal();
      await SellDatabase().updateSells(sellId, {'invoice_amount': total, 'pending_amount': total, 'is_synced': 0, 'discount_amount': discountAmount, 'discount_type': discountType});
      await SellDatabase().deleteSellLineBySellId(sellId);
      for (var it in cartItems) { await SellDatabase().store({'sell_id': sellId, 'product_id': it['product_id'], 'variation_id': it['id'], 'quantity': it['quantity'], 'unit_price': it['unit_price'], 'discount_amount': it['discount_amount'] ?? 0.0, 'discount_type': it['discount_type'] ?? 'fixed', 'is_completed': 1}); }
      var result = await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (ctx) => CheckOut(initialArgument: {..._getCheckoutArgs(), 'defaultPaymentMethod': method, 'autoFinalize': true}, replaceRootOnComplete: false), fullscreenDialog: true));
      if (result == true) { Navigator.pop(context, true); }
    } catch (e) { Helper().showNotification(context, '$e', isError: true); }
    finally { setState(() => isProcessingSale = false); }
  }

  Future<void> _saveDraft() async {
    if (cartItems.isEmpty) return;
    setState(() => isProcessingSale = true);
    try {
      int sellId = argument!['sellId'];
      double total = getCartTotal();
      await SellDatabase().updateSells(sellId, {'invoice_amount': total, 'pending_amount': total, 'is_synced': 0, 'discount_amount': discountAmount, 'discount_type': discountType, 'status': 'draft', 'is_quotation': 1});
      await SellDatabase().deleteSellLineBySellId(sellId);
      for (var it in cartItems) { await SellDatabase().store({'sell_id': sellId, 'product_id': it['product_id'], 'variation_id': it['id'], 'quantity': it['quantity'], 'unit_price': it['unit_price'], 'discount_amount': it['discount_amount'] ?? 0.0, 'discount_type': it['discount_type'] ?? 'fixed', 'is_completed': 1}); }
      Helper().showNotification(context, "Draft updated successfully");
      Navigator.pop(context, true);
    } catch (e) { Helper().showNotification(context, '$e', isError: true); }
    finally { setState(() => isProcessingSale = false); }
  }

  Future<void> finalizeExpressSale({String method = 'cash'}) async {
    if (isProcessingSale) return;
    if (cartItems.isEmpty) { Helper().showNotification(context, "Cart is empty", isError: true); return; }
    setState(() => isProcessingSale = true);
    try {
      int sellId = argument!['sellId'];
      double total = getCartTotal();
      await SellDatabase().updateSells(sellId, {'invoice_amount': total, 'pending_amount': 0.0, 'is_synced': 0, 'discount_amount': discountAmount, 'discount_type': discountType});
      await SellDatabase().deleteSellLineBySellId(sellId);
      for (var it in cartItems) { await SellDatabase().store({'sell_id': sellId, 'product_id': it['product_id'], 'variation_id': it['id'], 'quantity': it['quantity'], 'unit_price': it['unit_price'], 'discount_amount': 0.0, 'discount_type': 'fixed', 'is_completed': 1}); }
      await PaymentDatabase().delete(sellId);
      int? accountId;
      try {
        List methods = await System().get('payment_method', selectedLocationId);
        var selectedMethod = methods.firstWhere((m) => m['name'].toString().toLowerCase() == method.toLowerCase(), orElse: () => null);
        if (selectedMethod != null && selectedMethod['account_id'] != null) { accountId = int.tryParse(selectedMethod['account_id'].toString()); }
      } catch (_) {}
      await Sell().makePayment([{'method': method, 'amount': total, 'note': '${method[0].toUpperCase()}${method.substring(1)} Checkout (Edit)', 'account_id': accountId}], sellId);
      await Helper().printDocument(sellId, 0, context);
      if (await Helper().checkConnectivity()) { await Sell().createApiSell(sellId: sellId); }
      WhatsAppService().sendSaleNotification(sellId);
      Helper().showNotification(context, "Sale updated successfully!");
      Navigator.pushNamedAndRemoveUntil(context, '/layout', (route) => false, arguments: {'initialIndex': 1});
    } catch (e) { Helper().showNotification(context, "Error: $e", isError: true); }
    finally { setState(() => isProcessingSale = false); }
  }

  Future<void> _updateAndOpenCheckout() async {
    if (cartItems.isEmpty) { Helper().showNotification(context, "Cart is empty", isError: true); return; }
    setState(() => isProcessingSale = true);
    try {
      int sellId = argument!['sellId'];
      double total = getCartTotal();
      await SellDatabase().updateSells(sellId, {'invoice_amount': total, 'pending_amount': total, 'is_synced': 0, 'discount_amount': discountAmount, 'discount_type': discountType});
      await SellDatabase().deleteSellLineBySellId(sellId);
      for (var it in cartItems) { await SellDatabase().store({'sell_id': sellId, 'product_id': it['product_id'], 'variation_id': it['id'], 'quantity': it['quantity'], 'unit_price': it['unit_price'], 'discount_amount': 0.0, 'discount_type': 'fixed', 'is_completed': 1}); }
      var result = await Navigator.of(context).push(MaterialPageRoute<bool>(builder: (ctx) => CheckOut(initialArgument: Helper().argument(invoiceAmount: total, customerId: selectedCustomerId, locId: selectedLocationId, sellId: sellId), replaceRootOnComplete: false), fullscreenDialog: true));
      if (result == true) { Navigator.pushNamedAndRemoveUntil(context, '/layout', (route) => false, arguments: {'initialIndex': 1}); }
    } catch (e) { Helper().showNotification(context, "Error: $e", isError: true); }
    finally { setState(() => isProcessingSale = false); }
  }

  Widget _filterDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(child: Center(child: Text("Filters", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
          Expanded(child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButton<int>(isExpanded: true, value: categoryId, items: _categoryMenuItems, onChanged: (v) => setState(() { categoryId = v!; products = []; offset = 0; productList(); })),
              const SizedBox(height: 10),
              DropdownButton<int>(isExpanded: true, value: brandId, items: _brandsMenuItems, onChanged: (v) => setState(() { brandId = v!; products = []; offset = 0; productList(); })),
            ],
          )),
        ],
      ),
    );
  }

  setLocationMap() async {
    var value = await System().get('location');
    for (var element in value) {
      if (element['is_active'].toString() == '1') {
        locationListMap.add({
          'id': element['id'],
          'name': element['name'],
        });
      }
    }
  }

  void _updateCustomerDisplay() {
    try {
      final displayService = Provider.of<CustomerDisplayService>(context, listen: false);
      displayService.updateDisplay(
        items: cartItems
            .map((item) => {
                  'name': item['display_name'],
                  'quantity': item['quantity'],
                  'price': item['unit_price'].toStringAsFixed(2),
                })
            .toList(),
        total: getCartTotal().toStringAsFixed(2),
        symbol: symbol,
      );
    } catch (e) {}
  }
}

class _ProductGridWidget extends StatefulWidget {
  final String? name, image, symbol;
  final String? qtyAvailable;
  final double? price;
  final Color? cardColor;
  const _ProductGridWidget({Key? key, required this.name, required this.image, required this.qtyAvailable, required this.price, required this.symbol, this.cardColor}) : super(key: key);
  @override
  _ProductGridWidgetState createState() => _ProductGridWidgetState();
}

class _ProductGridWidgetState extends State<_ProductGridWidget> {
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  @override
  Widget build(BuildContext context) {
    String key = Generator.randomString(10);
    themeData = Theme.of(context);
    return Card(
      elevation: 4, shadowColor: Colors.black26, clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), color: widget.cardColor ?? Colors.white,
      child: Stack(children: [
        Positioned.fill(child: Hero(tag: key, child: CachedNetworkImage(fit: BoxFit.cover, errorWidget: (context, url, error) => Image.asset('assets/images/default_product.png'), placeholder: (context, url) => Image.asset('assets/images/default_product.png'), imageUrl: widget.image ?? ''))),
        if (widget.qtyAvailable != '-') Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: themeData.colorScheme.primary.withOpacity(0.9), borderRadius: BorderRadius.circular(6)), child: Text('Qty: ${widget.qtyAvailable}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
        Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.withOpacity(0.9), borderRadius: BorderRadius.circular(6)), child: Text("${widget.symbol}${Helper().formatCurrency(widget.price)}", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)))),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12))), child: Text(widget.name!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))))
      ]),
    );
  }
}
