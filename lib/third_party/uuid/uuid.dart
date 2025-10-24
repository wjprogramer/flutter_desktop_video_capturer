import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class MyUuid {
  MyUuid._();

  static String generate() {
    return _uuid.v4();
  }
}