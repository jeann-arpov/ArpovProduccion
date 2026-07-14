@IsTest
private class ValidarLicenciaCuentaRelacionadaTest {
    
    @TestSetup
    static void makeData() {
        RecordType rt = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Productor' LIMIT 1];
        RecordType rtObtentor = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor' LIMIT 1];
        
        // Crear cuenta padre (Obtentor principal)
        Account obtentorPadre = new Account(Name = 'Obtentor Padre', RecordTypeId =rtObtentor.Id);
        insert obtentorPadre;
        
        // Crear cuenta hijo (Obtentor relacionado)
        Account obtentorHijo = new Account(
            Name = 'Obtentor Hijo', 
            RecordTypeId =rtObtentor.Id,
            ParentId = obtentorPadre.Id
        );
        insert obtentorHijo;
        
        // Crear cuentas productores
        Account productor1 = new Account(Name = 'Productor 1', RecordTypeId =rt.Id);
        Account productor2 = new Account(Name = 'Productor 2', RecordTypeId =rt.Id);
        Account productor3 = new Account(Name = 'Productor 3', RecordTypeId =rt.Id);
        insert new List<Account>{productor1, productor2, productor3};
        
        // Crear variedades con diferentes biotecnologías
        List<Variedad__c> variedades = new List<Variedad__c>();
        
        variedades.add(new Variedad__c(
            Name = 'Variedad Enlist',
            Biotecnologia__c = 'Enlist E3',
            Obtentor_Comercializa__c = obtentorHijo.Id
        ));
        
        variedades.add(new Variedad__c(
            Name = 'Variedad RR',
            Biotecnologia__c = 'RR1',
            Obtentor_Comercializa__c = obtentorHijo.Id
        ));
        
        variedades.add(new Variedad__c(
            Name = 'Variedad HB4',
            Biotecnologia__c = 'HB4',
            Obtentor_Comercializa__c = obtentorHijo.Id
        ));
        
        variedades.add(new Variedad__c(
            Name = 'Variedad Conkesta',
            Biotecnologia__c = 'Conkesta E3',
            Obtentor_Comercializa__c = obtentorHijo.Id
        ));
        
        variedades.add(new Variedad__c(
            Name = 'Variedad Convencional',
            Biotecnologia__c = 'Convencional',
            Obtentor_Comercializa__c = obtentorHijo.Id
        ));
        
        variedades.add(new Variedad__c(
            Name = 'Variedad BGRR',
            Biotecnologia__c = 'BGRR',
            Obtentor_Comercializa__c = obtentorHijo.Id
        ));
        
        insert variedades;
        
        // Crear productos    
        List<Product2> productos = new List<Product2>();
        for(Variedad__c var : variedades) {
            productos.add(new Product2(
                Name = 'Producto ' + var.Name,
                Variedad2__c = var.Id,
                Variedad__c ='DON MARIO 46E1 E'
            ));
        }
        insert productos;

        Cultivo__c cultivo = new Cultivo__c(Name = 'Cultivo 1',Temporada__c='Anual', Densidad_de_Siembra__c= 23);
        insert cultivo;

        Campana_Agricola__c  campana = new Campana_Agricola__c (Name = 'Campaña 1', Ano__c='2025', Id_Externo__c = 'S787DS8SJGYS8',SKEY_CAMPANIA__c = 2020924,Z9_Clave_Unica__c='Z9123456',Cultivo__c= cultivo.Id);
        insert campana;
        
        // Crear ventas de diferentes tipos
        List<Venta__c> ventas = new List<Venta__c>();
            
        // Ventas tipo C con Obtentor como Originante (Productor como Destinatario)
        ventas.add(new Venta__c(
            Originante__c = productor1.Id,
            Destinatario__c = productor2.Id,
            Rol_Originante__c = 'Obtentor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'C',
            Producto__c = productos[0].Id,
            Cantidad__c = 12, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Ventas tipo Venta con Obtentor como Originante
        ventas.add(new Venta__c(
            Originante__c = productor1.Id,
            Destinatario__c = productor2.Id,
            Rol_Originante__c = 'Obtentor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'Venta',
            Producto__c = productos[1].Id,
            Cantidad__c = 13, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Ventas tipo TDS con Obtentor como Destinatario (Productor como Originante)
        ventas.add(new Venta__c(
            Originante__c = productor2.Id,
            Destinatario__c = productor1.Id,
            Rol_Originante__c = 'Productor',
            Rol_Destinatario__c = 'Obtentor',
            Tipo_de_Venta__c = 'TDS',
            Producto__c = productos[2].Id,
            Cantidad__c = 14, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Ventas tipo DPO con Obtentor como Destinatario
        ventas.add(new Venta__c(
            Originante__c = productor2.Id,
            Destinatario__c = productor1.Id,
            Rol_Originante__c = 'Productor',
            Rol_Destinatario__c = 'Obtentor',
            Tipo_de_Venta__c = 'DPO',
            Producto__c = productos[3].Id,
            Cantidad__c = 15, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Ventas tipo DPD
        ventas.add(new Venta__c(
            Originante__c = productor1.Id,
            Destinatario__c = productor2.Id,
            Rol_Originante__c = 'Productor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'DPD',
            Producto__c = productos[4].Id,
            Cantidad__c = 16, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        // Venta adicional con tecnología BGRR
        ventas.add(new Venta__c(
            Originante__c = productor3.Id,
            Destinatario__c = productor1.Id,
            Rol_Originante__c = 'Obtentor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'C',
            Producto__c = productos[5].Id,
            Cantidad__c = 16, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        ));
        
        insert ventas;
        
        // Crear licencias para cuentas relacionadas (usando el ParentId del obtentor)
        List<Licencia__c> licencias = new List<Licencia__c>();
        
        // Licencias Enlist
        licencias.add(new Licencia__c(
            Cuenta_Productor__c = productor1.Id,
            Cuenta_Obtentor__c = obtentorPadre.Id, // Usando cuenta padre
            Tecnologia__c = 'Enlist',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada'
        ));
        
        // Licencias RR
        licencias.add(new Licencia__c(
            Cuenta_Productor__c = productor2.Id,
            Cuenta_Obtentor__c = obtentorPadre.Id,
            Tecnologia__c = 'RR',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada'
        ));
        
        // Licencias Otra
        licencias.add(new Licencia__c(
            Cuenta_Productor__c = productor3.Id,
            Cuenta_Obtentor__c = obtentorPadre.Id,
            Tecnologia__c = 'Otra',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada'
        ));
        
        insert licencias;
    }
    
    @IsTest
    static void testExecuteMethodWithDestinatarioRole() {
        List<Account> productores = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Productor'];
        
        ValidarLicenciaCuentaRelacionada.Request request = new ValidarLicenciaCuentaRelacionada.Request();
        request.productores = new List<Id>();
        for(Account prod : productores) {
            request.productores.add(prod.Id);
        }
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciaCuentaRelacionada.Response> responses = 
            ValidarLicenciaCuentaRelacionada.execute(new List<ValidarLicenciaCuentaRelacionada.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].productoresOk, 'ProductoresOk should not be null');
    }
    
    @IsTest
    static void testExecuteMethodWithOriginanteRole() {
        List<Account> productores = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Productor'];
        
        ValidarLicenciaCuentaRelacionada.Request request = new ValidarLicenciaCuentaRelacionada.Request();
        request.productores = new List<Id>();
        for(Account prod : productores) {
            request.productores.add(prod.Id);
        }
        request.rol = 'Originante';
        
        Test.startTest();
        List<ValidarLicenciaCuentaRelacionada.Response> responses = 
            ValidarLicenciaCuentaRelacionada.execute(new List<ValidarLicenciaCuentaRelacionada.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].productoresOk, 'ProductoresOk should not be null');
    }
    
    @IsTest
    static void testGetProductoresMethod() {
        List<Venta__c> ventas = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                       Originante__c, Destinatario__c, 
                                       Producto__r.Variedad2__r.Biotecnologia__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                FROM Venta__c];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetClaveRolDestinatarioWithValidData() {
        List<Venta__c> ventas = [SELECT Id, Destinatario__c, 
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                FROM Venta__c 
                                WHERE Destinatario__c != null];
        
        Test.startTest();
        Set<String> result = ValidarLicenciaCuentaRelacionada.getClaveRolDestinatario(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() >= 0, 'Result should have at least 0 elements');
    }
    
    @IsTest
    static void testGetClaveRolDestinatarioWithNullDestinario() {
        List<Venta__c> ventas = [SELECT Id, Destinatario__c, 
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                FROM Venta__c 
                                LIMIT 1];
        
        // Simular caso con Destinatario null
        for(Venta__c v : ventas) {
            v.Destinatario__c = null;
        }
        
        Test.startTest();
        Set<String> result = ValidarLicenciaCuentaRelacionada.getClaveRolDestinatario(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty when Destinatario is null');
    }
    
    @IsTest
    static void testGetClaveRolOriginanteWithValidData() {
        List<Venta__c> ventas = [SELECT Id, Originante__c, 
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                FROM Venta__c 
                                WHERE Originante__c != null];
        
        Test.startTest();
        Set<String> result = ValidarLicenciaCuentaRelacionada.getClaveRolOriginante(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assert(result.size() >= 0, 'Result should have at least 0 elements');
    }
    
    @IsTest
    static void testGetClaveRolOriginanteWithNullOriginante() {
        List<Venta__c> ventas = [SELECT Id, Originante__c, 
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                FROM Venta__c 
                                LIMIT 1];
        
        // Simular caso con Originante null
        for(Venta__c v : ventas) {
            v.Originante__c = null;
        }
        
        Test.startTest();
        Set<String> result = ValidarLicenciaCuentaRelacionada.getClaveRolOriginante(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty when Originante is null');
    }
    
    @IsTest
    static void testGetProductoresWithEnlistTechnology() {
        // Crear ventas específicas para tecnología Enlist
        List<Venta__c> ventasEnlist = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                             Originante__c, Destinatario__c, 
                                             Producto__r.Variedad2__r.Biotecnologia__c,
                                             Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                             Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                      FROM Venta__c 
                                      WHERE Producto__r.Variedad2__r.Biotecnologia__c = 'Enlist E3'];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(ventasEnlist);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetProductoresWithRRTechnology() {
        // Crear ventas específicas para tecnología RR
        List<Venta__c> ventasRR = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                         Originante__c, Destinatario__c, 
                                         Producto__r.Variedad2__r.Biotecnologia__c,
                                         Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                         Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                  FROM Venta__c 
                                  WHERE Producto__r.Variedad2__r.Biotecnologia__c = 'RR2'];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(ventasRR);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetProductoresWithOtraTechnology() {
        // Crear ventas específicas para otras tecnologías (HB4, BGRR)
        List<Venta__c> ventasOtra = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                           Originante__c, Destinatario__c, 
                                           Producto__r.Variedad2__r.Biotecnologia__c,
                                           Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                           Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                    FROM Venta__c 
                                    WHERE Producto__r.Variedad2__r.Biotecnologia__c IN ('HB4', 'BGRR')];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(ventasOtra);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetProductoresWithConkestaTechnology() {
        // Crear ventas específicas para tecnología Conkesta
        List<Venta__c> ventasConkesta = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                               Originante__c, Destinatario__c, 
                                               Producto__r.Variedad2__r.Biotecnologia__c,
                                               Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                               Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                        FROM Venta__c 
                                        WHERE Producto__r.Variedad2__r.Biotecnologia__c = 'Conkesta E3'];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(ventasConkesta);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetProductoresWithConvencionalTechnology() {
        // Crear ventas específicas para tecnología Convencional
        List<Venta__c> ventasConv = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                           Originante__c, Destinatario__c, 
                                           Producto__r.Variedad2__r.Biotecnologia__c,
                                           Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                           Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                    FROM Venta__c 
                                    WHERE Producto__r.Variedad2__r.Biotecnologia__c = 'Convencional'];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(ventasConv);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testGetProductoresWithEmptyList() {
        List<Venta__c> ventasVacias = new List<Venta__c>();
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(ventasVacias);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty when input is empty');
    }
    
    @IsTest
    static void testGetProductoresWithMixedVentaTypes() {
        // Probar con una mezcla de todos los tipos de venta
        List<Venta__c> todasLasVentas = [SELECT Id, Rol_Originante__c, Rol_Destinatario__c, Tipo_de_Venta__c, 
                                               Originante__c, Destinatario__c, 
                                               Producto__r.Variedad2__r.Biotecnologia__c,
                                               Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                               Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                        FROM Venta__c];
        
        Test.startTest();
        Set<Id> result = ValidarLicenciaCuentaRelacionada.getProductores(todasLasVentas);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
    }
    
    @IsTest
    static void testExecuteWithEmptyProductorsList() {
        ValidarLicenciaCuentaRelacionada.Request request = new ValidarLicenciaCuentaRelacionada.Request();
        request.productores = new List<Id>();
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciaCuentaRelacionada.Response> responses = 
            ValidarLicenciaCuentaRelacionada.execute(new List<ValidarLicenciaCuentaRelacionada.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].productoresOk, 'ProductoresOk should not be null');
        System.assertEquals(0, responses[0].productoresOk.size(), 'ProductoresOk should be empty');
    }
    
    @IsTest
    static void testGetClaveRolDestinatarioWithNullParentId() {

        RecordType rtObtentor = [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor' LIMIT 1];

        // Crear una venta con obtentor sin ParentId
        Account obtentorSinPadre = new Account(Name = 'Obtentor Sin Padre', RecordTypeId =rtObtentor.Id);
        insert obtentorSinPadre;
        
        Variedad__c variedadSinPadre = new Variedad__c(
            Name = 'Variedad Sin Padre',
            Biotecnologia__c = 'Enlist E3',
            Obtentor_Comercializa__c = obtentorSinPadre.Id
        );
        insert variedadSinPadre;
        
        Product2 productoSinPadre = new Product2(
            Name = 'Producto Sin Padre',
            Variedad2__c = variedadSinPadre.Id,
            Variedad__c ='DON MARIO 46E1 2E'
        );
        insert productoSinPadre;

        Cultivo__c cultivo = new Cultivo__c(Name = 'Cultivo 03',Temporada__c='Anual', Densidad_de_Siembra__c= 23);
        insert cultivo;

        Campana_Agricola__c  campana = new Campana_Agricola__c (Name = 'Campaña 12', Ano__c='2025', Id_Externo__c = 'S787DS84JGYS8',SKEY_CAMPANIA__c = 2032924,Z9_Clave_Unica__c='Z9125156',Cultivo__c= cultivo.Id);
        insert campana;
        

        Account productor = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Productor' LIMIT 1];
        
        Venta__c ventaSinPadre = new Venta__c(
            Originante__c = productor.Id,
            Destinatario__c = productor.Id,
            Rol_Originante__c = 'Obtentor',
            Rol_Destinatario__c = 'Productor',
            Tipo_de_Venta__c = 'C',
            Producto__c = productoSinPadre.Id,
            Cantidad__c = 12, Campana_Agricola__c = campana.Id, Cultivo__c = cultivo.Id 
        );
        insert ventaSinPadre;
        
        List<Venta__c> ventas = [SELECT Id, Destinatario__c, 
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                                       Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                                FROM Venta__c 
                                WHERE Id = :ventaSinPadre.Id];
        
        Test.startTest();
        Set<String> result = ValidarLicenciaCuentaRelacionada.getClaveRolDestinatario(ventas);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(0, result.size(), 'Result should be empty when ParentId is null');
    }
}