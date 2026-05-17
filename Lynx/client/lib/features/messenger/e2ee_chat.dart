import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/providers/auth_provider.dart';

class E2eeEncryptedPayload {
  final String algorithm;
  final String nonceB64;
  final String ciphertextB64;
  final String senderPubB64;

  const E2eeEncryptedPayload({
    required this.algorithm,
    required this.nonceB64,
    required this.ciphertextB64,
    required this.senderPubB64,
  });

  Map<String, dynamic> toJson() => {
        'algorithm': algorithm,
        'nonce_b64': nonceB64,
        'ciphertext_b64': ciphertextB64,
        'sender_pub_b64': senderPubB64,
      };
}

class E2eeChatService {
  static const _algoName = 'x25519-aesgcm-v1';
  static const _privStorageKey = 'chat_e2ee_x25519_priv_b64';
  static const _pubStorageKey = 'chat_e2ee_x25519_pub_b64';

  final AuthProvider _auth;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final X25519 _x25519 = X25519();
  final AesGcm _aead = AesGcm.with256bits();

  final Map<String, SimplePublicKey> _peerKeyCache = {};
  SimpleKeyPairData? _myKeyPair;
  String? _myPublicKeyB64;
  bool _published = false;

  E2eeChatService(this._auth);

  Future<void> ensureReady() async {
    await _ensureLocalKeyPair();
    if (!_published) {
      await _publishMyPublicKey();
      _published = true;
    }
  }

  Future<E2eeEncryptedPayload?> encryptForPeer({
    required String peerId,
    required String plaintext,
  }) async {
    await ensureReady();
    final peerPub = await _fetchPeerKey(peerId);
    if (peerPub == null || _myKeyPair == null || _myPublicKeyB64 == null) return null;

    final shared = await _x25519.sharedSecretKey(
      keyPair: _myKeyPair!,
      remotePublicKey: peerPub,
    );
    final sharedBytes = await shared.extractBytes();

    final nonce = _randomBytes(12);
    final secretBox = await _aead.encrypt(
      utf8.encode(plaintext),
      secretKey: SecretKey(sharedBytes),
      nonce: nonce,
      aad: utf8.encode('nexus-chat:$_algoName'),
    );

    final joined = Uint8List(secretBox.cipherText.length + secretBox.mac.bytes.length)
      ..setRange(0, secretBox.cipherText.length, secretBox.cipherText)
      ..setRange(secretBox.cipherText.length, secretBox.cipherText.length + secretBox.mac.bytes.length, secretBox.mac.bytes);

    return E2eeEncryptedPayload(
      algorithm: _algoName,
      nonceB64: base64Encode(nonce),
      ciphertextB64: base64Encode(joined),
      senderPubB64: _myPublicKeyB64!,
    );
  }

  Future<String?> decryptIncoming({
    required String senderId,
    required String nonceB64,
    required String ciphertextB64,
    required String senderPubB64,
  }) async {
    await ensureReady();
    if (_myKeyPair == null) return null;

    try {
      final senderPub = SimplePublicKey(base64Decode(senderPubB64), type: KeyPairType.x25519);
      _peerKeyCache[senderId] = senderPub;

      final shared = await _x25519.sharedSecretKey(
        keyPair: _myKeyPair!,
        remotePublicKey: senderPub,
      );
      final sharedBytes = await shared.extractBytes();

      final nonce = base64Decode(nonceB64);
      final joined = base64Decode(ciphertextB64);
      if (joined.length < 16) return null;
      final cipherText = joined.sublist(0, joined.length - 16);
      final mac = Mac(joined.sublist(joined.length - 16));

      final clear = await _aead.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: SecretKey(sharedBytes),
        aad: utf8.encode('nexus-chat:$_algoName'),
      );
      return utf8.decode(clear, allowMalformed: true);
    } catch (e) {
      debugPrint('decryptIncoming: $e');
      return null;
    }
  }

  Future<void> _ensureLocalKeyPair() async {
    if (_myKeyPair != null && _myPublicKeyB64 != null) return;

    final storedPriv = await _storage.read(key: _privStorageKey);
    final storedPub = await _storage.read(key: _pubStorageKey);
    if (storedPriv != null && storedPub != null) {
      final priv = base64Decode(storedPriv);
      final pub = base64Decode(storedPub);
      _myKeyPair = SimpleKeyPairData(
        priv,
        publicKey: SimplePublicKey(pub, type: KeyPairType.x25519),
        type: KeyPairType.x25519,
      );
      _myPublicKeyB64 = storedPub;
      return;
    }

    final seed = _randomBytes(32);
    final kp = await _x25519.newKeyPairFromSeed(seed);
    final data = await kp.extract();
    final pubBytes = (await data.extractPublicKey()).bytes;
    final privB64 = base64Encode(data.bytes);
    final pubB64 = base64Encode(pubBytes);

    await _storage.write(key: _privStorageKey, value: privB64);
    await _storage.write(key: _pubStorageKey, value: pubB64);

    _myKeyPair = SimpleKeyPairData(
      data.bytes,
      publicKey: SimplePublicKey(pubBytes, type: KeyPairType.x25519),
      type: KeyPairType.x25519,
    );
    _myPublicKeyB64 = pubB64;
  }

  Future<void> _publishMyPublicKey() async {
    if (_myPublicKeyB64 == null) return;
    try {
      await _auth.http.put('/chat/e2ee/key', data: {'public_key_b64': _myPublicKeyB64});
    } catch (e) {
      debugPrint('publish e2ee key: $e');
    }
  }

  Future<SimplePublicKey?> _fetchPeerKey(String peerId) async {
    final cached = _peerKeyCache[peerId];
    if (cached != null) return cached;
    try {
      final r = await _auth.http.get<Map<String, dynamic>>('/chat/e2ee/key/$peerId');
      final b64 = r.data?['public_key_b64']?.toString();
      if (b64 == null || b64.isEmpty) return null;
      final key = SimplePublicKey(base64Decode(b64), type: KeyPairType.x25519);
      _peerKeyCache[peerId] = key;
      return key;
    } on DioException {
      return null;
    } catch (e) {
      debugPrint('fetch peer key: $e');
      return null;
    }
  }

  Uint8List _randomBytes(int n) {
    final rnd = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => rnd.nextInt(256)));
  }
}
