@IsTest
public with sharing class GraficoTrigoControllerTest {
    
    @IsTest
    static void test(){
        
        Account a = new Account();
        a.Name = 'Test';
        insert a;

        Historial_UP_y_Fiscalizada__c historial = new Historial_UP_y_Fiscalizada__c();
        historial.Cultivo__c = 'TRIGO';
        historial.Cuenta__c = a.Id;
        historial.Campana_Agricola__c = 'TRIGO';
        historial.Bolsas_UP_Bolsas_50Kg__c = 1;
        historial.Obtentor__c = 'Test';
        historial.Variedad__c = 'Test';
        // historial.Bolsas_SF_50_Kg__c = 1;
        insert historial;

        GraficoTrigoController.getData();
        
    }

}