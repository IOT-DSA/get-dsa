library get_dsa.elements.header;

import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_tabs.dart';
import 'package:paper_elements/paper_tab.dart';

GetDsaHeaderElement dsaHeader;

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

  void buttonClick() {
    asyncFire("menu-toggle");
  }

  void changeTab(String name) {
    ($["navTabs"] as PaperTabs).selected = tabs.indexOf(name);
  }
}
