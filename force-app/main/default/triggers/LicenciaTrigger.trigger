trigger LicenciaTrigger on Licencia__c (before update) {
    LicenciaTriggerHandler.run();
}