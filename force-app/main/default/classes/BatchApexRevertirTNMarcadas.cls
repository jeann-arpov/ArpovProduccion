public class BatchApexRevertirTNMarcadas implements Database.Batchable<sObject>, Database.Stateful{
    public List<Tonelada__History> tonsHistory;

    public BatchApexRevertirTNMarcadas(){}

    public BatchApexRevertirTNMarcadas(List<Tonelada__History>  tonsHistory){
        this.tonsHistory = tonsHistory;
    }
    public Iterable<Tonelada__History> start(Database.BatchableContext BC){
        if(test.isRunningTest()) {
            return this.tonsHistory;
        } else {
            Date fechaInicio = Configuracion_Reversion_de_TN__mdt.getInstance('global').fecha_inicio__c;
            Date fechaFin = Configuracion_Reversion_de_TN__mdt.getInstance('global').fecha_fin__c;
            return (Iterable<Tonelada__History>) Database.getQueryLocator('SELECT Id, ParentId FROM Tonelada__History WHERE Field = \'Tonelada_Anterior__c\' AND CreatedDate > :fechaInicio AND CreatedDate < :fechaFin AND  Parent.Tonelada_Anterior__c = true');
        }
    }

    public void execute(Database.BatchableContext BC, List<Tonelada__History> scope){
        system.debug(scope);
        List<Tonelada__c> tons  = new List<Tonelada__c>();
        for(Tonelada__History th : scope) {
            Tonelada__c ton = new Tonelada__c(
                Id = th.ParentId,
                Tonelada_Anterior__c = false
            );
            tons.add(ton);
        }

        Database.update(tons, true);
    }

    public void finish(Database.BatchableContext BC){
    }
}