import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_biometrics/flutter_biometrics.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _publicKey = 'Not retrieved/Not set';
  String _signature = 'Unknown';
  String _payload = 'Zmx1dHRlcl9iaW9tZXRyaWNz';

  @override
  void initState() {
    super.initState();
  }

  Future<void> createKeys() async {
    var biometrics = FlutterBiometrics();
    String publicKey = await biometrics.createKeys(
        reason: 'Please authenticate to create public/private key pair');

    setState(() {
      _publicKey = publicKey;
    });

    if (!mounted) return;
  }

  Future<void> sign() async {
    var biometrics = FlutterBiometrics();
    String signature = await biometrics.sign(
        payload: _payload,
        reason: 'Please authenticate to sign specified payload');

    setState(() {
      _signature = signature;
    });

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('flutter_biometrics'),
          backgroundColor: Colors.blueGrey,
        ),
        body: ListView(
          children: <Widget>[
            Container(
              margin: EdgeInsets.only(top: 20.0),
              alignment: Alignment.center,
              child: Text("1. Generate a key pair", style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),),
            ),
            Container(
              alignment: Alignment.center,
              margin: EdgeInsets.only(top: 20.0),
              child: RaisedButton(
                onPressed: createKeys,
                child: Text("Create keys"),
              ),
            ),
            Container(
              alignment: Alignment.center,
              width: double.infinity,
              padding: EdgeInsets.all(10.0),
              child: Text(
                "Public key: $_publicKey",
                style: TextStyle(color: Colors.white),
              ),
              margin: EdgeInsets.only(top: 10.0),
              color: Colors.blueGrey,
            ),
            Container(
              margin: EdgeInsets.only(top: 20.0, bottom: 10.0),
              alignment: Alignment.center,
              child: Text("2. Provide a payload to sign", style: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),),
            ),
            Container(
              margin: EdgeInsets.only(top: 20.0),
              alignment: Alignment.center,
              padding: EdgeInsets.all(10.0),
              child: TextField(
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Payload to sign (Base64 encoded)',
                  hintText: 'Zmx1dHRlcl9iaW9tZXRyaWNz',
                ),
                onChanged: (value) {
                  setState(() {
                    _payload = value;
                  });
                },
              ),
            ),
            Center(
              child: RaisedButton(
                onPressed: sign,
                child: Text("Sign '$_payload'"),
              ),
            ),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: EdgeInsets.all(10.0),
              child: Text(
                "Signature: $_signature",
                style: TextStyle(color: Colors.white),
              ),
              margin: EdgeInsets.only(top: 10.0),
              color: Colors.blueGrey,
            ),
          ],
        ),
      ),
    );
  }
}
