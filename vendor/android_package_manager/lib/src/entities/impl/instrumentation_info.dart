import '../base/instrumentation_info.dart';

class InstrumentationInfoImpl extends InstrumentationInfo {

  InstrumentationInfoImpl(Map<String, dynamic> data,): super(
    targetPackage: data['targetPackage'],
    sourceDir: data['sourceDir'],
    publicSourceDir: data['publicSourceDir'],
    splitSourceDirs: data['splitSourceDirs']?.whereType<String>().toList(growable: false,),
    splitPublicSourceDirs: data['splitPublicSourceDirs']?.whereType<String>().toList(growable: false,),
    dataDir: data['dataDir'],
    handleProfiling: data['handleProfiling'],
    functionalTest: data['functionalTest'],
    packageItemInfo: data,
  );
}