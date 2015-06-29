import 'dart:html';
import 'package:polymer/polymer.dart';
import 'lib/get_dsa_app.dart';

main() async {
  await initPolymer();
}

@initMethod
initialize() {
  Polymer.onReady.then((_) {
    (querySelector("get-dsa-app") as GetDsaAppElement).windowResize(window.innerWidth);
  });
}
