import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

/// A flag on the browser's `window`. Dart state is wiped by a hot restart,
/// but the page (and so this flag) is not, so finding it means `main` is
/// running for the second time on the same page.
const _startedFlag = r'$bonfireCrashCourseStarted';

/// Turns a web hot restart into a full page reload.
///
/// Flutter web (CanvasKit) does not free its WebGL contexts on a hot restart:
/// every restart leaves 3 behind. Chrome allows 16 per page, so from the
/// 5th or 6th restart on it starts killing the oldest ones ("Too many active
/// WebGL contexts. Oldest context will be lost."), Flutter rebuilds what was
/// lost, which kills more, and the console fills with thousands of warnings
/// and "Shader compilation error"s. A page reload throws every context away,
/// so the game always starts on a clean page.
///
/// Returns true when it started a reload: then `main` must not run the app,
/// since the page is about to be replaced anyway. Only debug builds can hot
/// restart, so release builds always return false.
bool reloadPageInsteadOfHotRestart() {
  if (!kDebugMode) return false;

  if (globalContext.has(_startedFlag)) {
    (globalContext['location'] as JSObject).callMethod('reload'.toJS);
    return true;
  }

  globalContext[_startedFlag] = true.toJS;
  return false;
}
