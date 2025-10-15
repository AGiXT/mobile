import 'dart:io';
import 'dart:math';

import 'package:android_package_manager/android_package_manager.dart';
import 'package:android_package_manager_example/utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final pm = AndroidPackageManager();
  test(
    'Application Label Test',
    () async {
      expect(Platform.isAndroid, true,);
      final random = Random();
      final packages = await pm.getInstalledPackages();
      expect(packages?.isNotEmpty ?? false, true,);
      final package = packages![random.nextInt(packages.length,)];
      debugPrint('Package: ${package.packageName}',);
      final appLabel = await pm.getApplicationLabel(
        packageName: package.packageName!,
      );
      debugPrint(
        'Application Label for ${package.packageName}: '
        '[$appLabel]',
      );
      expect(appLabel != null, true,);
    },
  );
}