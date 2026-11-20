Vendored copy of livekit_client 2.5.4 (https://github.com/livekit/client-sdk-flutter, Apache-2.0, see LICENSE).
One change: lib/src/participant/local.dart `negotiate()` reads `publishOptions!` once into a local so it compiles on
current Dart (the published release fails with "potentially null" errors). Remove this folder and depend on the
published package again once it resolves together with the app's other dependencies (it needs connectivity_plus 7,
while mighty_core still needs 6).
