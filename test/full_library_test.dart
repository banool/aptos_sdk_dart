import 'package:aptos_api_dart/aptos_api_dart.dart';
import 'package:aptos_sdk_dart/aptos_account.dart';
import 'package:aptos_sdk_dart/hex_string.dart';
import "package:flutter_test/flutter_test.dart";

HexString privateKey = HexString.fromString(
    "0x257e96d2d763967d72d34d90502625c2d9644401aa409fa3f5e9d6cc59095f9b");

Uri fullnodeUri = Uri.parse("https://fullnode.devnet.aptoslabs.com");

HexString otherAddress = HexString.fromString(
    "0x52a8736b51ff3ccb3b90726fda2b4bab1429d2ebde2f60924a5d500995514c57");

void main() {
  test("client account resources test", () async {
    // TODO: Use faucet client to fund and create a new account instead.
    AptosApiDart client =
        AptosApiDart(basePathOverride: fullnodeUri.toString());

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    // Get resources.
    await client
        .getAccountsApi()
        .getAccountResources(address: account.address.noPrefix());
  });

  test("sign transaction test", () async {
    // TODO: Use faucet client to fund and create a new account instead.
    AptosApiDart client =
        AptosApiDart(basePathOverride: fullnodeUri.toString());

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    // Get resources.
    await client
        .getAccountsApi()
        .getAccountResources(address: account.address.noPrefix());
  });
}

/*
// TODO NOTE: I learned that the Dart OpenAPI generator doesn't support
// oneOf / allOf. This means something like TransactionPayloadBuilder
// doesn't support passing in only the fields necessary for one of the
// variants, it requires all of them. I played with just passing in dummy
// values, but the builder started becoming intractably large. I'm looking
// for a workaround now.
//
// Build a transaction request.
TransactionPayloadBuilder transactionPayloadBuilder =
    TransactionPayloadBuilder()
      ..type = "script_function_payload"
      ..function_ = "0x1::Coin::transfer"
      ..typeArguments = ListBuilder(["0x1::TestCoin::TestCoin"])
      ..arguments = ListBuilder(
          [otherAddress.withPrefix(), "100"].map((e) => JsonObject(e)));
SubmitTransactionRequest submitTransactionRequest =
    (SubmitTransactionRequestBuilder()
          ..sender = account.address.withPrefix()
          ..payload = transactionPayloadBuilder)
        .build();

// Submit the transaction.
await client
    .getTransactionsApi()
    .submitTransaction(submitTransactionRequest: submitTransactionRequest);
    
client.getTransactionsApi().createSigningMessage(userTransactionRequest: userTransactionRequest)

*/