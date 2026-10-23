import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:krpos/helpers/AppTheme.dart';
import 'package:krpos/helpers/otherHelpers.dart';
import 'package:krpos/locale/MyLocalizations.dart';
import 'package:krpos/config.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:krpos/models/database.dart';
import 'package:krpos/models/sellDatabase.dart';
import 'package:krpos/pages/admin_settings_page.dart';

class WindowsMenu extends StatefulWidget {
  final bool accessExpenses;
  final bool isAdmin;
  final String userName;

  const WindowsMenu({
    Key? key,
    required this.accessExpenses,
    required this.isAdmin,
    required this.userName,
  }) : super(key: key);

  @override
  State<WindowsMenu> createState() => _WindowsMenuState();
}

class _WindowsMenuState extends State<WindowsMenu> {
  late List<Map<String, dynamic>> tiles;
  List<Map<String, dynamic>> recentlyAdded = [];

  // Define full pool of potential tiles with their properties
  final Map<String, Map<String, dynamic>> tilePool = {
    'New Sale': {'id': 'new_sale', 'title': 'New Sale', 'icon': Icons.shopping_bag, 'color': Colors.blue, 'width': 204.0, 'onTap': (context) => _navToLayoutStatic(context, 1)},
    'Reports': {'id': 'reports', 'title': 'Reports', 'icon': Icons.insert_chart, 'color': Colors.deepPurple, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/ReportScreen')},
    'Home': {'id': 'home', 'title': 'Home', 'icon': Icons.home, 'color': Colors.teal, 'width': 100.0, 'onTap': (context) => _navToLayoutStatic(context, 0)},
    'Customers': {'id': 'customers', 'title': 'Customers', 'icon': Icons.group, 'color': Colors.orange, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/leads')},
    'Sync': {'id': 'sync', 'title': 'Sync', 'icon': Icons.sync, 'color': Colors.indigo, 'width': 100.0, 'onTap': (context) => _handleSyncStatic(context)},
    'Expenses': {'id': 'expenses', 'title': 'Expenses', 'icon': Icons.money_off, 'color': Colors.pink.shade700, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/expense')},
    'Sales History': {'id': 'sales', 'title': 'Sales History', 'icon': Icons.history, 'color': Colors.green.shade700, 'width': 100.0, 'onTap': (context) => _navToLayoutStatic(context, 2)},
    'All Sales': {'id': 'sales', 'title': 'All Sales', 'icon': Icons.history, 'color': Colors.green.shade700, 'width': 100.0, 'onTap': (context) => _navToLayoutStatic(context, 2)},
    'Inventory': {'id': 'new_sale', 'title': 'Inventory', 'icon': Icons.inventory_2_outlined, 'color': Colors.blue, 'width': 204.0, 'onTap': (context) => _navToLayoutStatic(context, 1)},
    'Accounts': {'id': 'accounts', 'title': 'Accounts', 'icon': Icons.account_balance_wallet_outlined, 'color': Colors.amber.shade800, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/contactPayment')},
    'Contacts': {'id': 'customers', 'title': 'Contacts', 'icon': Icons.people_outline, 'color': Colors.orange, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/leads')},
    'Follow Ups': {'id': 'followup', 'title': 'Follow Ups', 'icon': Icons.notifications_active_outlined, 'color': Colors.redAccent, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/followUp')},
    'Shipments': {'id': 'shipment', 'title': 'Shipments', 'icon': Icons.local_shipping_outlined, 'color': Colors.cyan.shade700, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/shipment')},
    'Profile': {'id': 'profile', 'title': 'Profile', 'icon': Icons.person_pin_outlined, 'color': Colors.blueGrey, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/profile')},
    'Printer Settings': {'id': 'printer', 'title': 'Printer Settings', 'icon': Icons.print_outlined, 'color': Colors.grey.shade700, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/printerConfig')},
    'System Settings': {'id': 'admin_settings', 'title': 'System Settings', 'icon': Icons.settings_suggest_rounded, 'color': Colors.blueAccent, 'width': 204.0, 'onTap': (context) => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsPage()))},
    'Language': {'id': 'language', 'title': 'Language', 'icon': Icons.language, 'color': Colors.deepOrange, 'width': 100.0, 'onTap': (context) => _showLanguageDialogStatic(context)},
    'Field Visits': {'id': 'fieldForce', 'title': 'Field Visits', 'icon': Icons.location_on_outlined, 'color': Colors.greenAccent.shade700, 'width': 100.0, 'onTap': (context) => Navigator.pushNamed(context, '/fieldForce')},
  };

  static void _showLanguageDialogStatic(BuildContext context) {
    // This is a bit tricky since _showLanguageDialog is instance method.
    // I'll make it static or handle it in _tile onTap.
  }

  static void _navToLayoutStatic(BuildContext context, int index) {
    Navigator.of(context).pushNamedAndRemoveUntil('/layout', (route) => false, arguments: {'initialIndex': index});
  }

  static void _handleSyncStatic(BuildContext context) {
    Navigator.pop(context);
    Helper().showNotification(context, "Initiating system synchronization...");
  }

  @override
  void initState() {
    super.initState();
    _initializeMenu();
  }

  Future<void> _initializeMenu() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Default tiles (pool keys)
    List<String> defaultKeys = ['New Sale', 'Reports', 'Home', 'Customers', 'Sync', 'Expenses', 'Sales History'];
    
    List<String>? savedOrder = prefs.getStringList('windows_tiles_order_keys');
    List<String> keysToLoad = savedOrder ?? defaultKeys;

    tiles = [];
    for (String key in keysToLoad) {
      var entry = tilePool[key];
      if (entry != null) {
        var data = Map<String, dynamic>.from(entry);
        data['poolKey'] = key;
        tiles.add(data);
      }
    }
    
    await _loadRecentlyAdded();
    if (mounted) setState(() {});
  }

  void _togglePin(String poolKey) {
    setState(() {
      int index = tiles.indexWhere((t) => t['poolKey'] == poolKey);
      if (index != -1) {
        tiles.removeAt(index);
      } else {
        var entry = tilePool[poolKey];
        if (entry != null) {
          var data = Map<String, dynamic>.from(entry);
          data['poolKey'] = poolKey;
          tiles.add(data);
        }
      }
    });
    _saveTileOrder();
  }

  Future<void> _loadRecentlyAdded() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentJson = prefs.getStringList('recently_clicked_apps') ?? [];
    recentlyAdded = recentJson.map((item) {
      Map<String, dynamic> data = jsonDecode(item);
      return {
        'title': data['title'],
        'route': data['route'],
        'layoutIndex': data['layoutIndex'],
      };
    }).toList();
  }

  Future<void> _trackClick(String title, String route, {int? layoutIndex}) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> recentJson = prefs.getStringList('recently_clicked_apps') ?? [];
    
    // Remove if already exists to move to top
    recentJson.removeWhere((item) => jsonDecode(item)['title'] == title);
    
    // Add new click
    recentJson.insert(0, jsonEncode({
      'title': title,
      'route': route,
      'layoutIndex': layoutIndex,
    }));

    // Keep only last 3
    if (recentJson.length > 3) recentJson = recentJson.sublist(0, 3);
    
    await prefs.setStringList('recently_clicked_apps', recentJson);
  }

  Future<void> _saveTileOrder() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> order = tiles.map((t) => t['poolKey'] as String).toList();
    await prefs.setStringList('windows_tiles_order_keys', order);
  }

  void _navToLayout(BuildContext context, int index) {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/layout',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }

  void _handleSync(BuildContext context) {
    Navigator.pop(context);
    Helper().showNotification(context, "Initiating system synchronization...");
  }

  void _handleLogout(BuildContext context) async {
    List unsyncedSells = await SellDatabase().getNotSyncedSells();
    if (unsyncedSells.isNotEmpty) {
      Helper().showNotification(
        context,
        AppLocalizations.of(context).translate('sync_all_sales_before_logout'),
        isError: true,
      );
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt('prevUserId', Config.userId!);
    prefs.remove('userId');
    Config.userId = null;
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        var appLanguage = Provider.of<AppLanguage>(context);
        return AlertDialog(
          backgroundColor: const Color(0xFF1F1F1F),
          title: Text(
            AppLocalizations.of(context).translate('language'),
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: Config().lang.map((locale) {
              bool isSelected = appLanguage.appLocal.languageCode == locale['languageCode'];
              return ListTile(
                title: Text(
                  locale['name'],
                  style: TextStyle(
                    color: isSelected ? Colors.blueAccent : Colors.white,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected ? const Icon(Icons.check, color: Colors.blueAccent) : null,
                onTap: () {
                  appLanguage.changeLanguage(Locale(locale['languageCode']!), locale['languageCode']);
                  Navigator.pop(context);
                  Navigator.pop(context); // Close Drawer too
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).translate('cancel')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 850;

    return Drawer(
      width: isWide ? 800 : size.width * 0.95,
      backgroundColor: const Color(0xFF1F1F1F),
      child: Row(
        children: [
          // 1. Sidebar
          Container(
            width: 50,
            color: Colors.black.withOpacity(0.3),
            child: Column(
              children: [
                _sidebarIcon(Icons.menu, () => Navigator.pop(context), padding: 15),
                const Spacer(),
                _sidebarIcon(Icons.person, () => Navigator.pushNamed(context, '/profile'), tooltip: "User"),
                _sidebarIcon(Icons.description_outlined, () => _navToLayout(context, 2), tooltip: "Documents"),
                _sidebarIcon(Icons.local_shipping_outlined, () => Navigator.pushNamed(context, '/shipment'), tooltip: "Shipments"),
                _sidebarIcon(Icons.settings_suggest_rounded, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsPage())), tooltip: "System Settings"),
                _sidebarIcon(Icons.settings, () => Navigator.pushNamed(context, '/printerConfig'), tooltip: "Printer"),
                _sidebarIcon(Icons.power_settings_new, () => _handleLogout(context), tooltip: "Power", color: Colors.redAccent),
                const SizedBox(height: 10),
              ],
            ),
          ),

          // 2. All Apps List
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.only(left: 10, right: 5, top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Text("Recently added", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w300)),
                  ),
                  if (recentlyAdded.isEmpty)
                    _recentlyAddedItem("Home", "assets/images/default_product.png", () => _navToLayout(context, 0)),
                  ...recentlyAdded.map((item) => _recentlyAddedItem(
                    item['title'], 
                    "assets/images/default_product.png", 
                    () {
                      if (item['layoutIndex'] != null) {
                        _navToLayout(context, item['layoutIndex']);
                      } else {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, item['route']);
                      }
                    }
                  )),
                  const SizedBox(height: 15),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      children: [
                        _groupHeader("A"),
                        _appListItem(context, "Accounts", Icons.account_balance_wallet_outlined, '/contactPayment'),
                        _appListItem(context, "All Sales", Icons.history, '', layoutIndex: 2),
                        _groupHeader("C"),
                        _appListItem(context, "Customers", Icons.people_outline, '/leads'),
                        _groupHeader("E"),
                        if (widget.accessExpenses) _appListItem(context, "Expenses", Icons.money_off, '/expense'),
                        _groupHeader("F"),
                        _appListItem(context, "Follow Ups", Icons.notifications_active_outlined, '/followUp'),
                        if (Config().showFieldForce) _appListItem(context, "Field Visits", Icons.location_on_outlined, '/fieldForce'),
                        _groupHeader("H"),
                        _appListItem(context, "Home", Icons.home_outlined, '', layoutIndex: 0),
                        _groupHeader("N"),
                        _appListItem(context, "New Sales", Icons.inventory_2_outlined, '', layoutIndex: 1),
                        _groupHeader("L"),
                        _appListItem(context, "Language", Icons.language, '', customAction: () => _showLanguageDialog(context)),
                        _groupHeader("P"),
                        _appListItem(context, "Printer Settings", Icons.print_outlined, '/printerConfig'),
                        _appListItem(context, "Profile", Icons.person_pin_outlined, '/profile'),
                        _groupHeader("R"),
                        _appListItem(context, "Reports", Icons.bar_chart_outlined, '/ReportScreen'),
                        _groupHeader("S"),
                        _appListItem(context, "System Settings", Icons.settings_suggest_rounded, '', customAction: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminSettingsPage()))),
                        _appListItem(context, "Shipments", Icons.local_shipping_outlined, '/shipment'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Productivity Tiles
          if (isWide)
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.black.withOpacity(0.1),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Quick Access", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w400)),
                    const SizedBox(height: 15),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: List.generate(tiles.length, (index) {
                            return _buildDraggableTile(index);
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDraggableTile(int index) {
    final tileData = tiles[index];
    final poolKey = tileData['poolKey'] ?? '';

    return DragTarget<Object>(
      onWillAccept: (data) => data != index,
      onAccept: (data) {
        if (data is int) {
          setState(() {
            final draggedTile = tiles.removeAt(data);
            tiles.insert(index, draggedTile);
          });
        } else if (data is String) {
          // Pinning from Recently Added or All Apps
          var newTile = tilePool[data];
          if (newTile != null) {
            setState(() {
              tiles.removeWhere((t) => t['poolKey'] == data);
              var dataToInsert = Map<String, dynamic>.from(newTile);
              dataToInsert['poolKey'] = data;
              tiles.insert(index, dataToInsert);
            });
          }
        }
        _saveTileOrder();
      },
      builder: (context, candidateData, rejectedData) {
        return LongPressDraggable<int>(
          data: index,
          feedback: Material(
            color: Colors.transparent,
            child: _tile(
              tileData['title'],
              tileData['icon'],
              tileData['color'].withOpacity(0.5),
              tileData['width'],
              100,
              () {},
              isDragging: true,
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _tile(
              tileData['title'],
              tileData['icon'],
              tileData['color'],
              tileData['width'],
              100,
              () {},
            ),
          ),
          child: GestureDetector(
            onSecondaryTapDown: (details) => _showTileContextMenu(context, details.globalPosition, poolKey),
            onLongPressStart: (details) => _showTileContextMenu(context, details.globalPosition, poolKey),
            child: _tile(
              tileData['title'],
              tileData['icon'],
              tileData['color'],
              tileData['width'],
              100,
              () async {
                if (tileData['id'] != 'sync') {
                  await _trackClick(tileData['title'], '', layoutIndex: tileData['id'] == 'new_sale' ? 1 : (tileData['id'] == 'home' ? 0 : (tileData['id'] == 'sales' ? 2 : null)));
                }
                if (tileData['title'] == 'Language') {
                  _showLanguageDialog(context);
                } else {
                  tileData['onTap'](context);
                }
              },
            ),
          ),
        );
      },
    );
  }

  void _showTileContextMenu(BuildContext context, Offset position, String poolKey) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF2C2C2C),
      items: [
        PopupMenuItem(
          onTap: () => _togglePin(poolKey),
          child: const Row(
            children: [
              Icon(Icons.push_pin_outlined, color: Colors.white70, size: 18),
              SizedBox(width: 10),
              Text("Unpin from Quick Access", style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sidebarIcon(IconData icon, VoidCallback onTap, {double padding = 12, String? tooltip, Color? color}) {
    return Tooltip(
      message: tooltip ?? "",
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 50,
          width: 50,
          alignment: Alignment.center,
          child: Icon(icon, color: color ?? Colors.white.withOpacity(0.8), size: 22),
        ),
      ),
    );
  }

  Widget _groupHeader(String letter) {
    return Padding(
      padding: const EdgeInsets.only(top: 15, bottom: 5, left: 5),
      child: Text(letter, style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _recentlyAddedItem(String title, String imagePath, VoidCallback onTap) {
    return LongPressDraggable<String>(
      data: title,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.8), borderRadius: BorderRadius.circular(4)),
          child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.2), borderRadius: BorderRadius.circular(2)),
                child: const Icon(Icons.star, color: Colors.blue, size: 18),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appListItem(BuildContext context, String title, IconData icon, String route, {int? layoutIndex, VoidCallback? customAction}) {
    // Map list title to pool key
    String poolKey = title;
    if (title == "All Sales") poolKey = "All Sales";
    if (title == "New Sales") poolKey = "New Sale";
    if (title == "Inventory") poolKey = "Inventory";
    
    bool isPinned = tiles.any((t) => t['poolKey'] == poolKey);

    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      contentPadding: const EdgeInsets.symmetric(horizontal: 5),
      leading: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(2)),
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: 16),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w300)),
      trailing: IconButton(
        icon: Icon(isPinned ? Icons.push_pin : Icons.push_pin_outlined, 
                   color: isPinned ? Colors.blueAccent : Colors.white24, size: 14),
        onPressed: () => _togglePin(poolKey),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        tooltip: isPinned ? "Unpin" : "Pin to Quick Access",
      ),
      onTap: () async {
        if (customAction != null) {
          customAction();
        } else {
          await _trackClick(title, route, layoutIndex: layoutIndex);
          if (layoutIndex != null) {
            _navToLayout(context, layoutIndex);
          } else {
            Navigator.pop(context);
            Navigator.pushNamed(context, route);
          }
        }
      },
    );
  }

  Widget _tile(String title, IconData icon, Color color, double width, double height, VoidCallback onTap, {bool isDragging = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        color: color,
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Center(child: Icon(icon, color: Colors.white.withOpacity(0.9), size: width > 150 ? 36 : 28)),
            Positioned(
              bottom: 0,
              left: 0,
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w300, letterSpacing: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
