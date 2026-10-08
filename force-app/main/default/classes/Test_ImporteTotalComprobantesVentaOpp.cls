@isTest
private class Test_ImporteTotalComprobantesVentaOpp {

    @TestSetup static void setup() {
        Erpvs.TestUtils.insertDatosGenerales();
        insert new Erpvs__Deshabilitacion_triggers__c(Erpvs__Comprobante_de_Venta__c = true);

        Account cuenta = Test_TestUtils.crearObtentor();

        insert new List<Opportunity>{
            new Opportunity(Name = 'Opp CV 1', StageName = 'Pendiente de Facturación', CloseDate = Date.today(), AccountId = cuenta.Id),
            new Opportunity(Name = 'Opp CV 2', StageName = 'Pendiente de Facturación', CloseDate = Date.today(), AccountId = cuenta.Id)
        };
    }

    private static List<Opportunity> getOpps() {
        return [SELECT Id, Importe_Total_Comprobantes_Venta_ARS__c FROM Opportunity ORDER BY Name];
    }

    private static ERPvs__Comprobante_Venta__c nuevoCv(Id oppId, Decimal gravado, Decimal tipoCambio) {
        return new ERPvs__Comprobante_Venta__c(
            Oportunidad__c = oppId,
            ERPvs__Fecha__c = Date.today(),
            ERPvs__Gravado1__c = gravado,
            ERPvs__Tipo_cambio__c = tipoCambio
        );
    }

    private static Decimal sumaTotalArs(Id oppId) {
        Decimal total = 0;
        for (ERPvs__Comprobante_Venta__c cv : [SELECT Total_ARS__c FROM ERPvs__Comprobante_Venta__c WHERE Oportunidad__c = :oppId]) {
            total += cv.Total_ARS__c ?? 0;
        }
        return total;
    }

    @isTest static void testAltaModificacionYBaja() {
        Opportunity opp = getOpps()[0];

        ERPvs__Comprobante_Venta__c cv1 = nuevoCv(opp.Id, 100, 2);
        ERPvs__Comprobante_Venta__c cv2 = nuevoCv(opp.Id, 50, 1);

        Test.startTest();

        insert new List<ERPvs__Comprobante_Venta__c>{ cv1, cv2 };
        Decimal totalAlta = [SELECT Importe_Total_Comprobantes_Venta_ARS__c FROM Opportunity WHERE Id = :opp.Id].Importe_Total_Comprobantes_Venta_ARS__c;
        System.assertNotEquals(0, totalAlta, 'El alta debe acumular el Total ARS');
        System.assertEquals(sumaTotalArs(opp.Id), totalAlta);

        cv1.ERPvs__Gravado1__c = 300;
        update cv1;
        Decimal totalModificado = [SELECT Importe_Total_Comprobantes_Venta_ARS__c FROM Opportunity WHERE Id = :opp.Id].Importe_Total_Comprobantes_Venta_ARS__c;
        System.assertNotEquals(totalAlta, totalModificado, 'La modificación del Total ARS debe recalcular el acumulador');
        System.assertEquals(sumaTotalArs(opp.Id), totalModificado);

        delete cv1;
        Decimal totalBaja = [SELECT Importe_Total_Comprobantes_Venta_ARS__c FROM Opportunity WHERE Id = :opp.Id].Importe_Total_Comprobantes_Venta_ARS__c;
        System.assertEquals(sumaTotalArs(opp.Id), totalBaja);
        System.assertEquals([SELECT Total_ARS__c FROM ERPvs__Comprobante_Venta__c WHERE Id = :cv2.Id].Total_ARS__c, totalBaja);

        undelete cv1;
        System.assertEquals(totalModificado, [SELECT Importe_Total_Comprobantes_Venta_ARS__c FROM Opportunity WHERE Id = :opp.Id].Importe_Total_Comprobantes_Venta_ARS__c);

        delete new List<ERPvs__Comprobante_Venta__c>{ cv1, cv2 };
        System.assertEquals(0, [SELECT Importe_Total_Comprobantes_Venta_ARS__c FROM Opportunity WHERE Id = :opp.Id].Importe_Total_Comprobantes_Venta_ARS__c);

        Test.stopTest();
    }

    @isTest static void testCambioDeOportunidad() {
        List<Opportunity> opps = getOpps();
        ERPvs__Comprobante_Venta__c cv = nuevoCv(opps[0].Id, 100, 1);
        insert cv;

        Test.startTest();
        cv.Oportunidad__c = opps[1].Id;
        update cv;
        Test.stopTest();

        opps = getOpps();
        System.assertEquals(0, opps[0].Importe_Total_Comprobantes_Venta_ARS__c);
        System.assertEquals(sumaTotalArs(opps[1].Id), opps[1].Importe_Total_Comprobantes_Venta_ARS__c);
        System.assertNotEquals(0, opps[1].Importe_Total_Comprobantes_Venta_ARS__c);
    }

    @isTest static void testBatchCargaInicial() {
        Opportunity opp = getOpps()[0];
        insert nuevoCv(opp.Id, 100, 3);

        update new Opportunity(Id = opp.Id, Importe_Total_Comprobantes_Venta_ARS__c = null);

        Test.startTest();
        Database.executeBatch(new BatchApexImporteTotalCVOpp());
        Test.stopTest();

        System.assertEquals(sumaTotalArs(opp.Id), [SELECT Importe_Total_Comprobantes_Venta_ARS__c FROM Opportunity WHERE Id = :opp.Id].Importe_Total_Comprobantes_Venta_ARS__c);
    }
}
