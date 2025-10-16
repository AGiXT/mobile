class ComponentName {

  const ComponentName(this.pkg, this.cls,);

  final String pkg;
  final String cls;

  Map<String, dynamic> get asMap => {
    "pkg": pkg,
    "cls": cls,
  };
}