import 'package:aptos_sdk_dart/hex_string.dart';
import 'package:pinenacl/ed25519.dart';
import 'package:sha3/sha3.dart';

class AptosAccount {
  SigningKey _signingKey;
  HexString address;
  HexString authKey;

  // This class allows passing in an address, to handle account key rotation,
  // where auth_key != public_key (address).
  factory AptosAccount.fromPrivateKey(Uint8List privateKeyBytes,
      {HexString? address}) {
    var signingKey = SigningKey.fromSeed(privateKeyBytes.sublist(0, 32));
    var authKey = createAuthKey(signingKey);
    var a = address ?? authKey;
    return AptosAccount._internal(signingKey, a, authKey);
  }

  factory AptosAccount.fromPrivateKeyHexString(HexString privateKey,
      {HexString? address}) {
    return AptosAccount.fromPrivateKey(privateKey.toBytes(), address: address);
  }

  factory AptosAccount.generate() {
    var signingKey = SigningKey.generate();
    var authKey = createAuthKey(signingKey);
    return AptosAccount._internal(signingKey, authKey, authKey);
  }

  static HexString createAuthKey(SigningKey privateKey) {
    var hash = SHA3(256, SHA3_PADDING, 256);
    hash.update(privateKey.publicKey);
    hash.update("\x00".codeUnits);
    hash.finalize();
    return HexString.fromBytes(Uint8List.fromList(hash.digest()));
  }

  HexString pubKey() {
    return HexString.fromBytes(_signingKey.publicKey.asTypedList);
  }

  HexString signBytes(Uint8List bytes) {
    SignedMessage signedMessage = _signingKey.sign(bytes);
    return HexString.fromBytes(signedMessage.toUint8List()).substring(0, 128);
  }

  HexString signHexString(HexString hexString) {
    return signBytes(hexString.toBytes());
  }

  AptosAccount._internal(this._signingKey, this.address, this.authKey);
}
