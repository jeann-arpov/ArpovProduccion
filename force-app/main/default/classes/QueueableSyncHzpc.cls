public class QueueableSyncHzpc implements Queueable {
    private Set<Id> transaccionIds;
    private TriggerOperation context;

    public QueueableSyncHzpc(Set<Id> ids, TriggerOperation ctx){
        this.transaccionIds = ids;
        this.context = ctx;
    }

    public void execute(QueueableContext qc){
        Database.executeBatch(
            new BatchApexSyncTransaccionesHzpc(transaccionIds, context),
            BatchApexSyncTransaccionesHzpc.BATCH_SIZE
        );
    }
}