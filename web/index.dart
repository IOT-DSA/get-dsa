import 'dart:html';
import 'package:polymer/polymer.dart';
import 'package:get_dsa/workers.dart';
import 'lib/get_dsa_app.dart';

main() async {
  await initPolymer();
}

@initMethod
initialize() {
  print("Initialize");

  Polymer.onReady.then((_) {
    (querySelector("get-dsa-app") as GetDsaAppElement).windowResize(window.innerWidth);
  });

  startWorkers();
}
