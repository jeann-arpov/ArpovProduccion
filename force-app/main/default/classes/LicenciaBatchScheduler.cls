global class LicenciaBatchScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        LicenciaBatch batch = new LicenciaBatch();
        Database.executeBatch(batch, 200);
    }
}