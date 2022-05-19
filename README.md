# Dart Aptos SDK

This package re-exports the [Dart Aptos API](https://github.com/banool/aptos_api_dart) and provides additional functionality to support its use, such as utilities for working with hex strings / addresses and functionality supporting Aptos accounts, particularly for working with keys / account addresses.

For example code demonstrating how to use this library, check out https://github.com/banool/aptos_sdk_dart/blob/main/test/full_library_test.dart. I have replicated almost exactly the test in the typescript SDK and confirmed that the end result is identical.

Note: This SDK is currently still incomplete compared to the [typescript SDK](https://github.com/aptos-labs/aptos-core/blob/main/ecosystem/typescript/sdk). For example, this doesn't offer a faucet client. Hopefully I'll have time to build it out further in the future.

This library does lock you in to using Dio, apologies. Unfortunately the dart-dio generator was much better than the standard HTTP one. Beyond that I could've just generated models, but I opted for ease of use.
