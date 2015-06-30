library paper_elements.paper_table;

import "package:polymer/polymer.dart";

@CustomTag("paper-table")
class PaperTable extends PolymerElement {
  @published int shadow = 1;
  @published List columns = [];

  PaperTable.created() : super.created();

  @override
  void attached() {
    super.attached();
  }
}
