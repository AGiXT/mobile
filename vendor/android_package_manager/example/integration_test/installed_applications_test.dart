import 'package:android_package_manager/android_package_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Installed Applications Test',
    () async {
      final pm = AndroidPackageManager();
      final applications = await pm.getInstalledApplications(
        flags: ApplicationInfoFlags(
          {PMFlag.getMetaData,},
        ),
      );
      print("BEGIN: getInstalledApplications",);
      print(
        applications?.map(
          (ApplicationInfo e) {
            e.getAppIcon().then(
                  (bytes,) {
                print(
                  'App ${e.name} Icon (${e.packageName}): ${bytes?.length} bytes',
                );
              },
            );
            return "App Name: ${e.name} | Package: ${e.packageName} | Icon, Logo: ${e.icon}, ${e.logo}";
          },
        ).join("\n"),
      );
      print("END: getInstalledApplications",);
      expect(applications?.isNotEmpty, true,);
    },
  );
}