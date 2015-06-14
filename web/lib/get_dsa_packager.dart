library get_dsa.elements.packager;

import 'dart:js';
import 'dart:html';

import 'package:polymer/polymer.dart';
import 'package:get_dsa/bdist.dart';
import 'package:core_elements/core_menu.dart';
import 'package:paper_elements/paper_item.dart';
import 'package:get_dsa/packager.dart';
import 'package:get_dsa/utils.dart';

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
    "DGBox": "dgbox"
  });

  @observable
  List<Distribution> dists = toObservable([]);

  @override
  attached() {
    super.attached();
    loadDistributions().then((d) => dists.addAll(d));
  }

  createDistPackage() async {
    String platformName = (($["platform"] as CoreMenu).selectedItem as PaperItem).attributes["value"];
    String distId = (($["dist-type"] as CoreMenu).selectedItem as PaperItem).attributes["value"];
    String platform = platforms[platformName];
    Distribution dist = dists.firstWhere((x) => x.id == distId);

    print("Fetching Distribution...");
    var distArchive = await dist.download();
    print("Distribution Fetched.");
    print("Fetching Dart SDK...");
    var dartSdkArchive = await fetchDartSdk(platform);
    print("Dart SDK Fetched.");
    print("Building Package...");

    var rp = "unknown";

    if (platform.startsWith("linux-")
      || platform == "dgbox"
      || platform == "arm"
      || platform == "ci20") {
      rp = "linux";
    } else if (platform.startsWith("windows-")) {
      rp = "windows";
    } else if (platform.startsWith("macos-")) {
      rp = "mac";
    }

    var package = buildPackage(distArchive, dartSdkArchive, [], platform: platform.split("-").first);
    print("Built Package.");
    await null;
    var blob = new Blob([await compressZip(package)], "application/zip");
    await null;
    print("Downloading Package...");
    context.callMethod("download", [blob, "dsa.zip"]);
    print("Complete!");
  }
}
