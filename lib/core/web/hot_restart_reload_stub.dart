/// Outside the browser a hot restart has no WebGL contexts to leak, so there
/// is nothing to do: the app always starts normally.
bool reloadPageInsteadOfHotRestart() => false;
