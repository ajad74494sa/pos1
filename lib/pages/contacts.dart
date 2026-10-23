import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../apis/api.dart';
import '../apis/contact.dart';
import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import '../helpers/otherHelpers.dart';
import '../locale/MyLocalizations.dart';
import '../models/contact_model.dart';
import '../models/system.dart';
import '../services/whatsapp_service.dart';
import '../pages/forms.dart';
import '../pages/customer_profile.dart';

class Contacts extends StatefulWidget {
  @override
  _ContactsState createState() => _ContactsState();
}

class _ContactsState extends State<Contacts> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool isLoading = false,
      useOrderBy = false,
      orderByAsc = true,
      useSearchBy = false;
  int currentTabIndex = 0;

  List<Map<String, dynamic>> leadsList = [], customerList = [], suppliersList = [];

  ScrollController leadsListController = ScrollController(),
      customerListController = ScrollController(),
      suppliersListController = ScrollController();

  var searchController = TextEditingController();
  String?
  fetchLeads = Api().baseUrl + Api().apiUrl + "/crm/leads?per_page=10",
  fetchCustomers =
      Api().baseUrl + Api().apiUrl + "/contactapi?type=customer&per_page=10",
  fetchSuppliers =
      Api().baseUrl + Api().apiUrl + "/contactapi?type=supplier&per_page=10";
  String orderByColumn = 'name', orderByDirection = 'asc';

  TextEditingController prefix = TextEditingController(),
      firstName = TextEditingController(),
      middleName = TextEditingController(),
      lastName = TextEditingController(),
      mobile = TextEditingController(),
      addressLine1 = TextEditingController(),
      addressLine2 = TextEditingController(),
      city = TextEditingController(),
      state = TextEditingController(),
      country = TextEditingController(),
      zip = TextEditingController();

  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  @override
  void initState() {
    super.initState();
    setAllList();
    leadsListController.addListener(() {
      if (leadsListController.position.pixels ==
          leadsListController.position.maxScrollExtent) {
        setLeadsList();
      }
    });
    customerListController.addListener(() {
      if (customerListController.position.pixels ==
          customerListController.position.maxScrollExtent) {
        setCustomersList();
      }
    });
    suppliersListController.addListener(() {
      if (suppliersListController.position.pixels ==
          suppliersListController.position.maxScrollExtent) {
        setSuppliersList();
      }
    });
    Helper().syncCallLogs();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: 0,
      length: 3,
      child: Scaffold(
        key: _scaffoldKey,

        backgroundColor: customAppTheme.bgLayer1,
        endDrawer: _filterDrawer(),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<Null>(
                builder: (BuildContext context) {
                  return newCustomer();
                },
                fullscreenDialog: true,
              ),
            );
          },
          backgroundColor: themeData.colorScheme.primary,
          child: Icon(Symbols.person_add, color: Colors.white),
          elevation: 4,
        ),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: themeData.colorScheme.primary,
          iconTheme: IconThemeData(color: Colors.white),
          title: Text(
            AppLocalizations.of(context).translate('contacts'),
            style: AppTheme.getTextStyle(
              themeData.textTheme.titleLarge,
              color: Colors.white,
              fontWeight: 600,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Symbols.filter_alt, color: Colors.white),
              onPressed: () {
                _scaffoldKey.currentState!.openEndDrawer();
              },
            ),
          ],
          bottom: TabBar(
            onTap: (int val) {
              currentTabIndex = val;
              searchController.clear();
              sortContactList(tabIndex: val);
            },
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withAlpha(150),
            tabs: [
              Tab(child: Text(AppLocalizations.of(context).translate('leads').toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Tab(child: Text(AppLocalizations.of(context).translate('customer').toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Tab(child: Text(AppLocalizations.of(context).translate('suppliers').toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildContactList(leadsList, leadsListController),
            _buildContactList(customerList, customerListController),
            _buildContactList(suppliersList, suppliersListController),
          ],
        ),
      ),
    );
  }

  Widget _buildContactList(List<Map<String, dynamic>> list, ScrollController controller) {
    if (list.isEmpty && !isLoading) return Helper().noDataWidget(context);

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.all(MySize.size16!),
      physics: BouncingScrollPhysics(),
      itemCount: list.length + 1,
      itemBuilder: (context, index) {
        if (index == list.length) {
          return isLoading ? _buildProgressIndicator() : SizedBox(height: MySize.size80);
        }
        return _buildModernContactCard(list[index]);
      },
    );
  }

  Widget _buildModernContactCard(Map<String, dynamic> contact) {
    String name = contact['name'] ?? 'N/A';
    String businessName = contact['supplier_business_name']?.toString() ?? '';
    if (businessName == 'null') businessName = '';
    
    String initials = name.isNotEmpty ? name.trim().split(' ').map((l) => l[0]).take(2).join().toUpperCase() : '?';

    return Container(
      margin: EdgeInsets.only(bottom: MySize.size16!),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(MySize.size16!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(MySize.size16!),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CustomerProfile(customer: contact)),
            );
          },
          child: Padding(
            padding: EdgeInsets.all(MySize.size16!),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: MySize.size24,
                      backgroundColor: themeData.colorScheme.primary.withAlpha(20),
                      child: Text(
                        initials,
                        style: TextStyle(color: themeData.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                    SizedBox(width: MySize.size16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (businessName.isNotEmpty)
                            Text(
                              businessName,
                              style: AppTheme.getTextStyle(themeData.textTheme.titleSmall, fontWeight: 700, color: themeData.colorScheme.primary),
                            ),
                          Text(
                            name,
                            style: AppTheme.getTextStyle(themeData.textTheme.titleMedium, fontWeight: 600),
                          ),
                          if (contact['mobile'] != null)
                            Text(
                              contact['mobile'],
                              style: AppTheme.getTextStyle(themeData.textTheme.bodySmall, color: themeData.colorScheme.onSurface.withAlpha(150)),
                            ),
                        ],
                      ),
                    ),
                    Icon(Symbols.chevron_right, color: themeData.colorScheme.onSurface.withAlpha(100)),
                  ],
                ),
                if (contact['last_follow_up'] != null || contact['upcoming_follow_up'] != null) ...[
                  Divider(height: MySize.size24),
                  Row(
                    children: [
                      if (contact['last_follow_up'] != null)
                        Expanded(
                          child: _miniInfo(Symbols.history, AppLocalizations.of(context).translate('last'), contact['last_follow_up']),
                        ),
                      if (contact['upcoming_follow_up'] != null)
                        Expanded(
                          child: _miniInfo(Symbols.event, AppLocalizations.of(context).translate('upcoming'), contact['upcoming_follow_up']),
                        ),
                    ],
                  ),
                ],
                SizedBox(height: MySize.size12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Helper().makePhoneCall(contact['mobile']),
                        icon: Icon(Symbols.call, size: 18),
                        label: Text(AppLocalizations.of(context).translate('call')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.green,
                          side: BorderSide(color: Colors.green.withAlpha(100)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MySize.size8!)),
                        ),
                      ),
                    ),
                    SizedBox(width: MySize.size12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => FollowUpForm(contact)),
                          );
                        },
                        icon: Icon(Symbols.add, size: 18, color: Colors.white),
                        label: Text(AppLocalizations.of(context).translate('add'), style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeData.colorScheme.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MySize.size8!)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: themeData.colorScheme.onSurface.withAlpha(150)),
        SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 10, color: themeData.colorScheme.onSurface.withAlpha(150))),
              Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }

  //Retrieve leads list from api
  setLeadsList() async {
    setState(() {
      isLoading = true;
    });
    final dio = Dio();
    var token = await System().getToken();
    dio.options.headers['content-Type'] = 'application/json';
    dio.options.headers["Authorization"] = "Bearer $token";
    final response = await dio.get(fetchLeads!);
    List leads = response.data['data'];
    Map links = response.data['links'];
    setState(() {
      for (var element in leads) {
        leadsList.add(Map<String, dynamic>.from(element));
      }
      isLoading = false;
    });
    fetchLeads = links['next'];
  }

  //Retrieve customers list from api
  setCustomersList() async {
    setState(() {
      isLoading = true;
    });
    final dio = Dio();
    var token = await System().getToken();
    dio.options.headers['content-Type'] = 'application/json';
    dio.options.headers["Authorization"] = "Bearer $token";
    final response = await dio.get(fetchCustomers!);
    List customers = response.data['data'];
    Map links = response.data['links'];
    setState(() {
      for (var element in customers) {
        customerList.add(Map<String, dynamic>.from(element));
      }
      isLoading = false;
    });
    fetchCustomers = links['next'];
  }

  //Retrieve suppliers list from api
  setSuppliersList() async {
    setState(() {
      isLoading = true;
    });
    final dio = Dio();
    var token = await System().getToken();
    dio.options.headers['content-Type'] = 'application/json';
    dio.options.headers["Authorization"] = "Bearer $token";
    final response = await dio.get(fetchSuppliers!);
    List suppliers = response.data['data'];
    Map links = response.data['links'];
    setState(() {
      for (var element in suppliers) {
        suppliersList.add(Map<String, dynamic>.from(element));
      }
      isLoading = false;
    });
    fetchSuppliers = links['next'];
  }

  //set initial list
  setAllList() async {
    fetchLeads = getUrl();
    setLeadsList();
    setCustomersList();
    setSuppliersList();
  }

  //filter widget
  Widget _filterDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Material(
        color: Colors.white,
        child: SafeArea(
          child: Container(
            padding: EdgeInsets.all(MySize.size16!),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context).translate('filter').toUpperCase(),
                  style: AppTheme.getTextStyle(themeData.textTheme.titleMedium, fontWeight: 700),
                ),
                SizedBox(height: MySize.size20),
                TextFormField(
                  style: AppTheme.getTextStyle(themeData.textTheme.bodyMedium),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context).translate('search'),
                    prefixIcon: Icon(Symbols.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(MySize.size12!)),
                    filled: true,
                    fillColor: themeData.colorScheme.surface,
                  ),
                  controller: searchController,
                  onFieldSubmitted: (val) {
                    sortContactList(tabIndex: currentTabIndex);
                    Navigator.pop(context);
                  },
                ),
                SizedBox(height: MySize.size20),
                _filterSectionTitle(AppLocalizations.of(context).translate('order_by')),
                ListTile(
                  title: Text(AppLocalizations.of(context).translate('name')),
                  leading: Radio(
                    value: 'name',
                    groupValue: orderByColumn,
                    onChanged: (value) => setState(() => orderByColumn = value.toString()),
                  ),
                ),
                ListTile(
                  title: Text(AppLocalizations.of(context).translate('business_name')),
                  leading: Radio(
                    value: 'supplier_business_name',
                    groupValue: orderByColumn,
                    onChanged: (value) => setState(() => orderByColumn = value.toString()),
                  ),
                ),
                Divider(),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          searchController.clear();
                          setState(() {
                            useOrderBy = false;
                            orderByColumn = 'name';
                            orderByDirection = 'asc';
                          });
                          sortContactList(tabIndex: currentTabIndex);
                          Navigator.pop(context);
                        },
                        child: Text(AppLocalizations.of(context).translate('reset')),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          sortContactList(tabIndex: currentTabIndex);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: themeData.colorScheme.primary),
                        child: Text(AppLocalizations.of(context).translate('submit'), style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _filterSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: themeData.colorScheme.primary)),
    );
  }

  //filter list
  sortContactList({int? tabIndex}) {
    setState(() {
      isLoading = true;
    });
    switch (tabIndex) {
      case 0:
        leadsList = [];
        fetchLeads = getUrl();
        setLeadsList();
        break;
      case 1:
        customerList = [];
        fetchCustomers = getUrl();
        setCustomersList();
        break;
      case 2:
        suppliersList = [];
        fetchSuppliers = getUrl();
        setSuppliersList();
        break;
    }
  }

  getUrl({String? perPage = '10'}) {
    String contactType = (currentTabIndex == 0) ? '/crm/leads?' : '/contactapi?';
    String url = Api().baseUrl + Api().apiUrl + contactType;
    Map<String, dynamic> params = {};
    if (currentTabIndex == 1) params['type'] = 'customer';
    if (currentTabIndex == 2) params['type'] = 'supplier';
    if (searchController.text.isNotEmpty) {
      params['name'] = searchController.text;
      params['biz_name'] = searchController.text;
      params['mobile_num'] = searchController.text;
      params['contact_id'] = searchController.text;
    }
    if (perPage != null) params['per_page'] = perPage;
    params['order_by'] = orderByColumn;
    params['direction'] = orderByDirection;
    String queryString = Uri(queryParameters: params).query;
    url += queryString;
    return url;
  }

  //show add customer alert box
  Widget newCustomer() {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate('create_contact')),
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        padding: EdgeInsets.all(MySize.size16!),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                _buildFormSection(Symbols.person, [
                  _buildTextField(prefix, AppLocalizations.of(context).translate('prefix'), width: 80),
                  SizedBox(width: 12),
                  Expanded(child: _buildTextField(firstName, AppLocalizations.of(context).translate('first_name'), validator: true)),
                ]),
                _buildFormSection(null, [
                  Expanded(child: _buildTextField(middleName, AppLocalizations.of(context).translate('middle_name'))),
                  SizedBox(width: 12),
                  Expanded(child: _buildTextField(lastName, AppLocalizations.of(context).translate('last_name'))),
                ]),
                _buildFormSection(Symbols.call, [
                  Expanded(child: _buildTextField(mobile, AppLocalizations.of(context).translate('phone'), keyboard: TextInputType.phone, validator: true)),
                ]),
                _buildFormSection(Symbols.location_on, [
                  Expanded(child: _buildTextField(addressLine1, AppLocalizations.of(context).translate('address_line_1'))),
                ]),
                _buildFormSection(null, [
                  Expanded(child: _buildTextField(addressLine2, AppLocalizations.of(context).translate('address_line_2'))),
                ]),
                _buildFormSection(Symbols.map, [
                  Expanded(child: _buildTextField(city, AppLocalizations.of(context).translate('city'))),
                  SizedBox(width: 12),
                  Expanded(child: _buildTextField(state, AppLocalizations.of(context).translate('state'))),
                ]),
                _buildFormSection(null, [
                  Expanded(child: _buildTextField(country, AppLocalizations.of(context).translate('country'))),
                  SizedBox(width: 12),
                  Expanded(child: _buildTextField(zip, AppLocalizations.of(context).translate('zip_code'), keyboard: TextInputType.number)),
                ]),
                SizedBox(height: MySize.size30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitNewCustomer,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: themeData.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MySize.size12!)),
                    ),
                    child: Text(AppLocalizations.of(context).translate('add_to_contact').toUpperCase(), style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormSection(IconData? icon, List<Widget> children) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            child: icon != null ? Icon(icon, color: themeData.colorScheme.primary) : null,
          ),
          SizedBox(width: 12),
          Expanded(child: Row(children: children)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {double? width, bool validator = false, TextInputType keyboard = TextInputType.text}) {
    return Container(
      width: width,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        validator: validator ? (val) => val!.isEmpty ? AppLocalizations.of(context).translate('required') : null : null,
        decoration: InputDecoration(
          labelText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
    );
  }

  void _submitNewCustomer() async {
    if (await Helper().checkConnectivity()) {
      if (_formKey.currentState!.validate()) {
        String finalName = firstName.text.trim();
        String mobileNum = mobile.text.trim();

        // 1. If name is blank, try to fetch from WhatsApp automatically
        if (finalName.isEmpty && mobileNum.isNotEmpty) {
          Helper().showNotification(context, "Fetching name from WhatsApp...");
          var waContact = await WhatsAppService().getContactDetails(mobileNum);
          if (waContact != null && waContact['name'] != null && waContact['name'].toString().isNotEmpty) {
            finalName = waContact['name'];
            Helper().showNotification(context, "Found: $finalName");
          }
        }

        // 2. If still blank, use phone number as name
        if (finalName.isEmpty) {
          finalName = mobileNum;
        }

        Map newCustomer = {
          'type': 'customer',
          'prefix': prefix.text,
          'first_name': finalName,
          'middle_name': middleName.text,
          'last_name': lastName.text,
          'mobile': mobileNum,
          'address_line_1': addressLine1.text,
          'address_line_2': addressLine2.text,
          'city': city.text,
          'state': state.text,
          'country': country.text,
          'zip_code': zip.text,
        };
        await CustomerApi().add(newCustomer).then((value) {
          if (value['data'] != null) {
            Contact().insertContact(Contact().contactModel(value['data'])).then((value) {
              Navigator.pop(context);
              sortContactList(tabIndex: currentTabIndex);
            });
          }
        });
      }
    } else {
      Helper().showNotification(
        context,
        AppLocalizations.of(context).translate('check_connectivity'),
        isError: true,
      );
    }
  }

  Widget _buildProgressIndicator() {
    return Padding(
      padding: EdgeInsets.all(MySize.size16!),
      child: Helper().loadingIndicator(context, subTitle: 'LOADING CONTACTS...'),
    );
  }
}
