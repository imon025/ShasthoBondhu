import 'skin_service_base.dart';
import 'skin_service_mobile.dart' if (dart.library.html) 'skin_service_web.dart' as platform;

export 'skin_service_base.dart';

SkinService createSkinService() => platform.getService();
