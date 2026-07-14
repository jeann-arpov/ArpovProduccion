@IsTest
private class VentasInformadasDuplicateUtilTest {

    @IsTest
    static void marcarDuplicadoMismoLoteYDistintoComprobante() {
        Test_TestUtils.disableFlows();

        Ventas_Informadas__c base = new Ventas_Informadas__c(
            CUIT_Originante__c = '30709538418',
            CUIT_Destinatario__c = '30711969523',
            Variedad__c = 'SOJA DM 4615',
            Cantidad_de_Bolsas__c = 1000,
            Campana_de_Ventas__c = '2025',
            Categoria__c = 'Primera Multiplicación',
            N_de_Comprobante__c = '2606767922'
        );
        insert base;

        Ventas_Informadas__c duplicada = new Ventas_Informadas__c(
            CUIT_Originante__c = '30709538418',
            CUIT_Destinatario__c = '30711969523',
            Variedad__c = 'SOJA DM 4615',
            Cantidad_de_Bolsas__c = 1000,
            Campana_de_Ventas__c = '2025',
            Categoria__c = 'Primera Multiplicación',
            N_de_Comprobante__c = '2607768890'
        );

        Test.startTest();
        insert duplicada;
        Test.stopTest();

        duplicada = [
            SELECT Resultado__c, Estado__c
            FROM Ventas_Informadas__c
            WHERE Id = :duplicada.Id
        ];
        System.assertEquals(
            VentasInformadasDuplicateUtil.MSG_DUPLICADO,
            duplicada.Resultado__c,
            'Debe marcar duplicado aunque cambie el N° de comprobante.'
        );
        System.assertEquals('Preprocesado', duplicada.Estado__c);
    }

    @IsTest
    static void noMarcaSiCambiaCantidad() {
        Test_TestUtils.disableFlows();

        insert new Ventas_Informadas__c(
            CUIT_Originante__c = '20111111111',
            CUIT_Destinatario__c = '20222222222',
            Variedad__c = 'VAR-X',
            Cantidad_de_Bolsas__c = 500,
            Campana_de_Ventas__c = '2024',
            Categoria__c = 'Pre Básica',
            N_de_Comprobante__c = 'A-1'
        );

        Ventas_Informadas__c otra = new Ventas_Informadas__c(
            CUIT_Originante__c = '20111111111',
            CUIT_Destinatario__c = '20222222222',
            Variedad__c = 'VAR-X',
            Cantidad_de_Bolsas__c = 501,
            Campana_de_Ventas__c = '2024',
            Categoria__c = 'Pre Básica',
            N_de_Comprobante__c = 'A-2'
        );

        Test.startTest();
        insert otra;
        Test.stopTest();

        otra = [SELECT Resultado__c FROM Ventas_Informadas__c WHERE Id = :otra.Id];
        System.assertNotEquals(VentasInformadasDuplicateUtil.MSG_DUPLICADO, otra.Resultado__c);
    }
}