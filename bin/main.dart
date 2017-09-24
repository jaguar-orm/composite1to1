library one_to_one;

import 'dart:io';
import 'dart:async';
import 'package:jaguar_query/jaguar_query.dart';
import 'package:jaguar_orm/jaguar_orm.dart';
import 'package:jaguar_orm/src/relations/relations.dart';
import 'package:jaguar_query_postgresql/jaguar_query_postgresql.dart';

part 'main.g.dart';

class User {
  @PrimaryKey()
  String id;

  @PrimaryKey()
  int id1;

  String name;

  @HasOne(AddressBean)
  Address address;

  static const String tableName = '_user';

  String toString() => "User($id, $id1, $name, $address)";
}

class Address {
  @PrimaryKey()
  String id;

  @BelongsTo(UserBean)
  String userid;

  @BelongsTo(UserBean, refCol: 'id1')
  int userid1;

  String street;

  static String tableName = 'address';

  String toString() => "Post($id, $userid, $street)";
}

@GenBean()
class UserBean extends Bean<User> with _UserBean {
  UserBean(Adapter adapter)
      : addressBean = new AddressBean(adapter),
        super(adapter);

  final AddressBean addressBean;

  Future createTable() {
    final st = Sql
        .create(tableName)
        .addStr('id', primary: true, length: 50)
        .addInt('id1', primary: true)
        .addStr('name', length: 50);
    return execCreateTable(st);
  }
}

@GenBean()
class AddressBean extends Bean<Address> with _AddressBean {
  AddressBean(Adapter adapter) : super(adapter);

  Future createTable() {
    final st = Sql
        .create(tableName)
        .addStr('id', primary: true, length: 50)
        .addStr('street', length: 150)
        .addStr('userid', length: 50, foreignTable: '_user', foreignCol: 'id')
        .addInt('userid1', foreignTable: '_user', foreignCol: 'id1');
    return execCreateTable(st);
  }
}

/// The adapter
PgAdapter _adapter =
    new PgAdapter('postgres://postgres:dart_jaguar@localhost/example');

main() async {
  // Connect to database
  await _adapter.connect();

  // Create beans
  final userBean = new UserBean(_adapter);
  final addressBean = new AddressBean(_adapter);

  // Drop old tables
  await addressBean.drop();
  await userBean.drop();

  // Create new tables
  await userBean.createTable();
  await addressBean.createTable();

  // Cascaded One-To-One insert
  {
    final user = new User()
      ..id = '1'
      ..id1 = 1
      ..name = 'Teja'
      ..address = (new Address()
        ..id = '1'
        ..street = 'Stockholm');
    await userBean.insert(user, cascade: true);
  }

  // Fetch One-To-One preloaded
  {
    final user = await userBean.find('1', 1, preload: true);
    print(user);
  }

  // Manual One-To-One insert
  {
    User user = new User()
      ..id = '2'
      ..id1 = 2
      ..name = 'Kleak';
    await userBean.insert(user, cascade: true);

    user = await userBean.find('2', 2);

    final address = new Address()
      ..id = '2'
      ..street = 'Stockholm';
    addressBean.associateUser(address, user);
    await addressBean.insert(address);
  }

  // Manual One-To-One preload
  {
    final user = await userBean.find('2', 2);
    print(user);
    user.address = await addressBean.findByUser(user.id, user.id1);
    print(user);
  }

  // Preload many
  {
    final users = await userBean.getAll();
    print(users);
    await userBean.preloadAll(users);
    print(users);
  }

  // Cascaded One-To-One update
  {
    User user = await userBean.find('1', 1, preload: true);
    user.name = 'Teja Hackborn';
    user.address.street = 'Stockholm, Sweden';
    await userBean.update(user, cascade: true);
  }

  // Fetch One-To-One relationship preloaded
  {
    final user = await userBean.find('1', 1, preload: true);
    print(user);
  }

  // Cascaded removal of One-To-One relation
  await userBean.remove('1', 1, true);

  // Remove addresses belonging to a User
  await addressBean.removeByUser('2', 2);

  exit(0);
}
