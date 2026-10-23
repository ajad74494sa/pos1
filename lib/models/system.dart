import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import '../apis/system.dart';
import '../models/contact_model.dart';
import 'database.dart';

class System {
  late DbProvider dbProvider;

  System() {
    dbProvider = new DbProvider();
  }

  //store system data
  Future<int> insert(key, value, [keyId]) async {
    final db = await dbProvider.database;
    var data = {'key': '$key', 'keyId': keyId, 'value': value};
    var response = await db.insert('system', data);
    return response;
  }

  //batch store system data
  Future<void> batchInsert(List<Map<String, dynamic>> items) async {
    final db = await dbProvider.database;
    Batch batch = db.batch();
    for (var item in items) {
      batch.insert('system', item);
    }
    await batch.commit(noResult: true);
  }

//save user details
  Future<int> insertUserDetails(Map userDetails) async {
    final db = await dbProvider.database;
    var data = {'key': 'loggedInUser', 'value': jsonEncode(userDetails)};
    var response = await db.insert('system', data);
    return response;
  }

  //store token
  Future<int> insertToken(String token) async {
    final db = await dbProvider.database;
    var data = {'key': 'token', 'value': token};
    var response = await db.insert('system', data);
    return response;
  }

  insertProductLastSyncDateTimeNow() async {
    //if already present then update, else insert new
    final db = await dbProvider.database;
    String? lastSync = await this.getProductLastSync();

    if (lastSync == null) {
      var data = {
        'key': 'product_last_sync',
        'value': DateTime.now().toString()
      };
      await db.insert('system', data);
    } else {
      await db.update('system', {'value': DateTime.now().toString()},
          where: 'key = ?', whereArgs: ['product_last_sync']);
    }
  }

  // insert/update/get call_log_last_sync time
  callLogLastSyncDateTime([bool? insert]) async {
    //if already present then update, else insert new
    final db = await dbProvider.database;
    var lastSyncDetail = await db
        .query('system', where: 'key = ?', whereArgs: ['call_logs_last_sync']);
    var lastSync =
        (lastSyncDetail.isNotEmpty) ? lastSyncDetail[0]['value'] : null;

    if (insert == true && lastSync == null) {
      await db.insert('system',
          {'key': 'call_logs_last_sync', 'value': DateTime.now().toString()});
      return lastSync;
    } else if (insert == true) {
      db.update('system', {'value': DateTime.now().toString()},
          where: 'key = ?', whereArgs: ['call_logs_last_sync']);
      return lastSync;
    } else {
      return lastSync;
    }
  }

  Future<dynamic> getProductLastSync() async {
    final db = await dbProvider.database;
    var result = await db
        .query('system', where: 'key = ?', whereArgs: ['product_last_sync']);
    var response = (result.length > 0) ? result[0]['value'] : null;
    return response;
  }

  //fetch token
  Future<String> getToken() async {
    final db = await dbProvider.database;
    var result =
        await db.query('system', where: 'key = ?', whereArgs: ['token']);
    if (result.isNotEmpty) {
      return result[0]['value'].toString();
    }
    return '';
  }

  // Return permission list
  Future<List> getPermission() async {
    var result = await this.get('loggedInUser');
    
    // Check for admin status flexibly (bool, int 1, or string "1")
    bool isAdmin = false;
    if (result is Map && result.containsKey('is_admin')) {
      var val = result['is_admin'];
      if (val == true || val == 1 || val == '1') {
        isAdmin = true;
      }
    } else if (result is Map && result.containsKey('id')) {
      // If we have a user but no is_admin key, check if they are the first user or something
      // Or maybe check user_permissions for 'all'
      var permissions = await this.get('user_permissions');
      if (permissions is List && permissions.contains('all')) {
        isAdmin = true;
      }
    }

    if (isAdmin) {
      return ['all'];
    } else {
      var permissions = await this.get('user_permissions');
      List permissionList = permissions is List ? permissions : [];
      return permissionList;
    }
  }

  //Return the list of categories.
  Future<List> getCategories() async {
    var categories = await this.get('taxonomy');

    if (categories.length > 0) {
      return categories;
    } else {
      return [];
    }
  }

  //Return the list of sub categories.
  Future<List> getSubCategories(parentId) async {
    final db = await dbProvider.database;
    String where = 'and keyId = $parentId';
    var subCategories = await db.query('system',
        where: 'key = ? $where', whereArgs: ['sub_categories']);
    if (subCategories.length > 0) {
      return subCategories;
    } else {
      return [];
    }
  }

  //Return the list of brands.
  Future<List> getBrands() async {
    var brands = await this.get('brand');
    if (brands.length > 0) {
      return brands;
    } else {
      return [];
    }
  }

  storePermissions() async {
    final db = await dbProvider.database;
    var result = await this.get('loggedInUser');
    if (result.containsKey('all_permissions')) {
      var userData = {
        'key': 'user_permissions',
        'value': jsonEncode(result['all_permissions'])
      };
      await db.insert('system', userData);
    }
  }

  //Return the list of payment accounts.
  Future<List> getPaymentAccounts() async {
    var accounts = await this.get('payment_accounts');
    if (accounts.length > 0) {
      return accounts;
    } else {
      return [];
    }
  }

  //get brandList,categoryList,taxRateList,locationList,permissionList
  Future<dynamic> get(key, [keyId]) async {
    final db = await dbProvider.database;
    String where = '';
    if (keyId != null) {
      where = 'and keyId = $keyId';
    }
    List<Map<String, dynamic>> result =
        await db.query('system', where: 'key = ? $where', whereArgs: ['$key']);
    var response = (result.length > 0) ? jsonDecode(result[0]['value']) : [];
    return response;
  }

  //empty system table
  Future<int> empty() async {
    final db = await dbProvider.database;
    var response = await db.delete('system');
    return response;
  }

  //delete column from system table
  Future<int> delete(colName) async {
    final db = await dbProvider.database;
    var response =
        await db.delete('system', where: 'key = ?', whereArgs: ['$colName']);
    return response;
  }

  refreshPermissionList() async {
    final db = await dbProvider.database;
    await db
        .delete('system', where: 'key = ?', whereArgs: ['user_permissions']);
    await Permissions().get();
  }

  //delete column from system table
  refresh() async {
    final db = await dbProvider.database;
    List colNames = [
      'business',
      'user_permissions',
      'active-subscription',
      'payment_methods',
      'payment_method',
      'location',
      'tax',
      'brand',
      'taxonomy',
      'sub_categories',
      'payment_accounts'
    ];
    await Contact().emptyContact();
    for (var element in colNames) {
      await db.delete('system', where: 'key = ?', whereArgs: ['$element']);
    }
    await SystemApi().store();
  }
}
