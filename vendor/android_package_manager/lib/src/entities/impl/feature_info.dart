import '../base/feature_info.dart';

class FeatureInfoImpl extends FeatureInfo {

  FeatureInfoImpl(Map<String, dynamic> data,): super(
    name: data['name'],
    version: data['version'],
    reqGlEsVersion: data['reqGlEsVersion'],
    flags: data['flags'],
    glEsVersion: data['glEsVersion'],
  );
}

class FeatureGroupInfoImpl extends FeatureGroupInfo {

  FeatureGroupInfoImpl(Map<String, dynamic> data,) : super(
    _parseFeatures(data['features'],),
  );

  static List<FeatureInfo> _parseFeatures(dynamic data,) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().map<FeatureInfo>(
        (e) => FeatureInfoImpl(e,),
      ).toList(growable: false,);
    }
    return [];
  }
}