import 'package:dslink/worker.dart';

import 'package:get_dsa/bdist.dart';
import 'package:get_dsa/packager.dart';
import 'package:get_dsa/utils.dart';

import 'dart:html' show Blob, FileReader;

main(List<String> _, initial) async {
  Worker worker = await buildWorkerForScript(initial);
}
