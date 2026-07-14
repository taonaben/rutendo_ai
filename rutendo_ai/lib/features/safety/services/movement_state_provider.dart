enum UserMovementState { moving, stationary, unknown }

abstract class MovementStateProvider {
  UserMovementState getCurrentState();
}

class DefaultMovementStateProvider implements MovementStateProvider {
  const DefaultMovementStateProvider();

  @override
  UserMovementState getCurrentState() => UserMovementState.unknown;
}
