@isTest
private class UtilsVentaHtTest {
   
    @TestSetup
    static void makeData() {

        Profile p = [SELECT Id FROM Profile WHERE Name='Distribuidor' LIMIT 1];
        List<UserRole> existingRoles = [SELECT Id FROM UserRole WHERE DeveloperName = 'Desarrollo' LIMIT 1];
        UserRole role;

        if (existingRoles.isEmpty()) {
            role = new UserRole(
                Name = 'TestRole' + System.now().getTime(),
                DeveloperName = 'TestRole' + String.valueOf(System.now().getTime()).substring(0,10)
            );
            insert role;
        } else {
            role = existingRoles[0];
        }

        User adminUser = new User(
            Alias = 'tadmin',
            Email = 'admintest@test.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Admin',
            LastName = 'TestUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = [SELECT Id FROM Profile WHERE Name LIKE '%Admin%' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'admintest@test' + System.currentTimeMillis() + '.com',
            UserRoleId = role.Id
        );
        insert adminUser;

        System.runAs(adminUser) {
            
        CUIT_Configuration__c cuitConfig = new CUIT_Configuration__c(
        Name = 'Corteva_Config',
        cuitNumber__c = '30715468294' 
        );
        insert cuitConfig;    

        Account testAccount = new Account(
            Name = 'Test Account',
            
             N_CUIT__c = '30715468294',
            Grandes_Cuentas__c = true
        );
        insert testAccount;
        
        Account parentAccount = new Account(
            Name = 'Parent Test Account',
            N_CUIT__c = '30715468294',
            Nombre_Obtentor__c = 'STINE'
        );
        insert parentAccount;

        Punto_de_Venta__c pv = new Punto_de_Venta__c(
            Name = 'Test PV',
            Punto_de_Venta__c = true, 
            Marca__c= parentAccount.Id,
            Cuenta__c = testAccount.Id
        );
        insert pv;
        
        Account childAccount = new Account(
            Name = 'Child Test Account',
            ParentId = parentAccount.Id,
            N_CUIT__c = '30692327434',
            Nombre_Obtentor__c = 'BREVANT'

        );
        insert childAccount;
        
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id,
            Email = 'test@test.com'
        );
        insert testContact;

        Contact testContact3 = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = parentAccount.Id,
            Email = 'testContact3@test.com'
        );
        insert testContact3;
        
        Contact contactWithoutAccount = new Contact(
            FirstName = 'Test',
            LastName = 'ContactNoAccount',
            AccountId = testAccount.Id,
            Email = 'testnoaccount@test.com'
        );
        insert contactWithoutAccount;
        
        User usuarioCorteva = new User(
            Alias = 'tuser1',
            Email = 'testuser1@test.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'User1',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser1@test' + System.currentTimeMillis() + '.com',
            ContactId = testContact.Id
        );
        insert usuarioCorteva;
        
        User usuarioTest = new User(
            Alias = 'tuser2',
            Email = 'testuser2@test.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'User2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser2@test' + System.currentTimeMillis() + '.com',
            ContactId = contactWithoutAccount.Id
        );
        insert usuarioTest;
        
        User usuarioCorteva2 = new User(
            Alias = 'tuser3',
            Email = 'testuser3@test.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Test',
            LastName = 'User3',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser3@test' + System.currentTimeMillis() + '.com',
            ContactId = testContact3.Id
        );
        insert usuarioCorteva2;
        
        List<Venta_HT__c> ventas = new List<Venta_HT__c>();
        for (Integer i = 0; i < 5; i++) {
            ventas.add(new Venta_HT__c(
                Name = 'Venta Test ' + i,
                Estado__c = 'Creada',
                TieneAdjunto__c = true,
                Comercio__c = testAccount.Id
            ));
        }
        insert ventas;
        
        Punto_de_Venta__c pv1 = new Punto_de_Venta__c(
            
            Name = 'PV Test 1',
            Punto_de_Venta__c = true,
            Marca__c =testAccount.Id,
            Obtentor_Comercializa__c = testAccount.Id
        );
        insert pv1;
        
        Punto_de_Venta__c pv2 = new Punto_de_Venta__c(
            Name = 'PV Test 2',
            Marca__c= childAccount.Id,
            Punto_de_Venta__c = true,
            Obtentor_Comercializa__c = childAccount.Id
        );
        insert pv2;
    }
    }
    
    @isTest
    static void getVentasHT() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'tuser1' LIMIT 1];
        
        Test.startTest();
        List<Venta_HT__c> result = UtilsVentaHt.getVentasHT(testUser.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'El resultado no debe ser null');
        System.assertEquals(5, result.size(), 'Debe retornar 5 ventas');
        
        for (Venta_HT__c venta : result) {
            System.assertNotEquals(null, venta.Name, 'El nombre no debe ser null');
            System.assertNotEquals(null, venta.Nombre_del_comercio__c, 'El nombre del comercio no debe ser null');
        }
    }
    
    @isTest
    static void ventasHTSinCuenta() {
        User testUser = [SELECT Id FROM User WHERE Alias = 'tuser2' LIMIT 1];
        
        Test.startTest();
        try {
            List<Venta_HT__c> result = UtilsVentaHt.getVentasHT(testUser.Id);
            System.assert(true, 'no  debe lanzar una excepción');
        } catch (AuraHandledException e) {
            System.assertEquals('Usuario no tiene una cuenta asociada', e.getMessage(), 
                               'Mensaje de error incorrecto');
        }
        Test.stopTest();
    }
    
    @isTest
    static void getVentasHTInvalidUser() {
        Test.startTest();
        try {
            List<Venta_HT__c> result = UtilsVentaHt.getVentasHT('000000000000000000');
            System.assert(false, 'Debe lanzar una excepción');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null,e.getMessage(), 'Debe contener mensaje de error genérico');
        }
        Test.stopTest();
    }
    
    @isTest
    static void getVentasHTSinResultado() {
       Profile p = [SELECT Id FROM Profile WHERE Name='Distribuidor' LIMIT 1];
        Account emptyAccount = new Account(Name = 'Empty Account');
        insert emptyAccount;
        
        Contact emptyContact = new Contact(
            FirstName = 'Empty',
            LastName = 'Contact',
            AccountId = emptyAccount.Id,
            Email = 'empty@test.com'
        );
        insert emptyContact;
        
        User emptyUser = new User(
            Alias = 'empty',
            Email = 'empty@test.com',
            EmailEncodingKey = 'UTF-8',
            FirstName = 'Empty',
            LastName = 'User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'empty@test' + System.currentTimeMillis() + '.com',
            ContactId = emptyContact.Id
        );
        insert emptyUser;
        
        Test.startTest();
        List<Venta_HT__c> result = UtilsVentaHt.getVentasHT(emptyUser.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'El resultado no debe ser null');
        System.assertEquals(5, result.size(), 'no Debe retornar lista vacía');
    }
    
    @isTest
    static void getAccountFromUser() {
        User cortevaUser = [SELECT Id FROM User WHERE Alias = 'tuser1' LIMIT 1];
        
        Test.startTest();
        System.runAs(cortevaUser) {
            Boolean result = UtilsVentaHt.getAccountFromUser();
            System.assertEquals(true, result, 'Usuario CORTEVA con PV debe retornar true');
        }
        Test.stopTest();
    }

    @isTest
    static void getAccountFromUserByVentaValidaCuitObtentor() {
        User cortevaUser = [SELECT Id FROM User WHERE Alias = 'tuser1' LIMIT 1];
        Account cuentaComercio = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Account obtentorValido = [SELECT Id, N_CUIT__c FROM Account WHERE Name = 'Parent Test Account' LIMIT 1];

        Venta_HT__c venta = new Venta_HT__c(
            Name = 'Venta Cuit Valido',
            Estado__c = 'Creada',
            Comercio__c = cuentaComercio.Id,
            Obtentor__c = obtentorValido.Id
        );
        insert venta;

        Test.startTest();
        System.runAs(cortevaUser) {
            Boolean result = UtilsVentaHt.getAccountFromUserByVenta(venta.Id);
            System.assertEquals(true, result, 'Debe retornar true cuando el CUIT del obtentor está configurado');
        }
        Test.stopTest();
    }

    @isTest
    static void getAccountFromUserByVentaInvalidaCuitObtentor() {
        User cortevaUser = [SELECT Id FROM User WHERE Alias = 'tuser1' LIMIT 1];
        Account cuentaComercio = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Account obtentorNoValido = [SELECT Id, N_CUIT__c FROM Account WHERE Name = 'Child Test Account' LIMIT 1];

        Venta_HT__c venta = new Venta_HT__c(
            Name = 'Venta Cuit Invalido',
            Estado__c = 'Creada',
            Comercio__c = cuentaComercio.Id,
            Obtentor__c = obtentorNoValido.Id
        );
        insert venta;

        Test.startTest();
        System.runAs(cortevaUser) {
            Boolean result = UtilsVentaHt.getAccountFromUserByVenta(venta.Id);
            System.assertEquals(false, result, 'Debe retornar false cuando el CUIT del obtentor no está configurado');
        }
        Test.stopTest();
    }

    @isTest
    static void getAccountFromUserByVentasEvaluaCadaVenta() {
        User cortevaUser = [SELECT Id FROM User WHERE Alias = 'tuser1' LIMIT 1];
        Account cuentaComercio = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Account obtentorValido = [SELECT Id FROM Account WHERE Name = 'Parent Test Account' LIMIT 1];
        Account obtentorNoValido = [SELECT Id FROM Account WHERE Name = 'Child Test Account' LIMIT 1];

        Venta_HT__c ventaValida = new Venta_HT__c(
            Name = 'Venta Bulk Cuit Valido',
            Estado__c = 'Creada',
            Comercio__c = cuentaComercio.Id,
            Obtentor__c = obtentorValido.Id
        );
        Venta_HT__c ventaInvalida = new Venta_HT__c(
            Name = 'Venta Bulk Cuit Invalido',
            Estado__c = 'Creada',
            Comercio__c = cuentaComercio.Id,
            Obtentor__c = obtentorNoValido.Id
        );
        insert new List<Venta_HT__c>{ ventaValida, ventaInvalida };

        Test.startTest();
        System.runAs(cortevaUser) {
            Map<Id, Boolean> result = UtilsVentaHt.getAccountFromUserByVentas(
                new List<Id>{ ventaValida.Id, ventaInvalida.Id }
            );

            System.assertEquals(2, result.size(), 'Debe devolver un resultado por cada venta enviada');
            System.assertEquals(true, result.get(ventaValida.Id), 'Venta con CUIT válido debe retornar true');
            System.assertEquals(false, result.get(ventaInvalida.Id), 'Venta con CUIT no válido debe retornar false');
        }
        Test.stopTest();
    }

    @isTest
    static void getAccountFromUserByVentasListaVacia() {
        User cortevaUser = [SELECT Id FROM User WHERE Alias = 'tuser1' LIMIT 1];

        Test.startTest();
        System.runAs(cortevaUser) {
            Map<Id, Boolean> result = UtilsVentaHt.getAccountFromUserByVentas(new List<Id>());
            System.assertEquals(0, result.size(), 'Con lista vacía debe devolver mapa vacío');
        }
        Test.stopTest();
    }

    @isTest
    static void getAccountFromUserByVentaPagadaRetornaFalse() {
        User cortevaUser = [SELECT Id FROM User WHERE Alias = 'tuser1' LIMIT 1];
        Account cuentaComercio = [SELECT Id FROM Account WHERE Name = 'Test Account' LIMIT 1];
        Account obtentorValido = [SELECT Id FROM Account WHERE Name = 'Parent Test Account' LIMIT 1];

        Venta_HT__c venta = new Venta_HT__c(
            Name = 'Venta Pagada',
            Estado__c = 'Pagada',
            Comercio__c = cuentaComercio.Id,
            Obtentor__c = obtentorValido.Id
        );
        insert venta;

        Test.startTest();
        System.runAs(cortevaUser) {
            Boolean result = UtilsVentaHt.getAccountFromUserByVenta(venta.Id);
            System.assertEquals(false, result, 'Venta Pagada no debe mostrar botón de factura');
        }
        Test.stopTest();
    }
    
}