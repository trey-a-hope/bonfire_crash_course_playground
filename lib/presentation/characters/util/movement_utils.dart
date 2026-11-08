import 'package:bonfire/bonfire.dart';

/// Movement helpers for platform characters.
extension PlatformMovement on Movement {
  /// Stops walking sideways without cancelling a fall: only the horizontal
  /// speed is set to 0, so gravity keeps working.
  void stopWalking() {
    if (velocity.x != 0) velocity = velocity.copyWith(x: 0);
  }
}
