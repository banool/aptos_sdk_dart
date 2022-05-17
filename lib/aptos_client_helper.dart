import 'package:aptos_api_dart/aptos_api_dart.dart';
import 'package:aptos_sdk_dart/aptos_account.dart';
import 'package:dio/dio.dart';

import 'hex_string.dart';

// This class provides some helpful wrappers on top of the functionality
// provided by the client held within (AptosApiDart). If you don't see a
// function offered here explicitly, you will likely find the function on
// client instead.
class AptosClientHelper {
  AptosApiDart client;

  factory AptosClientHelper.fromDio(Dio dio) {
    return AptosClientHelper(AptosApiDart(dio: dio));
  }

  factory AptosClientHelper.fromBaseUrl(String baseUrl) {
    return AptosClientHelper(AptosApiDart(basePathOverride: baseUrl));
  }

  AptosClientHelper(this.client);

  static Future<T> unwrapClientCall<T>(Future<Response<T>> clientCall,
      {bool throwOnNon200 = true}) async {
    Response<T> response = await clientCall;
    if (response.data == null) {
      throw "Empty response: ${response.statusCode}: ${response.statusMessage}";
    }
    if (throwOnNon200 && response.statusCode != 200) {
      throw "Non-200 response: ${response.statusCode}: ${response.statusMessage}";
    }
    return response.data!;
  }

  Future<UserTransactionRequestBuilder> generateTransaction(
    HexString sender,
    TransactionPayloadBuilder transactionPayloadBuilder, {
    int maxGasAmount = 10,
    int gasUnitPrice = 1,
    String gasCurrencyCode = "XUS",
    int expirationFromNowSecs = 10,
  }) async {
    Account account = await unwrapClientCall(
        client.getAccountsApi().getAccount(address: sender.withPrefix()));
    return UserTransactionRequestBuilder()
      ..sender = sender.withPrefix()
      ..sequenceNumber = account.sequenceNumber
      ..payload = transactionPayloadBuilder
      ..maxGasAmount = "$maxGasAmount"
      ..gasUnitPrice = "$gasUnitPrice"
      ..gasCurrencyCode = gasCurrencyCode
      ..expirationTimestampSecs =
          "${(DateTime.now().millisecondsSinceEpoch ~/ 1000) + 10}";
  }

  // Converts a transaction request produced by `generate_transaction` into a
  // properly signed transaction, which can then be submitted to the blockchain.
  Future<SubmitTransactionRequestBuilder> signTransaction(
    AptosAccount accountFrom,
    UserTransactionRequestBuilder userTransactionRequest,
  ) async {
    CreateSigningMessage200Response createSigningMessageResponse =
        await unwrapClientCall(client.getTransactionsApi().createSigningMessage(
            userTransactionRequest: userTransactionRequest.build()));

    HexString signatureHex = accountFrom.signHexString(
        HexString.fromString(createSigningMessageResponse.message));

    TransactionSignatureBuilder transactionSignatureBuilder =
        (TransactionSignatureBuilder()
          ..type = "ed25519_signature"
          ..publicKey = accountFrom.pubKey().withPrefix()
          ..signature = signatureHex.withPrefix());

    SubmitTransactionRequestBuilder submitTransactionRequestBuilder =
        (SubmitTransactionRequestBuilder()
          ..signature = transactionSignatureBuilder
          ..sender = userTransactionRequest.sender
          ..sequenceNumber = userTransactionRequest.sequenceNumber
          ..maxGasAmount = userTransactionRequest.maxGasAmount
          ..gasUnitPrice = userTransactionRequest.maxGasAmount
          ..gasCurrencyCode = userTransactionRequest.gasCurrencyCode
          ..expirationTimestampSecs =
              userTransactionRequest.expirationTimestampSecs
          ..payload = userTransactionRequest.payload);

    return submitTransactionRequestBuilder;
  }

  // Waits for a transaction to move past pending state.
  // Returns true if the transaction moved past pending state, false if not.
  Future<bool> waitForTransaction(String txnHashOrVersion,
      {int durationSecs = 10}) async {
    int count = 0;
    int sleepAmountSecs = 1;
    while (count < durationSecs) {
      try {
        await unwrapClientCall(client
            .getTransactionsApi()
            .getTransaction(txnHashOrVersion: txnHashOrVersion));
        return true;
      } catch (e) {
        await Future.delayed(Duration(seconds: sleepAmountSecs));
        count += 1;
      }
    }
    return false;
  }
}
