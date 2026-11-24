// Picks the browser version of the hot restart guard on the web, and a
// do-nothing version everywhere else (tests, desktop, mobile).
export 'hot_restart_reload_stub.dart'
    if (dart.library.js_interop) 'hot_restart_reload_web.dart';
