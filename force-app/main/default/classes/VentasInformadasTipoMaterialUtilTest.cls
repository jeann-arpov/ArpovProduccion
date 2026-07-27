@IsTest
private class VentasInformadasTipoMaterialUtilTest {

    private class ProductosFixture {
        Product2 prodRc;
        Product2 prodSf;
        String cultivar;
        String categoria;
    }

    private static ProductosFixture crearProductosPar() {
        Test_TestUtils.disableFlows();
        String cultivar = 'VARRC' + String.valueOf(Math.abs(Crypto.getRandomInteger())).right(8);
        String categoria = 'Primera Multiplicación';

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'Cultivo RC ' + cultivar,
            Unidad_de_Medida_Por_Defecto__c = '40',
            Densidad_de_Siembra__c = 1
        );
        insert cultivo;
        Account obtentor = Test_TestUtils.crearObtentor();
        Variedad__c variedad = new Variedad__c(
            Name = cultivar,
            Cultivar_INASE__c = cultivar,
            Cultivo__c = cultivo.Id,
            Sembra_Evolucion__c = false
        );
        insert variedad;

        Product2 prodRc = Test_TestUtils.crearProducto(
            true,
            cultivar + ' RC',
            'RC' + cultivar.right(6),
            cultivar,
            cultivo,
            VentasInformadasTipoMaterialUtil.REGALIA_COMERCIAL,
            1,
            obtentor,
            variedad.Id,
            true
        );
        prodRc.Categoria__c = categoria;
        prodRc.Cultivar_Inase__c = cultivar;
        prodRc.Unidad_de_Medida__c = '40';

        Product2 prodSf = Test_TestUtils.crearProducto(
            true,
            cultivar + ' SF',
            'SF' + cultivar.right(6),
            cultivar,
            cultivo,
            VentasInformadasTipoMaterialUtil.SEMILLA_FISCALIZADA,
            1,
            obtentor,
            variedad.Id,
            true
        );
        prodSf.Categoria__c = categoria;
        prodSf.Cultivar_Inase__c = cultivar;
        prodSf.Unidad_de_Medida__c = '40';
        update new List<Product2>{ prodRc, prodSf };

        ProductosFixture fx = new ProductosFixture();
        fx.cultivar = cultivar;
        fx.categoria = categoria;
        fx.prodRc = [SELECT Id, Cultivo__c FROM Product2 WHERE Id = :prodRc.Id];
        fx.prodSf = [SELECT Id, Cultivo__c FROM Product2 WHERE Id = :prodSf.Id];
        return fx;
    }

    @IsTest
    static void triggerAlMarcarSeteaTipoYProductoRc() {
        ProductosFixture fx = crearProductosPar();

        Ventas_Informadas__c vi = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223',
            Variedad__c = fx.cultivar,
            Categoria__c = fx.categoria,
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2026',
            Tipo_de_regalia_comercial__c = true
        );

        Test.startTest();
        insert vi;
        Test.stopTest();

        vi = [
            SELECT Tipo_de_Material__c, Producto__c, Tipo_de_regalia_comercial__c
            FROM Ventas_Informadas__c
            WHERE Id = :vi.Id
        ];
        System.assertEquals(
            VentasInformadasTipoMaterialUtil.REGALIA_COMERCIAL,
            vi.Tipo_de_Material__c
        );
        System.assertEquals(fx.prodRc.Id, vi.Producto__c);
    }

    @IsTest
    static void triggerAlDesmarcarRestauraProductoYLimpiaTipo() {
        ProductosFixture fx = crearProductosPar();

        Ventas_Informadas__c vi = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223',
            Variedad__c = fx.cultivar,
            Categoria__c = fx.categoria,
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2026',
            Tipo_de_regalia_comercial__c = true
        );
        insert vi;

        vi = [
            SELECT Tipo_de_Material__c, Producto__c
            FROM Ventas_Informadas__c
            WHERE Id = :vi.Id
        ];
        System.assertEquals(fx.prodRc.Id, vi.Producto__c);

        Test.startTest();
        vi.Tipo_de_regalia_comercial__c = false;
        update vi;
        Test.stopTest();

        vi = [
            SELECT Tipo_de_Material__c, Producto__c, Tipo_de_regalia_comercial__c
            FROM Ventas_Informadas__c
            WHERE Id = :vi.Id
        ];
        System.assertEquals(null, vi.Tipo_de_Material__c);
        System.assertEquals(fx.prodSf.Id, vi.Producto__c);
        System.assertEquals(false, vi.Tipo_de_regalia_comercial__c);
    }

    @IsTest
    static void aplicaSoloSiCheckboxMarcadoYAsignaProducto() {
        ProductosFixture fx = crearProductosPar();

        Ventas_Informadas__c conCheck = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20111111112',
            CUIT_Destinatario__c = '20222222223',
            Variedad__c = fx.cultivar,
            Categoria__c = fx.categoria,
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2026',
            Tipo_de_regalia_comercial__c = true
        );
        Ventas_Informadas__c sinCheck = new Ventas_Informadas__c(
            Tipo_de_Comprobante__c = 'FC',
            Estado__c = 'Pendiente',
            CUIT_Originante__c = '20333333334',
            CUIT_Destinatario__c = '20444444445',
            Variedad__c = 'VAR-TM-NO',
            Categoria__c = fx.categoria,
            Cantidad_de_Bolsas__c = 40,
            Campana_de_Ventas__c = '2026',
            Tipo_de_regalia_comercial__c = false
        );
        insert new List<Ventas_Informadas__c>{ conCheck, sinCheck };

        // Insert ya aplicó por trigger; limpiamos Tipo/Producto en conCheck vía desmarcar
        // y reaplicamos con util DML (camino Reprocesar).
        conCheck.Tipo_de_regalia_comercial__c = false;
        update conCheck;
        conCheck.Tipo_de_regalia_comercial__c = true;
        update conCheck;

        Test.startTest();
        VentasInformadasTipoMaterialUtil.aplicarDesdeCheckbox(
            new Set<Id>{ conCheck.Id, sinCheck.Id }
        );
        Test.stopTest();

        Map<Id, Ventas_Informadas__c> byId = new Map<Id, Ventas_Informadas__c>([
            SELECT Tipo_de_Material__c, Tipo_de_regalia_comercial__c, Producto__c, Cultivo__c
            FROM Ventas_Informadas__c
            WHERE Id IN :new Set<Id>{ conCheck.Id, sinCheck.Id }
        ]);
        System.assertEquals(
            VentasInformadasTipoMaterialUtil.REGALIA_COMERCIAL,
            byId.get(conCheck.Id).Tipo_de_Material__c
        );
        System.assertEquals(fx.prodRc.Id, byId.get(conCheck.Id).Producto__c);
        System.assertEquals(null, byId.get(sinCheck.Id).Tipo_de_Material__c);
    }

    @IsTest
    static void setVacioNoHaceDml() {
        Test.startTest();
        VentasInformadasTipoMaterialUtil.aplicarDesdeCheckbox(null);
        VentasInformadasTipoMaterialUtil.aplicarDesdeCheckbox(new Set<Id>());
        Test.stopTest();
        System.assertEquals(0, Limits.getDmlStatements());
    }

    @IsTest
    static void esRegaliaComercialPorCheckboxOTipo() {
        System.assertEquals(
            true,
            VentasInformadasTipoMaterialUtil.esRegaliaComercial(
                new Ventas_Informadas__c(Tipo_de_regalia_comercial__c = true)
            )
        );
        System.assertEquals(
            true,
            VentasInformadasTipoMaterialUtil.esRegaliaComercial(
                new Ventas_Informadas__c(
                    Tipo_de_Material__c = VentasInformadasTipoMaterialUtil.REGALIA_COMERCIAL
                )
            )
        );
        System.assertEquals(
            false,
            VentasInformadasTipoMaterialUtil.esRegaliaComercial(
                new Ventas_Informadas__c(Tipo_de_regalia_comercial__c = false)
            )
        );
        System.assertEquals(false, VentasInformadasTipoMaterialUtil.esRegaliaComercial(null));
    }
}
