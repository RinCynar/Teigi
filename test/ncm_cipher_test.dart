import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:teigi/core/ncm/aes128.dart';

void main() {
  group('Aes128Ecb', () {
    test('decrypts FIPS 197 Appendix C.1 standard block', () {
      // Key: 2b 7e 15 16 28 ae d2 a6 ab f7 15 88 09 cf 4f 3c
      final key = Uint8List.fromList([
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6,
        0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
      ]);

      // Ciphertext: 3a d7 7b b4 0d 7a 36 60 a8 9e ca f3 24 66 ef 97
      final cipher = Uint8List.fromList([
        0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60,
        0xa8, 0x9e, 0xca, 0xf3, 0x24, 0x66, 0xef, 0x97,
      ]);

      // Expected Plaintext: 6b c1 be e2 2e 40 9f 96 e9 3d 7e 11 73 93 17 2a
      final expected = [
        0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96,
        0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
      ];

      final aes = Aes128Ecb(key);
      final decrypted = aes.decrypt(cipher);
      expect(decrypted, equals(expected));
    });

    test('round-trips arbitrary plaintext with PKCS#7 padding', () {
      final key = Uint8List.fromList([
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07,
        0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
      ]);
      final aes = Aes128Ecb(key);

      final inputs = [
        Uint8List.fromList([]),
        Uint8List.fromList([1, 2, 3]),
        Uint8List.fromList(List.generate(16, (i) => i)),
        Uint8List.fromList(List.generate(35, (i) => (i * 7) % 256)),
      ];

      for (final input in inputs) {
        final encrypted = aes.encrypt(input);
        expect(encrypted.length % 16, 0);
        final decrypted = aes.decrypt(encrypted);
        expect(decrypted, equals(input));
      }
    });

    test('validates key size', () {
      expect(() => Aes128Ecb(Uint8List(15)), throwsArgumentError);
      expect(() => Aes128Ecb(Uint8List(17)), throwsArgumentError);
    });
  });
}
