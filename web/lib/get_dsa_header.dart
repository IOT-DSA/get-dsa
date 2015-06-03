library get_dsa.elements.header;

import 'package:polymer/polymer.dart';
import 'package:paper_elements/paper_tabs.dart';
import 'package:paper_elements/paper_tab.dart';

@CustomTag('get-dsa-header')
class GetDsaHeaderElement extends PolymerElement {
  final List<String> tabs = ["Welcome", "Download"];
  final String branding = "Get DSA";

  GetDsaHeaderElement.created() : super.created() {
    addEventListener('core-select', (_) {
      var selected = (($["navTabs"] as PaperTabs).selectedItem as PaperTab);
      if (selected != null) {
        asyncFire("page-change", detail: selected.text);
      }
    });
  }

  void buttonClick() {
    asyncFire("menu-toggle");
  }
}
