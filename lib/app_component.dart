import 'dart:async';
import 'dart:convert';
import 'dart:js';
import 'dart:html';
import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';

import 'package:archive/archive.dart';
import 'package:get_dsa/bdist.dart';
import 'package:get_dsa/packager.dart';
import 'package:get_dsa/utils.dart';

final String ANDROID_INSTALL_SCRIPT = [
  r"#!/usr/bin/env bash",
  r"set -e",
  r"adb push . /sdcard/dsa",
  r"adb shell cp /sdcard/dsa/dart-sdk/bin/dart /data/local/tmp/dart",
  r"adb shell chmod 757 /data/local/tmp/dart"
].join("\n");

final String ANDROID_RUN_SCRIPT = [
  r"#!/usr/bin/env bash",
  r"set -e",
  r"adb shell cp /sdcard/dsa/dart-sdk/bin/dart /data/local/tmp/dart"
  r"adb shell chmod 757 /data/local/tmp/dart",
  r"adb shell /data/local/tmp/dart /sdcard/dsa/dglux-server/bin/dglux_server.dart"
].join("\n");

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

  if (platform.contains("Android")) {
    howToStart = """
    <p>
    Ensure you have ADB installed and your device is plugged in.<br/>
    Open a new command line.<br/>
    Navigate to the root folder of the extracted ZIP location.<br/>
    Run the following command:<br/>
    <code>
    bash install.sh<br/>
    bash run.sh
    </code><br/>
  You should be able to access DGLux5 at: http://device-ip:8080<br/>
  Default credentials are: dgSuper / dglux1234<br/>
    </p>

    <p>Your DSA instance is now running on Android!</p>
    """;
  }

  return """
  <h3 style="text-align: center;">Installation Instructions</h3>
  Extract the ZIP file provided by the Get DSA Packager.<br/>
  ${howToStart}<br/>
  If you have a license for a previous installation that was generated before the 8th of July in 2015, please request a new license, and a new one will be generated for you.<br/>
  """;
}

@Component(
  selector: 'my-app',
  styleUrls: const ['app_component.css'],
  templateUrl: 'app_component.html',
  directives: const [materialDirectives],
  providers: const [materialProviders],
)
class AppComponent {
  String helpText = "You must select a platform for installation help.";
  String buildTooltip = "Platform and Distribution are required.";
  bool statusHidden = true;
  String statusText = "";
  List<Distribution> _backendDists;

  static const List<Option> _platforms = const [
    const Option("windows-ia32", "x32 Windows"),
    const Option("windows-x64", "x64 Windows"),
    const Option("linux-ia32", "x32 Linux"),
    const Option("linux-x64", "x64 Linux"),
    const Option("x64_Linux_StaticGLibC", "x64 Linux (glibc Static)"),
    const Option("x64-linux-musl", "x64 Linux (Musl Static)"),
    const Option("macos-ia32", "x32 macOS"),
    const Option("macos-x64", "x64 macOS"),
    const Option("linux-arm", "ARMv7 Linux"),
    const Option("armv6", "ARMv6 Linux"),
    const Option("dreamplug", "Dreamplug"),
    const Option("beaglebone", "Beaglebone"),
    const Option("ci20", "MIPS Creator CI20"),
    const Option("am335x", "ARM am335x"),
    const Option("android", "ARM Android")
  ];
  SelectionModel<Option> selectedPlatform = new SelectionModel.withList();

  SelectionOptions<Option> get platforms =>
      new SelectionOptions.fromList(_platforms);

  String get selectedPlatformLabel =>
      selectedPlatform.selectedValues.length > 0
          ? selectedPlatform.selectedValues.first.label
          : "Platform";

  static List<Option> _dists = [];
  SelectionModel<Option> selectedDist = new SelectionModel.withList();

  SelectionOptions<Option> get dists => new SelectionOptions.fromList(_dists);

  String get selectedDistLabel =>
      selectedDist.selectedValues.length > 0
          ? selectedDist.selectedValues.first.label
          : "Distribution";

  static List<Option> _distVersions = [];
  SelectionModel<Option> selectedDistVersion = new SelectionModel.withList();

  SelectionOptions<Option> get distVersions => new SelectionOptions.fromList(_distVersions);

  String get selectedDistVersionLabel =>
      selectedDistVersion.selectedValues.length > 0
          ? selectedDistVersion.selectedValues.first.label
          : "latest";

  List<DSLinkModel> links = [];
  List<DSLinkLanguage> languages = [];
  List<DSLinkCategory> categories = [];

  AppComponent() {
    selectedDist.selectionChanges.listen((n) async {
      String dist = selectedDist.selectedValues.first.code;
      List<String> versions = await getDistributionVersions(dist);
      _distVersions.clear();
      versions.forEach((v) {
        _distVersions.add(new Option(v, v));
      });
    });

    selectedPlatform.selectionChanges.listen((n) {
      helpText = createPlatformHelp(selectedPlatform.selectedValues.first.code);
    });

    loadDistributions().then((dists) {
      dists.forEach((dist) {
        _dists.add(new Option(dist.id, dist.name));
      });
      _backendDists = dists;
    });
    loadLinks().then((l) {
      links.addAll(l.map((x) => new DSLinkModel(x)));
      links.sort((a, b) => a.displayName.compareTo(b.displayName));
      links.forEach((x) {
        var language = x.language;
        if (!languages.any((l) => l.name == language)) {
          var lang = new DSLinkLanguage(language);
          languages.add(lang);
          /*lang.changes.listen((e) {
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
          });*/
        }

        var category = x.category;

        if (!categories.any((l) => l.name == category)) {
          var cat = new DSLinkCategory(category);
          categories.add(cat);
          /*cat.changes.listen((e) {
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
          });*/
        }
      });
    });
  }

  buildPackageButton() async {
    statusHidden = false;

    String platform = selectedPlatform.selectedValues.first.code;
    Distribution dist = _backendDists.firstWhere((x) =>
    x.id == selectedDist.selectedValues.first.code);
    String version = selectedDistVersionLabel;
    List<DSLinkModel> ourLinks = links.where((x) => x.selected).toList();

    statusText = "Fetching distribution...";
    var distArchive = await dist.download(version);

    statusText = "Fetching Dart SDK...";
    var dartSdkArchive = await fetchDartSdk(platform);

    var pkgs = <DSLinkPackage>[];

    for (var l in ourLinks) {
      print("Fetching DSLink '${l["displayName"]}'");
      statusText = "Fetching DSLink '${l["displayName"]}'";
      var archive = await fetchArchive(l["zip"]);
      var pkg = new DSLinkPackage(l["name"], archive);
      pkgs.add(pkg);
      pkg.rewriteFilePaths();
      print("DSLink '${l["displayName"]}' fetched.");
    }

    statusText = "Building archive...";

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
    } else if (platform.startsWith("android")) {
      rp = "android";
    }

    dynamic mls = version;

    if (mls == null) {
      mls = dist.latest;
    } else if (mls is String) {
      try {
        mls = num.parse(mls);
      } catch(e) {
      }
    }

    var package = buildPackage({
      "dist": dist.id,
      "platform": platform,
      "platformType": rp,
      "links": ourLinks.map((DSLinkModel x) {
        return {
          "name": x.name,
          "language": x.language,
          "category": x.category,
          "revision": x.revision
        };
      }).toList(),
      "revision": mls
    }, dist.directoryName, distArchive, dartSdkArchive, pkgs, platform: rp, wrappers: dist.wrappers);

    if (rp == "android") {
      var encodedRunScript = const Utf8Encoder().convert(ANDROID_RUN_SCRIPT);
      var encodedInstallScript = const Utf8Encoder().convert(ANDROID_INSTALL_SCRIPT);
      var runScriptFile = new ArchiveFile("run.sh", encodedRunScript.length, encodedRunScript);
      var installScriptFile = new ArchiveFile("install.sh", encodedInstallScript.length, encodedInstallScript);
      package.addFile(runScriptFile);
      package.addFile(installScriptFile);
    }

    await new Future.value();
    var blob = new Blob([await compressZip(package)], "application/zip");
    await new Future.value();
    statusText = "Downloading Package";
    context.callMethod("download", [blob, "dsa.zip"]);
    statusText = "";
    statusHidden = true;
  }

  Future<List<String>> getDistributionVersions(String name) async {
    var content = await HttpRequest.getString("https://api.github.com/repos/IOT-DSA/dists/contents/${name}");
    var data = JSON.decode(content);
    var x = data.map((x) => x["name"]).toList();
    x.sort((a, b) {
      var x = int.parse(a, onError: (_) => null);
      var y = int.parse(b, onError: (_) => null);

      if (x == null || y == null) {
        return a.toString().compareTo(b.toString());
      }

      return x.compareTo(y);
    });
    return x.reversed.toList();
  }
}

class Option implements HasUIDisplayName {
  final String code;
  final String label;

  const Option(this.code, this.label);

  @override
  String get uiDisplayName => label;

  @override
  String toString() => uiDisplayName;
}

class DSLinkLanguage {
  final String name;

  bool filtered = false;

  DSLinkLanguage(this.name);
}

class DSLinkCategory {
  final String name;

  bool filtered = false;

  DSLinkCategory(this.name);
}

class DSLinkModel {
  final Map<String, dynamic> json;

  DSLinkModel(this.json) {
    if (!json.containsKey("category")) {
      json["category"] = "Misc.";
    }
  }

  bool selected = false;

  bool show = true;

  bool supported = true;

  String get displayName => json["displayName"];
  String get type => json["type"];
  String get zip => json["zip"];
  String get description => json["description"];
  String get category => json["category"];
  String get language => json["type"];
  String get revision => json["revision"];
  String get name => json["name"];
  List<String> get requires => json.containsKey("requires") ? json["requires"] : [];
  bool get extra => json.containsKey("extra") ? json["extra"] : false;

  dynamic operator [](String name) {
    return json[name];
  }
}
