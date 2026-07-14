public without sharing class HomeMulticultivo {
    
    @AuraEnabled
    public static List<Tarjeta> getLoadData(){
        
        Map<Id, Cultivo__c> mapCultivos = new Map<Id, Cultivo__c>([SELECT Id, Name FROM Cultivo__c WHERE Sembra_Evolucion__c = true]);

        Map<Id, Parametro_PPH__c> mapCultivoParametro = new Map<Id, Parametro_PPH__c>();
        for(Parametro_PPH__c param : [SELECT Id, Cultivo__c, Fecha_Inicio_Adhesion_PPH__c, Fecha_Fin_Rectificacion_2__c FROM Parametro_PPH__c WHERE Cultivo__C IN :mapCultivos.keySet() ORDER BY CreatedDate desc]){
            if(mapCultivoParametro.size() == mapCultivos.size()) break;
            if(!mapCultivoParametro.containsKey(param.Cultivo__c)) mapCultivoParametro.put(param.Cultivo__c, param);
        }

        Id productorId = CrearCompraController.getAccount().Id;

        Set<Id> paramIds = new Map<Id, Parametro_PPH__c>(mapCultivoParametro.values()).keySet();
        Map<Id, Plan_de_Siembra__c> mapPlanesSiembra = new Map<Id, Plan_de_Siembra__c>();
        for(Plan_de_Siembra__c plan : [SELECT Parametro_PPH__c FROM Plan_de_Siembra__c WHERE Parametro_PPH__c IN :paramIds AND Estado__c = 'Adherido' AND Productor__c = :productorId]){
            mapPlanesSiembra.put(plan.Parametro_PPH__c, plan);
        }

        List<Tarjeta> cultivos = new List<Tarjeta>();
        Map<Id, Decimal> mapSaldos = new Map<Id, Decimal>();
        for(AggregateResult saldoCultivo : [SELECT Cultivo__c cultivo, SUM(Cantidad_con_Signo__c) saldo FROM Hectareas_Tecnologicas__c WHERE Cultivo__c IN :mapCultivos.keySet() AND Productor__c = :productorId AND HT_Vigente__c = true GROUP BY Cultivo__c]){
            mapSaldos.put((Id) saldoCultivo.get('cultivo'), (Decimal) saldoCultivo.get('saldo'));
        }

        Set<Id> planesAdheridos = new Map<Id, Plan_de_Siembra__c>(mapPlanesSiembra.values()).keySet();
        Map<Id, Decimal> mapSaldosAdheridos = new Map<Id, Decimal>();
        for(AggregateResult saldoAdherido : [SELECT Plan_de_Siembra__c plan, SUM(Cantidad_con_Signo__c) saldo FROM Hectareas_Tecnologicas__c WHERE Plan_de_Siembra__c IN :planesAdheridos AND Productor__c = :productorId GROUP BY Plan_de_Siembra__c]){
            mapSaldosAdheridos.put((Id) saldoAdherido.get('plan'), (Decimal) saldoAdherido.get('saldo'));
        }

        for(Id cultivoId : mapCultivoParametro.keySet()){
            Parametro_PPH__c param = mapCultivoParametro.get(cultivoId);
            Decimal saldo;
            String version;
            if(Date.today() < param.Fecha_Inicio_Adhesion_PPH__c || Date.today() > param.Fecha_Fin_Rectificacion_2__c){
                saldo = mapSaldos.containsKey(cultivoId) ? (Decimal) mapSaldos.get(cultivoId) : 0;
                version = 'comprar';
            }else if(!mapPlanesSiembra.containsKey(param.Id)){
                saldo = mapSaldos.containsKey(cultivoId) ? (Decimal) mapSaldos.get(cultivoId) : 0;
                version = 'adherir';
            }else{
                version = 'adherido';
                saldo = mapSaldosAdheridos.get(mapPlanesSiembra.get(param.Id).Id);
            }
            cultivos.add(new Tarjeta(mapCultivos.get(cultivoId), param.Id, saldo, version));
        }

        return cultivos;
    }


    public class Tarjeta {
        @AuraEnabled public Cultivo__c cultivo;
        @AuraEnabled public String paramId;
        @AuraEnabled public Decimal saldoHTs;
        @AuraEnabled public String version;

        public Tarjeta(Cultivo__c cultivo, String paramId, Decimal saldoHTs, String version){
            this.cultivo = cultivo;
            this.paramId = paramId;
            this.saldoHTs = saldoHTs;
            this.version = version;
        }
    }
}