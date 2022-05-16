import 'package:aptos_sdk_dart/aptos_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aptos_sdk_dart/hex_string.dart';

String privateKey =
    "0x257e96d2d763967d72d34d90502625c2d9644401aa409fa3f5e9d6cc59095f9b";
String expectedPublicKey =
    "0xa7a74924e0bb0f7dcd178e71ce388be56c72f5591d1b90481014aa0567fbdd82";
String expectedAccount =
    "c40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd";

void main() {
  test("test values are as expected upon account creation", () {
    var aptosAccount =
        AptosAccount.fromPrivateKeyHexString(HexString.fromString(privateKey));
    expect(aptosAccount.pubKey(), HexString.fromString(expectedPublicKey));
    expect(aptosAccount.address, HexString.fromString(expectedAccount));
  });
}
