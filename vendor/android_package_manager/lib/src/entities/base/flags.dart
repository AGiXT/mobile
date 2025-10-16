enum PMFlag {
  getActivities,
  getReceivers,
  getServices,
  getProviders,
  getInstrumentation,
  getResolvedFilter,
  getMetaData,
  getGids,
  getSharedLibraryFiles,
  getUriPermissionPatterns,
  getPermissions,
  getConfigurations,
  getSigningCertificates,
  getAttributions,

  matchUninstalledPackages,
  matchDisabledComponents,
  matchDisabledUntilUsedComponents,
  matchDefaultOnly,
  matchAll,
  matchDirectBootUnaware,
  matchDirectBootAware,
  matchSystemOnly,
  matchFactoryOnly,
  matchAnyUser,
  matchKnownPackages,
  matchInstant,
  matchVisibleToInstantAppOnly,
  matchExplicitlyVisibleOnly,
  matchStaticSharedLibraries,
  matchDirectBootAuto,
  matchHiddenUntilInstalledComponents,
  matchApex,

  skipCurrentProfile,
  onlyIfNoMatchFound,
  moduleApexName,

  // Enabled Flag
  doNotKillApp,
  synchronous,
}

const _filterFlags = <PMFlag, int>{
  PMFlag.getActivities: 0x00000001,
  PMFlag.getReceivers: 0x00000002,
  PMFlag.getServices: 0x00000004,
  PMFlag.getProviders: 0x00000008,
  PMFlag.getInstrumentation: 0x00000010,
  PMFlag.getResolvedFilter: 0x00000040,
  PMFlag.getMetaData: 0x00000080,
  PMFlag.getGids: 0x00000100,
  PMFlag.matchDisabledComponents: 0x00000200,
  PMFlag.getSharedLibraryFiles: 0x00000400,
  PMFlag.getUriPermissionPatterns: 0x00000800,
  PMFlag.getPermissions: 0x00001000,
  PMFlag.matchUninstalledPackages: 0x00002000,
  PMFlag.getConfigurations: 0x00004000,
  PMFlag.matchDisabledUntilUsedComponents: 0x00008000,
  PMFlag.matchDefaultOnly: 0x00010000,
  PMFlag.matchAll: 0x00020000,
  PMFlag.matchDirectBootUnaware: 0x00040000,
  PMFlag.matchDirectBootAware: 0x00080000,
  PMFlag.matchSystemOnly: 0x00100000,
  PMFlag.matchFactoryOnly: 0x00200000,
  PMFlag.matchAnyUser: 0x00400000,
  PMFlag.matchKnownPackages: 0x00002000 | 0x00400000,
  PMFlag.matchInstant: 0x00800000,
  PMFlag.matchVisibleToInstantAppOnly: 0x01000000,
  PMFlag.matchExplicitlyVisibleOnly: 0x02000000,
  PMFlag.matchStaticSharedLibraries: 0x04000000,
  PMFlag.getSigningCertificates: 0x08000000,
  PMFlag.matchDirectBootAuto: 0x10000000,
  PMFlag.getAttributions: 0x80000000,
  PMFlag.matchHiddenUntilInstalledComponents: 0x20000000,
  PMFlag.matchApex: 0x40000000,
  
  PMFlag.skipCurrentProfile: 0x00000002,
  PMFlag.onlyIfNoMatchFound: 0x00000004,
  PMFlag.moduleApexName: 0x00000001,

  PMFlag.doNotKillApp: 0x00000001,
  PMFlag.synchronous: 0x00000002,
};

abstract class _FlagsProvider {

  _FlagsProvider._(Set<PMFlag> flagSet,): flagSet = Set.unmodifiable(flagSet,);

  final Set<PMFlag> flagSet;

  int get flags {
    final flagSet = this.flagSet;
    if (flagSet.isEmpty) {
      return 0;
    }
    return flagSet.fold(
      0,
      (previousValue, element,) {
        final flag = _filterFlags[element];
        return flag != null ? previousValue | flag : previousValue;
      },
    );
  }
}

class PackageInfoFlags extends _FlagsProvider {

  PackageInfoFlags(Set<PMFlag> flags,): super._(
    flags.intersection(_availableFlags,),
  );

  static const Set<PMFlag> _availableFlags = {
    PMFlag.getActivities,
    PMFlag.getConfigurations,
    PMFlag.getGids,
    PMFlag.getInstrumentation,
    PMFlag.getMetaData,
    PMFlag.getPermissions,
    PMFlag.getProviders,
    PMFlag.getReceivers,
    PMFlag.getServices,
    PMFlag.getSharedLibraryFiles,
    PMFlag.getSigningCertificates,
    PMFlag.getUriPermissionPatterns,
    PMFlag.matchUninstalledPackages,
    PMFlag.matchDisabledComponents,
    PMFlag.matchDisabledUntilUsedComponents,
    PMFlag.matchSystemOnly,
    PMFlag.matchFactoryOnly,
    PMFlag.matchDirectBootAuto,
    PMFlag.matchInstant,
    PMFlag.matchApex,
    PMFlag.matchHiddenUntilInstalledComponents,
    PMFlag.getAttributions,
  };
}

class ApplicationInfoFlags extends _FlagsProvider {

  ApplicationInfoFlags(Set<PMFlag> flags,): super._(
    flags.intersection(_availableFlags,),
  );
  
  static const Set<PMFlag> _availableFlags = {
    PMFlag.getMetaData,
    PMFlag.getSharedLibraryFiles,
    PMFlag.matchAll,
    PMFlag.matchDirectBootAuto,
    PMFlag.matchDisabledComponents,
    PMFlag.matchDisabledUntilUsedComponents,
    PMFlag.matchInstant,
    PMFlag.matchStaticSharedLibraries,
    PMFlag.matchHiddenUntilInstalledComponents,
    PMFlag.matchApex,
  };
}

class ComponentInfoFlags extends _FlagsProvider {
  
  ComponentInfoFlags(Set<PMFlag> flags,): super._(
    flags.intersection(_availableFlags,),
  );
  
  static const Set<PMFlag> _availableFlags = {
    PMFlag.getMetaData,
    PMFlag.getSharedLibraryFiles,
    PMFlag.matchAll,
    PMFlag.matchDirectBootAuto,
    PMFlag.matchDefaultOnly,
    PMFlag.matchDisabledComponents,
    PMFlag.matchDisabledUntilUsedComponents,
    PMFlag.matchDirectBootAware,
    PMFlag.matchDirectBootUnaware,
    PMFlag.matchSystemOnly,
    PMFlag.matchUninstalledPackages,
    PMFlag.matchInstant,
    PMFlag.matchStaticSharedLibraries,
  };
}

class ResolveInfoFlags extends _FlagsProvider {

  ResolveInfoFlags(Set<PMFlag> flags,): super._(
    flags.intersection(_availableFlags,),
  );
  
  static const Set<PMFlag> _availableFlags = {
    PMFlag.getMetaData,
    PMFlag.getResolvedFilter,
    PMFlag.getSharedLibraryFiles,
    PMFlag.matchAll,
    PMFlag.matchDirectBootAuto,
    PMFlag.matchDisabledComponents,
    PMFlag.matchDisabledUntilUsedComponents,
    PMFlag.matchDefaultOnly,
    PMFlag.matchDirectBootAware,
    PMFlag.matchDirectBootUnaware,
    PMFlag.matchSystemOnly,
    PMFlag.matchUninstalledPackages,
    PMFlag.matchInstant,
  };
}

class InstalledModulesFlags extends _FlagsProvider {
  
  InstalledModulesFlags({bool matchAll = true,}): super._(
    {
      if (matchAll)
        PMFlag.matchAll,
    },
  );
}

class PermissionInfoFlags extends _FlagsProvider {
  
  PermissionInfoFlags({bool provideMetaData = true,}): super._(
    {
      if (provideMetaData)
        PMFlag.getMetaData,
    },
  );
}

class PermissionGroupInfoFlags extends _FlagsProvider {

  PermissionGroupInfoFlags({bool provideMetaData = true,}): super._(
    {
      if (provideMetaData)
        PMFlag.getMetaData,
    },
  );
}

class InstrumentationInfoFlags extends _FlagsProvider {

  InstrumentationInfoFlags({bool provideMetaData = true,}): super._(
    {
      if (provideMetaData)
        PMFlag.getMetaData,
    },
  );
}

class ModuleInfoFlags extends _FlagsProvider {

  ModuleInfoFlags({bool provideApexName = false,}): super._(
    {
      if (provideApexName)
        PMFlag.moduleApexName,
    },
  );
}

class EnabledFlags extends _FlagsProvider {

  EnabledFlags(Set<PMFlag> flags,): super._(
    flags.intersection(_availableFlags,),
  );

  static const Set<PMFlag> _availableFlags = {
    PMFlag.doNotKillApp,
    PMFlag.synchronous,
  };
}

// enum ProtectionFlag {
//   priviledged,
//   development,
//   appop,
//   pre23,
//   installer,
//   setup,
//   instant,
//   runtimeOnly,
//   oem,
//   vendorPriviledged,
//   systemTextClassifier,
//   documenter,
//   configurator,
//   incidentReportApprover,
//   appPredictor,
//   companion,
//   retailDemo,
//   recents,
//   role,
//   knownSigner,
// }