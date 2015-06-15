library get_dsa.browser.dist;

import "dart:async";
import "dart:convert";
import "dart:html";
import "dart:typed_data";

import "package:archive/archive.dart";
import "utils.dart";

const String BASE_DIST_URL = "http://iot-dsa.github.io/dists";

class Distribution {
  final String id;
  final String name;
  final String latest;
  final String file;
  final List<String> wrappers;

  Distribution(this.id, this.name, this.latest, this.file, this.wrappers);

  factory Distribution.fromJSON(String id, input) {
    return new Distribution(
        id,
        input["displayName"],
        input["latest"],
        input["file"],
        input.containsKey("wrappers") ? input["wrappers"] : []
    );
  }

  String createZipUrl() => "${BASE_DIST_URL}/${id}/${latest}/${file}";

  Future<Archive> download() async {
    var bytes = await readUrlBytes(createZipUrl());
    await null;
    return await readArchive(bytes);
  }

  Map toJSON() {
    return {
      "id": id,
      "name": name,
      "latest": latest,
      "file": file,
      "wrappers": wrappers
    };
  }
}

Future<List<Distribution>> loadDistributions() async {
  var content = await HttpRequest.getString("${BASE_DIST_URL}/dists.json");
  var json = JSON.decode(content);
  var d = json["dists"];
  var l = [];
  for (var x in d.keys) {
    l.add(new Distribution.fromJSON(x, d[x]));
  }
  return l;
}

Future<Archive> fetchDartSdk(String platform) async {
  String url;

  if (!platform.startsWith("linux-") && !platform.startsWith("windows-") && !platform.startsWith("macos-")) {
    url = "http://iot-dsa.github.io/dart-sdk-builds/${platform}.zip";
  } else {
    url = "https://commondatastorage.googleapis.com/dart-archive/channels/dev/raw/latest/sdk/dartsdk-${platform}-release.zip";
  }

  var bytes = await readUrlBytes(url);

  await null;

  return await readArchive(bytes);
}

Future<List<int>> readUrlBytes(String url) {
  var request = new HttpRequest();
  var completer = new Completer();
  request.responseType = "arraybuffer";
  request.open("GET", url, async: true);

  request.onReadyStateChange.listen((x) {
    if (request.readyState == HttpRequest.DONE) {
      ByteBuffer buffer = request.response;
      Uint8List response = new Uint8List.view(buffer);

      completer.complete(response);
    }
  });

  request.send();

  return completer.future;
}
