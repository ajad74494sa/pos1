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

class Products extends StatefulWidget {
  const Products({super.key});

  @override
  State<Products> createState() => _ProductsState();
}

class _ProductsState extends State<Products> {
  List products = [];
  static List cachedProducts = [];
  static int cachedLocationId = -1;
  List<Map<String, dynamic>> cartItems = [];
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  bool changeLocation = false,
      changePriceGroup = false,
      canChangeLocation = true,
      canMakeSell = false,
      inStock = false,
      gridView = true,
      canAddSell = true,
      canViewProducts = true,
      usePriceGroup = false,
      allowOverselling = true;
  bool isLoadingProducts = false, isProcessingSale = false;
  int? activeSellId;
  String discountType = 'percentage';
  double discountAmount = 0.0;
  double selectedCustomerDue = 0.0;

  int selectedLocationId = 0,
      categoryId = 0,
      subCategoryId = 0,
      brandId = 0,
      cartCount = 0,
      sellingPriceGroupId = 0,
      offset = 0;
  int? byAlphabets = 0, byPrice;

  String symbol = '';
  final searchController = TextEditingController();
  final FocusNode productSearchFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchFormKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounce;
  List customers = [];
  int selectedCustomerId = 0;
  Map? argument;
  List<Map<dynamic, dynamic>> locationListMap = [
    {'id': 0, 'name': 'All'},
  ];
  List<DropdownMenuItem<int>> _categoryMenuItems = [];
  List<DropdownMenuItem<int>> _subCategoryMenuItems = [];
  List<DropdownMenuItem<int>> _brandsMenuItems = [];
  List<DropdownMenuItem<bool>> _priceGroupMenuItems = [];

  @override
  void initState() {
    super.initState();
    getPermission();
    _loadCustomers().whenComplete(() async {
      if (!mounted) return;
      setState(() {
        isLoadingProducts = false;
      });
      try {
        cachedProducts = List.from(products);
        cachedLocationId = selectedLocationId;
      } catch (_) {}
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        productList();
      }
    });

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

  Future<void> _loadCustomers() async {
    try {
      if (await Helper().checkConnectivity()) {
        await CustomerApi().get();
      }
      var list = await Contact().get();
      if (!mounted) return;
      setState(() {
        customers = list;
      });
      if (activeSellId == null) {
        await _selectDefaultCustomerForLocation(selectedLocationId);
      }
      await _updateCustomerDue();
    } catch (_) {}
  }

  Future<void> _selectDefaultCustomerForLocation(int locationId) async {
    final location = locationListMap.cast<Map>().firstWhere(
      (item) => int.tryParse(item['id'].toString()) == locationId,
      orElse: () => <String, dynamic>{},
    );
    final defaultCustomerId = int.tryParse(
      location['default_customer_id']?.toString() ?? '',
    );
    final defaultCustomer = defaultCustomerId == null
        ? null
        : customers.cast<Map>().where((customer) {
            return int.tryParse(customer['id'].toString()) == defaultCustomerId;
          }).firstOrNull;
    final walkInCustomer = customers.cast<Map>().where((customer) {
      final name = (customer['name'] ?? '').toString().toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final contactCode = (customer['contact_id'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      return name == 'walkincustomer' || contactCode == 'CO0001';
    }).firstOrNull;
    final customer = defaultCustomer ?? walkInCustomer;

    if (selectedLocationId == locationId &&
        activeSellId == null &&
        selectedCustomerId == 0) {
      if (mounted) {
        setState(() {
          selectedCustomerId =
              int.tryParse(customer?['id']?.toString() ?? '') ?? 0;
        });
      } else {
        selectedCustomerId =
            int.tryParse(customer?['id']?.toString() ?? '') ?? 0;
      }
      await _updateCustomerDue();
    }
  }

  Future<void> _updateCustomerDue() async {
    if (selectedCustomerId != 0) {
      double due = 0.0;
      if (await Helper().checkConnectivity()) {
        try {
          var response = await CustomerApi().getContactDetails(
            selectedCustomerId,
          );
          if (response != null &&
              response['data'] != null &&
              response['data'].isNotEmpty) {
            var contactData = response['data'][0];
            due =
                double.tryParse((contactData['sell_due'] ?? 0).toString()) ??
                0.0;
          } else {
            due = await SellDatabase().getCustomerDue(selectedCustomerId);
          }
        } catch (_) {
          due = await SellDatabase().getCustomerDue(selectedCustomerId);
        }
      } else {
        due = await SellDatabase().getCustomerDue(selectedCustomerId);
      }

      if (!mounted) return;
      setState(() {
        selectedCustomerDue = due;
      });
    } else {
      if (!mounted) return;
      setState(() {
        selectedCustomerDue = 0.0;
      });
    }
  }

  @override
  Future<void> didChangeDependencies() async {
    argument = ModalRoute.of(context)!.settings.arguments as Map?;
    if (argument != null && argument!['locationId'] != null) {
      selectedLocationId =
          int.tryParse(argument!['locationId'].toString()) ??
          selectedLocationId;
      canChangeLocation = false;

      if (argument!['sellId'] != null) {
        activeSellId = int.tryParse(argument!['sellId'].toString());
      }

      // We don't need a delay here usually, but if needed for animation/transition:
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) setState(() {});
      });
    } else {
      canChangeLocation = true;
    }
    await setLocationMap();
    await setInitDetails(selectedLocationId);
    if (activeSellId == null) {
      await _selectDefaultCustomerForLocation(selectedLocationId);
    }
    await cartList();
    if (mounted) {
      super.didChangeDependencies();
    }
  }

  Future<void> cartList() async {
    List lines = [];
    if (argument != null && argument!['locationId'] != null) {
      if (argument!['sellId'] != null) {
        lines = await SellDatabase().getInCompleteLines(
          argument!['locationId'],
          sellId: argument!['sellId'],
        );
      } else {
        lines = await SellDatabase().getInCompleteLines(
          argument!['locationId'],
        );
      }
    }

    if (lines.isNotEmpty) {
      setState(() {
        cartItems = lines
            .map((l) {
              return {
                'id': l['variation_id'],
                'product_id': l['product_id'],
                'display_name': l['name'] ?? '',
                'image': l['product_image_url'],
                'unit_price':
                    double.tryParse((l['unit_price'] ?? '0').toString()) ?? 0.0,
                'quantity': (l['quantity'] != null)
                    ? (l['quantity'] as num).toInt()
                    : 1,
                'discount_amount':
                    double.tryParse((l['discount_amount'] ?? '0').toString()) ??
                    0.0,
                'discount_type': l['discount_type'] ?? 'fixed',
              };
            })
            .toList()
            .cast<Map<String, dynamic>>();
        cartCount = cartItems.length;
      });
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

  Future<void> setInitDetails(int selectedLocationId) async {
    var activeSubscriptionDetails = await System().get('active-subscription');
    if (activeSubscriptionDetails.length > 0) {
      if (!mounted) return;
      setState(() {
        canMakeSell = true;
      });
    } else {
      if (mounted) {
        Helper().showNotification(
          context,
          AppLocalizations.of(context).translate('no_subscription_found'),
          isError: true,
        );
      }
    }
    await Helper().getFormattedBusinessDetails().then((value) {
      symbol = value['symbol'] + ' ';
    });
    unawaited(Helper().preloadBusinessLogo());
    setDefaultLocation(selectedLocationId);
    try {
      var stored = await System().get('products_cache', selectedLocationId);
      if (stored != null && stored is List && stored.isNotEmpty) {
        products = List.from(stored);
        try {
          products.sort((a, b) {
            final an = (a['display_name'] ?? a['name'] ?? '')
                .toString()
                .toLowerCase();
            final bn = (b['display_name'] ?? b['name'] ?? '')
                .toString()
                .toLowerCase();
            if (byAlphabets == 1) return bn.compareTo(an);
            return an.compareTo(bn);
          });
        } catch (_) {}
        cachedProducts = List.from(products);
        cachedLocationId = selectedLocationId;
        offset = products.isNotEmpty ? (products.length ~/ 50) : 0;
        if (!mounted) return;
        setState(() {});
      }
    } catch (_) {}

    bool canUseCache =
        (cachedProducts.isNotEmpty &&
        cachedLocationId == selectedLocationId &&
        searchController.text.trim().isEmpty &&
        categoryId == 0 &&
        subCategoryId == 0 &&
        brandId == 0 &&
        inStock == false &&
        byAlphabets == 0 &&
        byPrice == null);

    if (canUseCache) {
      products = List.from(cachedProducts);
      try {
        products.sort((a, b) {
          final an = (a['display_name'] ?? a['name'] ?? '')
              .toString()
              .toLowerCase();
          final bn = (b['display_name'] ?? b['name'] ?? '')
              .toString()
              .toLowerCase();
          if (byAlphabets == 1) return bn.compareTo(an);
          return an.compareTo(bn);
        });
      } catch (_) {}
      offset = products.isNotEmpty ? (products.length ~/ 50) : 0;
      setState(() {});
    } else {
      offset = products.isNotEmpty ? (products.length ~/ 50) : 0;
      productList();
    }
  }

  getPermission() async {
    if (await Helper().getPermission("direct_sell.access")) {
      canAddSell = true;
    }
    if (await Helper().getPermission("product.view")) {
      canViewProducts = true;
    }
  }

  findSellingPriceGroupId(locId) {
    if (usePriceGroup) {
      for (var element in locationListMap) {
        if (element['id'] == selectedLocationId &&
            element['selling_price_group_id'] != null) {
          sellingPriceGroupId = int.parse(
            element['selling_price_group_id'].toString(),
          );
        } else if (element['id'] == selectedLocationId &&
            element['selling_price_group_id'] == null) {
          sellingPriceGroupId = 0;
        }
      }
    } else {
      sellingPriceGroupId = 0;
    }
  }

  productList() async {
    if (isLoadingProducts) return;
    isLoadingProducts = true;
    String? lastSync = await System().getProductLastSync();
    final date2 = DateTime.now();

    // Only auto-sync if we aren't performing a search/filter to keep it fast
    bool isSearching =
        searchController.text.trim().isNotEmpty ||
        categoryId != 0 ||
        brandId != 0;

    if (!isSearching &&
        (lastSync == null ||
            (date2.difference(DateTime.parse(lastSync)).inMinutes > 10))) {
      if (await Helper().checkConnectivity()) {
        await Variations().refresh();
        await System().insertProductLastSyncDateTimeNow();
      }
    }

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
              double? price;
              if (product['selling_price_group'] != null) {
                try {
                  final groups = jsonDecode(product['selling_price_group']);
                  if (groups is List) {
                    for (var g in groups) {
                      if (g['key'] == sellingPriceGroupId) {
                        price = double.tryParse(g['value'].toString());
                      }
                    }
                  }
                } catch (_) {}
              }
              final p = ProductModel().product(product, price);
              if (p != null) {
                newProducts.add(p);
              }
            }
            setState(() {
              products.addAll(newProducts);
            });
          }
        })
        .whenComplete(() async {
          try {
            products.sort((a, b) {
              if (a == null || b == null) return 0;
              final an = (a['display_name'] ?? a['name'] ?? '')
                  .toString()
                  .toLowerCase();
              final bn = (b['display_name'] ?? b['name'] ?? '')
                  .toString()
                  .toLowerCase();
              if (byAlphabets == 1) return bn.compareTo(an);
              return an.compareTo(bn);
            });
          } catch (_) {}
          setState(() {
            isLoadingProducts = false;
          });
          try {
            cachedProducts = List.from(products);
            cachedLocationId = selectedLocationId;
            try {
              await System().delete('products_cache');
              await System().insert(
                'products_cache',
                jsonEncode(products),
                selectedLocationId,
              );
            } catch (_) {}
          } catch (_) {}
        });
  }

  categoryList() async {
    List categories = await System().getCategories();
    List<DropdownMenuItem<int>> tmp = [];
    tmp.add(
      DropdownMenuItem(
        value: 0,
        child: Text(AppLocalizations.of(context).translate('select_category')),
      ),
    );

    for (var category in categories) {
      tmp.add(
        DropdownMenuItem(value: category['id'], child: Text(category['name'])),
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
        value: 0,
        child: Text(
          AppLocalizations.of(context).translate('select_sub_category'),
        ),
      ),
    );
    for (var element in subCategories) {
      tmp.add(
        DropdownMenuItem(
          value: jsonDecode(element['value'])['id'],
          child: Text(jsonDecode(element['value'])['name']),
        ),
      );
    }
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

  priceGroupList() async {
    List<DropdownMenuItem<bool>> tmp = [];
    tmp.add(
      DropdownMenuItem<bool>(
        child: Text(
          AppLocalizations.of(context).translate('no_price_group_selected'),
        ),
        value: false,
      ),
    );

    bool addedDefault = false;
    for (var element in locationListMap) {
      if (!addedDefault &&
          element['id'] == selectedLocationId &&
          element['selling_price_group_id'] != null) {
        tmp.add(
          DropdownMenuItem<bool>(
            child: Text(
              AppLocalizations.of(context).translate('default_price_group'),
            ),
            value: true,
          ),
        );
        addedDefault = true;
      }
    }

    List<DropdownMenuItem<bool>> deduped = [];
    Set seen = <bool>{};
    for (var item in tmp) {
      if (!seen.contains(item.value)) {
        deduped.add(item);
        seen.add(item.value!);
      }
    }
    if (!mounted) return;
    setState(() {
      _priceGroupMenuItems = deduped;
      if (!seen.contains(usePriceGroup)) {
        usePriceGroup = false;
      }
    });
  }

  Future<String> getCartItemCount({isCompleted, sellId}) async {
    var counts = await Sell().cartItemCount(
      isCompleted: isCompleted,
      sellId: sellId,
    );
    setState(() {
      cartCount = int.parse(counts);
    });
    return counts;
  }

  double findAspectRatio(double width) {
    return (width / 2 - MySize.size24!) / ((width / 2 - MySize.size24!) + 60);
  }

  double getCartSubTotal() {
    double total = 0;
    for (var item in cartItems) {
      double price = (item['unit_price'] ?? 0);
      double quantity =
          double.tryParse((item['quantity'] ?? 1).toString()) ?? 1.0;
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

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: _handleShortcuts,
      child: SafeArea(
        child: Stack(
          children: [
            Scaffold(
              key: _scaffoldKey,
              resizeToAvoidBottomInset: false,
              backgroundColor: Colors.white,
              drawer: WindowsMenu(
                accessExpenses: canAddSell, // Approximation or fetch real perm
                isAdmin: true,
                userName: "",
              ),
              endDrawer: _filterDrawer(),
              appBar: AppBar(
                backgroundColor: const Color(
                  0xff732a13,
                ), // Match Home page brown
                elevation: 0,
                centerTitle: false,
                iconTheme: const IconThemeData(color: Colors.white),
                title: Text(
                  AppLocalizations.of(context).translate('products'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleLarge,
                    fontWeight: 600,
                    color: Colors.white,
                  ),
                ),
                leading: IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu, color: Colors.white),
                ),
                actions: <Widget>[
                  IconButton(
                    onPressed: () async {
                      if (await Helper().checkConnectivity()) {
                        Helper().showNotification(
                          context,
                          "Syncing products...",
                        );
                        await Variations().refresh();
                        setState(() {
                          products = [];
                          offset = 0;
                        });
                        _selectDefaultCustomerForLocation(selectedLocationId);
                        productList();
                      } else {
                        _showSafeToast(
                          AppLocalizations.of(context)
                              .translate('check_connectivity'),
                        );
                      }
                    },
                    icon: const Icon(Symbols.sync, color: Colors.white),
                  ),
                  Theme(
                    data: themeData.copyWith(
                      canvasColor: const Color(0xff732a13),
                    ),
                    child: locations(),
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
                                  child: (selectedLocationId == 0)
                                      ? _buildLocationPrompt()
                                      : _productsList(
                                          crossAxisCount:
                                              constraints.maxWidth > 500
                                              ? 3
                                              : 2,
                                        ),
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
                              width:
                                  constraints.maxWidth *
                                  (constraints.maxWidth > 1200 ? 0.3 : 0.4),
                              color: Colors.white,
                              padding: EdgeInsets.all(MySize.size16!),
                              child: _buildCartPanel(),
                            ),
                            const VerticalDivider(width: 1),
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(MySize.size8!),
                                color: const Color(0xfff5f5f5),
                                child: (selectedLocationId == 0)
                                    ? _buildLocationPrompt()
                                    : _productsList(
                                        crossAxisCount:
                                            constraints.maxWidth > 1200 ? 5 : 4,
                                      ),
                              ),
                            ),
                          ],
                        );
                      },
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
                child: Helper().loadingIndicator(
                  context,
                  subTitle: 'PROCESSING SALE...',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationPrompt() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [Icon(Icons.location_on), Text('Please set a location')],
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
          ),
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
          'contact_id': '',
        });
        for (var c in customers) {
          options.add({
            'id': c['id'],
            'name': c['name'],
            'mobile': c['mobile'] ?? '',
            'contact_id': c['contact_id'] ?? '',
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
                            opt['name'].toString().toLowerCase().contains(
                              query,
                            ) ||
                            opt['mobile'].toString().toLowerCase().contains(
                              query,
                            ) ||
                            opt['contact_id'].toString().toLowerCase().contains(
                              query,
                            ),
                      )
                      .toList();
                  setStateDialog(() {});
                }

                return AlertDialog(
                  title: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search Name/Mobile/ID",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: doFilter,
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                        .map((e) => e.isNotEmpty ? e[0] : '')
                                        .take(2)
                                        .join(),
                                  ),
                                ),
                                title: Text(opt['name'].toString()),
                                subtitle: Text(
                                  "${opt['mobile']} ${opt['contact_id'] != '' ? ' | ID: ${opt['contact_id']}' : ''}",
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
                        AppLocalizations.of(context).translate('add'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        AppLocalizations.of(context).translate('close'),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (selectedCustomerId == 0)
                        ? AppLocalizations.of(context)
                              .translate('walk_in_customer')
                        : (customers.firstWhere(
                                (c) => c['id'] == selectedCustomerId,
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
              icon: const Icon(
                Icons.person_add_alt_1,
                color: Color(0xff732a13),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // IconButton(
            //   onPressed: _showQuickSearchByMobileDialog,
            //   icon: const Icon(Symbols.contact_phone,
            //       color: Colors.blue, size: 20),
            //   padding: EdgeInsets.zero,
            //   constraints: const BoxConstraints(),
            // ),
            // const SizedBox(width: 4),
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
                      AppLocalizations.of(context)
                          .translate('no_items_added_to_cart'),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Subtotal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Icon(Icons.close, color: Colors.black, size: 20),
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
                        '$symbol${it['unit_price']}${it['discount_amount'] > 0 ? ' (-${it['discount_amount']}${it['discount_type'] == 'percentage' ? '%' : ''})' : ''}',
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
                              double price =
                                  double.tryParse(
                                    (it['unit_price'] ?? 0).toString(),
                                  ) ??
                                  0.0;
                              double quantity =
                                  double.tryParse(
                                    (it['quantity'] ?? 1).toString(),
                                  ) ??
                                  1.0;
                              double discountAmount =
                                  double.tryParse(
                                    (it['discount_amount'] ?? 0).toString(),
                                  ) ??
                                  0.0;

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
                            },
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
                        onPressed: () {
                          setState(() {
                            cartItems.removeAt(idx);
                          });
                          _updateCustomerDisplay();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      separatorBuilder: (_, _) => const Divider(height: 1),
    );
  }

  Widget _buildQtyControl(Map it, int idx) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
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
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: const Icon(
                Icons.remove,
                size: 16,
                color: Colors.redAccent,
              ),
            ),
          ),
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(minWidth: 30),
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
          Container(width: 1, height: 24, color: Colors.grey.shade300),
          InkWell(
            onTap: () {
              setState(() {
                num q = it['quantity'] ?? 1;
                it['quantity'] = q + 1;
              });
              _updateCustomerDisplay();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: const Icon(Icons.add, size: 16, color: Colors.green),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Subtotal',
                    Helper().formatCurrency(subTotal) + symbol,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: _showDiscountDialog,
                    child: _buildSummaryItem(
                      'Discount',
                      Helper().formatCurrency(discount) + symbol,
                      color: Colors.red,
                      icon: Icons.edit,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Total',
                    Helper().formatCurrency(totalPayable) + symbol,
                    color: Colors.green,
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildCartActions(),
      ],
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value, {
    Color? color,
    IconData? icon,
    bool alignEnd = false,
  }) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
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
                onPressed: _saveAsDraft,
                isLoading: isProcessingSale,
              ),
            ),
            SizedBox(width: MySize.size8!),
            Expanded(
              flex: 2,
              child: _buildActionButton(
                label: 'Pay & Checkout',
                color: const Color(0xff2196f3),
                onPressed: _goToCheckout,
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
        disabledBackgroundColor: color.withValues(alpha: 0.6),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total: ${Helper().formatCurrency(getCartTotal())} $symbol',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${cartItems.length} items',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (ctx) => SizedBox(
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
                          hintText: AppLocalizations.of(context)
                              .translate('search'),
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
                            color: themeData.colorScheme.onSurface.withAlpha(
                              150,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.only(right: 16),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        controller: searchController,
                        onChanged: (value) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(
                            const Duration(milliseconds: 300),
                            () {
                              setState(() {
                                products = [];
                                offset = 0;
                                isLoadingProducts = false; // Allow new search
                              });
                              productList();
                            },
                          );
                        },
                        onEditingComplete: () {
                          setState(() {
                            products = [];
                            offset = 0;
                            isLoadingProducts = false;
                          });
                          productList();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                    },
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
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () async {
                      var barcode = await Helper().barcodeScan();
                      await getScannedProduct(barcode);
                    },
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
                        Symbols.barcode,
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
                            const Icon(
                              Icons.hourglass_empty,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)
                                  .translate('no_products_found'),
                            ),
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
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                    childAspectRatio: 0.8,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                var product = products[index];
                                var effId =
                                    product['variation_id'] ??
                                    product['product_id'];
                                String effIdStr = effId?.toString() ?? '';
                                int cartIdx = cartItems.indexWhere(
                                  (item) =>
                                      (item['id']?.toString() ?? '') ==
                                      effIdStr,
                                );

                                return InkWell(
                                  onTap: () async => onTapProduct(index),
                                  child: Stack(
                                    children: [
                                      _ProductGridWidget(
                                        name: product['display_name'],
                                        image: product['product_image_url'],
                                        qtyAvailable:
                                            (product['enable_stock'] != 0)
                                            ? product['stock_available']
                                                  .toString()
                                            : '-',
                                        price: double.parse(
                                          product['unit_price'].toString(),
                                        ),
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
                                            onTap: () =>
                                                _showEditCartDialog(product),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.9,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Colors.black12,
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons
                                                        .shopping_cart_outlined,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '${cartItems[cartIdx]['quantity'] ?? 0}',
                                                  ),
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
                                  child: Center(
                                    child: Helper().loadingIndicator(context),
                                  ),
                                )
                              : const SizedBox(height: 100),
                        ),
                      ],
                    ),
                    if (isLoadingProducts && products.isEmpty)
                      Helper().loadingIndicator(
                        context,
                        subTitle: 'LOADING PRODUCTS...',
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _filterDrawer() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: EdgeInsets.only(bottom: MySize.size14 ?? 14.0),
      color: Colors.white,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              padding: EdgeInsets.only(
                top: MySize.size24 ?? 24.0,
                bottom: MySize.size24 ?? 24.0,
              ),
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  AppLocalizations.of(context).translate('sort'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleMedium,
                    fontWeight: 700,
                    color: themeData.colorScheme.primary,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () async {
                        setState(() {
                          if (byAlphabets == null) {
                            byAlphabets = 0;
                          } else if (byAlphabets == 0) {
                            byAlphabets = 1;
                          } else {
                            byAlphabets = null;
                          }
                        });
                        products = [];
                        offset = 0;
                        productList();
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: MySize.size16 ?? 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                            Radius.circular(MySize.size16 ?? 16.0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  themeData.cardTheme.shadowColor?.withAlpha(
                                    48,
                                  ) ??
                                  Colors.black.withAlpha(48),
                              blurRadius: (byAlphabets != null) ? 5 : 0,
                              offset: (byAlphabets != null)
                                  ? const Offset(3, 3)
                                  : const Offset(0, 0),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(MySize.size12 ?? 12.0),
                        child: Row(
                          children: [
                            Text(
                              "A",
                              style: AppTheme.getTextStyle(
                                themeData.textTheme.titleMedium,
                                fontWeight: 700,
                                color: (byAlphabets != null)
                                    ? themeData.colorScheme.primary
                                    : Colors.grey,
                              ),
                            ),
                            Icon(
                              (byAlphabets == 1)
                                  ? Symbols.arrow_left
                                  : Symbols.arrow_right,
                              color: (byAlphabets != null)
                                  ? themeData.colorScheme.primary
                                  : Colors.grey,
                              size: 22,
                            ),
                            Text(
                              "Z",
                              style: AppTheme.getTextStyle(
                                themeData.textTheme.titleMedium,
                                fontWeight: 700,
                                color: (byAlphabets != null)
                                    ? themeData.colorScheme.primary
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        setState(() {
                          if (byPrice == null) {
                            byPrice = 0;
                          } else if (byPrice == 0) {
                            byPrice = 1;
                          } else {
                            byPrice = null;
                          }
                        });
                        products = [];
                        offset = 0;
                        productList();
                      },
                      child: Container(
                        margin: EdgeInsets.only(left: MySize.size16 ?? 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                            Radius.circular(MySize.size16 ?? 16.0),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  themeData.cardTheme.shadowColor?.withAlpha(
                                    48,
                                  ) ??
                                  Colors.black.withAlpha(48),
                              blurRadius: (byPrice != null) ? 5 : 0,
                              offset: (byPrice != null)
                                  ? const Offset(3, 3)
                                  : const Offset(0, 0),
                            ),
                          ],
                        ),
                        padding: EdgeInsets.all(MySize.size12 ?? 12.0),
                        child: Row(
                          children: [
                            Text(
                              AppLocalizations.of(context).translate('price'),
                              style: AppTheme.getTextStyle(
                                themeData.textTheme.titleMedium,
                                fontWeight: 700,
                                color: (byPrice != null)
                                    ? themeData.colorScheme.primary
                                    : Colors.grey,
                              ),
                            ),
                            Icon(
                              (byPrice == 1)
                                  ? Symbols.arrow_downward
                                  : Symbols.arrow_upward,
                              color: (byPrice != null)
                                  ? themeData.colorScheme.primary
                                  : Colors.grey,
                              size: 22,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(),
              ],
            ),
            Container(
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  AppLocalizations.of(context).translate('filter'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleMedium,
                    fontWeight: 700,
                    color: themeData.colorScheme.primary,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      AppLocalizations.of(context).translate('in_stock'),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: inStock,
                    onChanged: (newValue) {
                      setState(() {
                        inStock = newValue!;
                      });
                      products = [];
                      offset = 0;
                      productList();
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                  ),
                  child: CheckboxListTile(
                    title: const Text('Allow Overselling'),
                    controlAffinity: ListTileControlAffinity.leading,
                    value: allowOverselling,
                    onChanged: (newValue) {
                      setState(() {
                        allowOverselling = newValue!;
                      });
                    },
                  ),
                ),
                const Divider(),
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                    top: MySize.size16!,
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('categories'),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyLarge,
                      fontWeight: 600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                    top: MySize.size8!,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: _categoryMenuItems.isEmpty
                        ? Container()
                        : DropdownButton<int>(
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down),
                            value:
                                _categoryMenuItems.any(
                                  (item) => item.value == categoryId,
                                )
                                ? categoryId
                                : (_categoryMenuItems.isNotEmpty
                                      ? _categoryMenuItems[0].value
                                      : 0),
                            items: _categoryMenuItems,
                            onChanged: (int? newValue) {
                              setState(() {
                                subCategoryId = 0;
                                categoryId = newValue!;
                                subCategoryList(categoryId);
                              });
                              products = [];
                              offset = 0;
                              productList();
                            },
                          ),
                  ),
                ),
                const Divider(),
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                    top: MySize.size16!,
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('sub_categories'),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyLarge,
                      fontWeight: 600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                    top: MySize.size8!,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: _subCategoryMenuItems.isEmpty
                        ? Container()
                        : DropdownButton<int>(
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down),
                            value:
                                _subCategoryMenuItems.any(
                                  (item) => item.value == subCategoryId,
                                )
                                ? subCategoryId
                                : (_subCategoryMenuItems.isNotEmpty
                                      ? _subCategoryMenuItems[0].value
                                      : 0),
                            items: _subCategoryMenuItems,
                            onChanged: (int? newValue) {
                              setState(() {
                                subCategoryId = newValue!;
                              });
                              products = [];
                              offset = 0;
                              productList();
                            },
                          ),
                  ),
                ),
                const Divider(),
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                    top: MySize.size16!,
                  ),
                  child: Text(
                    AppLocalizations.of(context).translate('brands'),
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyLarge,
                      fontWeight: 600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.only(
                    left: MySize.size16!,
                    right: MySize.size16!,
                    top: 0,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: _brandsMenuItems.isEmpty
                        ? Container()
                        : DropdownButton<int>(
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            icon: const Icon(Icons.arrow_drop_down),
                            value:
                                _brandsMenuItems.any(
                                  (item) => item.value == brandId,
                                )
                                ? brandId
                                : (_brandsMenuItems.isNotEmpty
                                      ? _brandsMenuItems[0].value
                                      : 0),
                            items: _brandsMenuItems,
                            onChanged: (int? newValue) {
                              setState(() {
                                brandId = newValue!;
                              });
                              products = [];
                              offset = 0;
                              productList();
                            },
                          ),
                  ),
                ),
                const Divider(),
              ],
            ),
            Container(
              alignment: Alignment.center,
              child: Center(
                child: Text(
                  AppLocalizations.of(context).translate('group_prices'),
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.titleMedium,
                    fontWeight: 700,
                    color: themeData.colorScheme.primary,
                  ),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: MySize.size16!,
                right: MySize.size16!,
                top: 0,
              ),
              child: DropdownButtonHideUnderline(
                child: _priceGroupMenuItems.isEmpty
                    ? Container()
                    : DropdownButton<bool>(
                        isExpanded: true,
                        dropdownColor: Colors.white,
                        icon: const Icon(Icons.arrow_drop_down),
                        value:
                            _priceGroupMenuItems.any(
                              (item) => item.value == usePriceGroup,
                            )
                            ? usePriceGroup
                            : (_priceGroupMenuItems.isNotEmpty
                                  ? _priceGroupMenuItems[0].value
                                  : false),
                        items: _priceGroupMenuItems,
                        onChanged: (bool? newValue) async {
                          await _showCartResetDialogForPriceGroup();
                          setState(() {
                            usePriceGroup = newValue!;
                            if (changePriceGroup) {
                              Sell().resetCart();
                              cartItems = [];
                              brandId = 0;
                              categoryId = 0;
                              searchController.clear();
                              inStock = false;
                              cartCount = 0;
                              products = [];
                              offset = 0;
                              productList();
                              _updateCustomerDisplay();
                            }
                          });
                        },
                      ),
              ),
            ),
            const Divider(),
            Container(
              margin: EdgeInsets.all(MySize.size16!),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff4c53a5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  AppLocalizations.of(context).translate('close'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  getScannedProduct(String barcode) async {
    if (!canMakeSell) {
      _showSafeToast(
        AppLocalizations.of(context).translate('no_subscription_found'),
      );
      return;
    }

    try {
      final value = await Variations().get(
        locationId: selectedLocationId,
        barcode: barcode,
        offset: 0,
        searchTerm: searchController.text,
      );

      if (!canAddSell) {
        if (mounted) {
          Helper().showNotification(
            context,
            AppLocalizations.of(context).translate("no_sells_permission"),
            isError: true,
          );
        }
        return;
      }

      if (value != null && value.isNotEmpty) {
        double? price;
        if (value[0]['selling_price_group'] != null) {
          try {
            jsonDecode(value[0]['selling_price_group']).forEach((element) {
              if (element['key'] == sellingPriceGroupId) {
                price = double.tryParse(element['value'].toString());
              }
            });
          } catch (_) {}
        }

        var product = ProductModel().product(value[0], price);
        if (product != null) {
          if (!allowOverselling &&
              (double.tryParse(product['stock_available']?.toString() ?? '0') ??
                      0) <=
                  0) {
            if (mounted) {
              Helper().showNotification(
                context,
                AppLocalizations.of(context).translate("out_of_stock"),
                isError: true,
              );
            }
            return;
          }

          _addToCartFromProduct(product);
          if (mounted) {
            Helper().showNotification(
              context,
              AppLocalizations.of(context).translate('added_to_cart'),
            );
          }

          int? targetSellId =
              activeSellId ?? (argument != null ? argument!['sellId'] : null);
          if (targetSellId != null) {
            await Sell().addToCart(product, targetSellId);
          }
        }
      } else {
        if (mounted) {
          Helper().showNotification(
            context,
            AppLocalizations.of(context).translate("no_product_found"),
            isError: true,
          );
        }
      }
    } catch (e) {
      debugPrint("Scanner Error: $e");
    }
  }

  onTapProduct(int index) async {
    if (!canAddSell) {
      if (mounted) {
        Helper().showNotification(
          context,
          AppLocalizations.of(context).translate("no_sells_permission"),
          isError: true,
        );
      }
      return;
    }
    if (!canMakeSell) {
      if (mounted) {
        Helper().showNotification(
          context,
          AppLocalizations.of(context).translate('no_subscription_found'),
          isError: true,
        );
      }
      return;
    }

    final product = products[index];
    if (!allowOverselling &&
        (double.tryParse(product['stock_available']?.toString() ?? '0') ?? 0) <=
            0) {
      if (mounted) {
        Helper().showNotification(
          context,
          AppLocalizations.of(context).translate("out_of_stock"),
          isError: true,
        );
      }
      return;
    }

    try {
      // 1. Update UI State
      _addToCartFromProduct(product);
      if (mounted) {
        Helper().showNotification(
          context,
          AppLocalizations.of(context).translate('added_to_cart'),
        );
      }

      // 2. Persist to Database if we are in a sale context
      int? targetSellId =
          activeSellId ?? (argument != null ? argument!['sellId'] : null);
      if (targetSellId != null) {
        await Sell().addToCart(product, targetSellId);
      }
    } catch (e) {
      debugPrint("Error adding product to cart: $e");
    }
  }

  onExpressCheckout(int index) async {
    if (!canAddSell || !canMakeSell) {
      if (mounted) {
        Helper().showNotification(
          context,
          AppLocalizations.of(context).translate('no_permission'),
          isError: true,
        );
      }
      return;
    }
    if (!allowOverselling && products[index]['stock_available'] <= 0) {
      if (mounted) {
        Helper().showNotification(
          context,
          AppLocalizations.of(context).translate('out_of_stock'),
          isError: true,
        );
      }
      return;
    }
    _addToCartFromProduct(products[index]);
    try {
      String invoiceNo = await Helper().generateRefNumber(
        'sell',
        locationId: selectedLocationId,
      );
      Map<String, dynamic> sellData = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss")
            .format(DateTime.now()),
        contactId: selectedCustomerId,
        locId: selectedLocationId,
        discountAmount: discountAmount,
        discountType: discountType,
        invoiceAmount: getCartTotal(),
        changeReturn: 0.0,
        pending: 0.0,
        saleStatus: 'draft',
      );
      var sellId = await SellDatabase().storeSell(sellData);
      for (var item in cartItems) {
        await Sell().addToCart(item, sellId);
      }
      if (!mounted) return;
      var result = await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (ctx) => CheckOut(
            initialArgument: Helper().argument(
              invoiceAmount: getCartTotal(),
              customerId: selectedCustomerId,
              locId: selectedLocationId,
              sellId: sellId,
            ),
            replaceRootOnComplete: false,
          ),
          fullscreenDialog: true,
        ),
      );
      if (result == true) {
        if (mounted) {
          setState(() {
            cartItems.clear();
          });
          _updateCustomerDisplay();
        }
      }
    } catch (e) {
      if (mounted) {
        Helper().showNotification(context, '$e', isError: true);
      }
    }
  }

  void _printSaleInBackground(int sellId) {
    final hasKitchen = PrinterService().printKitchenCopy;
    unawaited(() async {
      try {
        await Helper().printDocument(sellId, 0, context, keepAlive: hasKitchen);
        if (hasKitchen) {
          await Helper().printKitchenDocument(sellId, context);
        }
      } catch (e, stackTrace) {
        debugPrint('Background sale printing failed: $e\n$stackTrace');
      }
    }());
  }

  finalizeExpressSale({String method = 'cash'}) async {
    if (isProcessingSale) return;
    setState(() => isProcessingSale = true);
    try {
      double totalAmount = getCartTotal();
      if (totalAmount <= 0) {
        Helper().showNotification(context, "Cart is empty", isError: true);
        return;
      }
      String invoiceNo = await Helper().generateRefNumber(
        'sell',
        locationId: selectedLocationId,
      );
      Map<String, dynamic> sellData = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss")
            .format(DateTime.now()),
        contactId: selectedCustomerId,
        locId: selectedLocationId,
        discountAmount: discountAmount,
        discountType: discountType,
        invoiceAmount: totalAmount,
        changeReturn: 0.0,
        pending: 0.0,
        saleStatus: 'final',
        sellId: activeSellId,
      );

      int sellId;
      if (activeSellId != null) {
        await SellDatabase().updateSells(activeSellId, sellData);
        sellId = activeSellId!;
        await SellDatabase().deleteSellLineBySellId(sellId);
      } else {
        sellId = await SellDatabase().storeSell(sellData);
      }

      for (var item in cartItems) {
        Map<String, dynamic> sellLine = {
          'sell_id': sellId,
          'product_id': item['product_id'],
          'variation_id': item['id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'discount_amount': item['discount_amount'] ?? 0.0,
          'discount_type': item['discount_type'] ?? 'fixed',
          'is_completed': 1,
        };
        await SellDatabase().store(sellLine);
      }

      int? accountId;
      try {
        List methods = await System().get('payment_method', selectedLocationId);
        var selectedMethod = methods.firstWhere(
          (m) => m['name'].toString().toLowerCase() == method.toLowerCase(),
          orElse: () => null,
        );
        if (selectedMethod != null && selectedMethod['account_id'] != null) {
          accountId = int.tryParse(selectedMethod['account_id'].toString());
        }
      } catch (_) {}
      await Sell().makePayment([
        {
          'method': method,
          'amount': totalAmount,
          'note': '${method[0].toUpperCase()}${method.substring(1)} Checkout',
          'account_id': accountId,
        },
      ], sellId);
      _printSaleInBackground(sellId);
      if (await Helper().checkConnectivity()) {
        Sell().createApiSell(sellId: sellId, force: true);
        // Send WhatsApp notification in background
        WhatsAppService().sendSaleNotification(sellId);
      }
      Helper().showNotification(context, "Success ✅");
      _resetCartState();
    } catch (e) {
      Helper().showNotification(
        context,
        '$method checkout failed: $e',
        isError: true,
      );
    } finally {
      setState(() => isProcessingSale = false);
    }
  }

  finalizeDraftSale() async {
    if (isProcessingSale) return;

    double totalAmount = getCartTotal();
    if (totalAmount <= 0) {
      Helper().showNotification(context, "Cart is empty", isError: true);
      return;
    }

    // Guard: Prevent credit/draft sales for Walk-in or no-phone customers.
    final customer = await Contact().getCustomerDetailById(selectedCustomerId);
    final customerName = (customer?['name'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    final customerCode = (customer?['contact_id'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    if (selectedCustomerId == 0 ||
        customerName == 'walkincustomer' ||
        customerCode == 'CO0001') {
      _showErrorPopup(
        "Credit sales (Draft) not allowed for Walk-in Customer. Please select a registered customer.",
      );
      return;
    }

    if (customer == null ||
        customer['mobile'] == null ||
        customer['mobile'].toString().trim().isEmpty) {
      _showErrorPopup("Customer phone number is required for credit sales.");
      return;
    }

    // Optional Credit Limit Check
    double creditLimit =
        double.tryParse((customer['credit_limit'] ?? 0.0).toString()) ?? 0.0;
    double totalDue =
        double.tryParse((customer['total_due'] ?? 0.0).toString()) ?? 0.0;

    if (creditLimit > 0 && (totalDue + totalAmount) > creditLimit) {
      _showErrorPopup(
        "Credit limit exceeded. Available credit: $symbol${(creditLimit - totalDue).toStringAsFixed(2)}",
      );
      return;
    }

    setState(() => isProcessingSale = true);
    try {
      String invoiceNo = await Helper().generateRefNumber(
        'sell',
        locationId: selectedLocationId,
      );
      Map<String, dynamic> sellData = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss")
            .format(DateTime.now()),
        contactId: selectedCustomerId,
        locId: selectedLocationId,
        discountAmount: discountAmount,
        discountType: discountType,
        invoiceAmount: totalAmount,
        changeReturn: 0.0,
        pending: totalAmount,
        saleStatus: 'draft',
      );
      var sellId = await SellDatabase().storeSell(sellData);
      for (var item in cartItems) {
        Map<String, dynamic> sellLine = {
          'sell_id': sellId,
          'product_id': item['product_id'],
          'variation_id': item['id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'is_completed': 1,
        };
        await SellDatabase().store(sellLine);
      }
      if (await Helper().checkConnectivity()) {
        Sell().createApiSell(sellId: sellId);
      }
      Helper().showNotification(context, "Sale saved as draft!");
      _resetCartState();
    } catch (e) {
      Helper().showNotification(
        context,
        'Draft save failed: $e',
        isError: true,
      );
    } finally {
      setState(() => isProcessingSale = false);
    }
  }

  void _showErrorPopup(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Action Blocked"),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String tempType = discountType;
        TextEditingController amountController = TextEditingController(
          text: discountAmount.toString(),
        );
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.4,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Discount Reward',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(ctx2),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),
                    const Text(
                      'Edit Discount:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Discount Type:*',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: tempType,
                                          isExpanded: true,
                                          dropdownColor: Colors.white,
                                          items: const [
                                            DropdownMenuItem(
                                              child: Text('Percentage'),
                                              value: 'percentage',
                                            ),
                                            DropdownMenuItem(
                                              child: Text('Fixed'),
                                              value: 'fixed',
                                            ),
                                          ],
                                          onChanged: (val) {
                                            setStateDialog(() {
                                              tempType = val!;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Discount Amount:*',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Expanded(
                                      child: TextField(
                                        controller: amountController,
                                        onTap: () {
                                          amountController
                                              .selection = TextSelection(
                                            baseOffset: 0,
                                            extentOffset:
                                                amountController.text.length,
                                          );
                                        },
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Divider(),
                    const Text(
                      'Reward:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Redeemed:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: const Row(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Icon(
                                        Icons.card_giftcard,
                                        size: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    VerticalDivider(width: 1),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Available:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Redeemed Amount: 0.00 $symbol',
                                style: const TextStyle(
                                  color: Color(0xff2d348e),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              discountType = tempType;
                              discountAmount =
                                  double.tryParse(amountController.text) ?? 0.0;
                            });
                            Navigator.pop(ctx2);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff6200ee),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Update',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff2c3e50),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _addToCartFromProduct(Map product) {
    try {
      var effId =
          product['variation_id'] ?? product['product_id'] ?? product['id'];
      if (effId == null) {
        debugPrint("Error: Product missing ID");
        return;
      }

      String effIdStr = effId.toString();
      int existingIndex = cartItems.indexWhere(
        (item) => (item['id']?.toString() ?? '') == effIdStr,
      );

      if (existingIndex >= 0) {
        setState(() {
          double currentQty =
              double.tryParse(
                cartItems[existingIndex]['quantity'].toString(),
              ) ??
              0.0;
          cartItems[existingIndex]['quantity'] = currentQty + 1;
        });
      } else {
        setState(() {
          cartItems.add({
            'id': effId,
            'product_id': product['product_id'],
            'display_name':
                product['display_name'] ?? product['name'] ?? 'Product',
            'image': product['product_image_url'],
            'unit_price':
                double.tryParse((product['unit_price'] ?? '0').toString()) ??
                0.0,
            'quantity': 1,
            'discount_amount': 0.0,
            'discount_type': 'fixed',
          });
        });
      }

      try {
        _updateCustomerDisplay();
      } catch (e) {
        print("Customer Display Update Error: $e");
      }
    } catch (e) {
      print("CRITICAL ERROR in _addToCartFromProduct: $e");
    }
  }

  void _handleShortcuts(KeyEvent event) async {
    if (event is! KeyDownEvent) return;
    bool isControlPressed = HardwareKeyboard.instance.isControlPressed;
    if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyC) {
      _quickCheckout('cash');
    } else if (isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyB) {
      _quickCheckout('card');
    } else if (isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyM) {
      _goToCheckout();
    } else if (isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyD) {
      _saveAsDraft();
    } else if (isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyN) {
      Navigator.pushNamed(context, '/customer', arguments: _getCheckoutArgs());
    } else if (isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyS) {
      productSearchFocusNode.requestFocus();
    } else if (isControlPressed &&
        event.logicalKey == LogicalKeyboardKey.keyL) {
      _printLastInvoice();
    }
  }

  void _printLastInvoice() async {
    List sells = await SellDatabase().getSells();
    if (sells.isNotEmpty) {
      Helper().printDocument(
        sells[0]['id'],
        sells[0]['tax_rate_id'],
        context,
        isManual: true,
      );
    } else {
      Helper().showNotification(context, "No invoice found", isError: true);
    }
  }

  Map _getCheckoutArgs() {
    return Helper().argument(
      locId: selectedLocationId,
      taxId: argument != null ? argument!['taxId'] : null,
      discountType: discountType,
      discountAmount: discountAmount,
      invoiceAmount: getCartTotal(),
      sellId: argument != null ? argument!['sellId'] : null,
      isQuotation: argument != null ? argument!['is_quotation'] : 0,
      customerId: selectedCustomerId,
    );
  }

  void _resetCartState() {
    try {
      Sell().resetCart();
      SellDatabase().deleteInComplete();
    } catch (_) {}
    setState(() {
      cartItems = [];
      cartCount = 0;
      activeSellId = null;
      selectedCustomerId = 0;
      selectedCustomerDue = 0.0;
      discountAmount = 0.0;
      discountType = 'percentage';

      // Force Refresh Product List to show new stock levels
      products = [];
      offset = 0;
      cachedLocationId = -1; // Invalidate cache
    });
    productList();
    _updateCustomerDisplay();
  }

  Future<void> _saveAsDraft() async {
    if (cartItems.isEmpty) return;
    if (isProcessingSale) return;
    setState(() => isProcessingSale = true);
    try {
      String invoiceNo = await Helper().generateRefNumber(
        'sell',
        locationId: selectedLocationId,
      );
      Map<String, dynamic> sellData = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss")
            .format(DateTime.now()),
        contactId: selectedCustomerId,
        locId: selectedLocationId,
        discountAmount: discountAmount,
        discountType: discountType,
        invoiceAmount: getCartTotal(),
        changeReturn: 0.0,
        pending: getCartTotal(),
        saleStatus: 'draft',
        isQuotation: 1,
        sellId: activeSellId,
      );

      int sellId;
      if (activeSellId != null) {
        await SellDatabase().updateSells(activeSellId, sellData);
        sellId = activeSellId!;
        await SellDatabase().deleteSellLineBySellId(sellId);
      } else {
        sellId = await SellDatabase().storeSell(sellData);
        activeSellId = sellId;
      }

      for (var item in cartItems) {
        Map<String, dynamic> sellLine = {
          'sell_id': sellId,
          'product_id': item['product_id'],
          'variation_id': item['id'],
          'quantity': item['quantity'],
          'unit_price': item['unit_price'],
          'discount_amount': item['discount_amount'] ?? 0.0,
          'discount_type': item['discount_type'] ?? 'fixed',
          'is_completed': 1,
        };
        await SellDatabase().store(sellLine);
      }

      if (await Helper().checkConnectivity()) {
        Sell().createApiSell(sellId: sellId, force: true);
      }
      Helper().showNotification(context, "Draft saved successfully");
      _resetCartState();
    } catch (e) {
      Helper().showNotification(context, '$e', isError: true);
    } finally {
      setState(() => isProcessingSale = false);
    }
  }

  Future<void> _quickCheckout(String method) async {
    if (cartItems.isEmpty) return;
    if (isProcessingSale) return;
    setState(() => isProcessingSale = true);
    try {
      double total = getCartTotal();
      String invoiceNo = await Helper().generateRefNumber(
        'sell',
        locationId: selectedLocationId,
      );
      Map<String, dynamic> sellData = await Sell().createSell(
        invoiceNo: invoiceNo,
        transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss")
            .format(DateTime.now()),
        contactId: selectedCustomerId,
        locId: selectedLocationId,
        discountAmount: discountAmount,
        discountType: discountType,
        invoiceAmount: total,
        changeReturn: 0.0,
        pending: 0.0,
        saleStatus: 'final',
      );
      int sellId = await SellDatabase().storeSell(sellData);
      for (var item in cartItems) {
        await Sell().addToCart(item, sellId);
      }
      await SellDatabase().updateSellLine({
        'sell_id': sellId,
        'is_completed': 1,
      });
      int? accountId;
      try {
        List methods = await System().get('payment_method', selectedLocationId);
        var selectedMethod = methods.firstWhere(
          (m) => m['name'].toString().toLowerCase() == method.toLowerCase(),
          orElse: () => null,
        );
        if (selectedMethod != null && selectedMethod['account_id'] != null) {
          accountId = int.tryParse(selectedMethod['account_id'].toString());
        }
      } catch (_) {}
      await Sell().makePayment([
        {
          'method': method,
          'amount': total,
          'note':
              '${method[0].toUpperCase()}${method.substring(1)} Quick Checkout',
          'account_id': accountId,
        },
      ], sellId);
      _printSaleInBackground(sellId);
      if (await Helper().checkConnectivity()) {
        Sell().createApiSell(sellId: sellId);
        // Send WhatsApp notification in background
        WhatsAppService().sendSaleNotification(sellId);
      }
      Helper().showNotification(context, "Sale completed: $invoiceNo");
      _resetCartState();
    } catch (e) {
      Helper().showNotification(context, 'Error: $e', isError: true);
    } finally {
      setState(() => isProcessingSale = false);
    }
  }

  Future<void> _goToCheckout() async {
    if (cartItems.isEmpty) {
      Helper().showNotification(context, "Cart is empty", isError: true);
      return;
    }
    if (isProcessingSale) return;
    setState(() => isProcessingSale = true);
    try {
      // Use activeSellId if we've already created a draft in this session
      int? sellId =
          activeSellId ?? (argument != null ? argument!['sellId'] : null);

      if (sellId == null) {
        String invoiceNo = await Helper().generateRefNumber(
          'sell',
          locationId: selectedLocationId,
        );
        Map<String, dynamic> sellData = await Sell().createSell(
          invoiceNo: invoiceNo,
          transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss")
              .format(DateTime.now()),
          contactId: selectedCustomerId,
          locId: selectedLocationId,
          discountAmount: discountAmount,
          discountType: discountType,
          invoiceAmount: getCartTotal(),
          changeReturn: 0.0,
          pending: 0.0,
          saleStatus: 'draft',
        );
        sellId = await SellDatabase().storeSell(sellData);
        activeSellId = sellId; // REMEMBER THIS ID

        for (var item in cartItems) {
          await Sell().addToCart(item, sellId);
        }
      } else {
        // If we already have a sellId, just update the main sell record's total
        // The items are already being synced to this sellId via onTapProduct/onTapCart
        // But we should ensure the final amount and customer match current state
        Map<String, dynamic> sellData = await Sell().createSell(
          transactionDate: DateFormat("yyyy-MM-dd HH:mm:ss")
              .format(DateTime.now()),
          contactId: selectedCustomerId,
          locId: selectedLocationId,
          discountAmount: discountAmount,
          discountType: discountType,
          invoiceAmount: getCartTotal(),
          changeReturn: 0.0,
          pending: 0.0,
          saleStatus: 'draft',
          sellId: sellId,
        );
        await SellDatabase().updateSells(sellId, sellData);
      }

      var result = await Navigator.of(context).push(
        MaterialPageRoute<bool>(
          builder: (ctx) => CheckOut(
            initialArgument: Helper().argument(
              invoiceAmount: getCartTotal(),
              customerId: selectedCustomerId,
              locId: selectedLocationId,
              sellId: sellId,
            ),
            replaceRootOnComplete: false,
          ),
          fullscreenDialog: true,
        ),
      );
      if (result == true) {
        _resetCartState();
      }
    } catch (e) {
      Helper().showNotification(context, '$e', isError: true);
    } finally {
      setState(() => isProcessingSale = false);
    }
  }

  void _showEditCartItemDialog(int index) {
    var item = cartItems[index];
    TextEditingController priceController = TextEditingController(
      text: item['unit_price'].toString(),
    );
    TextEditingController discountController = TextEditingController(
      text: item['discount_amount'].toString(),
    );
    String currentDiscountType = item['discount_type'] ?? 'fixed';
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(item['display_name']),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: priceController,
                    decoration: const InputDecoration(labelText: 'Unit Price'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: discountController,
                          decoration: const InputDecoration(
                            labelText: 'Discount',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: currentDiscountType,
                        items: const [
                          DropdownMenuItem(
                            value: 'fixed',
                            child: Text('Fixed'),
                          ),
                          DropdownMenuItem(
                            value: 'percentage',
                            child: Text('Percentage'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              currentDiscountType = val;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      cartItems[index]['unit_price'] =
                          double.tryParse(priceController.text) ??
                          item['unit_price'];
                      cartItems[index]['discount_amount'] =
                          double.tryParse(discountController.text) ?? 0.0;
                      cartItems[index]['discount_type'] = currentDiscountType;
                    });
                    _updateCustomerDisplay();
                    Navigator.pop(context);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _updateCustomerDisplay() {
    final displayService = Provider.of<CustomerDisplayService>(
      context,
      listen: false,
    );
    displayService.updateDisplay(
      items: cartItems
          .map(
            (item) => {
              'name': item['display_name'],
              'quantity': item['quantity'],
              'price': item['unit_price'].toStringAsFixed(2),
            },
          )
          .toList(),
      total: getCartTotal().toStringAsFixed(2),
      symbol: symbol,
    );
  }

  int _getCartIndexForProduct(Map product) {
    var effId = product['variation_id'] ?? product['product_id'];
    String effIdStr = effId?.toString() ?? '';
    return cartItems.indexWhere(
      (item) => (item['id']?.toString() ?? '') == effIdStr,
    );
  }

  void _showEditCartDialog(Map product) async {
    int idx = _getCartIndexForProduct(product);
    if (idx < 0) return;
    TextEditingController qtyController = TextEditingController(
      text: (cartItems[idx]['quantity'] ?? 1).toString(),
    );
    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('edit_item')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(product['display_name'] ?? ''),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                onTap: () {
                  qtyController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: qtyController.text.length,
                  );
                },
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText:
                      AppLocalizations.of(context).translate('quantity') ??
                      'Quantity',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() {
                  cartItems.removeAt(idx);
                });
                _updateCustomerDisplay();
                try {
                  var effId = product['variation_id'] ?? product['product_id'];
                  if (argument != null && argument!['sellId'] != null) {
                    await SellDatabase().delete(
                      effId,
                      product['product_id'],
                      sellId: argument!['sellId'],
                    );
                  } else {
                    await SellDatabase().delete(effId, product['product_id']);
                  }
                } catch (_) {}
              },
              child: Text(
                AppLocalizations.of(context).translate('delete') ?? 'Delete',
                style: const TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
              },
              child: Text(
                AppLocalizations.of(context).translate('cancel') ?? 'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                double q = Helper().validateInput(qtyController.text);
                if (q <= 0) {
                  Helper().showNotification(
                    context,
                    AppLocalizations.of(context)
                            .translate('enter_valid_quantity') ??
                        'Enter valid quantity',
                    isError: true,
                  );
                  return;
                }
                setState(() {
                  cartItems[idx]['quantity'] = (q % 1 == 0) ? q.toInt() : q;
                });
                _updateCustomerDisplay();
                try {
                  var effId = product['variation_id'] ?? product['product_id'];
                  List rows = await SellDatabase().checkSellLine(
                    effId,
                    sellId: argument != null ? argument!['sellId'] : null,
                  );
                  if (rows.isNotEmpty) {
                    var dbId = rows[0]['id'];
                    await SellDatabase().update(dbId, {'quantity': q});
                  }
                } catch (_) {}
                Navigator.pop(ctx);
              },
              child: Text(
                AppLocalizations.of(context).translate('update') ?? 'Update',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> setLocationMap() async {
    var value = await System().get('location');
    List<Map<dynamic, dynamic>> tmp = [
      {'id': 0, 'name': 'All'},
    ];
    for (var element in value) {
      if (element['is_active'].toString() == '1') {
        tmp.add(Map<dynamic, dynamic>.from(element));
      }
    }
    if (!mounted) return;
    setState(() {
      locationListMap = tmp;
      if (selectedLocationId == 0 && tmp.length == 2) {
        selectedLocationId = int.tryParse(tmp[1]['id'].toString()) ?? 0;
      }
    });
    await priceGroupList();
    if (activeSellId == null) {
      await _selectDefaultCustomerForLocation(selectedLocationId);
    }
  }

  void setDefaultLocation(int defaultLocation) {
    final availableLocations = locationListMap.where((location) {
      final id = int.tryParse(location['id'].toString());
      return id != null && id > 0;
    });
    final selectedLocationIsAvailable = availableLocations.any(
      (location) => int.tryParse(location['id'].toString()) == defaultLocation,
    );
    final firstLocationId = availableLocations.isEmpty
        ? 0
        : int.tryParse(availableLocations.first['id'].toString()) ?? 0;
    final locationToSelect = selectedLocationIsAvailable
        ? defaultLocation
        : firstLocationId;

    if (selectedLocationId != locationToSelect && mounted) {
      setState(() {
        selectedLocationId = locationToSelect;
      });
    } else {
      selectedLocationId = locationToSelect;
    }
  }

  Widget locations() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        dropdownColor: const Color(0xff732a13),
        icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        value: locationListMap.any((item) => item['id'] == selectedLocationId)
            ? selectedLocationId
            : (locationListMap.isNotEmpty
                  ? (int.tryParse(locationListMap[0]['id'].toString()) ?? 0)
                  : 0),
        items: locationListMap.map<DropdownMenuItem<int>>((Map value) {
          return DropdownMenuItem<int>(
            value: value['id'],
            child: SizedBox(
              width: MySize.screenWidth! * 0.4,
              child: Text(
                '${value['name']}',
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
            ),
          );
        }).toList(),
        onTap: () {
          if (locationListMap.length <= 2) {
            canChangeLocation = false;
          }
        },
        onChanged: (int? newValue) async {
          if (canChangeLocation) {
            if (selectedLocationId == newValue) {
              changeLocation = false;
            } else if (selectedLocationId != 0) {
              await _showCartResetDialogForLocation();
              await priceGroupList();
            } else {
              changeLocation = true;
              await priceGroupList();
            }
            setState(() {
              if (changeLocation) {
                Sell().resetCart();
                cartItems = [];
                selectedLocationId = newValue!;
                selectedCustomerId = 0;
                brandId = 0;
                categoryId = 0;
                searchController.clear();
                inStock = false;
                cartCount = 0;
                products = [];
                offset = 0;
                productList();
                _updateCustomerDisplay();
              }
            });
            if (changeLocation) {
              await _selectDefaultCustomerForLocation(selectedLocationId);
            }
          } else {
            _showSafeToast(
              AppLocalizations.of(context).translate('cannot_change_location'),
            );
          }
        },
      ),
    );
  }

  Future<void> _showCartResetDialogForLocation() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context).translate('change_location'),
          ),
          content: Text(
            AppLocalizations.of(context)
                .translate('all_items_in_cart_will_be_remove'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                changeLocation = false;
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context).translate('no')),
            ),
            TextButton(
              onPressed: () {
                changeLocation = true;
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context).translate('yes')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCartResetDialogForPriceGroup() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)
                .translate('change_selling_price_group'),
          ),
          content: Text(
            AppLocalizations.of(context)
                .translate('all_items_in_cart_will_be_remove'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                changePriceGroup = false;
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context).translate('no')),
            ),
            TextButton(
              onPressed: () {
                changePriceGroup = true;
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context).translate('yes')),
            ),
          ],
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0xff732a13).withValues(alpha: 0.1),
                  blurRadius: 1,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xff732a13).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: Color(0xff732a13),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)
                                .translate('add_customer') ??
                            "Add New Customer",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff732a13),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _build3DTextField(
                        controller: nameController,
                        label:
                            AppLocalizations.of(context).translate('name') ??
                            "Name",
                        icon: Icons.person_outline_rounded,
                        autofocus: true,
                      ),
                      const SizedBox(height: 20),
                      _build3DTextField(
                        controller: mobileController,
                        label:
                            AppLocalizations.of(context).translate('mobile') ??
                            "Mobile Number",
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Icons.search_rounded,
                            color: Colors.blueAccent,
                          ),
                          onPressed: () async {
                            if (mobileController.text.length < 5) {
                              _showSafeToast("Enter at least 5 digits");
                              return;
                            }
                            // 1. Check locally first
                            dynamic existing;
                            try {
                              existing = customers.firstWhere(
                                (c) =>
                                    c['mobile']?.toString().contains(
                                      mobileController.text,
                                    ) ??
                                    false,
                              );
                            } catch (_) {
                              existing = null;
                            }

                            if (existing != null) {
                              if (mounted) {
                                setState(() {
                                  selectedCustomerId =
                                      int.tryParse(existing['id'].toString()) ??
                                      0;
                                });
                                await _updateCustomerDue();
                                Navigator.pop(ctx);
                                _showSafeToast(
                                  "Customer already exists locally: ${existing['name']}",
                                );
                              }
                              return;
                            }

                            // 2. Check on server
                            _showSafeToast("Checking on server...");
                            var serverSearch = await CustomerApi().search(
                              mobileController.text,
                            );
                            if (serverSearch != null &&
                                serverSearch['data'] != null &&
                                serverSearch['data'].isNotEmpty) {
                              var serverData = serverSearch['data'][0];

                              // Sync to local DB
                              await Contact().insertContact(
                                Contact().contactModel(serverData),
                              );
                              await _loadCustomers();

                              if (mounted) {
                                setState(() {
                                  selectedCustomerId =
                                      int.tryParse(
                                        serverData['id'].toString(),
                                      ) ??
                                      0;
                                });
                                await _updateCustomerDue();
                                Navigator.pop(ctx);
                                _showSafeToast(
                                  "Customer already exists on server: ${serverData['name']}",
                                );
                              }
                              return;
                            }

                            // 3. If not found locally or on server, search on WhatsApp
                            _showSafeToast("Searching on WhatsApp...");
                            try {
                              var waContact = await WhatsAppService()
                                  .getContactDetails(mobileController.text);

                              if (waContact != null &&
                                  waContact['name'] != null &&
                                  waContact['name'].toString().isNotEmpty) {
                                setDialogState(() {
                                  nameController.text = waContact['name'];
                                  if (waContact['number'] != null) {
                                    mobileController.text = waContact['number']
                                        .toString();
                                  }
                                });
                                _showSafeToast(
                                  "Found on WhatsApp! Name: ${waContact['name']}",
                                );
                              } else {
                                _showSafeToast(
                                  "Contact not found on WhatsApp server.",
                                );
                              }
                            } catch (e) {
                              debugPrint("WhatsApp Search Error in UI: $e");
                              _showSafeToast(
                                "WhatsApp server error or timeout.",
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: _build3DButton(
                              text:
                                  AppLocalizations.of(context)
                                      .translate('cancel') ??
                                  "Cancel",
                              color: Colors.grey.shade200,
                              textColor: Colors.grey.shade700,
                              onPressed: isSaving
                                  ? null
                                  : () => Navigator.pop(ctx),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _build3DButton(
                              text:
                                  AppLocalizations.of(context)
                                      .translate('save') ??
                                  "Save",
                              color: const Color(0xff732a13),
                              textColor: Colors.white,
                              isLoading: isSaving,
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (formKey.currentState!.validate()) {
                                        String finalName = nameController.text
                                            .trim();
                                        String mobileNum = mobileController.text
                                            .trim();

                                        if (finalName.isEmpty &&
                                            mobileNum.isEmpty) {
                                          _showSafeToast(
                                            "Name or Mobile is required",
                                          );
                                          return;
                                        }

                                        if (finalName.isEmpty) {
                                          finalName = mobileNum;
                                        }

                                        setDialogState(() => isSaving = true);
                                        try {
                                          // 1. If name is blank, try to fetch from WhatsApp automatically
                                          if (finalName.isEmpty &&
                                              mobileNum.isNotEmpty) {
                                            _showSafeToast(
                                              "Fetching name from WhatsApp...",
                                            );
                                            var waContact =
                                                await WhatsAppService()
                                                    .getContactDetails(
                                                      mobileNum,
                                                    );
                                            if (waContact != null &&
                                                waContact['name'] != null &&
                                                waContact['name']
                                                    .toString()
                                                    .isNotEmpty) {
                                              finalName = waContact['name'];
                                              _showSafeToast(
                                                "Found: $finalName",
                                              );
                                            }
                                          }

                                          // 2. If still blank, use phone number as name
                                          if (finalName.isEmpty) {
                                            finalName = mobileNum;
                                          }

                                          Map newCustomer = {
                                            'type': 'customer',
                                            'first_name': finalName,
                                            'mobile': mobileNum,
                                          };

                                          final response = await CustomerApi()
                                              .add(newCustomer);
                                          if (response != null &&
                                              (response['success'] == true ||
                                                  response['data'] != null)) {
                                            var responseData =
                                                response['data'] ?? response;

                                            // Sync to local DB
                                            await Contact().insertContact(
                                              Contact().contactModel(
                                                responseData,
                                              ),
                                            );

                                            // Refresh list and select the new customer
                                            await _loadCustomers();
                                            if (mounted) {
                                              setState(() {
                                                selectedCustomerId =
                                                    int.tryParse(
                                                      responseData['id']
                                                          .toString(),
                                                    ) ??
                                                    0;
                                              });
                                              await _updateCustomerDue();
                                              Navigator.pop(ctx);
                                              _showSafeToast(
                                                "Customer Added Successfully",
                                              );
                                            }
                                          } else {
                                            String msg =
                                                response?['message'] ??
                                                "Server failed to save contact";

                                            // Check if it's a duplicate entry error
                                            if (msg.toLowerCase().contains(
                                                  "already",
                                                ) ||
                                                msg.toLowerCase().contains(
                                                  "duplicate",
                                                ) ||
                                                msg.toLowerCase().contains(
                                                  "taken",
                                                )) {
                                              _showSafeToast(
                                                "Number already exists. Fetching details...",
                                              );

                                              // Try to find the existing customer on server
                                              var searchRes =
                                                  await CustomerApi().search(
                                                    mobileNum,
                                                  );
                                              if (searchRes != null &&
                                                  searchRes['data'] != null &&
                                                  searchRes['data']
                                                      .isNotEmpty) {
                                                var existingData =
                                                    searchRes['data'][0];
                                                await Contact().insertContact(
                                                  Contact().contactModel(
                                                    existingData,
                                                  ),
                                                );
                                                await _loadCustomers();
                                                if (mounted) {
                                                  setState(() {
                                                    selectedCustomerId =
                                                        int.tryParse(
                                                          existingData['id']
                                                              .toString(),
                                                        ) ??
                                                        0;
                                                  });
                                                  await _updateCustomerDue();
                                                  Navigator.pop(ctx);
                                                }
                                                return;
                                              }
                                            }

                                            _showSafeToast("Error: $msg");
                                          }
                                        } catch (e) {
                                          _showSafeToast("Error: $e");
                                        } finally {
                                          setDialogState(
                                            () => isSaving = false,
                                          );
                                        }
                                      }
                                    },
                            ),
                          ),
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

  Widget _build3DTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool autofocus = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          prefixIcon: Icon(icon, color: const Color(0xff732a13)),
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _build3DButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if (onPressed != null)
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}

class _ProductGridWidget extends StatefulWidget {
  final String? name, image, symbol;
  final String? qtyAvailable;
  final double? price;
  final Color? cardColor;
  const _ProductGridWidget({
    super.key,
    required this.name,
    required this.image,
    required this.qtyAvailable,
    required this.price,
    required this.symbol,
    this.cardColor,
  });
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
      elevation: 4,
      shadowColor: Colors.black26,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: widget.cardColor ?? Colors.white,
      child: Stack(
        children: [
          Positioned.fill(
            child: Hero(
              tag: key,
              child: CachedNetworkImage(
                fit: BoxFit.cover,
                errorWidget: (context, url, error) =>
                    Image.asset('assets/images/default_product.png'),
                placeholder: (context, url) =>
                    Image.asset('assets/images/default_product.png'),
                imageUrl: widget.image ?? '',
              ),
            ),
          ),
          if (widget.qtyAvailable != '-')
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: themeData.colorScheme.primary.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Qty: ${widget.qtyAvailable}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                "${widget.symbol}${Helper().formatCurrency(widget.price)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Text(
                widget.name!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductListWidget extends StatefulWidget {
  final String? name, image, symbol;
  final String? qtyAvailable;
  final double? price;
  final Color? cardColor;
  const _ProductListWidget({
    super.key,
    required this.name,
    required this.image,
    required this.qtyAvailable,
    required this.price,
    required this.symbol,
    this.cardColor,
  });
  @override
  _ProductListWidgetState createState() => _ProductListWidgetState();
}

class _ProductListWidgetState extends State<_ProductListWidget> {
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  @override
  Widget build(BuildContext context) {
    MySize().init(context);
    themeData = Theme.of(context);
    return Material(
      color: widget.cardColor ?? Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(MySize.size8!),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(MySize.size30!),
            child: CachedNetworkImage(
              errorWidget: (context, url, error) =>
                  Image.asset('assets/images/default_product.png'),
              placeholder: (context, url) =>
                  Image.asset('assets/images/default_product.png'),
              imageUrl: widget.image ?? '',
            ),
          ),
          title: Text(
            widget.name!,
            style: AppTheme.getTextStyle(
              themeData.textTheme.titleSmall,
              fontWeight: 500,
              letterSpacing: 0,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  Text(
                    Helper().formatCurrency(widget.price) + widget.symbol!,
                    style: AppTheme.getTextStyle(
                      themeData.textTheme.bodyMedium,
                      fontWeight: 700,
                      letterSpacing: 0,
                    ),
                  ),
                  Container(
                    width: MySize.size80,
                    decoration: BoxDecoration(
                      color: themeData.colorScheme.primary,
                      borderRadius: BorderRadius.all(
                        Radius.circular(MySize.size4!),
                      ),
                    ),
                    padding: EdgeInsets.only(
                      left: MySize.size6!,
                      right: MySize.size8!,
                      top: MySize.size2!,
                      bottom: MySize.getScaledSizeHeight(3.5),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Symbols.inventory,
                          color: themeData.colorScheme.onPrimary,
                          size: MySize.size12,
                        ),
                        Container(
                          margin: EdgeInsets.only(left: MySize.size4!),
                          child: (widget.qtyAvailable != '-')
                              ? Text(
                                  Helper().formatQuantity(widget.qtyAvailable),
                                  style: AppTheme.getTextStyle(
                                    themeData.textTheme.bodySmall,
                                    fontSize: 11,
                                    color: themeData.colorScheme.onPrimary,
                                    fontWeight: 600,
                                  ),
                                )
                              : const Text('-'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
