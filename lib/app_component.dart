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
import 'package:gtag_analytics/gtag_analytics.dart';

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
  r"adb shell /data/local/tmp/dart /sdcard/dsa/dsa-server/bin/dglux_server.dart"
].join("\n");

String createPlatformHelp(String platform) {
  String howToStart = """
  <p>
  Open a Terminal and change to the dsa-server directory in the extracted ZIP location.<br/>
  Run the following commands:<br/>
  <code>
  chmod 777 bin/*.sh<br/>
  ./bin/daemon.sh start
  </code><br/>
  You will be able to access DG Solution Builder at: http://localhost:8080<br/>
  Default credentials are: dgSuper / dg1234<br/>
  </p>

  <p>Your DSA instance is now running!</p>
  """;

  if (platform.contains("windows")) {
    howToStart = """
    <p>
    Navigate to the dsa-server folder in the extracted ZIP location.<br/>
    Open a new Command Prompt here.<br/>
    Run the following command:<br/>
    <code>
    bin\\daemon.bat start
    </code><br/>
  You will be able to access DG Solution Builder at: http://localhost:8080<br/>
  Default credentials are: dgSuper / dg1234<br/>
    </p>

    <p>Your DSA instance is now running!</p>
    """;
  }

  if (platform.contains("android")) {
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
  You should be able to access DG Solution Builder at: http://device-ip:8080<br/>
  Default credentials are: dgSuper / dg1234<br/>
    </p>

    <p>Your DSA instance is now running on Android!</p>
    """;
  }

  return """
  <h3>Installation Instructions</h3>
  Extract the ZIP file provided by the Get DSA Packager.<br/>
  ${howToStart}
  """;
}

@Component(
  selector: 'my-app',
  styleUrls: const ['app_component.scss.css'],
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

  final analytics = new GoogleAnalytics();

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

  String get selectedPlatformLabel => selectedPlatform.selectedValues.length > 0
      ? selectedPlatform.selectedValues.first.label
      : "Platform";

  static List<OptionGroup<Option>> _dists = [];
  SelectionModel<Option> selectedDist = new SelectionModel.withList();

  SelectionOptions<Option> get dists => new SelectionOptions.withOptionGroups(_dists);

  String get selectedDistLabel => selectedDist.selectedValues.length > 0
      ? selectedDist.selectedValues.first.label
      : "Distribution";

  static List<Option> _distVersions = [];
  SelectionModel<Option> selectedDistVersion = new SelectionModel.withList();

  SelectionOptions<Option> get distVersions =>
      new SelectionOptions.fromList(_distVersions);

  String get selectedDistVersionLabel =>
      selectedDistVersion.selectedValues.length > 0
          ? selectedDistVersion.selectedValues.first.label
          : "latest";

  static List<OptionGroup<Option>> _links = [];
  SelectionModel<Option> selectedLinks = new SelectionModel.withList(allowMulti: true);

  SelectionOptions<Option> links = new SelectionOptions.withOptionGroups(_links);

  String get selectedLinksLabel => "${selectedLinks.selectedValues.length} links selected";

  List<DSLinkModel> linkModels = [];
  List<DSLinkCategory> linkCategories = [];

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
      var platform = selectedPlatform.selectedValues.first.code;
      print("Changed platform help to: $platform");
      helpText = createPlatformHelp(platform);
    });

    refreshDists();

    loadLinks().then((l) {
      linkModels.addAll(l.map((x) => new DSLinkModel(x)));
      linkModels.sort((a, b) => a.displayName.compareTo(b.displayName));
      linkModels.forEach((x) {
        var category = x.category;

        if (!_links.any((x) => x.uiDisplayName == category)) {
          _links.add(new OptionGroup<Option>.withLabel([], category));
        }

        var optionGroup = _links.firstWhere((x) => x.uiDisplayName == category);
        optionGroup.add(new Option(x.name, x.displayName));
      });
    });
//    if (window.location.host.contains(new RegExp(r'(dglogik\.com|dglux\.com)'))){
//      () async {
//        document.querySelector('#distSelectDiv').style.display = 'none';
//      }();
    buildTooltip = "Platform is required.";
//      selectDefaultDist = true;
//    }
  }
//  bool selectDefaultDist = false;
  refreshDists() async {
    loadDistributions().then((dists) {
      _dists.clear();
      var current = new OptionGroup<Option>.withLabel([], "Current");
      var archived = new OptionGroup<Option>.withLabel([], "Archived");
      _dists.add(current);
      _dists.add(archived);

      current.add(new Option(dists[1].id, dists[1].name));
      selectedDist.select(current[0]);

//      if (selectDefaultDist) {
//        var host = window.location.host;
//        if (host.contains('dglogik.com')) {
//          current.add(new Option(dists[0].id, dists[0].name));
//        } else if (host.contains('dglux.com')) {
//          current.add(new Option(dists[1].id, dists[1].name));
//        }
//        selectedDist.select(current[0]);
//      } else {
//        dists.forEach((dist) {
//          if (!dist.archived) {
//            current.add(new Option(dist.id, dist.name));
//          } else {
//            archived.add(new Option(dist.id, dist.name));
//          }
//        });
//      }

      _backendDists = dists;
    });

  }

  buildPackageButton() async {
    if (selectedPlatform.selectedValues.length == 0 ||
        selectedDist.selectedValues.length == 0) {
      return;
    }

    statusHidden = false;

    String platform = selectedPlatform.selectedValues.first.code;
    Distribution dist = _backendDists
        .firstWhere((x) => x.id == selectedDist.selectedValues.first.code);
    String version = selectedDistVersionLabel;
    List<DSLinkModel> ourLinks = [];
    selectedLinks.selectedValues.forEach((opt) {
      ourLinks.add(linkModels.where((x) => x.name == opt.code).first);
    });

    analytics.sendCustom("platform", category: dist.directoryName, label: platform);
    analytics.sendCustom("version", category: dist.directoryName, label: version);

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

    if (platform.startsWith("linux-") ||
        platform.contains("Linux") ||
        platform == "dreamplug" ||
        platform == "beaglebone" ||
        platform == "arm" ||
        platform == "ci20" ||
        platform == "am335x") {
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
      } catch (e) {}
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
    }, dist.directoryName, distArchive, dartSdkArchive, pkgs,
        platform: rp, wrappers: dist.wrappers);

    if (rp == "android") {
      var encodedRunScript = const Utf8Encoder().convert(ANDROID_RUN_SCRIPT);
      var encodedInstallScript =
          const Utf8Encoder().convert(ANDROID_INSTALL_SCRIPT);
      var runScriptFile =
          new ArchiveFile("run.sh", encodedRunScript.length, encodedRunScript);
      var installScriptFile = new ArchiveFile(
          "install.sh", encodedInstallScript.length, encodedInstallScript);
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
    var content = await HttpRequest.getString(
        "https://api.github.com/repos/IOT-DSA/dists/contents/${name}");
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

class LinkSelectionOptions<T> extends StringSelectionOptions<T>
    implements Selectable {
  LinkSelectionOptions(List<T> options)
      : super(options, toFilterableString: (T option) => option.toString());

  LinkSelectionOptions.withOptionGroups(List<OptionGroup> optionGroups)
      : super.withOptionGroups(optionGroups,
      toFilterableString: (T option) => option.toString());

  @override
  SelectableOption getSelectable(item) =>
      item is Option
          ? SelectableOption.Disabled
          : SelectableOption.Selectable;
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

  List<String> get requires =>
      json.containsKey("requires") ? json["requires"] : [];

  bool get extra => json.containsKey("extra") ? json["extra"] : false;

  dynamic operator [](String name) {
    return json[name];
  }
}
