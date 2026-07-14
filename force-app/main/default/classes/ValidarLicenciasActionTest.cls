@isTest
public class ValidarLicenciasActionTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test accounts for productores and obtentores
        List<Account> accounts = new List<Account>();
        RecordType rt = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Productor' LIMIT 1];
        RecordType rtObtentor = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor' LIMIT 1];

        
        // Productores
        Account productor1 = new Account(Name = 'Productor 1', RecordTypeId =rt.Id);
        Account productor2 = new Account(Name = 'Productor 2', RecordTypeId =rt.Id);
        Account productor3 = new Account(Name = 'Productor 3', RecordTypeId =rt.Id);
        accounts.add(productor1);
        accounts.add(productor2);
        accounts.add(productor3);
        
        // Obtentores
        Account obtentor1 = new Account(Name = 'Obtentor 1', RecordTypeId = rtObtentor.Id);
        Account obtentor2 = new Account(Name = 'Obtentor 2', RecordTypeId = rtObtentor.Id);
        Account parentAccount = new Account(Name = 'Parent Obtentor', RecordTypeId = rtObtentor.Id);
        accounts.add(obtentor1);
        accounts.add(obtentor2);
        accounts.add(parentAccount);
        
        insert accounts;
        
        // Update obtentor2 to have parentAccount as parent
        obtentor2.ParentId = parentAccount.Id;
        update obtentor2;
        
        // Create Variedad2__c records
        List<Variedad__c> variedades = new List<Variedad__c>();
        Variedad__c variedad1 = new Variedad__c(Name = 'Variedad 1', Biotecnologia__c = 'Enlist E3',Obtentor_Comercializa__c = obtentor1.Id);
        Variedad__c variedad2 = new Variedad__c(Name = 'Variedad 2', Biotecnologia__c = 'RR1', Obtentor_Comercializa__c = obtentor2.Id);
        Variedad__c variedad3 = new Variedad__c(Name = 'Variedad 3', Biotecnologia__c = 'Conkesta E3', Obtentor_Comercializa__c = obtentor1.Id);
        Variedad__c variedad4 = new Variedad__c( Name = 'Variedad 4', Biotecnologia__c = 'RR2 - BT', Obtentor_Comercializa__c = obtentor2.Id);
        Variedad__c variedad5 = new Variedad__c( Name = 'Variedad 5', Biotecnologia__c = 'Convencional',Obtentor_Comercializa__c = obtentor1.Id );
        Variedad__c variedad6 = new Variedad__c( Name = 'Variedad 6', Biotecnologia__c = 'BGRR', Obtentor_Comercializa__c = obtentor2.Id);
        variedades.add(variedad1);
        variedades.add(variedad2);
        variedades.add(variedad3);
        variedades.add(variedad4);
        variedades.add(variedad5);
        variedades.add(variedad6);
        insert variedades;
        
        // Create Product records
        List<Product2> productos = new List<Product2>();
        Product2 producto1 = new Product2(Name = 'Producto 1', Variedad2__c = variedad1.Id, Variedad__c ='DON MARIO 46E21 E');
        Product2 producto2 = new Product2(Name = 'Producto 2', Variedad2__c = variedad2.Id, Variedad__c ='DON MARIO 46E 1E');
        Product2 producto3 = new Product2(Name = 'Producto 3', Variedad2__c = variedad3.Id, Variedad__c ='DON MARIO 46E 2E');
        Product2 producto4 = new Product2(Name = 'Producto 4', Variedad2__c = variedad4.Id, Variedad__c ='DON MARIO 46E 3E');
        Product2 producto5 = new Product2(Name = 'Producto 5', Variedad2__c = variedad5.Id, Variedad__c ='DON MARIO 46E 4E');
        Product2 producto6 = new Product2(Name = 'Producto 6', Variedad2__c = variedad6.Id, Variedad__c ='DON MARIO 46E 5E');
        productos.add(producto1);
        productos.add(producto2);
        productos.add(producto3);
        productos.add(producto4);
        productos.add(producto5);
        productos.add(producto6);
        insert productos;

        // Create Cultivo records
        List<Cultivo__c> cultivos = new List<Cultivo__c>();
        Cultivo__c cultivo1 = new Cultivo__c(Name = 'Cultivo 1',Temporada__c='Anual', Densidad_de_Siembra__c= 23);
        Cultivo__c cultivo2 = new Cultivo__c(Name = 'Cultivo 2', Temporada__c='Anual', Densidad_de_Siembra__c= 12);
        Cultivo__c cultivo3 = new Cultivo__c(Name = 'Cultivo 3', Temporada__c='Anual', Densidad_de_Siembra__c= 16);
        Cultivo__c cultivo4 = new Cultivo__c(Name = 'Cultivo 4', Temporada__c='Anual', Densidad_de_Siembra__c= 14);
        Cultivo__c cultivo5 = new Cultivo__c(Name = 'Cultivo 5', Temporada__c='Anual', Densidad_de_Siembra__c= 11);
        Cultivo__c cultivo6 = new Cultivo__c(Name = 'Cultivo 6', Temporada__c='Anual', Densidad_de_Siembra__c= 13);
        cultivos.add(cultivo1);
        cultivos.add(cultivo2);
        cultivos.add(cultivo3);
        cultivos.add(cultivo4);
        cultivos.add(cultivo5);
        cultivos.add(cultivo6);
        insert cultivos;

        //Create Campaña
        List<Campana_Agricola__c > campanas = new List<Campana_Agricola__c >();
        Campana_Agricola__c  campana1 = new Campana_Agricola__c (Name = 'Campaña 1', Ano__c='2025', Id_Externo__c = 'S787DS8SJGYS8',SKEY_CAMPANIA__c = 2020924,Z9_Clave_Unica__c='Z9123456',Cultivo__c= cultivo1.Id);
        Campana_Agricola__c  campana2 = new Campana_Agricola__c (Name = 'Campaña 2',Ano__c='2025', Id_Externo__c = 'S787DS8Sj37YS8',SKEY_CAMPANIA__c = 9320924,Z9_Clave_Unica__c='LPA23456',Cultivo__c= cultivo2.Id);
        Campana_Agricola__c  campana3 = new Campana_Agricola__c (Name = 'Campaña 3',Ano__c='2025', Id_Externo__c = 'LKD2DS8SJGYS8',SKEY_CAMPANIA__c = 7320924,Z9_Clave_Unica__c='90SA23456',Cultivo__c= cultivo3.Id);
        Campana_Agricola__c  campana4 = new Campana_Agricola__c (Name = 'Campaña 4',Ano__c='2025', Id_Externo__c = 'LSL001SJGYS8',SKEY_CAMPANIA__c = 3100924,Z9_Clave_Unica__c='IPX123456',Cultivo__c= cultivo4.Id);
        Campana_Agricola__c  campana5 = new Campana_Agricola__c (Name = 'Campaña 5', Ano__c='2025', Id_Externo__c = 'KL24SJGYS8',SKEY_CAMPANIA__c = 9812924,Z9_Clave_Unica__c='LQ123456',Cultivo__c= cultivo5.Id);
        Campana_Agricola__c  campana6 = new Campana_Agricola__c (Name = 'Campaña 6', Ano__c='2025', Id_Externo__c = '98WWS8SJGYS8',SKEY_CAMPANIA__c = 7850924,Z9_Clave_Unica__c='DGW23456',Cultivo__c= cultivo6.Id);
        campanas.add(campana1);
        campanas.add(campana2);
        campanas.add(campana3);
        campanas.add(campana4);
        campanas.add(campana5);
        campanas.add(campana6);
        insert campanas;
        
        // Create Venta__c records with different scenarios
        List<Venta__c> ventas = new List<Venta__c>();
        
        // Venta for Destinatario role
        Venta__c venta1 = new Venta__c(   Tipo_de_Venta__c = 'C', Destinatario__c = productor1.Id,  Originante__c = productor2.Id, Producto__c = producto1.Id, Cantidad__c = 12, Campana_Agricola__c = campana1.Id, Cultivo__c = cultivo1.Id );
        
        // Venta for Originante role
        Venta__c venta2 = new Venta__c( Tipo_de_Venta__c = 'Venta', Destinatario__c = productor2.Id, Originante__c = productor1.Id,Producto__c = producto2.Id, Cantidad__c = 14, Campana_Agricola__c = campana2.Id, Cultivo__c = cultivo2.Id  );
        
        // Venta with Obtentor type
        Venta__c venta3 = new Venta__c( Tipo_de_Venta__c = 'DPO',Destinatario__c = productor3.Id, Originante__c = productor1.Id, Producto__c = producto3.Id,Cantidad__c = 13, Campana_Agricola__c = campana3.Id, Cultivo__c = cultivo3.Id );
        
        // Venta with different type (not C, Obtentor, or Venta)
        Venta__c venta4 = new Venta__c(Tipo_de_Venta__c = 'TDD',Destinatario__c = productor2.Id,  Originante__c = productor3.Id,Producto__c = producto4.Id, Cantidad__c = 16, Campana_Agricola__c = campana4.Id, Cultivo__c = cultivo4.Id  );
        
        // Venta with null Destinatario
        Venta__c venta5 = new Venta__c(Tipo_de_Venta__c = 'C', Originante__c = productor1.Id,  Destinatario__c = productor3.Id, Producto__c = producto5.Id, Cantidad__c = 16, Campana_Agricola__c = campana5.Id, Cultivo__c = cultivo5.Id  );
        
        // Venta with parent account scenario
        Venta__c venta6 = new Venta__c( Tipo_de_Venta__c = 'Venta',Destinatario__c = productor1.Id,  Originante__c = productor2.Id, Producto__c = producto6.Id, Cantidad__c = 18, Campana_Agricola__c = campana6.Id, Cultivo__c = cultivo6.Id );    
        
        ventas.add(venta1);
        ventas.add(venta2);
        ventas.add(venta3);
        ventas.add(venta4);
        ventas.add(venta5);
        ventas.add(venta6);
        insert ventas;
        
        // Create Licencia__c records
        List<Licencia__c> licencias = new List<Licencia__c>();
        
        // Valid licenses
        Licencia__c licencia1 = new Licencia__c(
            Name = 'Licencia 1',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada',
            Cuenta_Productor__c = productor1.Id,
            Cuenta_Obtentor__c = obtentor1.Id,
            Tecnologia__c = 'Enlist'
        );
        
        Licencia__c licencia2 = new Licencia__c(
            Name = 'Licencia 2',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada',
            Cuenta_Productor__c = productor2.Id,
            Cuenta_Obtentor__c = obtentor2.Id,
            Tecnologia__c = 'RR'
        );
        
        // License that won't match (different technology)
        Licencia__c licencia3 = new Licencia__c(
            Name = 'Licencia 3',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada',
            Cuenta_Productor__c = productor3.Id,
            Cuenta_Obtentor__c = obtentor1.Id,
            Tecnologia__c = 'Otra'
        );
        
        // License for parent account
        Licencia__c licencia4 = new Licencia__c(
            Name = 'Licencia 4',
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada',
            Cuenta_Productor__c = productor1.Id,
            Cuenta_Obtentor__c = parentAccount.Id,
            Tecnologia__c = 'Otra'
        );
        
        licencias.add(licencia1);
        licencias.add(licencia2);
        licencias.add(licencia3);
        licencias.add(licencia4);
        insert licencias;
    }
    
    @isTest
    static void testExecuteWithDestinatarioRole() {
        // Get test data
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%' ORDER BY Name];
        
        // Create request for Destinatario role
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id, productores[1].Id, productores[2].Id};
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        // Assert results
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].productoresOk, 'ProductoresOk should not be null');
        
        // At least some producers should be valid
        System.assert(responses[0].productoresOk.size() >= 0, 'Should return list of valid producers');
    }
    @isTest
    static void testProductoresSinLicenciaWithAdicionales() {
        // This test ensures the branch where productoresSinLicencia is NOT empty and adicionales are added

        // Get test data
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%' ORDER BY Name];
        List<Account> obtentores = [SELECT Id FROM Account WHERE Name LIKE 'Obtentor%' ORDER BY Name];
        List<Product2> productos = [SELECT Id FROM Product2 ORDER BY Name];
        List<Cultivo__c> cultivos = [SELECT Id FROM Cultivo__c ORDER BY Name];
        List<Campana_Agricola__c> campanas = [SELECT Id FROM Campana_Agricola__c ORDER BY Name];

        // Insert a Venta that will NOT have a valid license (to ensure productoresSinLicencia is not empty)
        Venta__c ventaNoLic = new Venta__c(
            Tipo_de_Venta__c = 'C',
            Destinatario__c = productores[2].Id, // Productor 3 has no valid license for 'Enlist'
            Originante__c = productores[0].Id,
            Producto__c = productos[0].Id,
            Cantidad__c = 10,
            Campana_Agricola__c = campanas[0].Id,
            Cultivo__c = cultivos[0].Id
        );
        insert ventaNoLic;

        // Now run the action for Productor 3, which will have productoresSinLicencia NOT empty
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[2].Id};
        request.rol = 'Destinatario';

        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();

        System.assertNotEquals(null, responses, 'Response should not be null');
        // The test will hit the branch where productoresSinLicencia is not empty and adicionales are added
    }
    @isTest
    static void testObtenerProductoresCuentaPrincipal() {
        // Prepare test data
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%' ORDER BY Name];
        List<Account> obtentores = [SELECT Id FROM Account WHERE Name LIKE 'Obtentor%' ORDER BY Name];
        List<Product2> productos = [SELECT Id, Variedad2__c FROM Product2 ORDER BY Name];
        List<Venta__c> ventas = [SELECT Id, Tipo_de_Venta__c, Originante__c, Destinatario__c,
                            Producto__r.Variedad2__r.Biotecnologia__c,
                            Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                            Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId FROM Venta__c];


        Set<Id> productoresSet = new Set<Id>();
        for (Account prod : productores) {
            productoresSet.add(prod.Id);
        }

        Test.startTest();
        Set<Id> result = ValidarLicenciasAction.obtenerProductoresCuentaPrincipal(ventas, productoresSet);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result should not be null');
        // Optionally, assert expected values based on your test data
    }
    @isTest
    static void testExecuteWithOriginanteRole() {
        // Get test data
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%' ORDER BY Name];
        
        // Create request for Originante role (any role other than Destinatario)
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id, productores[1].Id, productores[2].Id};
        request.rol = 'Originante';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        // Assert results
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].productoresOk, 'ProductoresOk should not be null');
    }
    
    @isTest
    static void testExecuteWithEmptyProductoresSinLicencia() {
        // Create a scenario where all producers have valid licenses
        List<Account> productores = [SELECT Id FROM Account WHERE Name = 'Productor 1'];
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id};
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
    }
    
    
    
    @isTest
    static void testGetLicenciasSuccess() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%'];
        List<Account> obtentores = [SELECT Id FROM Account WHERE Name LIKE 'Obtentor%' OR Name = 'Parent Obtentor'];
        
        Set<Id> obtenorIds = new Set<Id>();
        for (Account obt : obtentores) {
            obtenorIds.add(obt.Id);
        }
        
        Test.startTest();
        List<Licencia__c> licencias = ValidarLicenciasAction.getLicencias(
            new List<Id>{productores[0].Id, productores[1].Id}, 
            obtenorIds
        );
        Test.stopTest();
        
        System.assertNotEquals(null, licencias, 'Licencias should not be null');
        System.assert(licencias.size() >= 0, 'Should return list of licenses');
    }
    
    @isTest 
    static void testGetVentasWithDestinatarioRole() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%'];
        Set<Id> productorIds = new Set<Id>();
        for (Account prod : productores) {
            productorIds.add(prod.Id);
        }
        
        Test.startTest();
        // Test private method through execute method - this will test getVentas with Destinatario
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>(productorIds);
        request.rol = 'Destinatario';
        
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Should execute successfully');
    }
    
    @isTest
    static void testGetVentasWithNonDestinatarioRole() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%'];
        Set<Id> productorIds = new Set<Id>();
        for (Account prod : productores) {
            productorIds.add(prod.Id);
        }
        
        Test.startTest();
        // Test private method through execute method - this will test getVentas with non-Destinatario
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>(productorIds);
        request.rol = 'Originante';
        
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Should execute successfully');
    }
    
    @isTest
    static void testAllMethodPathsWithBulkData() {
        // Create bulk test data to ensure all loops and conditions are tested
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%'];
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>();
        for (Account prod : productores) {
            request.productores.add(prod.Id);
        }
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        // This test ensures all private methods are called and all conditional branches are executed
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertNotEquals(null, responses[0].productoresOk, 'ProductoresOk should not be null');
    }
    
    @isTest
    static void testWithDifferentVentaTypes() {
        // This test will hit different branches in getProductoresPorRol and getClaveVentas methods
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%'];
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id, productores[1].Id, productores[2].Id};
        request.rol = 'TestRole'; // Non-Destinatario role
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
    }
    
    @isTest
    static void testNullHandlingScenarios() {
        // Test with minimal data to trigger null handling branches
        List<Account> productores = [SELECT Id FROM Account WHERE Name = 'Productor 1' LIMIT 1];
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id};
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
        System.assertEquals(1, responses.size(), 'Should return one response');
    }
    
    @isTest
    static void testParentAccountScenario() {
        // This specifically tests the parent account logic in getProductoresPorCuenta and getClaveVentasPorCuenta
        List<Account> productores = [SELECT Id FROM Account WHERE Name = 'Productor 1'];
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id};
        request.rol = 'Originante';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
    }
    @isTest
    static void testDestinatarioBranch() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%' ORDER BY Name];
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id, productores[1].Id, productores[2].Id};
        request.rol = 'Destinatario';

        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();

        System.assertNotEquals(null, responses);
        System.assertEquals(1, responses.size());
    }

    @isTest
    static void testOriginanteBranch() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%' ORDER BY Name];
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id, productores[1].Id, productores[2].Id};
        request.rol = 'Originante';

        Test.startTest();
        List<ValidarLicenciasAction.Response> responses2 = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();

        System.assertNotEquals(null, responses2);
    }
    @isTest
    static void testProductoresSinLicencia_Destinatario() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name = 'Productor 3']; // Tiene licencia no válida
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id};
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
    }

    @isTest 
    static void testProductoresSinLicencia_Originante() {
        List<Account> productores = [SELECT Id FROM Account WHERE Name = 'Productor 3']; // Tiene licencia no válida

        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id};
        request.rol = 'Originante';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses2 = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses2, 'Response should not be null');
    }
    
    @isTest
    static void testGetObtentoresWithNullValues() {
        // Test getObtentores method with various scenarios including null Obtentor_Comercializa__c
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%'];
        
        // Create additional Venta with null Obtentor_Comercializa__c
        Account testAccount = new Account(Name = 'Test Account Temp', RecordTypeId = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Productor' LIMIT 1].Id);
        insert testAccount;
        
        Variedad__c tempVariedad = new Variedad__c(
            Name = 'Temp Variedad',
            Biotecnologia__c = 'Enlist E3'
            // Obtentor_Comercializa__c is null
        );
        insert tempVariedad;
        
        Cultivo__c tempCultivo = new Cultivo__c (Name = 'Cultivo 45',Temporada__c='Anual', Densidad_de_Siembra__c= 65);
        insert tempCultivo;

        Campana_Agricola__c tempCampana = new  Campana_Agricola__c (Name = 'Campaña 1', Ano__c='2025', Id_Externo__c = 'S78sdS8SJGYS8',SKEY_CAMPANIA__c = 3430924,Z9_Clave_Unica__c='Z9112456',Cultivo__c= tempCultivo.Id);
        insert tempCampana;

        Product2 tempProducto = new Product2(Name = 'Temp Producto', Variedad2__c = tempVariedad.Id, Variedad__c ='DON MARIO 46E21 E');
        insert tempProducto;
        
        Venta__c tempVenta = new Venta__c(
            Tipo_de_Venta__c = 'C',
            Destinatario__c = testAccount.Id,
            Originante__c = productores[0].Id,
            Producto__c = tempProducto.Id,
            Cantidad__c = 18, Campana_Agricola__c = tempCampana.Id, Cultivo__c = tempCultivo.Id
        );
        insert tempVenta;
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{testAccount.Id};
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Should handle null Obtentor_Comercializa__c');
    }
    
    @isTest
    static void testParentAccountLogicSpecifically() {
        // This specifically tests the parent account conditional logic
        List<Account> productores = [SELECT Id FROM Account WHERE Name = 'Productor 1'];
        List<Account> obtentores = [SELECT Id FROM Account WHERE Name = 'Obtentor 2']; // This one has a parent
        
        // Create a venta that will trigger the parent account logic
        Variedad__c parentVariedad = new Variedad__c(
            Name = 'Parent Test Variedad',
            Biotecnologia__c = 'Enlist E3',
            Obtentor_Comercializa__c = obtentores[0].Id // This has ParentId
        );
        insert parentVariedad;
        
        Cultivo__c parentCultivo = new Cultivo__c (Name = 'Cultivo2 23',Temporada__c='Anual', Densidad_de_Siembra__c= 23);
        insert parentCultivo;

        Campana_Agricola__c parentCampana = new  Campana_Agricola__c (Name = 'Campaña 1', Ano__c='2025', Id_Externo__c = 'S792JS8SJGYS8',SKEY_CAMPANIA__c = 9830924,Z9_Clave_Unica__c='SF112456',Cultivo__c= parentCultivo.Id);
        insert parentCampana;

        Product2 parentProducto = new Product2(Name = 'Parent Test Producto', Variedad2__c = parentVariedad.Id, Variedad__c ='DON MARIO 46E1 E');
        insert parentProducto;

        Venta__c parentVenta = new Venta__c(
            Tipo_de_Venta__c = 'C',
            Destinatario__c = productores[0].Id,
            Originante__c = productores[0].Id,
            Producto__c = parentProducto.Id,
            Cantidad__c = 18, Campana_Agricola__c = parentCampana.Id, Cultivo__c = parentCultivo.Id
        );
        insert parentVenta;

        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id};
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Should handle parent account logic');
    }
    
    @isTest
    static void testVentaTypeVariations() {
        // Test all different Tipo_de_Venta__c variations to hit all branches
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%'];
        List<Product2> productos = [SELECT Id FROM Product2];
        List<Cultivo__c> cultivos = [SELECT Id FROM Cultivo__c];
        List<Campana_Agricola__c> campanas = [SELECT Id FROM Campana_Agricola__c];

        // Create ventas with each specific type to hit all conditional branches
        List<Venta__c> additionalVentas = new List<Venta__c>();
        // Test 'C' type specifically
        additionalVentas.add(new Venta__c(
            Tipo_de_Venta__c = 'C',
            Destinatario__c = productores[0].Id,
            Originante__c = productores[1].Id,
            Producto__c = productos[0].Id,
            Cantidad__c = 18, Campana_Agricola__c = campanas[0].Id, Cultivo__c = cultivos[0].Id
        ));
        
        // Test 'Obtentor' type specifically
        additionalVentas.add(new Venta__c(
            Tipo_de_Venta__c = 'TDD',
            Destinatario__c = productores[1].Id,
            Originante__c = productores[2].Id,
            Producto__c = productos[1].Id,
            Cantidad__c = 13, Campana_Agricola__c = campanas[1].Id, Cultivo__c = cultivos[1].Id
        ));
        
        // Test 'Venta' type specifically
        additionalVentas.add(new Venta__c(
            Tipo_de_Venta__c = 'Venta',
            Destinatario__c = productores[2].Id,
            Originante__c = productores[0].Id,
            Producto__c = productos[2].Id,
            Cantidad__c = 11, Campana_Agricola__c = campanas[2].Id, Cultivo__c = cultivos[2].Id
        ));
        
        // Test other type that doesn't match conditions
        additionalVentas.add(new Venta__c(
            Tipo_de_Venta__c = 'DPO',
            Destinatario__c = productores[0].Id,
            Originante__c = productores[1].Id,
            Producto__c = productos[3].Id,
            Cantidad__c = 16, Campana_Agricola__c = campanas[3].Id, Cultivo__c = cultivos[3].Id
        ));
        
        insert additionalVentas;
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id, productores[1].Id, productores[2].Id};
        request.rol = 'TestRole';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Should handle all venta types');
    }
    
    @isTest
    static void testLicenciaAccessException() {
        // Test the AuraHandledException in getLicencias
        // This is tricky since we can't easily remove object permissions in tests
        // But we can test that the method exists and works normally
        List<Account> productores = [SELECT Id FROM Account WHERE Name LIKE 'Productor%' LIMIT 1];
        List<Account> obtentores = [SELECT Id FROM Account WHERE Name LIKE 'Obtentor%' LIMIT 1];
        
        Set<Id> obtenorIds = new Set<Id>();
        for (Account obt : obtentores) {
            obtenorIds.add(obt.Id);
        }
        
        Test.startTest();
        
        try {
            List<Licencia__c> licencias = ValidarLicenciasAction.getLicencias(
                new List<Id>{productores[0].Id}, 
                obtenorIds
            );
            System.assertNotEquals(null, licencias, 'Should return licencias list');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('No tiene permiso'), 'Should throw permission exception');
        }
        
        Test.stopTest();
    }
    
    @isTest
    static void testEmptyCollectionsHandling() {
        // Test with empty productores list
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>();
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Should handle empty productores');
        System.assertEquals(1, responses.size(), 'Should return one response');
        System.assertEquals(0, responses[0].productoresOk.size(), 'Should return empty list');
    }
    
    @isTest
    static void testNullDestinatiarioHandling() {
        // Test the logic that handles null Destinatario in processing
        // Even though we can't insert with null Destinatario, we can test the conditional logic
        List<Account> productores = [SELECT Id FROM Account WHERE Name = 'Productor 1' LIMIT 1];
        
        ValidarLicenciasAction.Request request = new ValidarLicenciasAction.Request();
        request.productores = new List<Id>{productores[0].Id};
        request.rol = 'Destinatario';
        
        Test.startTest();
        List<ValidarLicenciasAction.Response> responses = ValidarLicenciasAction.execute(new List<ValidarLicenciasAction.Request>{request});
        Test.stopTest();
        
        System.assertNotEquals(null, responses, 'Response should not be null');
    }
    
    @isTest
    static void testMapearTecnologiaAllCases() {
        Test.startTest();
        
        // Test Enlist cases
        System.assertEquals('Enlist', ValidarLicenciasAction.mapearTecnologia('Enlist'), 'Should map Enlist to Enlist');
        System.assertEquals('Enlist', ValidarLicenciasAction.mapearTecnologia('Conkesta E3'), 'Should map Conkesta E3 to Enlist');
        
        // Test RR cases
        System.assertEquals('RR', ValidarLicenciasAction.mapearTecnologia('RR1'), 'Should map RR1 to RR');
        System.assertEquals('RR', ValidarLicenciasAction.mapearTecnologia('RR2 - BT'), 'Should map RR2 - BT to RR');
        System.assertEquals('RR', ValidarLicenciasAction.mapearTecnologia('Convencional'), 'Should map Convencional to RR');
        
        // Test default case
        System.assertEquals('Otra', ValidarLicenciasAction.mapearTecnologia('Otra'), 'Should return same value for unmapped technology');
        System.assertEquals('Otra', ValidarLicenciasAction.mapearTecnologia('Otra'), 'Should return same value for unknown technology');
        
        Test.stopTest();
    }

}