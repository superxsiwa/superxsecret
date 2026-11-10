// ignore_for_file: avoid_print
import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// CLI Tool to generate cryptographically signed SuperXSecret Pro License Keys.
///
/// Usage:
///   dart run scripts/generate_license.dart <owner_email_or_name> [lifetime|annual]
void main(List<String> args) async {
  final owner = args.isNotEmpty ? args[0] : 'customer@superxlab.com';
  final plan = args.length > 1 ? args[1] : 'lifetime';

  // Master Private Key (Keep secret, do not commit to client code)
  const privateKeyHex =
      '47083cf57f5a9cbb74207f9b0093e0f6b8cf9463491ae91d6a23a1af5f65256e';
  const publicKeyHex =
      '12f21eaea1309b4b9b37fba2dd9af60ccd8a3ca1d1744623c796a9c668a8b0eb';

  final payload = {
    'app': 'superxsecret',
    'owner': owner,
    'plan': plan,
    'issued_at': DateTime.now().toUtc().toIso8601String(),
  };

  final payloadJson = jsonEncode(payload);
  final payloadBytes = utf8.encode(payloadJson);
  final payloadB64 = base64Url.encode(payloadBytes).replaceAll('=', '');

  final privBytes = _hexToBytes(privateKeyHex);
  final pubBytes = _hexToBytes(publicKeyHex);

  final algorithm = Ed25519();
  final keyPair = SimpleKeyPairData(
    privBytes,
    publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
    type: KeyPairType.ed25519,
  );

  final signature = await algorithm.sign(payloadBytes, keyPair: keyPair);
  final signatureB64 = base64Url.encode(signature.bytes).replaceAll('=', '');

  final licenseKey = 'SXS-$payloadB64.$signatureB64';

  print('==============================================');
  print('SUPERXSECRET PRO LICENSE GENERATOR');
  print('==============================================');
  print('Owner:       $owner');
  print('Plan:        $plan');
  print('Issued At:   ${payload['issued_at']}');
  print('License Key:');
  print(licenseKey);
  print('==============================================');
}

List<int> _hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}
