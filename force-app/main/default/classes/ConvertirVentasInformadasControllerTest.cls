@IsTest
public with sharing class ConvertirVentasInformadasControllerTest {
    
    @TestSetup
    static void setup() {
        BatchApexConvertirVentasInformadasTest.setup();
    }

    @IsTest
    static void test() {
        Destinatarios_Errores_Batchs__c deb = new Destinatarios_Errores_Batchs__c();
        deb.Name = 'Test';
        deb.Email__c = 'test@email.com';
        insert deb;

        List<Ventas_Informadas__c> ventas = [
            SELECT Id
            FROM Ventas_Informadas__c
            WHERE Venta__c = null
            LIMIT 1
        ];
        System.assert(!ventas.isEmpty(), 'Se requiere venta informada de setup');

        ConvertirVentasInformadasController ctrl = new ConvertirVentasInformadasController(
            new ApexPages.StandardSetController(ventas)
        );
        ctrl.procesar();

        ApexPages.StandardSetController stdSel = new ApexPages.StandardSetController(ventas);
        stdSel.setSelected(ventas);
        update new Ventas_Informadas__c(
            Id = ventas[0].Id,
            Tipo_de_regalia_comercial__c = true
        );
        ConvertirVentasInformadasSeleccionadas ctrl2 = new ConvertirVentasInformadasSeleccionadas(stdSel);

        Test.startTest();
        ctrl2.procesar();
        Test.stopTest();

        Ventas_Informadas__c updated = [
            SELECT Tipo_de_Material__c FROM Ventas_Informadas__c WHERE Id = :ventas[0].Id
        ];
        System.assertEquals(
            VentasInformadasTipoMaterialUtil.REGALIA_COMERCIAL,
            updated.Tipo_de_Material__c
        );
        System.assertNotEquals(null, ctrl2.cancel());
        System.assertEquals(1, ctrl2.getSelectedRecordsAmount());
    }
}
