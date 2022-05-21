import 'package:aptos_api_dart/aptos_api_dart.dart';
import 'package:aptos_sdk_dart/aptos_account.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:built_collection/built_collection.dart';
import 'package:built_value/json_object.dart';
import 'package:curl_logger_dio_interceptor/curl_logger_dio_interceptor.dart';
import 'package:dio/dio.dart';
import "package:flutter_test/flutter_test.dart";
import 'package:one_of/one_of.dart';

HexString privateKey = HexString.fromString(
    "0x257e96d2d763967d72d34d90502625c2d9644401aa409fa3f5e9d6cc59095f9b");

Uri fullnodeUri = Uri.parse("https://fullnode.devnet.aptoslabs.com");

HexString otherAddress = HexString.fromString(
    "0x52a8736b51ff3ccb3b90726fda2b4bab1429d2ebde2f60924a5d500995514c57");

// TODO: Use faucet client to fund and create a new account instead.
// TODO: Find a way to only run these on demand, like integration tests.
void main() {
  test("test get resources", () async {
    AptosClientHelper aptosClientHelper =
        AptosClientHelper.fromBaseUrl(fullnodeUri.toString());

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    // Confirming that getting resources works.
    await unwrapClientCall(aptosClientHelper.client
        .getAccountsApi()
        .getAccountResources(address: account.address.noPrefix()));
  }, tags: "integration");

  test("test full transaction flow", () async {
    Dio dio = Dio(BaseOptions(
      baseUrl: fullnodeUri.toString(),
    ));

    // This can be very helpful with debugging.
    // dio.interceptors.add(CurlLoggerDioInterceptor(printOnSuccess: true));

    AptosClientHelper aptosClientHelper = AptosClientHelper.fromDio(dio);

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    // Build a script function payload that transfers coin.
    ScriptFunctionPayloadBuilder scriptFunctionPayloadBuilder =
        ScriptFunctionPayloadBuilder()
          ..type = "script_function_payload"
          ..function_ = "0x1::Coin::transfer"
          ..typeArguments = ListBuilder(["0x1::TestCoin::TestCoin"])
          ..arguments = ListBuilder([
            StringJsonObject(otherAddress.withPrefix()),
            StringJsonObject("717")
          ]);

    // Build that into a transaction payload.
    // You can also just use OneOf1(value: scriptFunctionPayloadBuilder.build())
    TransactionPayloadBuilder transactionPayloadBuilder =
        TransactionPayloadBuilder()
          ..oneOf = OneOf4<ModuleBundlePayload, ScriptFunctionPayload,
                  ScriptPayload, WriteSetPayload>(
              value: scriptFunctionPayloadBuilder.build(), typeIndex: 1);

    // Build a transasction request. This includes a call to determine the
    // current sequence number so we can build that transasction.
    $UserTransactionRequestBuilder userTransactionBuilder =
        await aptosClientHelper.generateTransaction(
            account.address, transactionPayloadBuilder);

    // Convert the transaction into the appropriate format and then sign it.
    SubmitTransactionRequestBuilder submitTransactionRequestBuilder =
        await aptosClientHelper.signTransaction(
            account, userTransactionBuilder);

    // Finally submit the transaction.
    PendingTransaction pendingTransaction = await unwrapClientCall(
        aptosClientHelper.client.getTransactionsApi().submitTransaction(
            submitTransactionRequest: submitTransactionRequestBuilder.build()));

    // Wait for the transaction to be committed.
    PendingTransactionResult pendingTransactionResult =
        await aptosClientHelper.waitForTransaction(pendingTransaction.hash);

    expect(pendingTransactionResult.committed, true);
  }, tags: "integration");
}
