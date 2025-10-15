import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:android_package_manager/android_package_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {

  @override
  void initState() {
    super.initState();
    final flags = PackageInfoFlags(
      {
        PMFlag.getMetaData,
        // Note: THIS IS REQUIRED if you need access to permissions
        // And the information is contained under `requestedPermissions`
        // instead of `permissions`
        PMFlag.getPermissions,
        PMFlag.getReceivers,
        PMFlag.getServices,
        PMFlag.getProviders,
      },
    );
    _pm.getInstalledPackages(flags: flags,).then(
      (value) => setState(
        () => _applicationInfoList = value,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appInfo = _applicationInfoList;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Android Package Manager Demo",
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: 24.0,
          vertical: 32.0,
        ),
        itemBuilder: (
          _,
          index,
        ) {
          final info = appInfo![index];
          return Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12.0,
            ),
            child: _PackageEntry(info: info,),
          );
        },
        itemCount: appInfo?.length ?? 0,
      ),
    );
  }

  List<PackageInfo>? _applicationInfoList;
  AndroidPackageManager get _pm => AndroidPackageManager();
}

class _Permissions extends StatelessWidget {

  const _Permissions({required this.permissions,});

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [
        Expanded(
          child: Text('Permissions (${permissions.length})',),
        ),
        TextButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => BottomSheet(
                onClosing: () {},
                builder: (_) {
                  return SizedBox(
                    height: MediaQuery.sizeOf(_,).height * 0.5,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 16,),
                      itemBuilder: (_, i,) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12,),
                          child: Text('[${i + 1}] ${permissions[i]}',),
                        );
                      },
                      separatorBuilder: (_, __,) => const Divider(height: 16,),
                      itemCount: permissions.length,
                    ),
                  );
                },
              ),
            );
          },
          child: const Text(
            'Show',
            style: TextStyle(decoration: TextDecoration.underline,),
          ),
        ),
      ],
    );
  }

  final List<String> permissions;
}

class _Receivers extends StatelessWidget {

  const _Receivers({required this.receivers,});

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [
        Expanded(
          child: Text('Receivers (${receivers.length})',),
        ),
        TextButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => BottomSheet(
                onClosing: () {},
                builder: (_) {
                  return SizedBox(
                    height: MediaQuery.sizeOf(_,).height * 0.5,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 16,),
                      itemBuilder: (_, i,) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12,),
                          child: Text('[${i + 1}] ${receivers[i].name}',),
                        );
                      },
                      separatorBuilder: (_, __,) => const Divider(height: 16,),
                      itemCount: receivers.length,
                    ),
                  );
                },
              ),
            );
          },
          child: const Text(
            'Show',
            style: TextStyle(decoration: TextDecoration.underline,),
          ),
        ),
      ],
    );
  }

  final List<ActivityInfo> receivers;
}

class _Services extends StatelessWidget {

  const _Services({required this.services,});

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [
        Expanded(
          child: Text('Services (${services.length})',),
        ),
        TextButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => BottomSheet(
                onClosing: () {},
                builder: (_) {
                  return SizedBox(
                    height: MediaQuery.sizeOf(_,).height * 0.5,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 16,),
                      itemBuilder: (_, i,) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12,),
                          child: Text('[${i + 1}] ${services[i].name}',),
                        );
                      },
                      separatorBuilder: (_, __,) => const Divider(height: 16,),
                      itemCount: services.length,
                    ),
                  );
                },
              ),
            );
          },
          child: const Text(
            'Show',
            style: TextStyle(decoration: TextDecoration.underline,),
          ),
        ),
      ],
    );
  }

  final List<ServiceInfo> services;
}

class _Providers extends StatelessWidget {

  const _Providers({required this.providers,});

  @override
  Widget build(BuildContext context) {

    return Row(
      children: [
        Expanded(
          child: Text('Providers (${providers.length})',),
        ),
        TextButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => BottomSheet(
                onClosing: () {},
                builder: (_) {
                  return SizedBox(
                    height: MediaQuery.sizeOf(_,).height * 0.5,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 16,),
                      itemBuilder: (_, i,) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12,),
                          child: Text('[${i + 1}] ${providers[i].name}',),
                        );
                      },
                      separatorBuilder: (_, __,) => const Divider(height: 16,),
                      itemCount: providers.length,
                    ),
                  );
                },
              ),
            );
          },
          child: const Text(
            'Show',
            style: TextStyle(decoration: TextDecoration.underline,),
          ),
        ),
      ],
    );
  }

  final List<ProviderInfo> providers;
}

class _AppIcon extends StatelessWidget {

  const _AppIcon({required this.info,});

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<Uint8List?>(
      future: info.applicationInfo?.getAppIcon(),
      builder: (context, snapshot,) {
        if (snapshot.hasData) {
          final iconBytes = snapshot.data!;
          return Image.memory(
            iconBytes,
            fit: BoxFit.fill,
          );
        }
        if (snapshot.hasError) {
          return const Icon(
            Icons.error,
            color: Colors.red,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  final PackageInfo info;
}

class _AppLabel extends StatelessWidget {

  const _AppLabel({required this.info,});

  @override
  Widget build(BuildContext context) {

    return FutureBuilder<String?>(
      future: AndroidPackageManager().getApplicationLabel(
        packageName: info.packageName!,
      ),
      builder: (context, snapshot) => Text(
        snapshot.data ?? "No Name",
      ),
    );
  }

  final PackageInfo info;
}

class _PackageEntry extends StatelessWidget {

  const _PackageEntry({required this.info,});

  @override
  Widget build(BuildContext context) {

    return Card(
      child: ListTile(
        leading: SizedBox.square(
          dimension: 48.0,
          child: _AppIcon(info: info,),
        ),
        title: _AppLabel(info: info,),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0,),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${info.packageName} (${info.longVersionCode ?? info.versionCode})'),
              Builder(
                builder: (_) {
                  final permissions = info.requestedPermissions;
                  if (permissions == null || permissions.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _Permissions(permissions: permissions,);
                },
              ),
              Builder(
                builder: (_) {
                  final receivers = info.receivers;
                  if (receivers == null || receivers.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _Receivers(receivers: receivers,);
                },
              ),
              Builder(
                builder: (_) {
                  final services = info.services;
                  if (services == null || services.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _Services(services: services,);
                },
              ),
              Builder(
                builder: (_) {
                  final providers = info.providers;
                  if (providers == null || providers.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return _Providers(providers: providers,);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  final PackageInfo info;
}