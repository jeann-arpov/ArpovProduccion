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

    @IsTest
    static void reprocesarConCheckboxRegaliaSeteaTipoMaterial() {
        List<Ventas_Informadas__c> ventas = [SELECT Id FROM Ventas_Informadas__c WHERE Venta__c = null LIMIT 1];
        System.assert(!ventas.isEmpty());
        update new Ventas_Informadas__c(
            Id = ventas[0].Id,
            Tipo_de_regalia_comercial__c = true
        );

        ApexPages.StandardSetController std = new ApexPages.StandardSetController(ventas);
        std.setSelected(ventas);
        ReprocesarVentasInformadasController cnt = new ReprocesarVentasInformadasController(std);

        Test.startTest();
        PageReference result = cnt.reprocesar();
        Test.stopTest();

        System.assertNotEquals(null, result);
        Ventas_Informadas__c updated = [
            SELECT Tipo_de_Material__c FROM Ventas_Informadas__c WHERE Id = :ventas[0].Id
        ];
        System.assertEquals(
            VentasInformadasTipoMaterialUtil.REGALIA_COMERCIAL,
            updated.Tipo_de_Material__c
        );
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