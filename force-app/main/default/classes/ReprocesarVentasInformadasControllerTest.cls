@isTest
public with sharing class ReprocesarVentasInformadasControllerTest {
    
    @TestSetup
    static void setup(){
        BatchApexConvertirVentasInformadasTest.setup();
    }

    public static testmethod void main() {
        List<Ventas_Informadas__c> ventas = [SELECT Id FROM Ventas_Informadas__c WHERE Venta__c = null LIMIT 1];
        System.assert(!ventas.isEmpty(), 'Se requiere al menos una venta informada sin venta asociada.');

        ApexPages.StandardSetController std = new ApexPages.StandardSetController(ventas);
        std.setSelected(ventas);
        ReprocesarVentasInformadasController cnt = new ReprocesarVentasInformadasController(std);
        System.assertEquals(1, cnt.getSelectedRecordsAmount());
        System.assertEquals(1, cnt.getElegiblesParaReprocesar());

        PageReference result = cnt.reprocesar();
        System.assertNotEquals(null, result);
        System.assert(result.getUrl().contains('batchApexMonitorContainer'));
    }

    @isTest
    static void reprocesarSinSeleccionMuestraErrorTest() {
        ApexPages.StandardSetController std = new ApexPages.StandardSetController([
            SELECT Id FROM Ventas_Informadas__c LIMIT 0
        ]);
        ReprocesarVentasInformadasController cnt = new ReprocesarVentasInformadasController(std);
        System.assertEquals(null, cnt.reprocesar());
        System.assertEquals(1, ApexPages.getMessages().size());
    }

    @isTest
    static void cancelRedirigeTest() {
        ApexPages.StandardSetController std = new ApexPages.StandardSetController([
            SELECT Id FROM Ventas_Informadas__c LIMIT 1
        ]);
        ReprocesarVentasInformadasController cnt = new ReprocesarVentasInformadasController(std);
        System.assertNotEquals(null, cnt.cancel());
    }
}