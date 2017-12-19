import 'package:angular/angular.dart';
import 'package:angular_components/angular_components.dart';

@Component(
  selector: 'my-app',
  styleUrls: const ['app_component.css'],
  templateUrl: 'app_component.html',
  directives: const [materialDirectives],
  providers: const [materialProviders],
)
class AppComponent {
  bool buildDisabled = true;
  String buildTooltip = "Platform and Distribution are required.";
  bool statusHidden = true;

  static const List<Option> _platforms = const [
    const Option("windows-ia32", "x32 Windows"),
    const Option("windows-x64", "x64 Windows"),
    const Option("linux-ia32", "x32 Linux"),
    const Option("linux-x64", "x64 Linux"),
    const Option("x64_Linux_StaticGLibC", "x64 Linux (glibc Static)"),
    const Option("x64-linux-musl", "x64 Linux (Musl Static)"),
    const Option("x32 macOS", "macos-ia32"),
    const Option("x64 macOS", "macos-x64"),
    const Option("linux-arm", "ARMv7 Linux"),
    const Option("armv6", "ARMv6 Linux"),
    const Option("dreamplug", "Dreamplug"),
    const Option("beaglebone", "Beaglebone"),
    const Option("ci20", "MIPS Creator CI20"),
    const Option("am335x", "ARM am335x"),
    const Option("android", "ARM Android")
  ];

  static const List<Option> _dists = const [
    const Option("dglux-server", "DGLux Server")
  ];

  SelectionOptions<Option> get platforms => new SelectionOptions.fromList(_platforms);

  SelectionOptions<Option> get dists => new SelectionOptions.fromList(_dists);

  buildPackage() {
    if (buildDisabled) {
      buildDisabled = false;
      return;
    }

    statusHidden = false;
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
