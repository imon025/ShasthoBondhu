import 'pneumonia_service_base.dart';
import 'pneumonia_service_mobile.dart' if (dart.library.html) 'pneumonia_service_web.dart' as platform;

export 'pneumonia_service_base.dart';

PneumoniaService createPneumoniaService() => platform.getService();
