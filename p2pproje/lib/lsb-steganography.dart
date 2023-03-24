

import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart';
import 'package:image_downloader/image_downloader.dart';
import 'package:image/image.dart' as img_library;
import 'package:flutter/material.dart';
import 'rsa.dart' as util_encryption;






Future<img_library.Image?> embed_to_image(String cipher_text, img_library.Image img1) async {
  int tmp = 0;
  int color;
  int j =0;
  int i = 0;
  int tmpColor = img1.getPixel(img1.width-1, img1.height-1);
  int tmp_len =  (cipher_text.length/256).floor();
  int tmp_remainder = cipher_text.length%256;
  img1.setPixel(img1.width-1, img1.height-1, getColor(tmp_len, tmp_remainder, getBlue(tmpColor)));

  String binary_cipher = my_encode(cipher_text);

  if(img1 != null) {

    while(tmp < binary_cipher.length && i < img1.width){
      j = 0;
      while(tmp < binary_cipher.length && j < img1.height){
        color = img1.getPixel(i, j);

        int red = getRed(color);
        int green = getGreen(color);
        int blue = getBlue(color);

        if(tmp  < binary_cipher.length){
          red = (red + insert_bit(red, binary_cipher, tmp))%256;
          tmp++;
        }
        if(tmp < binary_cipher.length){
          green = (green + insert_bit(green, binary_cipher, tmp))%256;
          tmp++;
        }
        if(tmp < binary_cipher.length){
          blue = (blue + insert_bit(blue, binary_cipher, tmp))%256;
          tmp++;
        }

        img1.setPixel(i, j, getColor(red, green, blue,0));
        j++;
      }
      i++;
    }

  }
  return img1;
}

//
Future<img_library.Image?> getImage() async{

  var fileName;
  var path;
  var size;
  var mimeType;

  try {
    // Saved with this method.
    var imageId = await ImageDownloader.downloadImage(
        "https://raw.githubusercontent.com/wiki/ko2ic/image_downloader/images/flutter.png");
    if (imageId == null) {
      return null;
    }

    // Below is a method of obtaining saved image information.
    fileName = await ImageDownloader.findName(imageId);
    path = await ImageDownloader.findPath(imageId);
    size = await ImageDownloader.findByteSize(imageId);
    mimeType = await ImageDownloader.findMimeType(imageId);
  } on PlatformException catch (error) {
    print(error);
  }

  img_library.Image? img = img_library.decodePng(io.File(path).readAsBytesSync());


  return img;
}


String extract_from_image(img_library.Image img1){
  String binary_cipher = '';
  int tmp = 0;
  // int final_len = string_length * 8;
  int tmpColor = img1.getPixel(img1.width-1, img1.height-1);
  int division = getRed(tmpColor)*256;
  int remainder = getGreen(tmpColor);
  int final_len = (division+remainder)*8;
  // final_len = final_len*256*8;
  int color;
  int j;
  int i = 0;

  while(tmp<final_len && i < img1.width){
    j = 0;
    while(tmp < final_len &&  j < img1.height){
      color = img1.getPixel(i, j);
      // print('before: $color');
      int red = getRed(color);
      int green = getGreen(color);
      int blue = getBlue(color);


      if(tmp < final_len) {
        if (red % 2 == 0) {
          binary_cipher = binary_cipher + '0';
        }
        else {
          binary_cipher = binary_cipher + '1';
        }
        tmp++;
      }

      if(tmp < final_len) {
        if (green % 2 == 0) {
          binary_cipher = binary_cipher + '0';
        }
        else {
          binary_cipher = binary_cipher + '1';
        }
        tmp++;
      }

      if(tmp < final_len) {
        if (blue % 2 == 0) {
          binary_cipher = binary_cipher + '0';
        }
        else {
          binary_cipher = binary_cipher + '1';
        }
        tmp++;
      }

      j++;
    }
    i++;
  }


  // print(binary_cipher.length);

  binary_cipher = binary_cipher.replaceAllMapped(RegExp(r".{8}"), (match) => "${match.group(0)} "); // her 8 biti gruplayip bosluk birakir
  //sona bir bosluk daha ekliyor
  if(binary_cipher != null && binary_cipher.length > 0){ // son boslugu sil
    binary_cipher = binary_cipher.substring(0,binary_cipher.length-1); // parse ederken sonuna bir bosluk atiyor onu sil!
  }

  String str = my_decode(binary_cipher); // string e cevir
  return str;

}


int getRed(int color) => (color) & 0xff;// verilen
int getGreen(int color) => (color >> 8) & 0xff;
int getBlue(int color) => (color >> 16) & 0xff;

int insert_bit(int x, String binary_cipher,int  tmp){
  if(x % 2 == 0){ // rengin degeri cift ise

    if(binary_cipher[tmp].compareTo('0') == 0){// ve 0 eklemek istiyorsak aynen birak
      // cunku son biti 0 zaten
      return 0;
    }
    else{
      // eger sayi ciftse ve biz 1 eklemek istiyorsak 1 ekle.
      //fonksiyonun donus degeri initial color degeriyle toplaniyor.
      return 1;
    }
  }
  else{
    //eger rengin degeri tek ise ve 0 kodlamak istiyorsak 1 ekle
    if(binary_cipher[tmp].compareTo('0') == 0){
      return 1;
    }
    else{
      //eger sayimiz tek ve biz 1 kodlamak istiyorsak 0 ekle
      return 0;
    }
  }
}


String my_encode(String value) {// string i binary string  e cevirir.

  return value.codeUnits.map((v) => v.toRadixString(2).padLeft(8, '0')).join("");
}

String my_decode(String value) {//binary string i string e cevirir
  //NOTE: bitleri 8 er gruplamak lazim. bunu kullanmak icin


  return String.fromCharCodes(value.split(" ").map( (v) => util_method(v)));
}

int util_method(String v){ //my_decode fonksiyonu icin yardimci metod.
  //boslugu parse etmesin diye

  if(v.length != 0){
    return int.parse(v,radix: 2);
  }

  return 0;
}


