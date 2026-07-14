trigger CaseOwnerChangeTrigger on Case (after update) {
    List<Id> changedCaseIds = new List<Id>();
    for (Case c : Trigger.new) {
        Case oldC = Trigger.oldMap.get(c.Id);
        if (c.OwnerId != oldC.OwnerId) {
            changedCaseIds.add(c.Id);
        }
    }
    if (!changedCaseIds.isEmpty()) {
        SendOwnerChangeEmail.sendEmail(changedCaseIds);
    }
}