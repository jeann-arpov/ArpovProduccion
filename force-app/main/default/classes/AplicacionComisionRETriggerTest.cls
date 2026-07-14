@IsTest
private class AplicacionComisionRETriggerTest {

    @IsTest(SeeAllData=true)
    static void triggerMarcaTieneComisionREConDatosExistentes() {
        List<Aplicacion__c> aplicaciones = [
            SELECT Id, Factura__c, CV_Comisiones__c
            FROM Aplicacion__c
            WHERE CV_Comisiones__c != null
            AND Factura__c != null
            LIMIT 1
        ];

        if (aplicaciones.isEmpty()) {
            return;
        }

        Aplicacion__c aplicacion = aplicaciones[0];
        Id cvComisionesId = aplicacion.CV_Comisiones__c;
        Opportunity factura = [
            SELECT Id, Tiene_Comision_RE__c
            FROM Opportunity
            WHERE Id = :aplicacion.Factura__c
            LIMIT 1
        ];

        aplicacion.CV_Comisiones__c = null;
        update aplicacion;

        Test.startTest();
        aplicacion.CV_Comisiones__c = cvComisionesId;
        update aplicacion;
        Test.stopTest();

        System.assertEquals(
            true,
            [SELECT Tiene_Comision_RE__c FROM Opportunity WHERE Id = :factura.Id].Tiene_Comision_RE__c
        );
    }
}