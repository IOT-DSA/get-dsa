library get_dsa.elements.packager;

import 'dart:async';
import 'dart:js';
import 'dart:html';
import 'dart:convert';

import 'package:polymer/polymer.dart';
import 'package:get_dsa/bdist.dart';
import 'package:core_elements/core_menu.dart';
import 'package:paper_elements/paper_spinner.dart';
import 'package:paper_elements/paper_item.dart';
import 'package:get_dsa/packager.dart';
import 'package:get_dsa/utils.dart';
import 'package:paper_elements/paper_checkbox.dart';
import 'get_dsa_header.dart';

String createPlatformHelp(String platform) {
  String howToStart = """
  <p>
  Open a Terminal and change to the dglux_server directory in the extracted ZIP location.<br/>
  Run the following commands:<br/>
  <code>
  chmod 777 bin/*.sh<br/>
  ./bin/daemon.sh start
  </code><br/>
  You should be able to access DGLux5 at: http://localhost:8080<br/>
  Default credentials are: dgSuper / dglux1234<br/>
  </p>

  <p>Your DSA instance is now running!</p>
  """;

  if (platform.contains("Windows")) {
    howToStart = """
    <p>
    Navigate to the dglux_server folder in the extracted ZIP location.<br/>
    Open a new Command Prompt here.<br/>
    Run the following command:<br/>
    <code>
    bin\\daemon.bat start
    </code><br/>
  You should be able to access DGLux5 at: http://localhost:8080<br/>
  Default credentials are: dgSuper / dglux1234<br/>
    </p>

    <p>Your DSA instance is now running!</p>
    """;
  }

  return """
  <h3 style="text-align: center;">Installation Instructions</h3>
  Extract the ZIP file provided by the Get DSA Packager.<br/>
  ${howToStart}
  """;
}

@CustomTag('get-dsa-packager')
class GetDsaPackagerElement extends PolymerElement {
  GetDsaPackagerElement.created() : super.created();

  String selectedDistributionVersion = "latest";

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

  @observable
  List<String> distv = toObservable([]);

  @override
  attached() {
    super.attached();
    loadDistributions().then((d) => dists.addAll(d));
    loadLinks().then((l) => links.addAll(l.map((x) => new DSLinkModel(x))));

    var pe = $["platform"] as CoreMenu;
    pe.on["core-select"].listen((e) {
      onPlatformSelected();
    });

    var dt = $["dist-type"] as CoreMenu;
    dt.on["core-select"].listen((e) {
      onDistSelected();
    });

    $["sdb-dd"].on["core-select"].listen((e) {
      $["sdb-dd"].close();
      selectedDistributionVersion = ($["sdb-dm"].selectedItem).text;
    });

    $["sdb-ib"].onClick.listen((e) {
      $["sdb-dd"].open();
    });
  }

  @override
  detached() {
    super.detached();
  }

  onDistSelected() {
    new Future(() async {
      String distId = (($["dist-type"] as CoreMenu).selectedItem as PaperItem).attributes["value"];
      List<String> versions = await getDistributionVersions(distId);
      distv.clear();
      distv.addAll(versions);
    });
  }

  onPlatformSelected() {
    new Future(() {
      String platformName = (($["platform"] as CoreMenu).selectedItem as PaperItem).attributes["value"];

      print("Selected Platform: ${platformName}");

      $["help"].setInnerHtml(createPlatformHelp(platformName), validator: new NullTreeValidator());
    });
  }

  selectAllLinks() {
    shadowRoot.querySelectorAll(".link-checkbox").forEach((PaperCheckbox box) {
      box.checked = true;
    });
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
    var distArchive = await dist.download(selectedDistributionVersion);
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
      var pkg = new DSLinkPackage(l["name"], archive);
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

    var package = buildPackage(dist.directoryName, distArchive, dartSdkArchive, pkgs, platform: rp, wrappers: dist.wrappers);
    print("Built Package.");
    await new Future.value();
    var blob = new Blob([await compressZip(package)], "application/zip");
    await new Future.value();
    status.text = "Downloading Package";
    print("Downloading Package...");
    context.callMethod("download", [blob, "dsa.zip"]);
    print("Complete!");
    status.text = "";
    spinner.active = false;
  }

  Future<List<String>> getDistributionVersions(String name) async {
    var content = await HttpRequest.getString("https://api.github.com/repos/IOT-DSA/dists/contents/${name}");
    var data = JSON.decode(content);
    var x = data.map((x) => x["name"]).toList();
    x.sort();
    return x.reversed.toList();
  }
}

class DSLinkModel {
  final Map<String, dynamic> json;

  DSLinkModel(this.json);

  String get displayName => json["displayName"];
  String get type => json["type"];
  String get zip => json["zip"];
  String get description => json["description"];

  dynamic operator [](String name) {
    return json[name];
  }
}
