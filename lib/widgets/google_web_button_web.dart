import 'package:flutter/widgets.dart';
import 'package:google_sign_in_web/web_only.dart' as web;

Widget googleWebButton() => web.renderButton(
  configuration: web.GSIButtonConfiguration(
    type: web.GSIButtonType.standard,
    text: web.GSIButtonText.continueWith,
    theme: web.GSIButtonTheme.outline,
    size: web.GSIButtonSize.large,
    shape: web.GSIButtonShape.rectangular,
    logoAlignment: web.GSIButtonLogoAlignment.left,
    minimumWidth: 320,
    locale: 'pt-BR',
  ),
);
