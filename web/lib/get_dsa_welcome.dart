library get_dsa.elements.welcome;

import 'package:polymer/polymer.dart';

import 'get_dsa_header.dart';

@CustomTag('get-dsa-welcome')
class GetDsaWelcomeElement extends PolymerElement {
  GetDsaWelcomeElement.created() : super.created();
  buildPackage() {
    dsaHeader.changeTab("Packager");
  }
}
