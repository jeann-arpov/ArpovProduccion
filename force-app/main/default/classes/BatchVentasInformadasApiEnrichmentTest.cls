@IsTest
private class BatchVentasInformadasApiEnrichmentTest {

    @TestSetup
    static void setup() {
        Test_TestUtils.disableFlows();
    }

    @IsTest
    static void enriqueceVentasApiPendientesEnBatch() {
        VentasInformadasApiNormalizer.forceEnabledForTests = false;
        insert new Ventas_Informadas_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normalizar_Ingreso_Externo__c = true
        );

        Cultivo__c cultivo = new Cultivo__c(Name = 'MAIZ BATCH', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Campana_Agricola__c(
            Name = 'Campana Batch 2025',
            Ano__c = '2025',
            Id_Externo__c = 'VI_BATCH_2025',
            Z9_Clave_Unica__c = 'VI_BATCH_Z9',
            SKEY_CAMPANIA__c = 8800300,
            Cultivo__c = cultivo.Id
        );

        insert new Variedad__c(
            Name = 'VAR BATCH 01',
            Cultivar_INASE__c = 'VAR BATCH 01',
            Cultivo__c = cultivo.Id
        );

        insert new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2025',
            Cantidad_de_Bolsas__c = 5,
            Categoria__c = 'Primera Multiplicación',
            Fecha_de_Facturacion__c = Date.today(),
            Variedad__c = 'VAR BATCH 01',
            Tipo_de_Comprobante__c = 'FC',
            Linea_Facturacion__c = 1
        );

        BatchVentasInformadasApiEnrichment batch =
            new BatchVentasInformadasApiEnrichment(UserInfo.getUserId());

        Test.startTest();
        Database.executeBatch(batch, 10);
        Test.stopTest();

        List<Ventas_Informadas__c> ventas = [
            SELECT Variedad_INASE__c, Campana_Agricola__c
            FROM Ventas_Informadas__c
            WHERE Variedad__c = 'VAR BATCH 01'
        ];
        System.assertEquals(1, ventas.size());
        System.assertNotEquals(null, ventas[0].Variedad_INASE__c);
        System.assertNotEquals(null, ventas[0].Campana_Agricola__c);
    }

    @IsTest
    static void executeAcumulaTotalesYFinishNoFalla() {
        VentasInformadasApiNormalizer.forceEnabledForTests = false;
        insert new Ventas_Informadas_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            Normalizar_Ingreso_Externo__c = true
        );

        Cultivo__c cultivo = new Cultivo__c(Name = 'TRIGO BATCH EXEC', Densidad_de_Siembra__c = 1);
        insert cultivo;

        insert new Campana_Agricola__c(
            Name = 'Campana Batch Exec 2024',
            Ano__c = '2024',
            Id_Externo__c = 'VI_BATCH_EXEC_2024',
            Z9_Clave_Unica__c = 'VI_BATCH_EXEC_Z9',
            SKEY_CAMPANIA__c = 8800301,
            Cultivo__c = cultivo.Id
        );

        insert new Variedad__c(
            Name = 'VAR BATCH EXEC',
            Cultivar_INASE__c = 'VAR BATCH EXEC',
            Cultivo__c = cultivo.Id
        );

        Ventas_Informadas__c venta = new Ventas_Informadas__c(
            Campana_de_Ventas__c = '2024',
            Cantidad_de_Bolsas__c = 3,
            Categoria__c = 'Primera Multiplicación',
            Fecha_de_Facturacion__c = Date.today(),
            Variedad__c = 'VAR BATCH EXEC',
            Tipo_de_Comprobante__c = 'FC',
            Linea_Facturacion__c = 1
        );
        insert venta;

        BatchVentasInformadasApiEnrichment batch =
            new BatchVentasInformadasApiEnrichment(UserInfo.getUserId());
        List<Ventas_Informadas__c> scope = (List<Ventas_Informadas__c>) Database.query(
            'SELECT ' +
                VentasInformadasPortalEnrichmentService.camposEnriquecimientoSoql() +
                ' FROM Ventas_Informadas__c WHERE Id = \'' +
                String.valueOf(venta.Id) +
                '\''
        );

        batch.execute(null, scope);
        System.assertEquals(1, batch.getTotalActualizados());
        System.assertEquals(0, batch.getTotalErrores());
        batch.finish(null);
    }
}