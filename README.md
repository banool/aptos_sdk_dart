# Dart Aptos SDK

This package re-exports the [Dart Aptos API](https://github.com/banool/aptos_api_dart) and provides additional functionality to support its use, such as utilities for working with hex strings / addresses and functionality supporting Aptos accounts, particularly for working with keys / account addresses.

**Warning**: Due to [deficiencies in the OpenAPI generator for Dart](https://stackoverflow.com/questions/72266600/how-to-use-oneof-with-openapi-generator-for-dart), any endpoint in the [OpenAPI spec](https://github.com/aptos-labs/aptos-core/blob/main/api/doc/openapi.yaml) that recursively depends on something with a OneOf / AllOf is not really usable. See more in the linked StackOverflow question. The only workaround right now is to write your own code for submitting to that endpoint. If you want to do so, consider writing a "fixer" for the [Dart Aptos API](https://github.com/banool/aptos_api_dart) that makes the change directly to that API post-codegen.

Ignoring the above issues, this SDK is currently still incomplete compared to the [typescript SDK](https://github.com/aptos-labs/aptos-core/blob/main/ecosystem/typescript/sdk). For example, this doesn't offer a faucet client. Hopefully I'll have time to build it out further in the future.

This library does lock you in to using Dio, apologies. Unfortunately the dart-dio generator was much better than the standard HTTP one. Beyond that I could've just generated models, but I opted for ease of use.