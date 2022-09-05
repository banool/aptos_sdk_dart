import 'package:aptos_api_dart/aptos_api_dart.dart';
import 'package:aptos_sdk_dart/aptos_account.dart';
import 'package:aptos_sdk_dart/aptos_client_helper.dart';
import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:built_value/json_object.dart';
import 'package:dio/dio.dart';
import "package:flutter_test/flutter_test.dart";

// To run these tests, the below account must exist.
//
// First, run a local testnet with a faucet like this:
// cargo run -p aptos -- node run-local-testnet --with-faucet --faucet-port 8081
//
// Next, create the two testing accounts:
// aptos account fund-with-faucet --account <account1> --url http://localhost:8080/v1 --faucet-url http://localhost:8081
// aptos account fund-with-faucet --account <account2> --url http://localhost:8080/v1 --faucet-url http://localhost:8081
//
// Now you should be good to run the tests.

HexString account1 = HexString.fromString(
    "0xc40f1c9b9fdc204cf77f68c9bb7029b0abbe8ad9e5561f7794964076a4fbdcfd");
HexString account2 = HexString.fromString(
    "0x52a8736b51ff3ccb3b90726fda2b4bab1429d2ebde2f60924a5d500995514c57");

// Private key for account1.
HexString privateKey = HexString.fromString(
    "0x257e96d2d763967d72d34d90502625c2d9644401aa409fa3f5e9d6cc59095f9b");

//Uri fullnodeUri = Uri.parse("http://localhost:8080/v1");
Uri fullnodeUri = Uri.parse("http://fullnode.devnet.aptoslabs.com/v1");

// TODO: Use faucet client to fund and create a new account instead.
// TODO: Find a way to only run these on demand, like integration tests.
void main() {
  test("test get resources", () async {
    AptosClientHelper aptosClientHelper = getTestAptosClient();

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    // Confirming that getting resources works.
    await unwrapClientCall(aptosClientHelper.client
        .getAccountsApi()
        .getAccountResources(address: account.address.noPrefix()));
  }, tags: "integration");

  test("test full transaction flow", () async {
    AptosClientHelper aptosClientHelper = getTestAptosClient();

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    // Build an entry function payload that transfers coin.
    TransactionPayloadBuilder transactionPayloadBuilder =
        getSampleTransactionPayloadBuilder();

    // Build a transasction request. This includes a call to determine the
    // current sequence number so we can build that transasction.
    SubmitTransactionRequestBuilder submitTransactionRequestBuilder =
        await aptosClientHelper.generateTransaction(
            account.address, transactionPayloadBuilder);

    // Convert the transaction into the appropriate format and then sign it.
    submitTransactionRequestBuilder = await aptosClientHelper.encodeSubmission(
        account, submitTransactionRequestBuilder);

    // Finally submit the transaction.
    PendingTransaction pendingTransaction = await unwrapClientCall(
        aptosClientHelper.client.getTransactionsApi().submitTransaction(
            submitTransactionRequest: submitTransactionRequestBuilder.build()));

    // Wait for the transaction to be committed.
    PendingTransactionResult pendingTransactionResult =
        await aptosClientHelper.waitForTransaction(pendingTransaction.hash);

    expect(pendingTransactionResult.committed, true);
  }, tags: "integration");

  test("test signBuildSubmitWait", () async {
    AptosClientHelper aptosClientHelper = getTestAptosClient();

    AptosAccount account = AptosAccount.fromPrivateKeyHexString(privateKey);

    // Get a sample transaction payload.
    TransactionPayloadBuilder transactionPayloadBuilder =
        getSampleTransactionPayloadBuilder();

    FullTransactionResult transactionResult = await aptosClientHelper
        .buildSignSubmitWait(transactionPayloadBuilder, account);

    // print(transactionResult);

    expect(transactionResult.committed, true);
  }, tags: "integration");
}

// Note: See how this doesn't use the AllOf version or any version of
// EntryFunctionPayloadBuilder, with or without a $ or _, that's intentional
TransactionPayloadBuilder getSampleTransactionPayloadBuilder() {
  return AptosClientHelper.buildPayload(
      "0x1::coin::transfer",
      ["0x1::aptos_coin::AptosCoin"],
      [StringJsonObject(account2.withPrefix()), StringJsonObject("717")]);
}

AptosClientHelper getTestAptosClient() {
  Dio dio = Dio(BaseOptions(
    baseUrl: fullnodeUri.toString(),
  ));

  // This can be very helpful with debugging.
  // dio.interceptors.add(CurlLoggerDioInterceptor(logPrint: print));

  AptosClientHelper aptosClientHelper = AptosClientHelper.fromDio(dio);

  return aptosClientHelper;
}
