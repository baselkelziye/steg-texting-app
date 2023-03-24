import 'dart:convert' as convert;


import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:pointycastle/src/platform_check/platform_check.dart';
import 'package:pointycastle/export.dart';
import 'package:flutter/widgets.dart';
import 'crypto.dart' as rsa_helper;
import 'lsb-steganography.dart' as lsb;
import 'package:image/image.dart' as img_library;
int debug_mode = 1;

AsymmetricKeyPair<RSAPublicKey,RSAPrivateKey> generateRSAkeyPair(
    SecureRandom secureRandom,
    {int bitLength = 2048}) {
  final keyGen = RSAKeyGenerator();

  keyGen.init(ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.parse('65537'),
      bitLength,64), secureRandom));


  final pair = keyGen.generateKeyPair();

  final myPublic  =pair.publicKey as RSAPublicKey;
  final myPrivate = pair.privateKey as RSAPrivateKey;


  return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(myPublic, myPrivate);
}

SecureRandom exampleSecureRandom(){
  final secureRandom = SecureRandom('Fortuna')
    ..seed(KeyParameter(
        Platform.instance.platformEntropySource().getBytes(32)
    ));

  return secureRandom;
}

Uint8List rsaEncrypt(RSAPublicKey myPublic, Uint8List dataToEncrypt){
  final encryptor = OAEPEncoding(RSAEngine())
    ..init(true, PublicKeyParameter<RSAPublicKey>(myPublic));

  return _processInBlocks(encryptor, dataToEncrypt);
}

Uint8List rsaDecrypt(RSAPrivateKey myPrivate, Uint8List cipherText) {
  final decryptor = OAEPEncoding(RSAEngine())
    ..init(false, PrivateKeyParameter<RSAPrivateKey>(myPrivate)); // false=decrypt

  return _processInBlocks(decryptor, cipherText);
}

Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
  final numBlocks = input.length ~/ engine.inputBlockSize +
      ((input.length % engine.inputBlockSize != 0) ? 1 : 0);

  final output = Uint8List(numBlocks * engine.outputBlockSize);

  var inputOffset = 0;
  var outputOffset = 0;
  while (inputOffset < input.length) {
    final chunkSize = (inputOffset + engine.inputBlockSize <= input.length)
        ? engine.inputBlockSize
        : input.length - inputOffset;

    outputOffset += engine.processBlock(
        input, inputOffset, chunkSize, output, outputOffset);

    inputOffset += chunkSize;
  }

  return (output.length == outputOffset)
      ? output
      : output.sublist(0, outputOffset);
}

Uint8List fromStringToUint8List(String str){
  List<int> list  = str.codeUnits;
  Uint8List bytes = Uint8List.fromList(list);
  return bytes;
}

String fromUint8ListToString(Uint8List obj){
  String str = '';
  str = String.fromCharCodes(obj);
  return str;

}

Uint8List hmacSha256(Uint8List hmacKey, Uint8List data){
  final hmac = HMac(SHA256Digest(),64)
    ..init(KeyParameter(hmacKey));
  return hmac.process(data);
}


String encrypt_message(String plain_text, final public_key){ // encrypt text given a public key;

  String cipher_text = '';
  cipher_text = String.fromCharCodes(rsaEncrypt(public_key  , fromStringToUint8List(plain_text)));
  return cipher_text;
}

Uint8List new_encrypt(String plain_text, final public_key){
  Uint8List cipher_block;
  cipher_block = rsaEncrypt(public_key, fromStringToUint8List(plain_text));
  return cipher_block;
}

String decrypt_message(String cipher_text, final private_key){ // decrypt a text given a private key;

  String plain_text = '';

  plain_text = String.fromCharCodes(rsaDecrypt(private_key, fromStringToUint8List(cipher_text)));


  return plain_text;
}

String stringToBinary(String str) { // converts a string to binary;
  return str.codeUnits.map((int codeUnit) => codeUnit.toRadixString(2)).join(' ');
  // return str.codeUnits.map((v) => v.toRadixString(2).padLeft(8, '0')).join(" ");
}

Uint8List calculate_hmac(String plain_text, final keyBytes){ // calculate hmac given an private key and plain text
  Uint8List hmacValue = hmacSha256(keyBytes, fromStringToUint8List(plain_text));
  return hmacValue;
}


void sendMessage(String plain_text, RSAPublicKey reciever_pub_key, String reciever,FlutterSecureStorage storage) async{
  img_library.Image?img1 = await lsb.getImage() as img_library.Image?;
  Uint8List hmac_code;
  if(debug_mode == 1){
    print('Message from $reciever');
  }

  String cipher_text = encrypt_message(plain_text, reciever_pub_key);
  if(img1 != null){
    print('Img1 Recieved is not NULL!');
    img1 = await lsb.embed_to_image(cipher_text, img1);
  }
  else{
    print('ERROR! While fetching the image!');
  }
  String hmacKeyString = await retrieve_hmac_key(storage) as String;

  Uint8List HmacKeyBytes = fromStringToUint8List(hmacKeyString);
  hmac_code = calculate_hmac(plain_text, HmacKeyBytes);



  recieveMessage(img1!, hmac_code, storage);

}


void recieveMessage(img_library.Image img1, Uint8List hmac, FlutterSecureStorage storage) async{


  String extracted_cipher_text = await lsb.extract_from_image(img1);
  if(extracted_cipher_text != ''){
    String? retrieved_pem = await storage.read(key: 'private_key');
    RSAPrivateKey retrieved_private_key = rsa_helper.CryptoUtils.rsaPrivateKeyFromPem(retrieved_pem!);
    String plain_text = decrypt_message(extracted_cipher_text, retrieved_private_key);

    String hmacKeyString = await retrieve_hmac_key(storage) as String;
    Uint8List HmacKeyBytes = fromStringToUint8List(hmacKeyString);
    Uint8List hmac_code = calculate_hmac(plain_text, HmacKeyBytes);

    if(fromUint8ListToString(hmac_code) != fromUint8ListToString(hmac)){
      print('Message Were Altered Please send again!');
    }
    else{
      print('plain text extracted is $plain_text');
    }




  }
  else{
    print('extracted cipher text is null!');
  }
}


void store_hmac_key(String hmac_key, FlutterSecureStorage storage){
  storage.write(key: 'hmac_key', value: hmac_key);
}

Future<String> retrieve_hmac_key(FlutterSecureStorage storage) async{
  String key_str = '';
  key_str = await storage.read(key: 'hmac_key') as String;
  return key_str;
}




