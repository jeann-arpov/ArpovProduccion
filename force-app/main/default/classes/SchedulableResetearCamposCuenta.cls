global with sharing class SchedulableResetearCamposCuenta implements Schedulable{
    global void execute(SchedulableContext sc) {
		Database.executeBatch(new BatchApexResetearCamposCuenta(),1000);
	}
}