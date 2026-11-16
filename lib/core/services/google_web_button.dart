// Picks the right implementation per platform: the real Google button on
// web, an empty widget everywhere else.
export 'google_web_button_stub.dart'
if (dart.library.js_interop) 'google_web_button_web.dart';