import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:core';
import 'package:chat_bubbles/bubbles/bubble_normal.dart';
import 'package:p2pproje/lsb-steganography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:image/image.dart' as img_library;
import 'rsa.dart';
import 'package:flutter/material.dart';
import 'package:peerdart/peerdart.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'crypto.dart' as rsa_helper;




class DataConnectionExample extends StatefulWidget {
  const DataConnectionExample({Key? key}) : super(key: key);

  @override
  State<DataConnectionExample> createState() => _DataConnectionExampleState();
}

class _DataConnectionExampleState extends State<DataConnectionExample> {
  Peer peer = Peer(options: PeerOptions(debug: LogLevel.All));
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _messagecontroller = TextEditingController();
  String msgValue = "";
  String? peerId;
  late DataConnection conn;
  bool connected = false;
  bool recievedTargetKey = false;
  String recieved = "";
  String recipientPublicKeyPem = "";
  String myPublicKeyPem = "myPublicKeyPem";
  final pair = generateRSAkeyPair(exampleSecureRandom());
  late RSAPublicKey public_key;
  late RSAPrivateKey private_key;
  var sleepDuration = Duration(milliseconds: 500);
  FlutterSecureStorage storage = new FlutterSecureStorage();
  @override
  void dispose() {
    peer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    peer.on("open").listen((id) {
      setState(() {
        peerId = peer.id;
        public_key = pair.publicKey as RSAPublicKey;
        private_key = pair.privateKey as RSAPrivateKey;
        myPublicKeyPem = rsa_helper.CryptoUtils.encodeRSAPublicKeyToPem(public_key);
        String myPrivatePem = rsa_helper.CryptoUtils.encodeRSAPrivateKeyToPem(private_key!);
        // storage.write(key: "private_key", value: myPrivatePem);
        myPrivatePem = "";

      });
    });

    peer.on<DataConnection>("connection").listen((event) {
      conn = event;


      conn.on("data").listen((data) {

        if(data[0] == '-' && data[1] == '-' && data[2] == '-' && data[3] == '-'){
          if(!recievedTargetKey){
            sendPublicKey();
          }
          setState(() {
            recipientPublicKeyPem = data;
            recievedTargetKey = true;
          });
        }
        else{

          setState(() {
            recieved = data;
          });
        }


      });

      conn.on("binary").listen((data) {
        img_library.Image? recievedImg = img_library.decodePng(data);
        String retrievedCipher = extract_from_image(recievedImg!);
        // RSAPrivateKey? tmpPrivate = retrievePrivateKey(storage) as RSAPrivateKey?;
        String plain_text  = decrypt_message(retrievedCipher, private_key);
        setState(() {
          recieved = plain_text;
        });
      });

      conn.on("close").listen((event) {
        setState(() {
          connected = false;
        });
      });

      setState(() {
        connected = true;
        // sendHelloWorld(myPublicKeyPem);
        sendPublicKey();
      });

    });
  }

  void connect() {
    final connection = peer.connect(_controller.text);
    conn = connection;


    conn.on("open").listen((event) {

      setState(() {
        connected = true;
        // sendHelloWorld(myPublicKeyPem);
        sendPublicKey();
      });

      connection.on("close").listen((event) {
        setState(() {
          connected = false;
        });
      });

      conn.on("data").listen((data) {

        if(data[0] == '-' && data[1] == '-' && data[2] == '-' && data[3] == '-'){



          if(!recievedTargetKey){

            sendPublicKey();
          }
          setState(() {
            recipientPublicKeyPem = data;
            recievedTargetKey = true;
          });
        }
        else{

          setState(() {
            recieved = data;
          });
        }


      });

      conn.on("binary").listen((data) {

        img_library.Image? recievedImg = img_library.decodePng(data);

        String retrievedCipher = extract_from_image(recievedImg!);


        // RSAPrivateKey? tmpPrivate = retrievePrivateKey(storage) as RSAPrivateKey?;
        String plain_text  = decrypt_message(retrievedCipher, private_key);

        setState(() {
          recieved = plain_text;
        });

      });

    });
  }

  void sendHelloWorld(msg) {

    conn.send(msg);
  }

  void sendPublicKey(){

    conn.send(myPublicKeyPem);
  }

  void sendBinary(dynamic msg) async{
    img_library.Image? myImg = await getImage();
    if(myImg == null){
      print('couldnt get image!');
    }
    RSAPublicKey recipientKey = rsa_helper.CryptoUtils.rsaPublicKeyFromPem(recipientPublicKeyPem);
    String cipherText = encrypt_message(msg, recipientKey);
    myImg = await embed_to_image(cipherText, myImg!) as img_library.Image;
    final bytes = img_library.encodePng(myImg) as Uint8List;
    // final bytes = Uint8List(30);
    conn.sendBinary(bytes);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(),
      body: connected? buildChatBody(): myCustomBody(),

    );
  }

  Widget _renderState() {
    Color bgColor = connected ? Colors.green : Colors.grey;
    Color txtColor = Colors.white;

    String txt = connected ? "Connected" : "Standby";
    if(connected){
      sendHelloWorld(myPublicKeyPem);
      return buildChatBody();
    }
    return Container(
      decoration: BoxDecoration(color: bgColor),
      child: Text(
        txt,
        style:
        Theme.of(context).textTheme.titleLarge?.copyWith(color: txtColor),
      ),
    );
  }




  buildChatBody(){

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          children: [
            buildSentMessageBubble(),
            buildRecievedMessageBubble(recieved),
          ],
        ),

        buildMessageInputBar(),
      ],
    );
  }
//
  buildSentMessageBubble(){
    return BubbleNormal(
      text: msgValue,
      color: Color(0xFF1b97f3),
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,

      ),
      isSender: true,
      tail: true,
    );
  }


  buildRecievedMessageBubble(msg){
    return BubbleNormal(
      text: msg,
      color: Color(0xFFe8E8EE),
      textStyle: TextStyle(
        color: Colors.black,
        fontSize: 20,
      ),
      isSender: false,
      tail: true,
    );

  }


  myCustomBody(){
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _renderState(),
          const Text(
            'Connection ID:',
          ),
          SelectableText(peerId ?? ""),
          TextField(
            controller: _controller,
          ),
          ElevatedButton(onPressed: connect, child: const Text("connect")),

        ],
      ),
    );
  }

//
  buildMessageInputBar(){
    return SafeArea(child:  Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            child: TextFormField(
              controller: _messagecontroller,//stringi tutuyor
              decoration: InputDecoration(
                labelText: "",
              ),
            ),
            width: 350.0,

          ),
          ElevatedButton(
              onPressed: (){
                sendBinary(_messagecontroller.text);
                setState(() {
                  msgValue = _messagecontroller.text;
                });
                _messagecontroller.text = "";
              },
              child: Icon(Icons.send))
        ],
      ),
    )

    );



  }


  Future<RSAPrivateKey> retrievePrivateKey(FlutterSecureStorage storage) async {
    String pr_str = await storage.read(key: "private_key") as String;
    RSAPrivateKey myPrivate = rsa_helper.CryptoUtils.rsaPrivateKeyFromPem(pr_str);
    return myPrivate;
  }

}



