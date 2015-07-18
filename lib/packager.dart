library get_dsa.packager;

import "dart:convert";

import "package:archive/archive.dart";

const String SHELL_DART_WRAPPER = r"""
#!/usr/bin/env bash
$(dirname $0)/../../dart-sdk/bin/dart ${0%.sh}.dart ${@}
""";

const String BATCH_DART_WRAPPER = r"""
@echo off
set me=%~f0
set me=%me:~0,-4%
%~0\..\..\..\dart-sdk\bin\dart.exe %me%.dart %*
""";

class DSLinkPackage {
  final String name;
  final Archive archive;

  DSLinkPackage(this.name, this.archive);

  void rewriteFilePaths() {
    if (archive.files.every((f) => f.name.split("/").length >= 2)) {
      archive.files.forEach((file) {
        file.name = file.name.split("/").skip(1).join("/");
      });
    }
  }
}

Archive buildPackage(Map cfg, String distName, Archive baseDistribution, Archive dartSdk, List<DSLinkPackage> links, {List<String> wrappers, String platform: "unknown"}) {
  var pkg = new Archive();

  pkg.files.addAll(baseDistribution.files.map((x) {
    x.name = "${distName}/${x.name}";
    return x;
  }));

  if (!dartSdk.files.every((f) => f.name.startsWith("dart-sdk/"))) {
    dartSdk.files.forEach((f) => f.name = "dart-sdk/${f.name}");
  }

  pkg.files.addAll(dartSdk);

  for (var link in links) {
    var archive = link.archive;
    if (archive.files.every((f) => f.name.split("/").length >= 2)) {
      archive.files.forEach((file) {
        file.name = file.name.split("/").skip(1).join("/");
      });
    }

    archive.files.forEach((file) {
      file.name = "${distName}/dslinks/${link.name}/${file.name}";
    });

    pkg.files.addAll(archive.files);
  }

  var json = UTF8.encode(new JsonEncoder.withIndent("  ").convert(cfg) + "\n");
  ArchiveFile installConfig = new ArchiveFile("${distName}/install.json", json.length, json);

  pkg.files.add(installConfig);

  if (wrappers != null) {
    for (var wrapper in wrappers) {
      if (platform == "linux" || platform == "mac") {
        var encoded = UTF8.encode(SHELL_DART_WRAPPER);
        pkg.addFile(new ArchiveFile("${distName}/bin/${wrapper}.sh", encoded.length, encoded)..mode = 777);
      } else if (platform == "windows") {
        var encoded = UTF8.encode(BATCH_DART_WRAPPER);
        pkg.addFile(new ArchiveFile("${distName}/bin/${wrapper}.bat", encoded.length, encoded)..mode = 777);
      }
    }
  }

  return pkg;
}
