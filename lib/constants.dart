library get_dsa.constants;

const String DART_VM_VERSION = "1.17.1";
const String DART_VM_CHANNEL = "stable";
const String BASE_LINKS_URL = "https://dsa.s3.amazonaws.com/links";
const String BASE_DIST_URL = "https://dsa.s3.amazonaws.com/dists";

final String SHELL_DART_WRAPPER = [
  r"#!/usr/bin/env bash",
  r"exec $(dirname $0)/../../dart-sdk/bin/dart ${0%.sh}.dart ${@}"
].join("\n");

final String BATCH_DART_WRAPPER = [
  r"@echo off",
  r"set me=%~f0",
  r"set me=%me:~0,-4%",
  r'%~0\..\..\..\dart-sdk\bin\dart.exe "%me%.dart" %*'
].join("\r\n");
