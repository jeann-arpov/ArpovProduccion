@IsTest
private class TestREST{
    // Methods for testing
    @isTest static void test() {
    
        Cultivo__c cultivo = new Cultivo__c();
        cultivo.Name = 'Test';
        cultivo.Densidad_de_Siembra__c = 5;
        insert cultivo;
        
        Campana_Agricola__c campana1 = new Campana_Agricola__c();
        campana1.Name = 'Campaña 1';
        campana1.Id_Externo__c = 'campana1';
        campana1.Ano__c = '2013';
        campana1.Cultivo__c = cultivo.Id;
        campana1.SKEY_CAMPANIA__c = Utils.getRandomLong(10);
        insert campana1;
        
        Campana_Agricola__c campana2 = new Campana_Agricola__c();
        campana2.Nombre_de_Campana_Anterior__c = campana1.ID;
        campana2.Name = 'Campaña 2';
        campana2.Id_Externo__c = 'campana2';
        campana2.Ano__c = '2014';
        campana2.Cultivo__c = cultivo.Id;
        campana2.SKEY_CAMPANIA__c = Utils.getRandomLong(10);
        insert campana2;
        
        Lote__c lote = Test_TestUtils.crearLote();
        lote.Campana__c = campana2.ID;
        lote.Cultivo__c = cultivo.ID;
        lote.Tipo__c = 'Basico';
        insert lote;
            
        RESTExecuteBatchGenerarDups.execute(lote.ID);
        
        RESTExecuteBatchGenerarPDFsDups.execute(lote.ID);
    
    }
    
}