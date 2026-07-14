@IsTest
private class ValidarLicenciasCuentaPrincipalTest {
    
    @TestSetup
    static void makeData() {
        // Crear cuentas de test
        RecordType rt = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Productor' LIMIT 1];
        RecordType rtObtentor = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor' LIMIT 1];
        Account obtentor = new Account(Name = 'Obtentor Test', RecordTypeId =rtObtentor.Id);
        insert obtentor;
        
        Account productor1 = new Account(Name = 'Productor 1', RecordTypeId =rt.Id, ParentId = obtentor.Id);
        Account productor2 = new Account(Name = 'Productor 2', RecordTypeId =rt.Id, ParentId = obtentor.Id);
        insert new List<Account>{productor1, productor2};
        
        // Crear variedad con biotecnología
        Variedad__c variedad = new Variedad__c(Name = 'Variedad 1', Biotecnologia__c = 'Enlist E3',Obtentor_Comercializa__c = obtentor.Id);
        insert variedad;

        // Crear producto
        Product2 producto = new Product2(Name = 'Producto 1', Variedad2__c = variedad.Id, Variedad__c ='DON MARIO 46E21 E');
        insert producto;

        Cultivo__c cultivo = new Cultivo__c(Name = 'Cultivo 1',Temporada__c='Anual', Densidad_de_Siembra__c= 23);
        insert cultivo;

        Campana_Agricola__c  campana = new Campana_Agricola__c (Name = 'Campaña 1', Ano__c='2025', Id_Externo__c = 'S787DS8SJGYS8',SKEY_CAMPANIA__c = 2020924,Z9_Clave_Unica__c='Z9123456',Cultivo__c= cultivo.Id);
        insert campana;
        
        // Crear ventas de diferentes tipos
        List<Venta__c> ventas = new List<Venta__c>();
        
        // Venta tipo C con Obtentor como Originante
        ventas.add(new Venta__c(
            Originante__c = productor1.Id,
            Destinatario__c = productor2.Id,
            Rol_Originante__c = 'Obtentor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'C',
            Producto__c = producto.Id,
            Cantidad__c = 12, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Venta tipo Venta con Obtentor como Originante
        ventas.add(new Venta__c(
            Originante__c = productor1.Id,
            Destinatario__c = productor2.Id,
            Rol_Originante__c = 'Obtentor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'Venta',
            Producto__c = producto.Id,
            Cantidad__c = 13, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Venta tipo TDS con Obtentor como Destinatario
        ventas.add(new Venta__c(
            Originante__c = productor2.Id,
            Destinatario__c = productor1.Id,
            Rol_Originante__c = 'Productor',
            Rol_Destinatario__c = 'Obtentor',
            Tipo_de_Venta__c = 'TDS',
            Producto__c = producto.Id,
            Cantidad__c = 14, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Venta tipo DPO con Obtentor como Destinatario
        ventas.add(new Venta__c(
            Originante__c = productor2.Id,
            Destinatario__c = productor1.Id,
            Rol_Originante__c = 'Productor',
            Rol_Destinatario__c = 'Obtentor',
            Tipo_de_Venta__c = 'DPO',
            Producto__c = producto.Id,
            Cantidad__c = 15, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Venta tipo DPD
        ventas.add(new Venta__c(
            Originante__c = productor1.Id,
            Destinatario__c = productor2.Id,
            Rol_Originante__c = 'Productor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'DPD',
            Producto__c = producto.Id,
            Cantidad__c = 16, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        insert ventas;
        
        // Crear licencias
        List<Licencia__c> licencias = new List<Licencia__c>();
        
        licencias.add(new Licencia__c(
            Cuenta_Productor__c = productor1.Id,
            Cuenta_Obtentor__c = obtentor.Id,
            Tecnologia__c = 'Enlist',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada'
        ));
        
        licencias.add(new Licencia__c(
            Cuenta_Productor__c = productor2.Id,
            Cuenta_Obtentor__c = obtentor.Id,
            Tecnologia__c = 'RR',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada'
        ));
        
        insert licencias;
    }
    
    @IsTest
    static void testExecuteMethodWithDestinatarioRole() {
        List<Account> productores = [SELECT Id FROM Account WHERE Type = 'Productor'];
        
        ValidarLicenciasCuentaPrincipal.Request request = new ValidarLicenciasCuentaPrincipal.Request();
        request.productores = new List<Id>();
        for(Account prod : productores) {
            request.productores.add(prod.Id);
        }
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasCuentaPrincipal.Response> responses = 
            ValidarLicenciasCuentaPrincipal.execute(new List<ValidarLicenciasCuentaPrincipal.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses);
        System.assertEquals(1, responses.size());
        System.assertNotEquals(null, responses[0].productoresOk);
    }
    
    @IsTest
    static void testExecuteMethodWithOriginanteRole() {
        List<Account> productores = [SELECT Id FROM Account WHERE Type = 'Productor'];
        
        ValidarLicenciasCuentaPrincipal.Request request = new ValidarLicenciasCuentaPrincipal.Request();
        request.productores = new List<Id>();
        for(Account prod : productores) {
            request.productores.add(prod.Id);
        }
        request.rol = 'Originante';
        
        Test.startTest();
        List<ValidarLicenciasCuentaPrincipal.Response> responses = 
            ValidarLicenciasCuentaPrincipal.execute(new List<ValidarLicenciasCuentaPrincipal.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses);
        System.assertEquals(1, responses.size());
        System.assertNotEquals(null, responses[0].productoresOk);
    }
    
    @IsTest
    static void testGetVentasTipoCoVentas() {
        List<Venta__c> ventas = [SELECT Id, Rol_Originante__c, Tipo_de_Venta__c FROM Venta__c];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.getVentasTipoCoVentas(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        for(Venta__c v : result) {
            System.assertEquals('Obtentor', v.Rol_Originante__c);
            System.assert(v.Tipo_de_Venta__c == 'C' || v.Tipo_de_Venta__c == 'Venta');
        }
    }
    
    @IsTest
    static void testGetVentasTipoTDSoDPO() {
        List<Venta__c> ventas = [SELECT Id, Rol_Destinatario__c, Tipo_de_Venta__c FROM Venta__c];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.getVentasTipoTDSoDPO(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        for(Venta__c v : result) {
            System.assertEquals('Obtentor', v.Rol_Destinatario__c);
            System.assert(v.Tipo_de_Venta__c == 'TDS' || v.Tipo_de_Venta__c == 'DPO');
        }
    }
    
    @IsTest
    static void testGetVentasTipoVenta() {
        List<Venta__c> ventas = [SELECT Id, Tipo_de_Venta__c FROM Venta__c];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.getVentasTipoVenta(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        for(Venta__c v : result) {
            System.assertEquals('Venta', v.Tipo_de_Venta__c);
        }
    }
    
    @IsTest
    static void testGetVentasTipoTDS() {
        List<Venta__c> ventas = [SELECT Id, Tipo_de_Venta__c FROM Venta__c];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.getVentasTipoTDS(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        for(Venta__c v : result) {
            System.assert(v.Tipo_de_Venta__c == 'DPD' || v.Tipo_de_Venta__c == 'DPO');
        }
    }
    
    @IsTest
    static void testMapearTecnologiaEnlist() {
        // Crear variedad con biotecnología Enlist
        Account obtentor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Obtentor' LIMIT 1];

        Variedad__c variedadEnlist = new Variedad__c(
            Name = 'Variedad Enlist',
            Biotecnologia__c = 'Enlist E3',
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedadEnlist;
         // Crear producto
        Product2 productoEnlist = new Product2(Name = 'Producto Enlist', Variedad2__c = variedadEnlist.Id, Variedad__c ='DON MARIO 4E1 E');
        insert productoEnlist;

        
        List<Venta__c> ventas = [SELECT Id, Producto__r.Variedad2__r.Biotecnologia__c FROM Venta__c];
        ventas[0].Producto__c = productoEnlist.Id;
        update ventas;
        
        ventas = [SELECT Id, Producto__r.Variedad2__r.Biotecnologia__c FROM Venta__c WHERE Producto__c = :productoEnlist.Id];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.mapearTecnologiaEnlist(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testMapearTecnologiaRR() {
        // Crear variedad con biotecnología RR
        Account obtentor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Obtentor' LIMIT 1];
        Variedad__c variedadRR = new Variedad__c(
            Name = 'Variedad RR',
            Biotecnologia__c = 'RR1',
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedadRR;
        
        Product2 productoRR = new Product2(
            Name = 'Producto RR',
            Variedad2__c = variedadRR.Id,
            Variedad__c ='DON MARIO 46E1 2E'
        );
        insert productoRR;
        
        List<Venta__c> ventas = [SELECT Id FROM Venta__c LIMIT 1];
        ventas[0].Producto__c = productoRR.Id;
        update ventas;
        
        ventas = [SELECT Id, Producto__r.Variedad2__r.Biotecnologia__c FROM Venta__c WHERE Producto__c = :productoRR.Id];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.mapearTecnologiaRR(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testMapearTecnologiaOtra() {
        // Crear variedad con biotecnología HB4
        Account obtentor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Obtentor' LIMIT 1];
        Variedad__c variedadHB4 = new Variedad__c(
            Name = 'Variedad HB4',
            Biotecnologia__c = 'HB4',
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedadHB4;
        
        Product2 productoHB4 = new Product2(
            Name = 'Producto HB4',
            Variedad2__c = variedadHB4.Id,
            Variedad__c ='DON MARIO 46E2 1E'
        );
        insert productoHB4;
        
        List<Venta__c> ventas = [SELECT Id FROM Venta__c LIMIT 1];
        ventas[0].Producto__c = productoHB4.Id;
        update ventas;
        
        ventas = [SELECT Id, Producto__r.Variedad2__r.Biotecnologia__c FROM Venta__c WHERE Producto__c = :productoHB4.Id];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.mapearTecnologiaOtra(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testGetLicencias() {
        Set<String> claves = new Set<String>();
        List<Account> productores = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Productor'];
        Account obtentor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Obtentor' LIMIT 1];
        
        for(Account prod : productores) {
            claves.add(prod.Id + '' + obtentor.Id);
        }
        
        Test.startTest();
        List<Licencia__c> result = ValidarLicenciasCuentaPrincipal.getLicencias(claves, 'Enlist');
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testGetProductoresConLicencia() {
        List<Licencia__c> licencias = [SELECT Id, Cuenta_Productor__c FROM Licencia__c];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciasCuentaPrincipal.getProductoresConLicencia(licencias);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(licencias.size(), result.size());
    }
    
    @IsTest
    static void testGetVentas() {
        List<Account> productores = [SELECT Id FROM Account WHERE Type = 'Productor'];
        Set<Id> productoresIds = new Set<Id>();
        for(Account prod : productores) {
            productoresIds.add(prod.Id);
        }
        
        Test.startTest();
        List<Venta__c> resultDestinatario = ValidarLicenciasCuentaPrincipal.getVentas(productoresIds, 'Destinatario');
        List<Venta__c> resultOriginante = ValidarLicenciasCuentaPrincipal.getVentas(productoresIds, 'Originante');
        Test.stopTest();
        
        System.assertNotEquals(null, resultDestinatario);
        System.assertNotEquals(null, resultOriginante);
    }
    
    @IsTest
    static void testGetClaveVentasRolDestinatario() {
        List<Venta__c> ventas = [SELECT Id, Destinatario__c, Producto__r.Variedad2__r.Obtentor_Comercializa__c FROM Venta__c WHERE Destinatario__c != null];
        
        Test.startTest();
        Set<String> result = ValidarLicenciasCuentaPrincipal.getClaveVentasRolDestinatario(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }
    
    @IsTest
    static void testGetClaveVentasRolOriginante() {
        List<Venta__c> ventas = [SELECT Id, Originante__c, Producto__r.Variedad2__r.Obtentor_Comercializa__c FROM Venta__c WHERE Originante__c != null];
        
        Test.startTest();
        Set<String> result = ValidarLicenciasCuentaPrincipal.getClaveVentasRolOriginante(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);
    }
    
    @IsTest
    static void testObtenerProductores() {
        List<Venta__c> ventas = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                       Originante__c, Destinatario__c, 
                                       Producto__r.Variedad2__r.Biotecnologia__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__c 
                                FROM Venta__c];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciasCuentaPrincipal.obtenerProductores(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
    }
    
    @IsTest
    static void testMapearTecnologiaConkesta() {
        // Crear variedad con biotecnología Conkesta E3
        Account obtentor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Obtentor' LIMIT 1];
        Variedad__c variedadConkesta = new Variedad__c(
            Name = 'Variedad Conkesta',
            Biotecnologia__c = 'Conkesta E3',
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedadConkesta;
                    
        Product2 productoConkesta = new Product2(
            Name = 'Producto Conkesta',
            Variedad2__c = variedadConkesta.Id,
            Variedad__c ='DON MARIO 46E2 4E'
        );
        insert productoConkesta;
        
        List<Venta__c> ventas = [SELECT Id FROM Venta__c LIMIT 1];
        ventas[0].Producto__c = productoConkesta.Id;
        update ventas;
        
        ventas = [SELECT Id, Producto__r.Variedad2__r.Biotecnologia__c FROM Venta__c WHERE Producto__c = :productoConkesta.Id];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.mapearTecnologiaEnlist(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }
    
    @IsTest
    static void testMapearTecnologiaConvencional() {
        // Crear variedad con biotecnología Convencional
        Account obtentor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Obtentor' LIMIT 1];
        Variedad__c variedadConv = new Variedad__c(
            Name = 'Variedad Convencional',
            Biotecnologia__c = 'Convencional',
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedadConv;
        
        
        Product2 productoConv = new Product2(
            Name = 'Producto Convencional',
            Variedad2__c = variedadConv.Id,
            Variedad__c ='DON MARIO 46E2 6E'
        );
        insert productoConv;
        
        List<Venta__c> ventas = [SELECT Id FROM Venta__c LIMIT 1];
        ventas[0].Producto__c = productoConv.Id;
        update ventas;
        
        ventas = [SELECT Id, Producto__r.Variedad2__r.Biotecnologia__c FROM Venta__c WHERE Producto__c = :productoConv.Id];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.mapearTecnologiaRR(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }
    
    @IsTest
    static void testMapearTecnologiaBGRR() {
        // Crear variedad con biotecnología BGRR
        Account obtentor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Obtentor' LIMIT 1];
        Variedad__c variedadBGRR = new Variedad__c(
            Name = 'Variedad BGRR',
            Biotecnologia__c = 'BGRR',
            Obtentor_Comercializa__c = obtentor.Id
        );
        insert variedadBGRR;

        
        
        Product2 productoBGRR = new Product2(
            Name = 'Producto BGRR',
            Variedad2__c = variedadBGRR.Id,
            Variedad__c ='DON MARIO 4662 7E'
        );
        insert productoBGRR;
        
        List<Venta__c> ventas = [SELECT Id FROM Venta__c LIMIT 1];
        ventas[0].Producto__c = productoBGRR.Id;
        update ventas;
        
        ventas = [SELECT Id, Producto__r.Variedad2__r.Biotecnologia__c FROM Venta__c WHERE Producto__c = :productoBGRR.Id];
        
        Test.startTest();
        List<Venta__c> result = ValidarLicenciasCuentaPrincipal.mapearTecnologiaOtra(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result);
        System.assertEquals(1, result.size());
    }
}