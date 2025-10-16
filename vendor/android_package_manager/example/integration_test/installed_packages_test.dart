import 'package:android_package_manager/android_package_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    "getInstalledPackages",
    () async {
      final pm = AndroidPackageManager();
      final packages = await pm.getInstalledPackages(
        flags: PackageInfoFlags(
          {
            PMFlag.getMetaData,
            PMFlag.getPermissions,
            // PMFlag.getReceivers,
            // PMFlag.getServices,
            // PMFlag.getProviders,
          },
        ),
      );
      debugPrint("BEGIN: getInstalledPackages",);
      debugPrint(
        packages?.map(
          (e) {
            e.activities?.forEach(
              (activity) {
                activity.getIcon().then(
                  (aIcon) {
                    debugPrint(
                      'Package ${e.packageName} Icon: ${aIcon?.length} bytes',
                    );
                  },
                );
                activity.getLogo().then(
                  (aLogo) {
                    debugPrint(
                      'Package ${e.packageName} Logo: ${aLogo?.length} bytes',
                    );
                  },
                );
              },
            );
            return "${e.packageName} | (${e.applicationInfo != null})\n\tAppInfo.name: ${e.applicationInfo?.name}\n\tRequested Permissions: ${e.requestedPermissions}";
          },
        ).join("\n",),
      );
      debugPrint("END: getInstalledPackages",);
      expect(packages != null, true,);

      // Uncomment this to test individual Package (also import dart:math)
      // final rnd = Random();
      // final randomPackage = packages![rnd.nextInt(packages.length,)];
      // final packageName = randomPackage.packageName!;
      // debugPrint('Testing random package with name: $packageName',);
      // final inquiries = await Future.wait(
      //   [
      //     pm.getPackageInfo(
      //       packageName: packageName,
      //     ),
      //     pm.getPackageInfo(
      //       packageName: packageName,
      //       flags: PackageInfoFlags(
      //         {
      //           PMFlag.getPermissions,
      //         },
      //       ),
      //     ),
      //   ],
      // );
      // final piWithoutFlag = inquiries[0];
      // final piWithFlag = inquiries[1];
      // debugPrint('Without Flag: ${piWithoutFlag?.requestedPermissions}',);
      // debugPrint('With Flag: ${piWithFlag?.requestedPermissions}',);
    },
  );
}