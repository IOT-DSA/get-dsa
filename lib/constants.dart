library get_dsa.constants;

const String DART_VM_VERSION = "1.15.0";
const String DART_VM_CHANNEL = "stable";
const String BASE_LINKS_URL = "https://dsa.s3.amazonaws.com/links";
const String BASE_DIST_URL = "https://dsa.s3.amazonaws.com/dists";

const String SHELL_DART_WRAPPER = r"""
#!/usr/bin/env bash
$(dirname $0)/../../dart-sdk/bin/dart ${0%.sh}.dart ${@}
""";

const String BATCH_DART_WRAPPER = r"""
@echo off
set me=%~f0
set me=%me:~0,-4%
%~0\..\..\..\dart-sdk\bin\dart.exe "%me%.dart" %*
""";
