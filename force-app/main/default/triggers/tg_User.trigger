trigger tg_User on User (after insert) {
    PortalUserContactHandler.afterInsert(Trigger.new);
}
