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

  test("test signing message", () {
    var aptosAccount = AptosAccount.fromPrivateKeyHexString(HexString.fromString(
        "0xc5338cd251c22daa8c9c9cc94f498cc8a5c7e1d2e75287a5dda91096fe64efa5de19e5d1880cac87d57484ce9ed2e84cf0f9599f12e7cc3a52e4e7657a763f2c"));
    expect(
      aptosAccount
          .signHexString(HexString.fromString("0xdeadbeef"))
          .withPrefix(),
      "0xb1bc150b03c7770e5f87490b3d4d216cebc1236885c375eb3ad8e9e846fe25b4f0077945a97c38f4626625fd26e72b0809083c4a0ee1ef8676532a57eab28208",
    );
  });
}
