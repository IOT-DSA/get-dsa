library get_dsa.io;

import "dart:async";
import "dart:io";

Future<List<int>> fetchUrl(String url) async {
  var client = new HttpClient();
  var request = await client.getUrl(Uri.parse(url));
  var response = await request.close();
  var bytes = await response.fold([], (a, b) => a..addAll(b));
  client.close();
  return bytes;
}

Future writeToFile(String path, List<int> bytes) async {
  var file = new File(path);
  if (!(await file.exists())) {
    await file.create(recursive: true);
  }
  await file.writeAsBytes(bytes);
}
