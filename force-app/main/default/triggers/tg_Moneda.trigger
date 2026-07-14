trigger tg_Moneda on Moneda__c (after insert, after update) {
    //if(Trigger.isInsert && Trigger.isAfter){
        List<Moneda__c> monedas = [Select id from Moneda__c where Moneda_de_la_compania__c = true];
        for(Moneda__c moneda: Trigger.New)
            if(monedas.size() > 1)
                moneda.addError('Ya existe una moneda default cargada en el sistema.');
            
    //}
}