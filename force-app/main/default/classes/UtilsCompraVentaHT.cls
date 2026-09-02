public inherited sharing class UtilsCompraVentaHT {

    public static List<Map<String, Object>> getCultivos(){
        List<Map<String, Object>> options = new List<Map<String, Object>>();

        for(Cultivo__c cultivo : [SELECT Id, Name FROM Cultivo__c WHERE Sembra_Evolucion__c = true]){
            options.add(new Map<String, Object>{'label' => cultivo.Name, 'value' => cultivo.Id});
        }

        return options;
    }

    /** Cultivos SE con saldo de Cuenta Granaria HT (Campania nula = Compra HT Disponible). */
    public static List<Map<String, Object>> getCultivosConSaldo(Id productorId) {
        List<Map<String, Object>> options = getCultivos();
        if (productorId == null || options.isEmpty()) {
            return options;
        }

        Set<Id> cultivoIds = new Set<Id>();
        for (Map<String, Object> option : options) {
            cultivoIds.add((Id) option.get('value'));
        }

        Map<Id, Decimal> saldoByCultivo = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Cultivo__c cultivoId, SUM(Saldo_Cuenta__c) total
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productorId
            AND Cultivo__c IN :cultivoIds
            AND Campania__c = null
            GROUP BY Cultivo__c
        ]) {
            Decimal total = (Decimal) ar.get('total');
            saldoByCultivo.put((Id) ar.get('cultivoId'), total != null ? total : 0);
        }

        for (Map<String, Object> option : options) {
            Id cultivoId = (Id) option.get('value');
            Decimal saldo = saldoByCultivo.containsKey(cultivoId) ? saldoByCultivo.get(cultivoId) : 0;
            option.put('saldo', saldo);
        }

        return options;
    }

    /** Saldo total de cuenta granaria por cultivo (todas las subcuentas). */
    public static List<Map<String, Object>> getCultivosConSaldoGranaria(Id productorId) {
        List<Map<String, Object>> options = getCultivos();
        if (productorId == null || options.isEmpty()) {
            return options;
        }

        Set<Id> cultivoIds = new Set<Id>();
        for (Map<String, Object> option : options) {
            cultivoIds.add((Id) option.get('value'));
        }

        Map<Id, Decimal> saldoByCultivo = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Cultivo__c cultivoId, SUM(Saldo_Cuenta__c) total
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productorId
            AND Cultivo__c IN :cultivoIds
            GROUP BY Cultivo__c
        ]) {
            Decimal total = (Decimal) ar.get('total');
            saldoByCultivo.put((Id) ar.get('cultivoId'), total != null ? total : 0);
        }

        for (Map<String, Object> option : options) {
            Id cultivoId = (Id) option.get('value');
            Decimal saldo = saldoByCultivo.containsKey(cultivoId) ? saldoByCultivo.get(cultivoId) : 0;
            option.put('saldo', saldo);
        }

        return options;
    }

    public static Set<Id> getVariedadesSreProductor(String productorId){
        Set<Id> variedadesSreIds = new Set<Id>();
        for(Variedad_SRE_por_Productor__c variedadSreProductor : [SELECT Variedad__c FROM Variedad_SRE_por_Productor__c WHERE Cuenta__c = :productorId]){
            variedadesSreIds.add(variedadSreProductor.Variedad__c);
        }
        return variedadesSreIds;
    }
}