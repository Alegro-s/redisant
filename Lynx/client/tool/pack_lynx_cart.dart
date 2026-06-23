// Pack project folder to .lynxcart (dev helper for wave 17).
import 'dart:io';

import 'package:client/features/engine/runtime/lynx_cart_io.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln('Usage: dart run tool/pack_lynx_cart.dart <projectRoot> <output.lynxcart>');
    exit(1);
  }
  final file = await packProjectToLynxCart(
    projectRoot: args[0],
    outputPath: args[1],
  );
  stdout.writeln('OK: ${file.path}');
}
