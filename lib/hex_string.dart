import 'package:pinenacl/ed25519.dart';
import 'package:convert/convert.dart';

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
    // Attempt to clean up when a user passes in an int list with the ascii
    // representations of 0 and x as the first two elements.
    if (l[1] == 78) {
      l = l.sublist(2);
    }
    return HexString.fromString(hex.encode(l));
  }

  HexString._internal(this._hexString);

  String noPrefix() {
    return _hexString.substring(2);
  }

  String withPrefix() {
    return _hexString;
  }

  Uint8List toBytes() {
    return Uint8List.fromList(hex.decode(noPrefix()));
  }

  // Forwards a substring call to the inner string, skipping the 0x prefix.
  HexString substring(int start, [int? end]) {
    if (end != null) {
      end += 2;
    }
    return HexString._internal("0x${_hexString.substring(start + 2, end)}");
  }

  @override
  String toString() {
    return "borking because toString is ambiguous, use noPrefix or withPrefix: ${withPrefix()}";
  }

  @override
  int get hashCode => _hexString.hashCode;

  @override
  bool operator ==(Object other) {
    return (other is HexString && _hexString == other._hexString);
  }
}
