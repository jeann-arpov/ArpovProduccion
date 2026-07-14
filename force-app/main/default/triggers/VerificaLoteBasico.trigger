trigger VerificaLoteBasico on Lote__c (before insert, before update) {
    List<Lote__c> lotes = Trigger.new;
    List<Lote__c> lotesBasico;
    Map<String, Lote__c> mapCampanaLoteBasico = new Map<String, Lote__c>();
    try {
        lotesBasico = [SELECT ID, Campana__c FROM Lote__c WHERE Tipo__c = 'Basico'];
    } catch(Exception e){}
    for(Lote__c l : lotesBasico){
        mapCampanaLoteBasico.put(l.Campana__c, l);
    }
    for(Lote__c l : lotes){
        if(mapCampanaLoteBasico.get(l.Campana__c) == null){
            if(l.Tipo__c == 'Basico'){
                mapCampanaLoteBasico.put(l.Campana__c, l);
                if(l.ID != mapCampanaLoteBasico.get(l.Campana__c).ID){
                    l.addError(Label.Error_Lote_Basico_Duplicado);
                }
            }
        } else {
            if(l.Tipo__c == 'Basico' && l.ID != mapCampanaLoteBasico.get(l.Campana__c).ID){
                l.addError(Label.Error_Lote_Basico_Duplicado);
            }
        }
    }
}