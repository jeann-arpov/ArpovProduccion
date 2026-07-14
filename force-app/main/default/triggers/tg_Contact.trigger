trigger tg_Contact on Contact (before update) {
    ContactTriggerHandler.run();
}