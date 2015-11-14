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
import 'get_dsa_header.dart';

String createPlatformHelp(String platform) {
  String howToStart = """
  <p>
  Open a Terminal and change to the dglux-server directory in the extracted ZIP location.<br/>
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
    Navigate to the dglux-server folder in the extracted ZIP location.<br/>
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
  ${howToStart}<br/>
  If you have a license for a previous installation that was generated before the 8th of July in 2015, please request a new license, and a new one will be generated for you.<br/>
  """;
}

class Filter {
  final String field;
  final String value;

  Filter(this.field, this.value);
}

@CustomTag('get-dsa-packager')
class GetDsaPackagerElement extends PolymerElement {
  GetDsaPackagerElement.created() : super.created();

  String selectedDistributionVersion = "latest";

  @observable
  bool supported = true;

  @observable
  ObservableMap<String, String> platforms = toObservable({
    "x86 Windows": "windows-ia32",
    "x64 Windows": "windows-x64",
    "x86 Linux": "linux-ia32",
    "x64 Linux": "linux-x64",
    "x64 Linux (Static)": "x64_Linux_StaticGLibC",
    "x86 Mac OS": "macos-ia32",
    "x64 Mac OS": "macos-x64",
    "ARM Linux": "linux-arm",
    "Dreamplug": "dreamplug",
    "Beaglebone": "beaglebone",
    "MIPS Creator CI20": "ci20",
    "ARM am335x": "am335x"
  });

  void addFilter(Filter filter) {
    filters.add(filter);
    refilter();
  }

  void removeFilter(String n, String v) {
    filters.removeWhere((x) => x.field == n && x.value == v);
    refilter();
  }

  void refilter() {
    if (filters.isEmpty) {
      links.forEach((x) => x.show = true);
      return;
    }

    links.forEach((x) => x.show = false);
    for (var f in filters) {
      for (var l in links) {
        l.show = l.show || l.json[f.field] == f.value;
      }
    }

    links.forEach((x) {
      if (!x.show && x.selected) {
        x.selected = false;
      }
    });
  }

  @observable
  ObservableList<DSLinkModel> links = toObservable([]);

  @observable
  ObservableList<Distribution> dists = toObservable([]);

  @observable
  ObservableList<String> distv = toObservable([]);

  @observable
  ObservableList<DSLinkLanguage> languages = toObservable([]);

  @observable
  ObservableList<DSLinkCategory> categories = toObservable([]);

  List<Filter> filters = [];

  @override
  attached() {
    super.attached();

    if (!(window.navigator.userAgent.contains("Chrome") || window.navigator.userAgent.contains("Chromium"))) {
      supported = false;
      return;
    }

    loadDistributions().then((d) => dists.addAll(d));
    loadLinks().then((l) {
      links.addAll(l.map((x) => new DSLinkModel(x)));
      links.forEach((x) {
        var language = x.language;
        if (!languages.any((l) => l.name == language)) {
          var lang = new DSLinkLanguage(language);
          languages.add(lang);
          lang.changes.listen((e) {
            for (PropertyChangeRecord change in e) {
              if (change.name == #filtered) {
                var val = change.newValue;

                if (val) {
                  addFilter(new Filter("type", lang.name));
                } else {
                  removeFilter("type", lang.name);
                }
              }
            }
          });
        }

        var category = x.category;

        if (!categories.any((l) => l.name == category)) {
          var cat = new DSLinkCategory(category);
          categories.add(cat);
          cat.changes.listen((e) {
            for (PropertyChangeRecord change in e) {
              if (change.name == #filtered) {
                var val = change.newValue;

                if (val) {
                  addFilter(new Filter("category", cat.name));
                } else {
                  removeFilter("category", cat.name);
                }
              }
            }
          });
        }
      });
    });

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

    var ld = $["links-dialog"];
    ld.$["scroller"].style.width = "1024px";
    ld.on["core-overlay-close-completed"].listen((e) {
      var count = links.where((x) => x.selected).length;
      var verb = count == 1 ? "link" : "links";
      var msg = "${count} ${verb} selected.";
      $["links-count"].text = msg;
    });

    CssStyleDeclaration decl = ld.$["scroller"].style;
    decl.overflowY = "scroll";
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

      var type = getPlatformType(platformName);

      for (var x in links) {
        if (x.requires.isEmpty) {
          x.supported = true;
          continue;
        }

        x.supported = x.requires.contains(type) || x.requires.contains(platformName);
      }

      $["help"].setInnerHtml(createPlatformHelp(platformName), validator: new NullTreeValidator());
    });
  }

  String getPlatformType(String name) {
    name = name.toLowerCase();

    if (name.contains("linux")) {
      return "linux";
    }

    if (name.contains("windows")) {
      return "windows";
    }

    if (name.contains("mac")) {
      return "mac";
    }

    return "linux";
  }

  openLinksDialog() {
    $["links-dialog"].open();
  }

  selectAllLinks() {
    links.forEach((x) => x.selected = x.show && x.supported && !x.extra);
  }

  createDistPackage() async {
    String platformName = (($["platform"] as CoreMenu).selectedItem as PaperItem).attributes["value"];
    String distId = (($["dist-type"] as CoreMenu).selectedItem as PaperItem).attributes["value"];
    List<DSLinkModel> ourLinks = links.where((x) => x.selected).toList();
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
      || platform.contains("Linux")
      || platform == "dreamplug"
      || platform == "beaglebone"
      || platform == "arm"
      || platform == "ci20"
      || platform == "am335x") {
      rp = "linux";
    } else if (platform.startsWith("windows-")) {
      rp = "windows";
    } else if (platform.startsWith("macos-")) {
      rp = "mac";
    }

    var package = buildPackage({
      "dist": dist.id,
      "platform": platform,
      "platformType": rp,
      "links": ourLinks.map((DSLinkModel x) {
        return {
          "name": x.name,
          "language": x.language,
          "category": x.category
        };
      }).toList()
    }, dist.directoryName, distArchive, dartSdkArchive, pkgs, platform: rp, wrappers: dist.wrappers);
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

class DSLinkLanguage extends Observable {
  final String name;

  @observable
  bool filtered = false;

  DSLinkLanguage(this.name);
}

class DSLinkCategory extends Observable {
  final String name;

  @observable
  bool filtered = false;

  DSLinkCategory(this.name);
}

class DSLinkModel extends Observable {
  final Map<String, dynamic> json;

  DSLinkModel(this.json) {
    if (!json.containsKey("category")) {
      json["category"] = "Misc.";
    }
  }

  @observable
  bool selected = false;

  @observable
  bool show = true;

  @observable
  bool supported = true;

  String get displayName => json["displayName"];
  String get type => json["type"];
  String get zip => json["zip"];
  String get description => json["description"];
  String get category => json["category"];
  String get language => json["type"];
  String get name => json["name"];
  List<String> get requires => json.containsKey("requires") ? json["requires"] : [];
  bool get extra => json.containsKey("extra") ? json["extra"] : false;

  dynamic operator [](String name) {
    return json[name];
  }
}
