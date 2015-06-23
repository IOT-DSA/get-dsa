library get_dsa.elements.app;

import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:core_elements/core_drawer_panel.dart';
import 'package:paper_elements/paper_dialog.dart';

PaperDialog helpDialog;

@CustomTag('get-dsa-app')
class GetDsaAppElement extends PolymerElement {
  int _preWidth = 0;

  GetDsaAppElement.created() : super.created();

  @override
  attached() {
    super.attached();

    $["header"].addEventListener('menu-toggle', (_) {
      toggleDrawer();
    });

    $["header"].addEventListener('page-change', (CustomEvent event) {
      String page = event.detail.toLowerCase();
      DivElement e = $["content"];
      var pageElement = document.createElement("get-dsa-${page}");
      e.children.clear();
      e.classes.add("content-page");
      e.children.add(pageElement);
    });

    helpDialog = $["help-dialog"];
  }

  toggleDrawer() => ($["our-drawer"] as CoreDrawerPanel).togglePanel();
  closeDrawer() => ($["our-drawer"] as CoreDrawerPanel).closeDrawer();

  windowResize(int width) {
    if (width >= 768 && width > _preWidth) {
      (querySelector("get-dsa-app") as GetDsaAppElement).closeDrawer();
    }
    _preWidth = width;
  }
}
