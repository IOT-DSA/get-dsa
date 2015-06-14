import "package:get_dsa/packager.dart";
import "package:get_dsa/io.dart";
import "package:get_dsa/utils.dart";

main() async {
  var sdkUrl = "https://gsdview.appspot.com/dart-archive/channels/stable/release/latest/sdk/dartsdk-macos-x64-release.zip";
  var distUrl = "https://github.com/IOT-DSA/dists/raw/master/dglux_server/152/dglux_server.zip";

  var sdk = readArchive(await fetchUrl(sdkUrl));
  var dist = readArchive(await fetchUrl(distUrl));

  var pkg = buildPackage(dist, sdk, [], wrappers: ["daemon", "server"], platform: "mac");
  var data = compressZip(pkg);
  await writeToFile("package.zip", data);
}
