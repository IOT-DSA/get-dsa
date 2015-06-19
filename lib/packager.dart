library get_dsa.packager;

import "dart:convert";

import "package:archive/archive.dart";

const String SHELL_DART_WRAPPER = r"""
#!/usr/bin/env bash
$(dirname $0)/../dart-sdk/bin/dart ${0}.dart ${@}
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

Archive buildPackage(String distName, Archive baseDistribution, Archive dartSdk, List<DSLinkPackage> links, {List<String> wrappers, String platform: "unknown"}) {
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

  if (wrappers != null) {
    for (var wrapper in wrappers) {
      if (platform == "linux" || platform == "mac") {
        var encoded = UTF8.encode(SHELL_DART_WRAPPER);
        pkg.addFile(new ArchiveFile("${distName}/bin/${wrapper}.sh", encoded.length, encoded)..mode = 755);
      }
    }
  }

  return pkg;
}
