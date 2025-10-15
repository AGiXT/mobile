abstract class FeatureInfo {

  const FeatureInfo({
    this.name,
    this.version,
    this.reqGlEsVersion,
    this.flags,
    this.glEsVersion,
  });

  final String? name;
  final int? version;
  final int? reqGlEsVersion;
  final int? flags;
  final String? glEsVersion;
}
abstract class FeatureGroupInfo {

  FeatureGroupInfo(this.features,);

  final List<FeatureInfo> features;

}