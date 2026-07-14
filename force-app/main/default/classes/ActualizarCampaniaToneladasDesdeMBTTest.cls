@isTest
private class ActualizarCampaniaToneladasDesdeMBTTest {
    @isTest
    static void actualizaCampaniaDesdeCosechaMbt() {
        Account productor = Test_TestUtils.crearProductor();
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Temporada__c = 'Anual',
            Densidad_de_Siembra__c = 23
        );
        insert cultivo;

        Campana_Agricola__c campana2024 = new Campana_Agricola__c(
            Name = 'Campaña 2024',
            Ano__c = '2024',
            Id_Externo__c = 'TEST_EXT_2024',
            SKEY_CAMPANIA__c = 2024002,
            Z9_Clave_Unica__c = 'TEST_Z9_2024',
            Cultivo__c = cultivo.Id,
            Fecha_Inicio_SE__c = Date.newInstance(2024, 1, 1),
            Fecha_Fin_SE__c = Date.newInstance(2024, 12, 31)
        );
        insert campana2024;

        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
            Estado__c = 'Creado',
            Fecha_de_Analisis__c = '15/10/2023',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'Enlist',
            CTG__c = '123',
            Codigo_de_Muestra__c = '123',
            Peso_Neto__c = 100,
            CUIT_Titular__c = productor.N_CUIT__c,
            Cuit_Destinatario__c = productor.N_CUIT__c,
            Cosecha__c = '2426'
        );
        insert mbt;

        Tonelada__c tn = new Tonelada__c(
            Productor__c = productor.Id,
            Cantidad__c = 10,
            Cultivo__c = cultivo.Id,
            Mov_BolsaTech__c = mbt.Id
        );
        insert tn;

        ActualizarCampaniaToneladasDesdeMBT.Request req = new ActualizarCampaniaToneladasDesdeMBT.Request();
        req.movimientoBolsaTechId = mbt.Id;

        Test.startTest();
        ActualizarCampaniaToneladasDesdeMBT.ejecutar(new List<ActualizarCampaniaToneladasDesdeMBT.Request>{ req });
        Test.stopTest();

        Tonelada__c tnActualizada = [SELECT Campania__c FROM Tonelada__c WHERE Id = :tn.Id];
        System.assertEquals(campana2024.Id, tnActualizada.Campania__c);
    }
}