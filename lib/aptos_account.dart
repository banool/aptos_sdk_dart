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

  /*
  HexString signBytes(Uint8List bytes) {
    return HexString.fromBytes(_signingKey.sign(bytes).message.asTypedList);
    // todo slice 128 or something
  }

  HexString signHexString()
  */

/*
  signHexString(hexString: MaybeHexString): HexString {
    const toSign = HexString.ensure(hexString).toBuffer();
    return this.signBuffer(toSign);
  }

  AptosAccountObject toAptosAccountObject() {
    var a = address().hex();
    return {
      address: this.address().hex(),
      publicKeyHex: this.pubKey().hex(),
      privateKeyHex:
          HexString.fromUint8Array(this.signingKey.secretKey.slice(0, 32))
              .hex(),
    };
  }
  */

  AptosAccount._internal(this._signingKey, this.address, this.authKey);
}


/*
import * as Nacl from "tweetnacl";
import * as SHA3 from "js-sha3";
import { Buffer } from "buffer/"; // the trailing slash is important!
import { HexString, MaybeHexString } from "./hex_string";
import 
import 'hex_string.dart';{ Types } from "./types";

export interface AptosAccountObject {
  address?: string;
  publicKeyHex?: Types.HexEncodedBytes;
  privateKeyHex: Types.HexEncodedBytes;
}

export class AptosAccount {
  readonly signingKey: Nacl.SignKeyPair;

  private readonly accountAddress: HexString;

  private authKeyCached?: HexString;

  static fromAptosAccountObject(obj: AptosAccountObject): AptosAccount {
    return new AptosAccount(HexString.ensure(obj.privateKeyHex).toUint8Array(), obj.address);
  }

  /** This class allows passing in an address, to handle account key rotation, where auth_key != public_key */
  constructor(privateKeyBytes?: Uint8Array | undefined, address?: MaybeHexString) {
    if (privateKeyBytes) {
      this.signingKey = Nacl.sign.keyPair.fromSeed(privateKeyBytes.slice(0, 32));
    } else {
      this.signingKey = Nacl.sign.keyPair();
    }
    this.accountAddress = HexString.ensure(address || this.authKey().hex());
  }

  /** Returns the address associated with the given account */
  address(): HexString {
    return this.accountAddress;
  }

  /** Returns the authKey for the associated account
   * See here for more info: https://aptos.dev/basics/basics-accounts#single-signer-authentication */
  authKey(): HexString {
    if (!this.authKeyCached) {
      const hash = SHA3.sha3_256.create();
      hash.update(Buffer.from(this.signingKey.publicKey));
      hash.update("\x00");
      this.authKeyCached = new HexString(hash.hex());
    }
    return this.authKeyCached;
  }

  /** Returns the public key for the associated account */
  pubKey(): HexString {
    return HexString.ensure(Buffer.from(this.signingKey.publicKey).toString("hex"));
  }

  signBuffer(buffer: Buffer): HexString {
    const signature = Nacl.sign(buffer, this.signingKey.secretKey);
    return HexString.ensure(Buffer.from(signature).toString("hex").slice(0, 128));
  }

  signHexString(hexString: MaybeHexString): HexString {
    const toSign = HexString.ensure(hexString).toBuffer();
    return this.signBuffer(toSign);
  }

  toPrivateKeyObject(): AptosAccountObject {
    return {
      address: this.address().hex(),
      publicKeyHex: this.pubKey().hex(),
      privateKeyHex: HexString.fromUint8Array(this.signingKey.secretKey.slice(0, 32)).hex(),
    };
  }
  */