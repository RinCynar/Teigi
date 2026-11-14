import 'dart:typed_data';

/// Pure Dart AES-128 in ECB mode.
///
/// Designed specifically for decrypting key and metadata envelopes in NCM files.
/// Conforms to FIPS 197 standard.
class Aes128Ecb {
  final Uint8List _key;
  late final Uint32List _expandedKey;

  static final Uint8List ncmCoreKey = Uint8List.fromList(const [
    0x68, 0x7A, 0x48, 0x52, 0x41, 0x6D, 0x73, 0x6F,
    0x35, 0x6B, 0x49, 0x6E, 0x62, 0x61, 0x78, 0x57,
  ]);

  static final Uint8List ncmMetaKey = Uint8List.fromList(const [
    0x23, 0x31, 0x34, 0x6C, 0x6A, 0x6B, 0x5F, 0x21,
    0x5C, 0x5D, 0x26, 0x30, 0x55, 0x3C, 0x27, 0x28,
  ]);

  Aes128Ecb(this._key) {
    if (_key.length != 16) {
      throw ArgumentError('AES-128 key must be exactly 16 bytes');
    }
    _expandedKey = _expandKey(_key);
  }

  /// Encrypts a full plaintext payload in ECB mode with PKCS#7 padding.
  Uint8List encrypt(Uint8List plainText) {
    final padded = _pkcs7Pad(plainText);
    final cipher = Uint8List(padded.length);
    for (int offset = 0; offset < padded.length; offset += 16) {
      _encryptBlock(padded, offset, cipher, offset);
    }
    return cipher;
  }

  Uint8List _pkcs7Pad(Uint8List data) {
    final padLen = 16 - (data.length % 16);
    final out = Uint8List(data.length + padLen);
    out.setRange(0, data.length, data);
    for (int i = data.length; i < out.length; i++) {
      out[i] = padLen;
    }
    return out;
  }

  void _encryptBlock(Uint8List src, int srcOff, Uint8List dst, int dstOff) {
    int s00 = src[srcOff];
    int s10 = src[srcOff + 1];
    int s20 = src[srcOff + 2];
    int s30 = src[srcOff + 3];

    int s01 = src[srcOff + 4];
    int s11 = src[srcOff + 5];
    int s21 = src[srcOff + 6];
    int s31 = src[srcOff + 7];

    int s02 = src[srcOff + 8];
    int s12 = src[srcOff + 9];
    int s22 = src[srcOff + 10];
    int s32 = src[srcOff + 11];

    int s03 = src[srcOff + 12];
    int s13 = src[srcOff + 13];
    int s23 = src[srcOff + 14];
    int s33 = src[srcOff + 15];

    // Initial round
    s00 ^= (_expandedKey[0] >> 24) & 0xFF;
    s10 ^= (_expandedKey[0] >> 16) & 0xFF;
    s20 ^= (_expandedKey[0] >> 8) & 0xFF;
    s30 ^= _expandedKey[0] & 0xFF;

    s01 ^= (_expandedKey[1] >> 24) & 0xFF;
    s11 ^= (_expandedKey[1] >> 16) & 0xFF;
    s21 ^= (_expandedKey[1] >> 8) & 0xFF;
    s31 ^= _expandedKey[1] & 0xFF;

    s02 ^= (_expandedKey[2] >> 24) & 0xFF;
    s12 ^= (_expandedKey[2] >> 16) & 0xFF;
    s22 ^= (_expandedKey[2] >> 8) & 0xFF;
    s32 ^= _expandedKey[2] & 0xFF;

    s03 ^= (_expandedKey[3] >> 24) & 0xFF;
    s13 ^= (_expandedKey[3] >> 16) & 0xFF;
    s23 ^= (_expandedKey[3] >> 8) & 0xFF;
    s33 ^= _expandedKey[3] & 0xFF;

    // Rounds 1 to 9
    for (int round = 1; round <= 9; round++) {
      final t00 = _sBox[s00];
      final t01 = _sBox[s01];
      final t02 = _sBox[s02];
      final t03 = _sBox[s03];

      final t10 = _sBox[s11];
      final t11 = _sBox[s12];
      final t12 = _sBox[s13];
      final t13 = _sBox[s10];

      final t20 = _sBox[s22];
      final t21 = _sBox[s23];
      final t22 = _sBox[s20];
      final t23 = _sBox[s21];

      final t30 = _sBox[s33];
      final t31 = _sBox[s30];
      final t32 = _sBox[s31];
      final t33 = _sBox[s32];

      final u00 = _mul2(t00) ^ _mul3(t10) ^ t20 ^ t30;
      final u10 = t00 ^ _mul2(t10) ^ _mul3(t20) ^ t30;
      final u20 = t00 ^ t10 ^ _mul2(t20) ^ _mul3(t30);
      final u30 = _mul3(t00) ^ t10 ^ t20 ^ _mul2(t30);

      final u01 = _mul2(t01) ^ _mul3(t11) ^ t21 ^ t31;
      final u11 = t01 ^ _mul2(t11) ^ _mul3(t21) ^ t31;
      final u21 = t01 ^ t11 ^ _mul2(t21) ^ _mul3(t31);
      final u31 = _mul3(t01) ^ t11 ^ t21 ^ _mul2(t31);

      final u02 = _mul2(t02) ^ _mul3(t12) ^ t22 ^ t32;
      final u12 = t02 ^ _mul2(t12) ^ _mul3(t22) ^ t32;
      final u22 = t02 ^ t12 ^ _mul2(t22) ^ _mul3(t32);
      final u32 = _mul3(t02) ^ t12 ^ t22 ^ _mul2(t32);

      final u03 = _mul2(t03) ^ _mul3(t13) ^ t23 ^ t33;
      final u13 = t03 ^ _mul2(t13) ^ _mul3(t23) ^ t33;
      final u23 = t03 ^ t13 ^ _mul2(t23) ^ _mul3(t33);
      final u33 = _mul3(t03) ^ t13 ^ t23 ^ _mul2(t33);

      final kOff = round * 4;
      final k0 = _expandedKey[kOff];
      final k1 = _expandedKey[kOff + 1];
      final k2 = _expandedKey[kOff + 2];
      final k3 = _expandedKey[kOff + 3];

      s00 = u00 ^ ((k0 >> 24) & 0xFF);
      s10 = u10 ^ ((k0 >> 16) & 0xFF);
      s20 = u20 ^ ((k0 >> 8) & 0xFF);
      s30 = u30 ^ (k0 & 0xFF);

      s01 = u01 ^ ((k1 >> 24) & 0xFF);
      s11 = u11 ^ ((k1 >> 16) & 0xFF);
      s21 = u21 ^ ((k1 >> 8) & 0xFF);
      s31 = u31 ^ (k1 & 0xFF);

      s02 = u02 ^ ((k2 >> 24) & 0xFF);
      s12 = u12 ^ ((k2 >> 16) & 0xFF);
      s22 = u22 ^ ((k2 >> 8) & 0xFF);
      s32 = u32 ^ (k2 & 0xFF);

      s03 = u03 ^ ((k3 >> 24) & 0xFF);
      s13 = u13 ^ ((k3 >> 16) & 0xFF);
      s23 = u23 ^ ((k3 >> 8) & 0xFF);
      s33 = u33 ^ (k3 & 0xFF);
    }

    // Final Round
    final f00 = _sBox[s00];
    final f01 = _sBox[s01];
    final f02 = _sBox[s02];
    final f03 = _sBox[s03];

    final f10 = _sBox[s11];
    final f11 = _sBox[s12];
    final f12 = _sBox[s13];
    final f13 = _sBox[s10];

    final f20 = _sBox[s22];
    final f21 = _sBox[s23];
    final f22 = _sBox[s20];
    final f23 = _sBox[s21];

    final f30 = _sBox[s33];
    final f31 = _sBox[s30];
    final f32 = _sBox[s31];
    final f33 = _sBox[s32];

    final k0 = _expandedKey[40];
    final k1 = _expandedKey[41];
    final k2 = _expandedKey[42];
    final k3 = _expandedKey[43];

    dst[dstOff] = f00 ^ ((k0 >> 24) & 0xFF);
    dst[dstOff + 1] = f10 ^ ((k0 >> 16) & 0xFF);
    dst[dstOff + 2] = f20 ^ ((k0 >> 8) & 0xFF);
    dst[dstOff + 3] = f30 ^ (k0 & 0xFF);

    dst[dstOff + 4] = f01 ^ ((k1 >> 24) & 0xFF);
    dst[dstOff + 5] = f11 ^ ((k1 >> 16) & 0xFF);
    dst[dstOff + 6] = f21 ^ ((k1 >> 8) & 0xFF);
    dst[dstOff + 7] = f31 ^ (k1 & 0xFF);

    dst[dstOff + 8] = f02 ^ ((k2 >> 24) & 0xFF);
    dst[dstOff + 9] = f12 ^ ((k2 >> 16) & 0xFF);
    dst[dstOff + 10] = f22 ^ ((k2 >> 8) & 0xFF);
    dst[dstOff + 11] = f32 ^ (k2 & 0xFF);

    dst[dstOff + 12] = f03 ^ ((k3 >> 24) & 0xFF);
    dst[dstOff + 13] = f13 ^ ((k3 >> 16) & 0xFF);
    dst[dstOff + 14] = f23 ^ ((k3 >> 8) & 0xFF);
    dst[dstOff + 15] = f33 ^ (k3 & 0xFF);
  }

  /// Decrypts a full ciphertext payload in ECB mode with PKCS#7 unpadding.
  Uint8List decrypt(Uint8List cipherText) {
    if (cipherText.isEmpty || cipherText.length % 16 != 0) {
      throw ArgumentError('Ciphertext length must be a multiple of 16 bytes');
    }

    final plain = Uint8List(cipherText.length);
    for (int offset = 0; offset < cipherText.length; offset += 16) {
      _decryptBlock(cipherText, offset, plain, offset);
    }

    return _pkcs7Unpad(plain);
  }

  /// Decrypts a single 16-byte block from [src] at [srcOff] into [dst] at [dstOff].
  void _decryptBlock(Uint8List src, int srcOff, Uint8List dst, int dstOff) {
    // Load block into state matrix (column-major order)
    int s00 = src[srcOff];
    int s10 = src[srcOff + 1];
    int s20 = src[srcOff + 2];
    int s30 = src[srcOff + 3];

    int s01 = src[srcOff + 4];
    int s11 = src[srcOff + 5];
    int s21 = src[srcOff + 6];
    int s31 = src[srcOff + 7];

    int s02 = src[srcOff + 8];
    int s12 = src[srcOff + 9];
    int s22 = src[srcOff + 10];
    int s32 = src[srcOff + 11];

    int s03 = src[srcOff + 12];
    int s13 = src[srcOff + 13];
    int s23 = src[srcOff + 14];
    int s33 = src[srcOff + 15];

    // Initial round key addition (Round 10 key)
    int kOff = 40;
    s00 ^= (_expandedKey[kOff] >> 24) & 0xFF;
    s10 ^= (_expandedKey[kOff] >> 16) & 0xFF;
    s20 ^= (_expandedKey[kOff] >> 8) & 0xFF;
    s30 ^= _expandedKey[kOff] & 0xFF;

    s01 ^= (_expandedKey[kOff + 1] >> 24) & 0xFF;
    s11 ^= (_expandedKey[kOff + 1] >> 16) & 0xFF;
    s21 ^= (_expandedKey[kOff + 1] >> 8) & 0xFF;
    s31 ^= _expandedKey[kOff + 1] & 0xFF;

    s02 ^= (_expandedKey[kOff + 2] >> 24) & 0xFF;
    s12 ^= (_expandedKey[kOff + 2] >> 16) & 0xFF;
    s22 ^= (_expandedKey[kOff + 2] >> 8) & 0xFF;
    s32 ^= _expandedKey[kOff + 2] & 0xFF;

    s03 ^= (_expandedKey[kOff + 3] >> 24) & 0xFF;
    s13 ^= (_expandedKey[kOff + 3] >> 16) & 0xFF;
    s23 ^= (_expandedKey[kOff + 3] >> 8) & 0xFF;
    s33 ^= _expandedKey[kOff + 3] & 0xFF;

    // Rounds 9 down to 1
    for (int round = 9; round >= 1; round--) {
      // 1. InvShiftRows + InvSubBytes
      // Row 0: shift 0
      final t00 = _invSBox[s00];
      final t01 = _invSBox[s01];
      final t02 = _invSBox[s02];
      final t03 = _invSBox[s03];

      // Row 1: shift right 1 (left 3)
      final t10 = _invSBox[s13];
      final t11 = _invSBox[s10];
      final t12 = _invSBox[s11];
      final t13 = _invSBox[s12];

      // Row 2: shift right 2 (left 2)
      final t20 = _invSBox[s22];
      final t21 = _invSBox[s23];
      final t22 = _invSBox[s20];
      final t23 = _invSBox[s21];

      // Row 3: shift right 3 (left 1)
      final t30 = _invSBox[s31];
      final t31 = _invSBox[s32];
      final t32 = _invSBox[s33];
      final t33 = _invSBox[s30];

      // 2. AddRoundKey
      kOff = round * 4;
      final k0 = _expandedKey[kOff];
      final k1 = _expandedKey[kOff + 1];
      final k2 = _expandedKey[kOff + 2];
      final k3 = _expandedKey[kOff + 3];

      final u00 = t00 ^ ((k0 >> 24) & 0xFF);
      final u10 = t10 ^ ((k0 >> 16) & 0xFF);
      final u20 = t20 ^ ((k0 >> 8) & 0xFF);
      final u30 = t30 ^ (k0 & 0xFF);

      final u01 = t01 ^ ((k1 >> 24) & 0xFF);
      final u11 = t11 ^ ((k1 >> 16) & 0xFF);
      final u21 = t21 ^ ((k1 >> 8) & 0xFF);
      final u31 = t31 ^ (k1 & 0xFF);

      final u02 = t02 ^ ((k2 >> 24) & 0xFF);
      final u12 = t12 ^ ((k2 >> 16) & 0xFF);
      final u22 = t22 ^ ((k2 >> 8) & 0xFF);
      final u32 = t32 ^ (k2 & 0xFF);

      final u03 = t03 ^ ((k3 >> 24) & 0xFF);
      final u13 = t13 ^ ((k3 >> 16) & 0xFF);
      final u23 = t23 ^ ((k3 >> 8) & 0xFF);
      final u33 = t33 ^ (k3 & 0xFF);

      // 3. InvMixColumns
      s00 = _mul14(u00) ^ _mul11(u10) ^ _mul13(u20) ^ _mul9(u30);
      s10 = _mul9(u00) ^ _mul14(u10) ^ _mul11(u20) ^ _mul13(u30);
      s20 = _mul13(u00) ^ _mul9(u10) ^ _mul14(u20) ^ _mul11(u30);
      s30 = _mul11(u00) ^ _mul13(u10) ^ _mul9(u20) ^ _mul14(u30);

      s01 = _mul14(u01) ^ _mul11(u11) ^ _mul13(u21) ^ _mul9(u31);
      s11 = _mul9(u01) ^ _mul14(u11) ^ _mul11(u21) ^ _mul13(u31);
      s21 = _mul13(u01) ^ _mul9(u11) ^ _mul14(u21) ^ _mul11(u31);
      s31 = _mul11(u01) ^ _mul13(u11) ^ _mul9(u21) ^ _mul14(u31);

      s02 = _mul14(u02) ^ _mul11(u12) ^ _mul13(u22) ^ _mul9(u32);
      s12 = _mul9(u02) ^ _mul14(u12) ^ _mul11(u22) ^ _mul13(u32);
      s22 = _mul13(u02) ^ _mul9(u12) ^ _mul14(u22) ^ _mul11(u32);
      s32 = _mul11(u02) ^ _mul13(u12) ^ _mul9(u22) ^ _mul14(u32);

      s03 = _mul14(u03) ^ _mul11(u13) ^ _mul13(u23) ^ _mul9(u33);
      s13 = _mul9(u03) ^ _mul14(u13) ^ _mul11(u23) ^ _mul13(u33);
      s23 = _mul13(u03) ^ _mul9(u13) ^ _mul14(u23) ^ _mul11(u33);
      s33 = _mul11(u03) ^ _mul13(u13) ^ _mul9(u23) ^ _mul14(u33);
    }

    // Final Round (Round 0)
    // 1. InvShiftRows + InvSubBytes
    final f00 = _invSBox[s00];
    final f01 = _invSBox[s01];
    final f02 = _invSBox[s02];
    final f03 = _invSBox[s03];

    final f10 = _invSBox[s13];
    final f11 = _invSBox[s10];
    final f12 = _invSBox[s11];
    final f13 = _invSBox[s12];

    final f20 = _invSBox[s22];
    final f21 = _invSBox[s23];
    final f22 = _invSBox[s20];
    final f23 = _invSBox[s21];

    final f30 = _invSBox[s31];
    final f31 = _invSBox[s32];
    final f32 = _invSBox[s33];
    final f33 = _invSBox[s30];

    // 2. AddRoundKey (Round 0 key)
    final k0 = _expandedKey[0];
    final k1 = _expandedKey[1];
    final k2 = _expandedKey[2];
    final k3 = _expandedKey[3];

    dst[dstOff] = f00 ^ ((k0 >> 24) & 0xFF);
    dst[dstOff + 1] = f10 ^ ((k0 >> 16) & 0xFF);
    dst[dstOff + 2] = f20 ^ ((k0 >> 8) & 0xFF);
    dst[dstOff + 3] = f30 ^ (k0 & 0xFF);

    dst[dstOff + 4] = f01 ^ ((k1 >> 24) & 0xFF);
    dst[dstOff + 5] = f11 ^ ((k1 >> 16) & 0xFF);
    dst[dstOff + 6] = f21 ^ ((k1 >> 8) & 0xFF);
    dst[dstOff + 7] = f31 ^ (k1 & 0xFF);

    dst[dstOff + 8] = f02 ^ ((k2 >> 24) & 0xFF);
    dst[dstOff + 9] = f12 ^ ((k2 >> 16) & 0xFF);
    dst[dstOff + 10] = f22 ^ ((k2 >> 8) & 0xFF);
    dst[dstOff + 11] = f32 ^ (k2 & 0xFF);

    dst[dstOff + 12] = f03 ^ ((k3 >> 24) & 0xFF);
    dst[dstOff + 13] = f13 ^ ((k3 >> 16) & 0xFF);
    dst[dstOff + 14] = f23 ^ ((k3 >> 8) & 0xFF);
    dst[dstOff + 15] = f33 ^ (k3 & 0xFF);
  }

  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen <= 0 || padLen > 16 || padLen > data.length) {
      // If padding format is non-standard or corrupt, return full block
      return data;
    }
    for (int i = data.length - padLen; i < data.length; i++) {
      if (data[i] != padLen) {
        return data;
      }
    }
    return Uint8List.sublistView(data, 0, data.length - padLen);
  }

  static Uint32List _expandKey(Uint8List key) {
    final w = Uint32List(44);
    for (int i = 0; i < 4; i++) {
      w[i] = (key[4 * i] << 24) |
          (key[4 * i + 1] << 16) |
          (key[4 * i + 2] << 8) |
          key[4 * i + 3];
    }

    const rcon = [
      0x01000000, 0x02000000, 0x04000000, 0x08000000,
      0x10000000, 0x20000000, 0x40000000, 0x80000000,
      0x1B000000, 0x36000000,
    ];

    for (int i = 4; i < 44; i++) {
      int temp = w[i - 1];
      if (i % 4 == 0) {
        // RotWord
        temp = ((temp << 8) & 0xFFFFFFFF) | ((temp >> 24) & 0xFF);
        // SubWord
        temp = (_sBox[(temp >> 24) & 0xFF] << 24) |
            (_sBox[(temp >> 16) & 0xFF] << 16) |
            (_sBox[(temp >> 8) & 0xFF] << 8) |
            _sBox[temp & 0xFF];
        temp ^= rcon[(i ~/ 4) - 1];
      }
      w[i] = (w[i - 4] ^ temp) & 0xFFFFFFFF;
    }
    return w;
  }

  static int _xtimes(int b) =>
      (((b << 1) & 0xFF) ^ (((b >> 7) & 1) != 0 ? 0x1B : 0));

  static int _mul2(int b) => _xtimes(b);
  static int _mul3(int b) => _mul2(b) ^ b;
  static int _mul4(int b) => _mul2(_mul2(b));
  static int _mul8(int b) => _mul2(_mul4(b));

  static int _mul9(int b) => _mul8(b) ^ b;
  static int _mul11(int b) => _mul8(b) ^ _mul2(b) ^ b;
  static int _mul13(int b) => _mul8(b) ^ _mul4(b) ^ b;
  static int _mul14(int b) => _mul8(b) ^ _mul4(b) ^ _mul2(b);

  static const List<int> _sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16,
  ];

  static const List<int> _invSBox = [
    0x52, 0x09, 0x6a, 0xd5, 0x30, 0x36, 0xa5, 0x38, 0xbf, 0x40, 0xa3, 0x9e, 0x81, 0xf3, 0xd7, 0xfb,
    0x7c, 0xe3, 0x39, 0x82, 0x9b, 0x2f, 0xff, 0x87, 0x34, 0x8e, 0x43, 0x44, 0xc4, 0xde, 0xe9, 0xcb,
    0x54, 0x7b, 0x94, 0x32, 0xa6, 0xc2, 0x23, 0x3d, 0xee, 0x4c, 0x95, 0x0b, 0x42, 0xfa, 0xc3, 0x4e,
    0x08, 0x2e, 0xa1, 0x66, 0x28, 0xd9, 0x24, 0xb2, 0x76, 0x5b, 0xa2, 0x49, 0x6d, 0x8b, 0xd1, 0x25,
    0x72, 0xf8, 0xf6, 0x64, 0x86, 0x68, 0x98, 0x16, 0xd4, 0xa4, 0x5c, 0xcc, 0x5d, 0x65, 0xb6, 0x92,
    0x6c, 0x70, 0x48, 0x50, 0xfd, 0xed, 0xb9, 0xda, 0x5e, 0x15, 0x46, 0x57, 0xa7, 0x8d, 0x9d, 0x84,
    0x90, 0xd8, 0xab, 0x00, 0x8c, 0xbc, 0xd3, 0x0a, 0xf7, 0xe4, 0x58, 0x05, 0xb8, 0xb3, 0x45, 0x06,
    0xd0, 0x2c, 0x1e, 0x8f, 0xca, 0x3f, 0x0f, 0x02, 0xc1, 0xaf, 0xbd, 0x03, 0x01, 0x13, 0x8a, 0x6b,
    0x3a, 0x91, 0x11, 0x41, 0x4f, 0x67, 0xdc, 0xea, 0x97, 0xf2, 0xcf, 0xce, 0xf0, 0xb4, 0xe6, 0x73,
    0x96, 0xac, 0x74, 0x22, 0xe7, 0xad, 0x35, 0x85, 0xe2, 0xf9, 0x37, 0xe8, 0x1c, 0x75, 0xdf, 0x6e,
    0x47, 0xf1, 0x1a, 0x71, 0x1d, 0x29, 0xc5, 0x89, 0x6f, 0xb7, 0x62, 0x0e, 0xaa, 0x18, 0xbe, 0x1b,
    0xfc, 0x56, 0x3e, 0x4b, 0xc6, 0xd2, 0x79, 0x20, 0x9a, 0xdb, 0xc0, 0xfe, 0x78, 0xcd, 0x5a, 0xf4,
    0x1f, 0xdd, 0xa8, 0x33, 0x88, 0x07, 0xc7, 0x31, 0xb1, 0x12, 0x10, 0x59, 0x27, 0x80, 0xec, 0x5f,
    0x60, 0x51, 0x7f, 0xa9, 0x19, 0xb5, 0x4a, 0x0d, 0x2d, 0xe5, 0x7a, 0x9f, 0x93, 0xc9, 0x9c, 0xef,
    0xa0, 0xe0, 0x3b, 0x4d, 0xae, 0x2a, 0xf5, 0xb0, 0xc8, 0xeb, 0xbb, 0x3c, 0x83, 0x53, 0x99, 0x61,
    0x17, 0x2b, 0x04, 0x7e, 0xba, 0x77, 0xd6, 0x26, 0xe1, 0x69, 0x14, 0x63, 0x55, 0x21, 0x0c, 0x7d,
  ];
}
