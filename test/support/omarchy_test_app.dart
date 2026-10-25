import 'package:flutter_omarchy/flutter_omarchy.dart';

const OmarchyThemeData testOmarchyTheme = OmarchyThemeData(
  colors: OmarchyColorThemes.tokyoNight,
  text: OmarchyTextStyleData.fallback(),
);

Widget wrapInOmarchy(Widget child) => OmarchyApp(
  debugShowCheckedModeBanner: false,
  theme: testOmarchyTheme,
  home: child,
);
