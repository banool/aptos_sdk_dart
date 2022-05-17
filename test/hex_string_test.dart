import 'package:flutter_test/flutter_test.dart';
import 'package:aptos_sdk_dart/hex_string.dart';

const withoutPrefix = "007711b4d0";
const withPrefix = "0x$withoutPrefix";

void validate(HexString hexString) {
  expect(hexString.withPrefix(), withPrefix);
  expect(hexString.noPrefix(), withoutPrefix);
}

void main() {
  test("test from / to Uint8List", () {
    var hs = HexString.fromString(withoutPrefix);
    expect(HexString.fromBytes(hs.toBytes()).withPrefix(), withPrefix);
  });

  test("test input without prefix", () {
    var hs = HexString.fromString(withoutPrefix);
    validate(hs);
  });

  test("test input with prefix", () {
    var hs = HexString.fromString(withPrefix);
    validate(hs);
  });
}
