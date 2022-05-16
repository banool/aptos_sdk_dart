import 'package:flutter_test/flutter_test.dart';
import 'package:aptos_sdk_dart/hex_string.dart';

const withoutPrefix = "007711b4d0";
const withPrefix = "0x$withoutPrefix";

void validate(HexString hexString) {
  expect(hexString.hex(), withPrefix);
  expect(hexString.toString(), withPrefix);
  expect("$hexString", withPrefix);
  expect(hexString.noPrefix(), withoutPrefix);
}

void main() {
  test("from/to List<int>", () {
    var hs = HexString.fromString(withoutPrefix);
    expect(HexString.fromBytes(hs.toBytes()).hex(), withPrefix);
  });

  test("accepts input without prefix", () {
    var hs = HexString.fromString(withoutPrefix);
    validate(hs);
  });

  test("accepts input with prefix", () {
    var hs = HexString.fromString(withPrefix);
    validate(hs);
  });
}
