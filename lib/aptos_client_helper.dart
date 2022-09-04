import 'package:aptos_api_dart/aptos_api_dart.dart';
import 'package:aptos_sdk_dart/aptos_account.dart';
import 'package:dio/dio.dart';
import 'package:one_of/one_of.dart';
import 'package:pinenacl/ed25519.dart';

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

  try {
    response = await clientCall;
  } catch (e) {
    if (e is DioError) {
      // Add the response data to the error message.
      var newError = DioError(
        error: "${e.message} ${e.response?.data}",
        requestOptions: e.requestOptions,
        response: e.response,
        type: e.type,
      );
      newError.stackTrace = e.stackTrace;
      throw newError;
    }
    rethrow;
  }
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

  PendingTransactionResult(this.committed, this.error);
}

// This class provides some helpful wrappers on top of the functionality
// provided by the client held within (AptosApiDart). If you don't see a
// function offered here explicitly, you will likely find the function on
// `client` directly instead.
class AptosClientHelper {
  final AptosApiDart client;

  factory AptosClientHelper.fromDio(Dio dio) {
    return AptosClientHelper(AptosApiDart(dio: dio));
  }

  factory AptosClientHelper.fromBaseUrl(String baseUrl) {
    return AptosClientHelper(AptosApiDart(
      basePathOverride: fixNodeUrl(baseUrl),
    ));
  }

  AptosClientHelper(this.client);

  // This function gets the current sequence number of the account and then
  // builds a transaction using that value.
  Future<SubmitTransactionRequestBuilder> generateTransaction(
    HexString sender,
    TransactionPayloadBuilder transactionPayloadBuilder, {
    int maxGasAmount = 1000,
    int gasUnitPrice = 1,
    String gasCurrencyCode = "XUS",
    int expirationFromNowSecs = 10,
  }) async {
    AccountData accountData = await unwrapClientCall(
        client.getAccountsApi().getAccount(address: sender.withPrefix()));
    // Include a fake signature.
    TransactionSignatureEd25519SignatureBuilder fakeEd25519SignatureBuilder =
        TransactionSignatureEd25519SignatureBuilder()
          ..type = "ed25519_signature"
          ..publicKey = HexString.fromBytes(
              Uint8List.fromList(List<int>.generate(32, (_) => 0))).noPrefix()
          ..signature = HexString.fromBytes(
              Uint8List.fromList(List<int>.generate(32, (_) => 0))).noPrefix();
    TransactionSignatureBuilder fakeSignatureBuilder =
        TransactionSignatureBuilder()
          ..oneOf = OneOf1(value: fakeEd25519SignatureBuilder.build());
    return SubmitTransactionRequestBuilder()
      ..sender = sender.withPrefix()
      ..signature = fakeSignatureBuilder
      ..sequenceNumber = accountData.sequenceNumber
      ..payload = transactionPayloadBuilder
      ..maxGasAmount = "$maxGasAmount"
      ..gasUnitPrice = "$gasUnitPrice"
      ..expirationTimestampSecs =
          "${(DateTime.now().millisecondsSinceEpoch + expirationFromNowSecs * 1000) ~/ 1000}";
  }

  // Converts a transaction request produced by `generateTransaction` into a
  // properly signed transaction, which can then be submitted to the blockchain.
  Future<SubmitTransactionRequestBuilder> encodeSubmission(
    AptosAccount accountFrom,
    SubmitTransactionRequestBuilder submitTransactionRequest,
  ) async {
    // Build the request to create the signing message.
    EncodeSubmissionRequestBuilder encodeSubmissionRequestBuilder =
        EncodeSubmissionRequestBuilder()
          ..sender = submitTransactionRequest.sender
          ..sequenceNumber = submitTransactionRequest.sequenceNumber
          ..payload = submitTransactionRequest.payload
          ..maxGasAmount = submitTransactionRequest.maxGasAmount
          ..gasUnitPrice = submitTransactionRequest.gasUnitPrice
          ..expirationTimestampSecs =
              submitTransactionRequest.expirationTimestampSecs;

    // This call is where the error is coming from. It happens in the actual
    // call, not in unwrapClientCall, so it's an issue with the client /
    // endpoint code / my request.
    String encodeSubmissionResponse = await unwrapClientCall(client
        .getTransactionsApi()
        .encodeSubmission(
            encodeSubmissionRequest: encodeSubmissionRequestBuilder.build()));

    HexString signatureHex = accountFrom
        .signHexString(HexString.fromString(encodeSubmissionResponse));

    TransactionSignatureEd25519SignatureBuilder ed25519signatureBuilder =
        (TransactionSignatureEd25519SignatureBuilder()
          ..type = "ed25519_signature"
          ..publicKey = accountFrom.pubKey().withPrefix()
          ..signature = signatureHex.withPrefix());

    TransactionSignatureBuilder transactionSignatureBuilder =
        (TransactionSignatureBuilder()
          ..oneOf = OneOf1(value: ed25519signatureBuilder.build()));

    SubmitTransactionRequestBuilder submitTransactionRequestBuilder =
        (SubmitTransactionRequestBuilder()
          ..signature = transactionSignatureBuilder
          ..sender = submitTransactionRequest.sender
          ..sequenceNumber = submitTransactionRequest.sequenceNumber
          ..maxGasAmount = submitTransactionRequest.maxGasAmount
          ..gasUnitPrice = submitTransactionRequest.gasUnitPrice
          ..expirationTimestampSecs =
              submitTransactionRequest.expirationTimestampSecs
          ..payload = submitTransactionRequest.payload);

    return submitTransactionRequestBuilder;
  }

  // Waits for a transaction to move past pending state.
  // Returns true if the transaction moved past pending state, false if not.
  Future<PendingTransactionResult> waitForTransaction(String hash,
      {int durationSecs = 10}) async {
    int count = 0;
    int sleepAmountSecs = 1;
    while (true) {
      try {
        await unwrapClientCall(
            client.getTransactionsApi().getTransactionByHash(txnHash: hash));
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

  // This is a more opinionated helper that aims to make it super simple to
  // submit transactions. Given your payload, it will handle generating the
  // transaction, submitting it, waiting for it, and returning the result in
  // a more helpful format, the TransactionResult.
  //
  // Example usage:
  // ```
  // var entryFunctionPayloadBuilder = $EntryFunctionPayloadBuilder()
  //   ..type = "entry_function_payload"
  //   ..function_ = "0xabcabcbacbacbcbaabcbcbc323443::MyModule::my_func"
  //   ..typeArguments = ListBuilder([])
  //   ..arguments = ListBuilder([]);
  // var payload = OneOf1<ScriptFunctionPayload>(value: scriptFunctionPayloadBuilder.build());
  // var transactionResult = await signBuildSubmitWait(payload, aptosAccount);
  // ```
  //
  // Make sure to include the type parameter in OneOf or the (de)serialization
  // will fail.
  Future<FullTransactionResult> buildSignSubmitWait(
      TransactionPayloadBuilder transactionPayloadBuilder,
      AptosAccount aptosAccount) async {
    SubmitTransactionRequestBuilder? submitTransactionRequestBuilder;
    bool committed = false;
    String? errorString;
    String failedAt = "generatedTransaction";

    try {
      submitTransactionRequestBuilder = await generateTransaction(
          aptosAccount.address, transactionPayloadBuilder);

      failedAt = "signTransaction";
      submitTransactionRequestBuilder =
          await encodeSubmission(aptosAccount, submitTransactionRequestBuilder);

      failedAt = "submitTransaction";
      PendingTransaction pendingTransaction = await unwrapClientCall(client
          .getTransactionsApi()
          .submitTransaction(
              submitTransactionRequest:
                  submitTransactionRequestBuilder.build()));

      failedAt = "waitForTransaction";
      PendingTransactionResult pendingTransactionResult =
          await waitForTransaction(pendingTransaction.hash);

      committed = pendingTransactionResult.committed;
      errorString = getErrorString(pendingTransactionResult.error);
    } catch (e) {
      errorString = getErrorString(e);
    }

    return FullTransactionResult(committed,
        submitTransactionRequestBuilder?.build(), errorString, failedAt);
  }
}

class FullTransactionResult {
  // Note, this implies exactly what it says. If committed is false, that does
  // not mean it failed, it just might not have been committed yet / we failed
  // to check that it was committed.
  bool committed;

  // The transaction we submitted.
  SubmitTransactionRequest? transaction;

  // Any error from the process.
  String? errorString;

  String? failedAt;

  FullTransactionResult(
      this.committed, this.transaction, this.errorString, this.failedAt);

  @override
  String toString() {
    return "Committed: $committed, Transaction: $transaction, Error: $errorString, Failed at: $failedAt";
  }
}

String? getErrorString(Object? error) {
  if (error == null) {
    return null;
  }
  if (error is DioError) {
    return "Type: ${error.type}\n"
        "Message: ${error.message}\n"
        "Response: ${error.response}\n"
        "Error: ${error.error}";
  }
  return "$error";
}

const String defaultVersionPathBase = "/v1";

// Take a node URL and if it is missing a version suffix, add it.
String fixNodeUrl(String nodeUrl) {
  String out = nodeUrl;
  if (out.endsWith("/")) {
    out = out.substring(0, out.length - 1);
  }
  if (!out.endsWith(defaultVersionPathBase)) {
    out = "$out$defaultVersionPathBase";
  }
  return out;
}
