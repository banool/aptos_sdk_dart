import 'package:pinenacl/ed25519.dart';

/// We use this class for strings that represent hex values (addresses) so we
/// can deal with the 0x prefix properly.
class HexString {
  String _hexString;

  factory HexString.fromString(String s) {
    if (!s.startsWith("0x")) {
      s = "0x$s";
    }
    return HexString._internal(s);
  }

  factory HexString.fromBytes(Uint8List l) {
    return HexString.fromString(String.fromCharCodes(l));
  }

  HexString._internal(this._hexString);

  String hex() {
    return _hexString;
  }

  String noPrefix() {
    return _hexString.substring(2);
  }

  @override
  String toString() {
    return hex();
  }

  Uint8List toBytes() {
    return Uint8List.fromList(noPrefix().codeUnits);
  }
}
