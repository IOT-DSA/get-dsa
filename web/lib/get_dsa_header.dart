library get_dsa.elements.header;

import "dart:html";

import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_tabs.dart';
import 'package:paper_elements/paper_tab.dart';
import 'get_dsa_app.dart';

GetDsaHeaderElement dsaHeader;

Function toggleHelpButton;

class NullTreeValidator implements NodeValidator {
  @override
  bool allowsAttribute(Element element, String attributeName, String value) {
    return true;
  }

  @override
  bool allowsElement(Element element) {
    return true;
  }
}

void setHelpContent(String stuff) {
  helpDialog.setInnerHtml(stuff, validator: new NullTreeValidator());
}

@CustomTag('get-dsa-header')
class GetDsaHeaderElement extends PolymerElement {
  final List<String> tabs = ["Welcome", "Packager"];
  final String branding = "Get DSA";

  GetDsaHeaderElement.created() : super.created() {
    dsaHeader = this;
    addEventListener('core-select', (_) {
      try {
        var selected = (($["navTabs"] as PaperTabs).selectedItem as PaperTab).attributes["label"];
        if (selected != null) {
          asyncFire("page-change", detail: selected);
        }
      } catch (e) {}
    });
  }

  @override
  attached() {
    Element help = $["help"];
    toggleHelpButton = (on) {
      help.hidden = !on;
    };

    help.onClick.listen((e) {
      helpDialog.open();
    });
  }

  void buttonClick() {
    asyncFire("menu-toggle");
  }

  void changeTab(String name) {
    ($["navTabs"] as PaperTabs).selected = tabs.indexOf(name);
  }
}
