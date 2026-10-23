import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';
import '../apis/contact.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../services/nfc_service.dart';

class CustomerProfile extends StatefulWidget {
  final Map<String, dynamic> customer;
  CustomerProfile({required this.customer});

  @override
  _CustomerProfileState createState() => _CustomerProfileState();
}

class _CustomerProfileState extends State<CustomerProfile> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, dynamic> customerData;
  bool isRefreshing = false;
  
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  @override
  void initState() {
    super.initState();
    customerData = Map<String, dynamic>.from(widget.customer);
    _tabController = TabController(length: 2, vsync: this);
    _refreshCustomerData();
  }

  Future<void> _refreshCustomerData() async {
    if (await Helper().checkConnectivity()) {
      setState(() => isRefreshing = true);
      try {
        var response = await CustomerApi().getContactDetails(customerData['id']);
        if (response != null && response['data'] != null && response['data'].isNotEmpty) {
          if (mounted) {
            setState(() {
              customerData = Map<String, dynamic>.from(response['data'][0]);
            });
          }
        }
      } catch (e) {
        print('Error refreshing customer data: $e');
      } finally {
        if (mounted) setState(() => isRefreshing = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: customAppTheme.bgLayer1,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverAppBar(
              expandedHeight: MySize.size180,
              floating: false,
              pinned: true,
              backgroundColor: themeData.colorScheme.primary,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: isRefreshing 
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshCustomerData,
                ),
                IconButton(
                  icon: Icon(Symbols.edit, color: Colors.white),
                  onPressed: () {},
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeaderBackground(),
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: themeData.colorScheme.primary,
                  unselectedLabelColor: themeData.colorScheme.onSurface.withAlpha(150),
                  indicatorColor: themeData.colorScheme.primary,
                  tabs: [
                    Tab(text: AppLocalizations.of(context).translate('home').toUpperCase()),
                    Tab(text: AppLocalizations.of(context).translate('sales').toUpperCase()),
                  ],
                ),
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildTransactionsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBackground() {
    String name = customerData['name'] ?? 'N/A';
    String initials = name.isNotEmpty ? name.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            themeData.colorScheme.primary,
            themeData.colorScheme.primary.withAlpha(180),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: MySize.size20),
          Container(
            padding: EdgeInsets.all(MySize.size4!),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(50),
            ),
            child: CircleAvatar(
              radius: MySize.size44,
              backgroundColor: Colors.white,
              child: Text(
                initials,
                style: AppTheme.getTextStyle(
                  themeData.textTheme.headlineMedium,
                  color: themeData.colorScheme.primary,
                  fontWeight: 700,
                ),
              ),
            ),
          ),
          SizedBox(height: MySize.size12),
          Text(
            name,
            style: AppTheme.getTextStyle(
              themeData.textTheme.titleLarge,
              color: Colors.white,
              fontWeight: 700,
            ),
          ),
          Text(
            customerData['contact_id'] ?? '',
            style: AppTheme.getTextStyle(
              themeData.textTheme.bodySmall,
              color: Colors.white.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(MySize.size20!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuickActions(),
          SizedBox(height: MySize.size24),
          _buildStats(),
          SizedBox(height: MySize.size24),
          _buildInfoSection(),
          SizedBox(height: MySize.size24),
          _buildAddressSection(),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.receipt_long, size: MySize.size64, color: themeData.colorScheme.onSurface.withAlpha(50)),
          SizedBox(height: MySize.size16),
          Text(
            "No recent transactions",
            style: AppTheme.getTextStyle(
              themeData.textTheme.bodyMedium,
              color: themeData.colorScheme.onSurface.withAlpha(150),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: MySize.size16!),
      decoration: BoxDecoration(
        color: customAppTheme.bgLayer1,
        borderRadius: BorderRadius.circular(MySize.size16!),
        boxShadow: [
          BoxShadow(
            color: themeData.shadowColor.withAlpha(15),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: MySize.size8!),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _actionItem(Symbols.call, AppLocalizations.of(context).translate('call'), Colors.green, () {
              Helper().makePhoneCall(customerData['mobile']);
            }),
            SizedBox(width: MySize.size12),
            _actionItem(Symbols.chat, "WhatsApp", Colors.blue, () {
              _launchWhatsApp(customerData['mobile']);
            }),
            SizedBox(width: MySize.size12),
            _actionItem(Symbols.nfc, "NFC Card", Colors.teal, () {
              _showNfcAssignmentDialog();
            }),
            SizedBox(width: MySize.size12),
            _actionItem(Symbols.payments, AppLocalizations.of(context).translate('payments'), Colors.orange, () async {
              await Navigator.pushNamed(context, '/contact_payment', arguments: {'customer': customerData});
              _refreshCustomerData();
            }),
            SizedBox(width: MySize.size12),
            _actionItem(Symbols.add_shopping_cart, AppLocalizations.of(context).translate('sales'), Colors.purple, () {
              Navigator.pushNamed(context, '/products');
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(MySize.size10!),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: MySize.size24),
          ),
          SizedBox(height: MySize.size8),
          Text(
            label,
            style: AppTheme.getTextStyle(
              themeData.textTheme.bodySmall,
              fontWeight: 600,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                AppLocalizations.of(context).translate('due_amount'),
                "${customerData['total_due'] ?? '0.00'}",
                Colors.red,
                Symbols.account_balance_wallet,
              ),
            ),
            SizedBox(width: MySize.size16),
            Expanded(
              child: _statCard(
                "Advance Balance",
                "${customerData['advance_balance'] ?? customerData['balance'] ?? '0.00'}",
                Colors.teal,
                Symbols.savings,
              ),
            ),
          ],
        ),
        SizedBox(height: MySize.size12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                "Credit Limit",
                "${customerData['credit_limit'] ?? '0.00'}",
                Colors.orange,
                Symbols.credit_card,
              ),
            ),
            SizedBox(width: MySize.size16),
            Expanded(
              child: _statCard(
                AppLocalizations.of(context).translate('total_sell'),
                "${customerData['total_invoice'] ?? '0.00'}",
                Colors.green,
                Symbols.shopping_bag,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(MySize.size16!),
      decoration: BoxDecoration(
        color: color.withAlpha(10),
        borderRadius: BorderRadius.circular(MySize.size16!),
        border: Border.all(color: color.withAlpha(30), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: MySize.size20),
          SizedBox(height: MySize.size12),
          Text(
            label,
            style: AppTheme.getTextStyle(
              themeData.textTheme.bodySmall,
              fontWeight: 600,
              color: themeData.colorScheme.onSurface.withAlpha(180),
            ),
          ),
          SizedBox(height: MySize.size4),
          Text(
            value,
            style: AppTheme.getTextStyle(
              themeData.textTheme.titleMedium,
              color: color,
              fontWeight: 800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    String nfcId = (customerData['custom_field1'] ?? customerData['nfc_card_id'])?.toString() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: MySize.size4!),
          child: Text(
            AppLocalizations.of(context).translate('user_details'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.titleMedium,
              fontWeight: 700,
            ),
          ),
        ),
        SizedBox(height: MySize.size16),
        _infoTile(Symbols.nfc, "NFC Card UID", nfcId.isNotEmpty ? nfcId : "Not Assigned"),
        _infoTile(Symbols.phone, AppLocalizations.of(context).translate('mobile_no'), customerData['mobile'] ?? '-'),
        _infoTile(Symbols.mail, AppLocalizations.of(context).translate('email'), customerData['email'] ?? '-'),
        _infoTile(Symbols.cake, AppLocalizations.of(context).translate('dob'), customerData['dob'] ?? '-'),
      ],
    );
  }

  void _showNfcAssignmentDialog() async {
    bool isAvailable = await NfcService().isNfcAvailable();
    if (!mounted) return;

    String? currentNfcId = (customerData['custom_field1'] ?? customerData['nfc_card_id'])?.toString();
    TextEditingController manualCardController = TextEditingController(text: currentNfcId ?? '');
    bool isManualMode = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        String statusMessage = isAvailable
            ? "Please tap the NFC card on the back of the device..."
            : "NFC scanning unavailable. Enter Card ID manually below.";

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (isAvailable && !isManualMode) {
              NfcService().startScanning(
                onCardScanned: (cardUid) async {
                  NfcService().stopScanning();
                  int customerId = customerData['id'];
                  await Contact().updateNfcCardId(customerId, cardUid);

                  if (mounted) {
                    setState(() {
                      customerData['custom_field1'] = cardUid;
                      customerData['nfc_card_id'] = cardUid;
                    });
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("NFC Card ($cardUid) linked successfully!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                onError: (error) {
                  if (mounted) {
                    setDialogState(() {
                      statusMessage = error;
                    });
                  }
                },
              );
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Symbols.nfc, color: themeData.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentNfcId != null && currentNfcId.isNotEmpty
                          ? "Re-assign NFC Card"
                          : "Assign NFC Card",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAvailable && !isManualMode) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: themeData.colorScheme.primary.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Symbols.contactless,
                        size: 48,
                        color: themeData.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        NfcService().stopScanning();
                        setDialogState(() {
                          isManualMode = true;
                        });
                      },
                      icon: const Icon(Symbols.edit_note, size: 18),
                      label: const Text("Enter Card ID Manually"),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      "Enter Card ID / UID manually:",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: manualCardController,
                      decoration: InputDecoration(
                        hintText: "e.g. E2003410",
                        prefixIcon: const Icon(Symbols.credit_card),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    if (isAvailable) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            isManualMode = false;
                          });
                        },
                        icon: const Icon(Symbols.sensors, size: 18),
                        label: const Text("Switch to NFC Tap Scan"),
                      ),
                    ],
                  ],
                  if (currentNfcId != null && currentNfcId.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.teal.withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Current Card ID: $currentNfcId",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.teal),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    NfcService().stopScanning();
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text("Cancel"),
                ),
                if (isManualMode || !isAvailable)
                  ElevatedButton(
                    onPressed: () async {
                      String manualUid = manualCardController.text.trim();
                      if (manualUid.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Please enter a valid Card ID")),
                        );
                        return;
                      }
                      NfcService().stopScanning();
                      int customerId = customerData['id'];
                      await Contact().updateNfcCardId(customerId, manualUid);

                      if (mounted) {
                        setState(() {
                          customerData['custom_field1'] = manualUid;
                          customerData['nfc_card_id'] = manualUid;
                        });
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("NFC Card ($manualUid) saved successfully!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                    child: const Text("Save"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: EdgeInsets.only(bottom: MySize.size12!),
      padding: EdgeInsets.all(MySize.size12!),
      decoration: BoxDecoration(
        color: customAppTheme.bgLayer2,
        borderRadius: BorderRadius.circular(MySize.size12!),
      ),
      child: Row(
        children: [
          Icon(icon, size: MySize.size20, color: themeData.colorScheme.primary),
          SizedBox(width: MySize.size16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.getTextStyle(
                  themeData.textTheme.bodySmall,
                  fontSize: 10,
                  color: themeData.colorScheme.onSurface.withAlpha(150),
                ),
              ),
              Text(
                value,
                style: AppTheme.getTextStyle(
                  themeData.textTheme.bodyMedium,
                  fontWeight: 600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    String address = [
      customerData['address_line_1'],
      customerData['address_line_2'],
      customerData['city'],
      customerData['state'],
      customerData['country'],
      customerData['zip_code']
    ].where((e) => e != null && e.toString().isNotEmpty && e.toString() != 'null').join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: MySize.size4!),
          child: Text(
            AppLocalizations.of(context).translate('address'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.titleMedium,
              fontWeight: 700,
            ),
          ),
        ),
        SizedBox(height: MySize.size12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(MySize.size16!),
          decoration: BoxDecoration(
            color: customAppTheme.bgLayer2,
            borderRadius: BorderRadius.circular(MySize.size12!),
            border: Border.all(color: customAppTheme.bgLayer4, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.location_on, color: themeData.colorScheme.primary, size: MySize.size20),
              SizedBox(width: MySize.size12),
              Expanded(
                child: Text(
                  address.isEmpty ? '-' : address,
                  style: AppTheme.getTextStyle(
                    themeData.textTheme.bodyMedium,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _launchWhatsApp(String? phone) async {
    if (phone == null || phone.isEmpty || phone == 'null') return;
    var url = "whatsapp://send?phone=$phone";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("WhatsApp not installed")),
      );
    }
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
