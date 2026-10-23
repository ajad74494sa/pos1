// import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:krpos/config.dart';

import '../helpers/AppTheme.dart';
import '../helpers/SizeConfig.dart';
import 'database.dart';

class FollowUpModel {
  var createFollowUpMap;
  var followUpMap;
  static int themeType = 1;
  ThemeData themeData = AppTheme.getThemeFromThemeMode(themeType);
  CustomAppTheme customAppTheme = AppTheme.getCustomAppTheme(themeType);

  followUpForm(customerDetail) {
    followUpMap = {
      'id': customerDetail['contact_id'],
      'followUpId': customerDetail['id'],
      'name': '${customerDetail['customer']['name']}',
      'mobile': '${customerDetail['customer']['mobile']}',
      'landline': '${customerDetail['customer']['landline']}',
      'alternate_number': '${customerDetail['customer']['alternate_number']}',
      'title': '${customerDetail['title']}',
      'status': '${customerDetail['status']}',
      if (customerDetail['followup_category'] != null)
        'followup_category': {
          'id': int.parse(customerDetail['followup_category']['id'].toString()),
          'name': customerDetail['followup_category']['name']
        },
      'schedule_type': '${customerDetail['schedule_type']}',
      'start_datetime': '${customerDetail['start_datetime']}',
      'end_datetime': '${customerDetail['end_datetime']}',
      'description': customerDetail['description'] ?? ''
    };
    return followUpMap;
  }

  submitFollowUp(
      {id,
      contactId,
      title,
      scheduleType,
      status,
      followUpCategoryId,
      startDate,
      endDate,
      description,
      duration}) {
    createFollowUpMap = {
      'title': title,
      'contact_id': contactId,
      'schedule_type': scheduleType,
      'user_id': [Config.userId],
      'status': status,
      'followup_category_id': followUpCategoryId,
      'start_datetime': '$startDate',
      'end_datetime': '$endDate',
      'description': '$description',
      'followup_additional_info': (duration != null && scheduleType == 'call')
          ? {'call duration': '$duration'}
          : ''
    };
    return createFollowUpMap;
  }

  // Future<CallLogEntry> getLogs(number) async {int from = DateTime.now().subtract(Duration(hours: 8)).millisecondsSinceEpoch;String numberQuery = '%${number.replaceAll(RegExp("[^0-9]"), "")}';Iterable<CallLogEntry> entries = await CallLog.query(number: numberQuery, dateFrom: from);return (entries.isNotEmpty) ? entries.first : null;}

  //calling widget
  Widget callCustomer() {
    return Container(
      margin: EdgeInsets.only(left: MySize.size8!),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(MySize.size8!)),
        boxShadow: [
          BoxShadow(
            color: themeData.cardTheme.shadowColor!.withAlpha(48),
            blurRadius: 3,
            offset: Offset(0, 1),
          )
        ],
      ),
      padding: EdgeInsets.all(MySize.size4!),
      child: Icon(
        Icons.call,
        color: themeData.colorScheme.surface,
      ),
    );
  }
}

class Contact {
  late DbProvider dbProvider;

  Contact() {
    dbProvider = new DbProvider();
  }

  Map<String, dynamic> contactModel(element) {
    //contact model
    Map<String, dynamic> customer = {
      'id': element['id'],
      'name': element['supplier_business_name'] ?? element['name'],
      'city': element['city'],
      'state': element['state'],
      'country': element['country'],
      'address_line_1': element['address_line_1'],
      'address_line_2': element['address_line_2'],
      'zip_code': element['zip_code'],
      'mobile': element['mobile'],
      'email': element['email'],
      'contact_id': element['contact_id'],
      'dob': element['dob'],
      'landline': element['landline'],
      'alternate_number': element['alternate_number'],
      'credit_limit': double.tryParse((element['credit_limit'] ?? 0.0).toString()) ?? 0.0,
      'total_due': double.tryParse((element['total_due'] ?? element['sell_due'] ?? 0.0).toString()) ?? 0.0,
      'custom_field1': (element['custom_field1'] ?? element['nfc_card_id'] ?? '').toString(),
      'nfc_card_id': (element['custom_field1'] ?? element['nfc_card_id'] ?? '').toString(),
      'advance_balance': double.tryParse((element['advance_balance'] ?? element['balance'] ?? 0.0).toString()) ?? 0.0,
    };
    return customer;
  }

  //save contact
  insertContact(customer) async {
    final db = await dbProvider.database;
    var response = await db.insert('contact', customer,
        conflictAlgorithm: ConflictAlgorithm.replace);
    return response;
  }

  //save multiple contacts in batch
  insertContactsBatch(List<Map<String, dynamic>> customers) async {
    final db = await dbProvider.database;
    Batch batch = db.batch();
    for (var customer in customers) {
      batch.insert('contact', customer,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  //get customer details by id
  getCustomerDetailById(id) async {
    final db = await dbProvider.database;
    List response =
        await db.query('contact', where: 'id = ?', whereArgs: ['$id']);
    var customerDetail = (response.length > 0) ? response[0] : null;
    return customerDetail;
  }

  //get customer detail by NFC Card UID
  Future<Map<String, dynamic>?> getCustomerByNfcCard(String cardUid) async {
    final db = await dbProvider.database;
    try {
      List response = await db.query(
        'contact',
        where: 'custom_field1 = ? OR nfc_card_id = ?',
        whereArgs: [cardUid, cardUid],
      );
      if (response.isNotEmpty) {
        return Map<String, dynamic>.from(response.first);
      }
    } catch (e) {
      try {
        List response = await db.query(
          'contact',
          where: 'custom_field1 = ?',
          whereArgs: [cardUid],
        );
        if (response.isNotEmpty) {
          return Map<String, dynamic>.from(response.first);
        }
      } catch (_) {
        List response = await db.query(
          'contact',
          where: 'nfc_card_id = ?',
          whereArgs: [cardUid],
        );
        if (response.isNotEmpty) {
          return Map<String, dynamic>.from(response.first);
        }
      }
    }
    return null;
  }

  //update NFC card UID for customer
  Future<int> updateNfcCardId(int customerId, String cardUid) async {
    final db = await dbProvider.database;
    try {
      return await db.update(
        'contact',
        {'custom_field1': cardUid, 'nfc_card_id': cardUid},
        where: 'id = ?',
        whereArgs: [customerId],
      );
    } catch (e) {
      try {
        return await db.update(
          'contact',
          {'custom_field1': cardUid},
          where: 'id = ?',
          whereArgs: [customerId],
        );
      } catch (_) {
        return await db.update(
          'contact',
          {'nfc_card_id': cardUid},
          where: 'id = ?',
          whereArgs: [customerId],
        );
      }
    }
  }

  // Update advance balance locally in contact table
  Future<int> updateAdvanceBalanceLocally(int customerId, double amount) async {
    final db = await dbProvider.database;
    try {
      return await db.rawUpdate(
        'UPDATE contact SET advance_balance = advance_balance + ? WHERE id = ? OR contact_id = ?',
        [amount, customerId, customerId],
      );
    } catch (e) {
      print("Error updating advance_balance locally: $e");
      return 0;
    }
  }

  //get customer name by contact_id
  Future<List<Map<String, dynamic>>> get({bool? all}) async {
    final db = await dbProvider.database;
    if (all == true) {
      List<Map<String, dynamic>> customers = await db.query('contact');
      return customers;
    } else {
      List<Map<String, dynamic>> customers = await db.query('contact',
          columns: ['id', 'name', 'mobile', 'contact_id', 'credit_limit', 'total_due', 'custom_field1', 'nfc_card_id', 'advance_balance'],
          orderBy: 'name ASC');
      return customers;
    }
  }

  //empty contact table
  emptyContact() async {
    final db = await dbProvider.database;
    var response = await db.delete('contact');
    return response;
  }
}
