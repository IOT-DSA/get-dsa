library get_dsa.elements.packager;

import 'dart:js';
import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:get_dsa/bdist.dart';
import 'package:core_elements/core_menu.dart';
import 'package:paper_elements/paper_spinner.dart';
import 'package:paper_elements/paper_item.dart';
import 'package:get_dsa/packager.dart';
import 'package:get_dsa/utils.dart';
import 'package:paper_elements/paper_checkbox.dart';

@CustomTag('get-dsa-packager')
class GetDsaPackagerElement extends PolymerElement {
  GetDsaPackagerElement.created() : super.created();

  @observable
  Map<String, String> platforms = toObservable({
    "x86 Windows": "windows-ia32",
    "x64 Windows": "windows-x64",
    "x86 Linux": "linux-ia32",
    "x64 Linux": "linux-x64",
    "x86 Mac OS": "macos-ia32",
    "x64 Mac OS": "macos-x64",
    "ARM Linux": "arm",
    "DGBox": "dgbox",
    "Beaglebone": "beaglebone",
    "MIPS Creator CI20": "ci20"
  });

  @observable
  List<DSLinkModel> links = toObservable([]);

  @observable
  List<Distribution> dists = toObservable([]);

  @override
  attached() {
    super.attached();
    loadDistributions().then((d) => dists.addAll(d));
    loadLinks().then((l) => links.addAll(l.map((x) => new DSLinkModel(x))));
  }

  createDistPackage() async {
    String platformName = (($["platform"] as CoreMenu).selectedItem as PaperItem).attributes["value"];
    String distId = (($["dist-type"] as CoreMenu).selectedItem as PaperItem).attributes["value"];
    List<DSLinkModel> ourLinks = shadowRoot.querySelectorAll(".link-checkbox").where((PaperCheckbox box) {
      return box.checked;
    }).map((PaperCheckbox box) => links.firstWhere((l) => l.displayName == box.getAttribute("value"))).toList();
    String platform = platforms[platformName];
    Distribution dist = dists.firstWhere((x) => x.id == distId);

    var spinner = $["spinner"] as PaperSpinner;
    spinner.active = true;

    var status = $["status"] as ParagraphElement;

    print("Fetching Distribution...");
    status.text = "Fetching Distribution";
    var distArchive = await dist.download();
    print("Distribution Fetched.");
    print("Fetching Dart SDK...");
    status.text = "Fetching Dart SDK";
    var dartSdkArchive = await fetchDartSdk(platform);
    print("Dart SDK Fetched.");

    var pkgs = <DSLinkPackage>[];

    print("Fetching DSLinks...");
    for (var l in ourLinks) {
      print("Fetching DSLink '${l["displayName"]}'");
      status.text = "Fetching DSLink '${l["displayName"]}'";
      var archive = await fetchArchive(l["zip"]);
      var pkg = new DSLinkPackage(l["displayName"], archive);
      pkgs.add(pkg);
      pkg.rewriteFilePaths();
      print("DSLink '${l["displayName"]}' fetched.");
    }
    print("DSLinks Fetched.");

    status.text = "Building Package";

    print("Building Package...");

    var rp = "unknown";

    if (platform.startsWith("linux-")
      || platform == "dgbox"
      || platform == "beaglebone"
      || platform == "arm"
      || platform == "ci20") {
      rp = "linux";
    } else if (platform.startsWith("windows-")) {
      rp = "windows";
    } else if (platform.startsWith("macos-")) {
      rp = "mac";
    }

    var package = buildPackage(dist.id, distArchive, dartSdkArchive, pkgs, platform: rp, wrappers: dist.wrappers);
    print("Built Package.");
    await null;
    var blob = new Blob([await compressZip(package)], "application/zip");
    await null;
    status.text = "Downloading Package";
    print("Downloading Package...");
    context.callMethod("download", [blob, "dsa.zip"]);
    print("Complete!");
    status.text = "";
    spinner.active = false;
  }
}

class DSLinkModel {
  final Map<String, dynamic> json;

  DSLinkModel(this.json);

  String get displayName => json["displayName"];
  String get type => json["type"];
  String get zip => json["zip"];

  dynamic operator [](String name) {
    return json[name];
  }
}
