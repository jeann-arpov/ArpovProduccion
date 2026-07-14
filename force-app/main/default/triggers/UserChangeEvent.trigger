trigger UserChangeEvent on UserChangeEvent (after insert) {
    UserChangedEventHandler.run();
}