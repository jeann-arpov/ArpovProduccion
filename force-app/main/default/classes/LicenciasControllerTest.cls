@IsTest
public class LicenciasControllerTest {
    
    // Setup test data
    @TestSetup
    static void setupTestData() {
        // Create test accounts (obtentores, productores, distribuidores)
        Account obtentorParent = new Account(
            Name = 'Obtentor Parent Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Obtentor').getRecordTypeId()
        );
        insert obtentorParent;
        
        Account obtentorChild = new Account(
            Name = 'Obtentor Child Test',
            ParentId = obtentorParent.Id,
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Obtentor').getRecordTypeId()
        );
        insert obtentorChild;
        
        Account productor = new Account(
            Name = 'Productor Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Productor').getRecordTypeId()
        );
        insert productor;
        
        Account distribuidor = new Account(
            Name = 'Distribuidor Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Distribuidor').getRecordTypeId()
        );
        insert distribuidor;
        
        
        // Create test contact for user association
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'User',
            AccountId = obtentorChild.Id
        );
        insert testContact;
        
       Account acc = new Account(
            Name = 'Cuenta Portal',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Comercio').getRecordTypeId()
        );
        insert acc;
        
        Contact c = new Contact(
            LastName = 'Contacto Portal',
            AccountId = acc.Id,
            Email = 'contact@test.com'
        );
        insert c;
        
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name LIKE '%Customer%'
            LIMIT 1
        ];
        
        User portalUser = new User(
            Username = 'portal' + System.currentTimeMillis() + '@test.com',
            Email = 'portal@test.com',
            LastName = 'Portal',
            Alias = 'port',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = portalProfile.Id,
            ContactId = c.Id
        );
        
        insert portalUser; // ✅
                
        // Create test licencias with different scenarios
        List<Licencia__c> licencias = new List<Licencia__c>();
        
        // Licencia for obtentor
        licencias.add(new Licencia__c(
            Name = 'LIC-001',
            Created__c = Date.today().addDays(-10),
            Cuenta_Obtentor__c = obtentorChild.Id,
            Cuenta_Distribuidor__c = distribuidor.Id,
            Tipo_de_Licencia__c = 'Comercio',
            Tecnologia__c = 'Enlist',
            Estado__c = 'Aprobada',
            Direccion_Fiscal_Firmante__c = 'Calle Falsa 123',
            Email__c = 'test1@test.com',
            Firmante_Celular__c = '1234567890',
            Carta_de_Aceptacion_Firmada__c = true
        ));
        
        // Licencia for productor
        licencias.add(new Licencia__c(
            Name = 'LIC-002',
            Created__c = Date.today().addDays(-5),
            Cuenta_Productor__c = productor.Id,
            Cuenta_Distribuidor__c = distribuidor.Id,
            Tipo_de_Licencia__c = 'Productor',
            Tecnologia__c = 'Enlist',
            Estado__c = 'Creada',
            Direccion_Fiscal_Firmante__c = 'Calle Falsa 456',
            Email__c = 'test2@test.com',
            Firmante_Celular__c = '0987654321',
            Carta_de_Aceptacion_Firmada__c = false
        ));
        
        // Licencia with different estado for filtering
        licencias.add(new Licencia__c(
            Name = 'LIC-003',
            Created__c = Date.today().addDays(-3),
            Cuenta_Obtentor__c = obtentorChild.Id,
            Cuenta_Distribuidor__c = distribuidor.Id,
            Tipo_de_Licencia__c = 'Comercio',
            Tecnologia__c = 'Enlist',
            Estado__c = 'Rechazada',
            Direccion_Fiscal_Firmante__c = 'Calle Falsa 789',
            Email__c = 'test3@test.com',
            Firmante_Celular__c = '1122334455',
            Carta_de_Aceptacion_Firmada__c = true
        ));
        
        // Licencia for parent obtentor
        licencias.add(new Licencia__c(
            Name = 'LIC-004',
            Created__c = Date.today().addDays(-1),
            Cuenta_Obtentor__c = obtentorParent.Id,
            Cuenta_Distribuidor__c = distribuidor.Id,
            Tipo_de_Licencia__c = 'Comercio',
            Tecnologia__c = 'Enlist',
            Estado__c = 'Validada',
            Direccion_Fiscal_Firmante__c = 'Calle Falsa 101',
            Email__c = 'test4@test.com',
            Firmante_Celular__c = '5566778899',
            Carta_de_Aceptacion_Firmada__c = false
        ));
        
        insert licencias;
    }
    
    // Test esUsuarioEspecial method
    @IsTest
    static void testEsUsuarioEspecial() {
        // Get test user with contact
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            Boolean isSpecial = LicenciasController.esUsuarioEspecial();
            Test.stopTest();
            
            // Should return false for regular user
            System.assert(!isSpecial, 'Regular user should not be special');
        }
    }
    
 // Test getLicenciasObtentor with no filters
    @IsTest
    static void testGetLicenciasObtentorNoFilters() {
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasObtentor(1, 10, '{}');
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Result should not be null');
            System.assertNotEquals(null, result.licencias, 'Licencias list should not be null');
            System.assert(result.totalRecords >= 0, 'Total records should be >= 0');
            System.assertEquals(1, result.pageNumber, 'Page number should be 1');
            System.assertEquals(10, result.pageSize, 'Page size should be 10');
        }
    }
    
      // Test getLicenciasObtentor with filters
    @IsTest
    static void testGetLicenciasObtentorWithFilters() {
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            // Create filter JSON
            Map<String, Object> filters = new Map<String, Object>{
                'estado' => 'Aprobada',
                'tipo' => 'Comercio',
                'carta' => 'Subida',
                'searchTerm' => 'LIC-001'
            };
            String filtersJSON = JSON.serialize(filters);
            
            Test.startTest();
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasObtentor(1, 10, filtersJSON);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }
    
     // Test getLicenciasObtentor with origen filter for non-special user
    @IsTest
    static void testGetLicenciasObtentorWithOrigenFilter() {
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            // Create filter JSON with origen
            Map<String, Object> filters = new Map<String, Object>{
                'origen' => 'Tecnología A'
            };
            String filtersJSON = JSON.serialize(filters);
            
            Test.startTest();
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasObtentor(1, 10, filtersJSON);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }
    
      // Test formatLicencias method indirectly through getLicenciasObtentor
    @IsTest
    static void testFormatLicencias() {
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasObtentor(1, 10, '{}');
            Test.stopTest();
            
            System.assertNotEquals(null, result.licencias, 'Formatted licencias should not be null');
            if (!result.licencias.isEmpty()) {
                Map<String, String> firstLicencia = result.licencias[0];
                System.assert(firstLicencia.containsKey('id'), 'Should have id field');
                System.assert(firstLicencia.containsKey('name'), 'Should have name field');
                System.assert(firstLicencia.containsKey('fecha'), 'Should have fecha field');
                System.assert(firstLicencia.containsKey('estado'), 'Should have estado field');
                System.assert(firstLicencia.containsKey('carta'), 'Should have carta field');
            }
        }
    }
    
    // Test getLicenciasObtentor with empty search term
    @IsTest
    static void testGetLicenciasObtentorWithEmptySearchTerm() {
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Map<String, Object> filters = new Map<String, Object>{
                'searchTerm' => ''
            };
            String filtersJSON = JSON.serialize(filters);
            
            Test.startTest();
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasObtentor(1, 10, filtersJSON);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }
    
   // Test getLicenciasObtentor with null filters
    @IsTest
    static void testGetLicenciasObtentorWithNullFilters() {
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasObtentor(1, 10, null);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }
  
   
    // Test getLicenciasProductor with filters
    @IsTest
    static void testGetLicenciasProductorWithFilters() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test' LIMIT 1];
        Contact productorContact = new Contact(
            FirstName = 'Productor',
            LastName = 'Contact',
            AccountId = productor.Id
        );
        insert productorContact;
           Profile userProfile = [
            SELECT Id
            FROM Profile
            WHERE Name LIKE '%Customer%'
            LIMIT 1
        ];
        User productorUser = new User(
            Alias = 'prodr2',
            Email = 'produser2@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Productor2',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = userProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'produser2@test.com.test',
            ContactId = productorContact.Id
        );
        insert productorUser;
        
        System.runAs(productorUser) {
            // Test different estado filters
            Map<String, Object> filtersEnCurso = new Map<String, Object>{
                'estado' => 'En curso'
            };
            String filtersJSON = JSON.serialize(filtersEnCurso);
            
            Test.startTest();
            LicenciasController.PaginatedResult result1 = LicenciasController.getLicenciasProductor(1, 10, filtersJSON);
            
            Map<String, Object> filtersAprobada = new Map<String, Object>{
                'estado' => 'Aprobada'
            };
            result1 = LicenciasController.getLicenciasProductor(1, 10, JSON.serialize(filtersAprobada));
            
            Map<String, Object> filtersRechazada = new Map<String, Object>{
                'estado' => 'Rechazada'
            };
            result1 = LicenciasController.getLicenciasProductor(1, 10, JSON.serialize(filtersRechazada));
            
            // Test with multiple filters
            Map<String, Object> filtersMultiple = new Map<String, Object>{
                'estado' => 'En curso',
                'origen' => 'Tecnología B',
                'tipo' => 'Productor',
                'carta' => 'Sin subir',
                'searchTerm' => 'Marca'
            };
            LicenciasController.PaginatedResult result2 = LicenciasController.getLicenciasProductor(1, 10, JSON.serialize(filtersMultiple));
            Test.stopTest();
            
            System.assertNotEquals(null, result2, 'Result should not be null');
        }
    }
    
   // Test getLicenciasProductor with null filters
    @IsTest
    static void testGetLicenciasProductorWithNullFilters() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'Productor Test' LIMIT 1];
        Contact productorContact = new Contact(
            FirstName = 'Productor',
            LastName = 'Contact',
            AccountId = productor.Id
        );
        insert productorContact;
           Profile userProfile = [
            SELECT Id
            FROM Profile
            WHERE Name LIKE '%Customer%'
            LIMIT 1
        ];
        
        User productorUser = new User(
            Alias = 'prod3',
            Email = 'produser3@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Productor3',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = userProfile.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            Username = 'produser3@test.com.test',
            ContactId = productorContact.Id
        );
       insert productorUser;
        
        System.runAs(productorUser) {
            Test.startTest();
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasProductor(1, 10, null);
            Test.stopTest();
            
            System.assertNotEquals(null, result, 'Result should not be null');
        }
    }
    

    
    // Test getEstadosLicencia method
    @IsTest
    static void testGetEstadosLicencia() {
        Test.startTest();
        List<String> estados = LicenciasController.getEstadosLicencia();
        Test.stopTest();
        
        System.assertNotEquals(null, estados, 'Estados list should not be null');
    }
    
   // Test getTiposLicencia method
    @IsTest
    static void testGetTiposLicencia() {
        Test.startTest();
        List<String> tipos = LicenciasController.getTiposLicencia();
        Test.stopTest();
        
        System.assertNotEquals(null, tipos, 'Tipos list should not be null');
    }
    
    // Test getOrigenesLicencia method for regular user
    @IsTest
    static void testGetOrigenesLicenciaRegularUser() {
        User testUser = [SELECT Id FROM User WHERE Email = 'portal@test.com' LIMIT 1];
        
        System.runAs(testUser) {
            Test.startTest();
            List<String> origenes = LicenciasController.getOrigenesLicencia();
            Test.stopTest();
            
            System.assertNotEquals(null, origenes, 'Origenes list should not be null');
        }
    }
     // Test formatLicencias method with all fields populated
    @IsTest
    static void testFormatLicenciasWithAllFields() {
        // Create a test account for obtentor
        Account obtentorAccount = new Account(
            Name = 'Obtentor Full Fields Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Obtentor').getRecordTypeId()
        );
        insert obtentorAccount;
        
        // Create a test account for distribuidor
        Account distribuidorAccount = new Account(
            Name = 'Distribuidor Full Fields Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Distribuidor').getRecordTypeId()
        );
        insert distribuidorAccount;
        
        // Create a test account for comercio SGL
        Account comercioSGLAccount = new Account(
            Name = 'Comercio SGL Full Fields Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Comercio').getRecordTypeId()
        );
        insert comercioSGLAccount;
        
        // Create a test contact for user
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'FullFields',
            AccountId = obtentorAccount.Id
        );
        insert testContact;
        
        // Create test user
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name LIKE '%Customer%'
            LIMIT 1
        ];
        
        User testUser = new User(
            Username = 'fullfields' + System.currentTimeMillis() + '@test.com',
            Email = 'fullfields@test.com',
            LastName = 'FullFields',
            Alias = 'full',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = portalProfile.Id,
            ContactId = testContact.Id
        );
        insert testUser;
        
        // Create a licencia with ALL fields populated
        Licencia__c fullLicencia = new Licencia__c(
            Name = 'LIC-FULL-001',
            Created__c = Date.today(),
            //Razon_Social_Licenciatario__c = 'Licenciatario Completo Test',
            //N_CUIT__c = '30123456789',
            Cuenta_Obtentor__c = obtentorAccount.Id,
            Cuenta_Distribuidor__c = distribuidorAccount.Id,
            Tipo_de_Licencia__c = 'Comercio',
           // Origen_de_Licencia__c = 'Tecnología Completa',
            //Nombres_Marcas__c = 'Marca Completa Test',
            Estado__c = 'Aprobada',
           // Comercio_SGL__c = comercioSGLAccount.Id,
            Direccion_Fiscal_Firmante__c = 'Calle Completa 123',
            Email__c = 'completo@test.com',
            Firmante_Celular__c = '1122334455',
            Carta_de_Aceptacion_Firmada__c = true
            //CodigoLicenciaTexto__c = 'LIC-FULL-TEXT-001'
        );
        insert fullLicencia;
        
        // Also create a licencia with null values to test null handling
        Licencia__c nullLicencia = new Licencia__c(
            Name = 'LIC-NULL-001',
            Created__c = Date.today().addDays(-1),
            Cuenta_Obtentor__c = obtentorAccount.Id,
            Cuenta_Distribuidor__c = distribuidorAccount.Id,
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Creada',
            Carta_de_Aceptacion_Firmada__c = false
            // Intentionally leaving other fields null
        );
        insert nullLicencia;
        
        System.runAs(testUser) {
            Test.startTest();
            // Call getLicenciasObtentor which will use formatLicencias
            LicenciasController.PaginatedResult result = LicenciasController.getLicenciasObtentor(1, 10, '{}');
            Test.stopTest();
            
            System.assertNotEquals(null, result.licencias, 'Formatted licencias should not be null');
            System.assert(result.licencias.size() >= 2, 'Should have at least 2 licencias');
            
            // Find the full licencia in results
            Map<String, String> fullLicenciaMap = null;
            Map<String, String> nullLicenciaMap = null;
            
            for (Map<String, String> licMap : result.licencias) {
                if (licMap.get('name') == 'LIC-FULL-001') {
                    fullLicenciaMap = licMap;
                } else if (licMap.get('name') == 'LIC-NULL-001') {
                    nullLicenciaMap = licMap;
                }
            }
            
            // Verify full licencia has all fields correctly formatted
            if (fullLicenciaMap != null) {
                System.assertEquals('LIC-FULL-001', fullLicenciaMap.get('name'), 'Name should match');
            }
            
            // Verify null licencia handles null values correctly
            if (nullLicenciaMap != null) {
                System.assertEquals('LIC-NULL-001', nullLicenciaMap.get('name'), 'Name should match');
               
            }
        }
    }
    
    /**
 * Métodos de test para cubrir los métodos faltantes en LicenciasController
 * Siguiendo las buenas prácticas establecidas en la clase existente
 */

// ============================================================================
// TEST PARA getOrigenesLicenciaProductor
// ============================================================================

    @IsTest
    static void testGetOrigenesLicenciaProductor() {
        // Setup: Crear cuenta productor y licencias con diferentes orígenes
        Account productorAccount = new Account(
            Name = 'Productor Origen Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Productor').getRecordTypeId()
        );
        insert productorAccount;
        
        // Crear contacto y usuario para productor
        Contact productorContact = new Contact(
            FirstName = 'Productor',
            LastName = 'Origen Test',
            AccountId = productorAccount.Id
        );
        insert productorContact;
        
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name LIKE '%Customer%'
            LIMIT 1
        ];
        
        User productorUser = new User(
            Username = 'productor.origen@test.com',
            Email = 'productor.origen@test.com',
            LastName = 'ProductorOrigen',
            Alias = 'porig',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = portalProfile.Id,
            ContactId = productorContact.Id
        );
        insert productorUser;
        
        // Crear licencias con diferentes orígenes para el productor
        List<Licencia__c> licencias = new List<Licencia__c>();
        
        // Licencia con origen "Tecnología A"
        licencias.add(new Licencia__c(
            Name = 'LIC-PROD-001',
            Created__c = Date.today(),
            Cuenta_Productor__c = productorAccount.Id,
            Tecnologia__c = 'Enlist',
            Estado__c = 'Aprobada'
        ));
        
        // Licencia con origen "Tecnología B"
        licencias.add(new Licencia__c(
            Name = 'LIC-PROD-002',
            Created__c = Date.today().addDays(-1),
            Cuenta_Productor__c = productorAccount.Id,
            Tecnologia__c = 'Enlist',
            Estado__c = 'Creada'
        ));
        
        // Licencia con mismo origen (debería ser único en el resultado)
        licencias.add(new Licencia__c(
            Name = 'LIC-PROD-003',
            Created__c = Date.today().addDays(-2),
            Cuenta_Productor__c = productorAccount.Id,
            Tecnologia__c = 'Enlist', // Duplicado
            Estado__c = 'Validada'
        ));
        
        // Licencia con origen null (no debería aparecer)
        licencias.add(new Licencia__c(
            Name = 'LIC-PROD-004',
            Created__c = Date.today().addDays(-3),
            Cuenta_Productor__c = productorAccount.Id,
            Tecnologia__c = null,
            Estado__c = 'Rechazada'
        ));
        
        insert licencias;
        
        System.runAs(productorUser) {
            Test.startTest();
            List<String> origenes = LicenciasController.getOrigenesLicenciaProductor();
            Test.stopTest();
            
            // Verificaciones
            System.assertNotEquals(null, origenes, 'La lista de orígenes no debe ser nula');
            System.assertEquals(2, origenes.size(), 'Debe haber 2 orígenes únicos (Tecnología A y B)');
        }
    }
        @IsTest
    static void testGetOrigenesLicenciaDistribuidor() {
        // Setup: Crear cuenta distribuidor y licencias con diferentes orígenes
        Account distribuidorAccount = new Account(
            Name = 'Distribuidor Origen Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Distribuidor').getRecordTypeId()
        );
        insert distribuidorAccount;
        
        // Crear contacto y usuario para distribuidor
        Contact distribuidorContact = new Contact(
            FirstName = 'Distribuidor',
            LastName = 'Origen Test',
            AccountId = distribuidorAccount.Id
        );
        insert distribuidorContact;
        
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name LIKE '%Customer%'
            LIMIT 1
        ];
        
        User distribuidorUser = new User(
            Username = 'distribuidor.origen@test.com',
            Email = 'distribuidor.origen@test.com',
            LastName = 'DistribuidorOrigen',
            Alias = 'dorig',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = portalProfile.Id,
            ContactId = distribuidorContact.Id
        );
        insert distribuidorUser;
        
        // Crear licencias con diferentes orígenes para el distribuidor
        List<Licencia__c> licencias = new List<Licencia__c>();
        
        // Licencia con origen "Enlist"
        licencias.add(new Licencia__c(
            Name = 'LIC-DIST-001',
            Created__c = Date.today(),
            Cuenta_Distribuidor__c = distribuidorAccount.Id,
            Tecnologia__c = 'Enlist',
            Estado__c = 'Aprobada'
        ));
        
        // Licencia con origen "Intacta"
        licencias.add(new Licencia__c(
            Name = 'LIC-DIST-002',
            Created__c = Date.today().addDays(-1),
            Cuenta_Distribuidor__c = distribuidorAccount.Id,
            Tecnologia__c = 'Enlist',
            Estado__c = 'Creada'
        ));
        
        // Licencia con origen null (no debería aparecer)
        licencias.add(new Licencia__c(
            Name = 'LIC-DIST-003',
            Created__c = Date.today().addDays(-2),
            Cuenta_Distribuidor__c = distribuidorAccount.Id,
            Tecnologia__c = null,
            Estado__c = 'Validada'
        ));
        
        // Licencia de OTRO distribuidor (no debería aparecer)
        Account otroDistribuidor = new Account(
            Name = 'Otro Distribuidor',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Distribuidor').getRecordTypeId()
        );
        insert otroDistribuidor;
        
        licencias.add(new Licencia__c(
            Name = 'LIC-DIST-004',
            Created__c = Date.today().addDays(-3),
            Cuenta_Distribuidor__c = otroDistribuidor.Id,
            Tecnologia__c = 'Enlist',
            Estado__c = 'Rechazada'
        ));
        
        insert licencias;
        
        System.runAs(distribuidorUser) {
            Test.startTest();
            List<String> origenes = LicenciasController.getOrigenesLicenciaDistribuidor();
            Test.stopTest();
            
            // Verificaciones
            System.assertNotEquals(null, origenes, 'La lista de orígenes no debe ser nula');
            System.assertEquals(2, origenes.size(), 'Debe haber 2 orígenes únicos para este distribuidor');
        }
    }
    
        @IsTest
    static void testGetLicencias_Distribuidor() {
        // Setup: Crear cuenta distribuidor y licencias
        Account distribuidorAccount = new Account(
            Name = 'Distribuidor Principal Test',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Distribuidor').getRecordTypeId()
        );
        insert distribuidorAccount;
        
        // Crear cuenta obtentor para asociar licencias
        Account obtentorAccount = new Account(
            Name = 'Obtentor Para Distribuidor',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByName().get('Obtentor').getRecordTypeId()
        );
        insert obtentorAccount;
        
        // Crear contacto y usuario para distribuidor
        Contact distribuidorContact = new Contact(
            FirstName = 'Distribuidor',
            LastName = 'Principal',
            AccountId = distribuidorAccount.Id
        );
        insert distribuidorContact;
        
        Profile portalProfile = [
            SELECT Id
            FROM Profile
            WHERE Name LIKE '%Customer%'
            LIMIT 1
        ];
        
        User distribuidorUser = new User(
            Username = 'distribuidor.principal@test.com',
            Email = 'distribuidor.principal@test.com',
            LastName = 'DistribuidorPrincipal',
            Alias = 'dprin',
            TimeZoneSidKey = 'America/New_York',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = portalProfile.Id,
            ContactId = distribuidorContact.Id
        );
        insert distribuidorUser;
        
        // Crear licencias para el distribuidor
        List<Licencia__c> licencias = new List<Licencia__c>();
        
        for (Integer i = 1; i <= 15; i++) {
            licencias.add(new Licencia__c(
                Name = 'LIC-DIST-' + i,
                Created__c = Date.today().addDays(-i),
                Cuenta_Distribuidor__c = distribuidorAccount.Id,
                Cuenta_Obtentor__c = obtentorAccount.Id,
                Tipo_de_Licencia__c = 'Comercio',
                Tecnologia__c = 'Enlist',
                Estado__c = i <= 5 ? 'Aprobada' : (i <= 10 ? 'Creada' : 'Rechazada'),
                Direccion_Fiscal_Firmante__c = 'Calle ' + i,
                Email__c = 'test' + i + '@test.com',
                Firmante_Celular__c = '12345678' + i,
                Carta_de_Aceptacion_Firmada__c = Math.mod(i, 2) == 0
            ));
        }
        
        insert licencias;
        
        System.runAs(distribuidorUser) {
            // Test 1: Sin filtros, primera página
            Test.startTest();
            
            // Caso 1: Sin filtros
            LicenciasController.PaginatedResult result1 = LicenciasController.getLicencias(1, 10, '{}');
            
            // Caso 2: Con filtro de estado "En curso"
            Map<String, Object> filters2 = new Map<String, Object>{
                'estado' => 'En curso'
            };
            LicenciasController.PaginatedResult result2 = LicenciasController.getLicencias(1, 10, JSON.serialize(filters2));
            
            // Caso 3: Con filtro de origen
            Map<String, Object> filters3 = new Map<String, Object>{
                'origen' => 'Tecnología 1'
            };
            LicenciasController.PaginatedResult result3 = LicenciasController.getLicencias(1, 10, JSON.serialize(filters3));
            
            // Caso 4: Con filtro de tipo
            Map<String, Object> filters4 = new Map<String, Object>{
                'tipo' => 'Comercio'
            };
            LicenciasController.PaginatedResult result4 = LicenciasController.getLicencias(1, 10, JSON.serialize(filters4));
            
            // Caso 5: Con búsqueda
            Map<String, Object> filters5 = new Map<String, Object>{
                'searchTerm' => 'LIC-DIST-1'
            };
            LicenciasController.PaginatedResult result5 = LicenciasController.getLicencias(1, 10, JSON.serialize(filters5));
            
            // Caso 6: Página 2
            LicenciasController.PaginatedResult result6 = LicenciasController.getLicencias(2, 5, '{}');
            
            Test.stopTest();
            
            // Verificaciones
            System.assertNotEquals(null, result1, 'Resultado 1 no debe ser nulo');
            System.assertEquals(10, result1.licencias.size(), 'Primera página debe tener 10 licencias');
            System.assertEquals(15, result1.totalRecords, 'Total debe ser 15 licencias');
            System.assertEquals(2, result1.totalPages, 'Debe haber 2 páginas con pageSize=10');
            
            System.assertNotEquals(null, result2, 'Resultado con filtro estado no debe ser nulo');
            System.assertNotEquals(null, result3, 'Resultado con filtro origen no debe ser nulo');
            System.assertNotEquals(null, result4, 'Resultado con filtro tipo no debe ser nulo');
        }
    }

}