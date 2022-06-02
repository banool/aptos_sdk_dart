import 'package:aptos_api_dart/aptos_api_dart.dart';
import 'package:aptos_sdk_dart/aptos_account.dart';
import 'package:dio/dio.dart';
import 'package:one_of/one_of.dart';

import 'hex_string.dart';

// For an explanation of MyClass vs $MyClass, please see this issue:
// https://github.com/OpenAPITools/openapi-generator/pull/12295
// In short, imagine a class X that participates in defining another class,
// e.g. class A implements X. This means that X must be abstract. To create
// a concrete instance of X, you want to use $X instead (there is nothing
// special about the $, this is just a naming convention).

Future<T> unwrapClientCall<T>(Future<Response<T>> clientCall,
    {bool throwOnNon200 = true}) async {
  Response<T> response;
  response = await clientCall;
  if (response.data == null) {
    throw "Empty response: ${response.statusCode}: ${response.statusMessage}";
  }
  if (throwOnNon200 &&
      response.statusCode != null &&
      (response.statusCode! < 200 || response.statusCode! > 299)) {
    throw "Non-200 response: ${response.statusCode}: ${response.statusMessage}";
  }
  return response.data as T; // Dart prefers this over !
}

class PendingTransactionResult {
  bool committed;
  Object? error;

  String? getErrorString() {
    if (error == null) {
      return null;
    }
    if (error is DioError) {
      var e = error as DioError;
      return "Type: ${e.type}\nMessage: ${e.message}\nResponse: ${e.response}\nError: ${e.error}";
    } else {
      return "$error";
    }
  }

  PendingTransactionResult(this.committed, this.error);
}

// This class provides some helpful wrappers on top of the functionality
// provided by the client held within (AptosApiDart). If you don't see a
// function offered here explicitly, you will likely find the function on
// `client` directly instead.
class AptosClientHelper {
  final AptosApiDart client;
  final bool ignoreErroneousErrorOnSuccess;

  factory AptosClientHelper.fromDio(Dio dio,
      {bool ignoreErroneousErrorOnSuccess = true}) {
    return AptosClientHelper(
        AptosApiDart(dio: dio), ignoreErroneousErrorOnSuccess);
  }

  factory AptosClientHelper.fromBaseUrl(String baseUrl,
      {bool ignoreErroneousErrorOnSuccess = true}) {
    return AptosClientHelper(
        AptosApiDart(basePathOverride: baseUrl), ignoreErroneousErrorOnSuccess);
  }

  AptosClientHelper(this.client, this.ignoreErroneousErrorOnSuccess);

  // This function gets the current sequence number of the account and then
  // builds a transaction using that value.
  Future<$UserTransactionRequestBuilder> generateTransaction(
    HexString sender,
    TransactionPayloadBuilder transactionPayloadBuilder, {
    int maxGasAmount = 1000,
    int gasUnitPrice = 1,
    String gasCurrencyCode = "XUS",
    int expirationFromNowSecs = 10,
  }) async {
    Account account = await unwrapClientCall(
        client.getAccountsApi().getAccount(address: sender.withPrefix()));
    return $UserTransactionRequestBuilder()
      ..sender = sender.withPrefix()
      ..sequenceNumber = account.sequenceNumber
      ..payload = transactionPayloadBuilder
      ..maxGasAmount = "$maxGasAmount"
      ..gasUnitPrice = "$gasUnitPrice"
      ..gasCurrencyCode = gasCurrencyCode
      ..expirationTimestampSecs =
          "${(DateTime.now().millisecondsSinceEpoch + expirationFromNowSecs * 1000) ~/ 1000}";
  }

  // Converts a transaction request produced by `generate_transaction` into a
  // properly signed transaction, which can then be submitted to the blockchain.
  Future<SubmitTransactionRequestBuilder> signTransaction(
    AptosAccount accountFrom,
    $UserTransactionRequestBuilder userTransactionRequest,
  ) async {
    // Build the request to create the signing message.
    UserTransactionRequest u = userTransactionRequest.build();
    UserCreateSigningMessageRequestBuilder userCreateSigningMessageRequest =
        UserCreateSigningMessageRequestBuilder()
          ..sender = u.sender
          ..sequenceNumber = u.sequenceNumber
          ..payload = u.payload.toBuilder()
          ..maxGasAmount = u.maxGasAmount
          ..gasUnitPrice = u.gasUnitPrice
          ..gasCurrencyCode = u.gasCurrencyCode
          ..expirationTimestampSecs = u.expirationTimestampSecs;

    // This call is where the error is coming from. It happens in the actual
    // call, not in unwrapClientCall, so it's an issue with the client /
    // endpoint code / my request.
    CreateSigningMessage200Response createSigningMessageResponse =
        await unwrapClientCall(client.getTransactionsApi().createSigningMessage(
            userCreateSigningMessageRequest:
                userCreateSigningMessageRequest.build()));

    HexString signatureHex = accountFrom.signHexString(
        HexString.fromString(createSigningMessageResponse.message));

    Ed25519SignatureBuilder ed25519signatureBuilder = (Ed25519SignatureBuilder()
      ..type = "ed25519_signature"
      ..publicKey = accountFrom.pubKey().withPrefix()
      ..signature = signatureHex.withPrefix());

    TransactionSignatureBuilder transactionSignatureBuilder =
        TransactionSignatureBuilder()
          ..oneOf = OneOf3<Ed25519Signature, MultiAgentSignature,
                  MultiEd25519Signature>(
              value: ed25519signatureBuilder.build(), typeIndex: 0);

    SubmitTransactionRequestBuilder submitTransactionRequestBuilder =
        (SubmitTransactionRequestBuilder()
          ..signature = transactionSignatureBuilder
          ..sender = userTransactionRequest.sender
          ..sequenceNumber = userTransactionRequest.sequenceNumber
          ..maxGasAmount = userTransactionRequest.maxGasAmount
          ..gasUnitPrice = userTransactionRequest.gasUnitPrice
          ..gasCurrencyCode = userTransactionRequest.gasCurrencyCode
          ..expirationTimestampSecs =
              userTransactionRequest.expirationTimestampSecs
          ..payload = userTransactionRequest.payload);

    return submitTransactionRequestBuilder;
  }

  // Waits for a transaction to move past pending state.
  // Returns true if the transaction moved past pending state, false if not.
  Future<PendingTransactionResult> waitForTransaction(String txnHashOrVersion,
      {int durationSecs = 10}) async {
    int count = 0;
    int sleepAmountSecs = 1;
    while (true) {
      try {
        await unwrapClientCall(client
            .getTransactionsApi()
            .getTransaction(txnHashOrVersion: txnHashOrVersion));
        return PendingTransactionResult(true, null);
      } catch (e) {
        // This is a temporary thing to handle the case where the client says
        // the call failed, but really it succeeded, and it's just that the API
        // returns a struct with an illegally empty field according to the
        // OpenAPI spec.
        if (e.toString().contains("mark \"handle\" with @nullable")) {
          return PendingTransactionResult(true, null);
        }
        await Future.delayed(Duration(seconds: sleepAmountSecs));
        count += 1;
        if (count == durationSecs) {
          return PendingTransactionResult(false, e);
        }
      }
    }
  }
}
