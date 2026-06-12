#!/usr/bin/env dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

void printUsage() {
  stdout.writeln('''
=== URL 加密/解密工具 ===

Usage: dart tools/encrypt_url.dart [options]

Options:
  --generate-key           Generate a new 32-byte base64 key and print it
  --encrypt <text>         Encrypt input text/URL
  --decrypt <text>         Decrypt ciphertext
  --url <url>              Same as --encrypt (encrypt a URL)
  --key <base64key>        Provide base64 key for encrypt/decrypt (required for encrypt/decrypt)
  -h, --help               Show this help message

Examples:
  # Generate key
  dart tools/encrypt_url.dart --generate-key

  # Encrypt URL
  dart tools/encrypt_url.dart --key "CAoLDA0..." --url "https://example.com/path"
  dart tools/encrypt_url.dart --key "CAoLDA0..." --encrypt "https://example.com/path"

  # Decrypt
  dart tools/encrypt_url.dart --key "CAoLDA0..." --decrypt "aWprbG1ub3B..."
''');
}

String generateKeyBase64([int length = 32]) {
  final rnd = Random.secure();
  final bytes = List<int>.generate(length, (_) => rnd.nextInt(256));
  return base64Encode(bytes);
}

/// XOR 加密
Uint8List xorEncrypt(List<int> data, List<int> key) {
  final result = Uint8List(data.length);
  for (int i = 0; i < data.length; i++) {
    result[i] = data[i] ^ key[i % key.length];
  }
  return result;
}

/// XOR 解密
Uint8List xorDecrypt(List<int> data, List<int> key) {
  return xorEncrypt(data, key); // XOR 对称性
}

/// 生成随机字节
Uint8List generateRandomBytes(int length) {
  final rnd = Random.secure();
  return Uint8List.fromList(List<int>.generate(length, (_) => rnd.nextInt(256)));
}

/// 常时间比较（防止时序攻击）
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  int result = 0;
  for (int i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}

/// 加密 URL
String encryptUrl(String plainUrl, String encryptionKey) {
  try {
    // 解码 Base64 密钥
    final keyBytes = base64Decode(encryptionKey);
    if (keyBytes.length != 32) {
      throw ArgumentError('加密密钥必须是 32 字节（256 bit）Base64 编码');
    }

    // 生成随机 IV（16 字节）
    final iv = generateRandomBytes(16);
    
    // 使用 HMAC-SHA256 进行认证加密
    final urlBytes = utf8.encode(plainUrl);
    final hmac = Hmac(sha256, keyBytes);
    final signature = hmac.convert(urlBytes).bytes;
    
    // 对 URL + 签名进行 XOR 操作
    final encryptedUrl = xorEncrypt(urlBytes, keyBytes);
    final encryptedSignature = xorEncrypt(signature, keyBytes);
    
    // 组合：IV + EncryptedUrl + EncryptedSignature
    final combined = Uint8List.fromList([
      ...iv,
      ...encryptedUrl,
      ...encryptedSignature,
    ]);
    
    return base64Encode(combined);
  } catch (e) {
    stderr.writeln('❌ 加密失败: $e');
    exit(1);
  }
}

/// 解密 URL
String decryptUrl(String encryptedUrl, String encryptionKey) {
  try {
    // 解码 Base64 密钥
    final keyBytes = base64Decode(encryptionKey);
    if (keyBytes.length != 32) {
      throw ArgumentError('加密密钥必须是 32 字节（256 bit）Base64 编码');
    }

    // 解码加密数据
    final combined = base64Decode(encryptedUrl);
    
    if (combined.length < 48) {
      throw ArgumentError('加密数据格式不正确');
    }
    
    // 提取部分：IV(16) + EncryptedUrl + EncryptedSignature(32)
    final encryptedSignature = combined.sublist(combined.length - 32);
    final encryptedUrlBytes = combined.sublist(16, combined.length - 32);
    
    // 解密 URL
    final urlBytes = xorDecrypt(encryptedUrlBytes, keyBytes);
    final plainUrl = utf8.decode(urlBytes);
    
    // 验证签名
    final hmac = Hmac(sha256, keyBytes);
    final expectedSignature = hmac.convert(urlBytes).bytes;
    final decryptedSignature = xorDecrypt(encryptedSignature, keyBytes);
    
    if (!constantTimeEquals(expectedSignature, decryptedSignature)) {
      throw Exception('签名验证失败，数据可能被篡改');
    }
    
    return plainUrl;
  } catch (e) {
    stderr.writeln('❌ 解密失败: $e');
    exit(1);
  }
}

String? _getArgValue(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index >= 0 && index + 1 < args.length) {
    return args[index + 1];
  }
  return null;
}

void main(List<String> args) {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    printUsage();
    exit(0);
  }

  if (args.contains('--generate-key')) {
    stdout.writeln('\n=== URL 加密工具 ===\n');
    stdout.writeln('生成新的加密密钥 (32 字节)...\n');
    final key = generateKeyBase64(32);
    stdout.writeln('✓ 加密密钥已生成：');
    stdout.writeln('  $key\n');
    stdout.writeln('使用此密钥：');
    stdout.writeln('  1. 将其设置为环境变量或构建参数');
    stdout.writeln('  2. 在应用启动时调用 ConfigFileLoader.setEncryptionKey(key)');
    stdout.writeln('  3. 使用此密钥加密 URL\n');
    exit(0);
  }

  final encryptionKey = _getArgValue(args, '--key');
  final encryptText = _getArgValue(args, '--encrypt') ?? _getArgValue(args, '--url');
  final decryptText = _getArgValue(args, '--decrypt');

  if (encryptText != null) {
    if (encryptionKey == null) {
      stderr.writeln('❌ 错误：加密需要提供 --key 参数');
      printUsage();
      exit(1);
    }
    
    stdout.writeln('\n加密 URL...\n');
    final encrypted = encryptUrl(encryptText, encryptionKey);
    stdout.writeln('✓ 加密结果：');
    stdout.writeln('  $encrypted\n');
    stdout.writeln('可以将此密文添加到 encryptedRemoteSources 列表中：');
    stdout.writeln('  (name: \'redirect-x\', encryptedUrl: \'$encrypted\', priority: 90),\n');
    exit(0);
  }

  if (decryptText != null) {
    if (encryptionKey == null) {
      stderr.writeln('❌ 错误：解密需要提供 --key 参数');
      printUsage();
      exit(1);
    }
    
    stdout.writeln('\n解密 URL...\n');
    final decrypted = decryptUrl(decryptText, encryptionKey);
    stdout.writeln('✓ 解密结果：');
    stdout.writeln('  $decrypted\n');
    exit(0);
  }

  stderr.writeln('❌ 错误：请指定 --generate-key、--encrypt/--url 或 --decrypt\n');
  printUsage();
  exit(1);
}
