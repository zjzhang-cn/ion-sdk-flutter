import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter_ion/flutter_ion.dart' as ion;

class Controller extends GetxController {
  Rx<RTCVideoRenderer> localRenderer = RTCVideoRenderer().obs;
  Rx<RTCVideoRenderer> remoteRenderer = RTCVideoRenderer().obs;

  @override
  @mustCallSuper
  void onInit() {
    super.onInit();
    localRenderer.value.initialize();
    remoteRenderer.value.initialize();
  }

  set localSrcObject(MediaStream stream) {
    localRenderer.value.srcObject = stream;
    localRenderer.refresh();
  }

  set remoteSrcObject(MediaStream stream) {
    remoteRenderer.value.srcObject = stream;
    remoteRenderer.refresh();
  }
}

class EchoTestView extends StatelessWidget {
  final Controller c = Get.put(Controller());
  ion.Signal _signalLocal;
  ion.Signal _signalRemote;
  ion.Client _clientPub;
  ion.Client _clientSub;
  ion.LocalStream _localStream;

  void _echotest() async {
    if (_clientPub == null) {
      _signalLocal = ion.JsonRPCSignal("ws://192.168.1.2:7000/ws");

      _clientPub = await ion.Client.create(
          sid: "echotest-session", signal: _signalLocal);

      _localStream = await ion.LocalStream.getUserMedia(
          constraints: ion.Constraints.defaults..simulcast = false);
      await _clientPub.publish(_localStream);

      c.localSrcObject = _localStream.stream;
    } else {
      await _localStream.unpublish();
      _localStream.stream.getTracks().forEach((element) {
        element.dispose();
      });
      _localStream.stream.dispose();
      _localStream = null;
      _clientPub.close();
      _clientPub = null;
      c.localSrcObject = null;
    }

    if (_clientSub == null) {
      _signalRemote = ion.JsonRPCSignal("ws://192.168.1.2:7000/ws");
      _clientSub = await ion.Client.create(
          sid: "echotest-session", signal: _signalRemote);
      _clientSub.ontrack = (track, ion.RemoteStream stream) {
        if (track.kind == 'video') {
          print('ontrack: stream => ${stream.id}');
          c.remoteSrcObject = stream.stream;
          Timer(Duration(seconds: 4), () {
            stream.preferLayer(ion.Layer.low);
          });
        }
      };
    } else {
      _clientSub.close();
      _clientSub = null;
      c.remoteSrcObject = null;
    }
  }

  @override
  Widget build(context) => Scaffold(
      appBar: AppBar(title: Text("echotest")),
      body: Center(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text("Local"),
          Obx(() => Expanded(child: RTCVideoView(c.localRenderer.value))),
          Text("Remote"),
          Obx(() => Expanded(child: RTCVideoView(c.remoteRenderer.value)))
        ],
      )),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.video_call), onPressed: _echotest));
}
