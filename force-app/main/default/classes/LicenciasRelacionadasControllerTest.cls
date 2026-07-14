@IsTest
private class LicenciasRelacionadasControllerTest {
    

    @IsTest
    static void testGetLicenciasByProductor_conDatosValidos() {
        
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
            N_CUIT__c = '30710432089',
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
        
       Account acc = new Account(Name = 'Cuenta Portal');
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
            Estado__c = 'Aprobada',
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

       
        Test.startTest();
        List<LicenciasRelacionadasController.LicenciaDTO> result =
            LicenciasRelacionadasController.getLicenciasByProductor(productor.N_CUIT__c);
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Debe devolver solo la licencia válida');

        LicenciasRelacionadasController.LicenciaDTO dto = result[0];

        System.assertEquals('LIC-002', dto.codigoLicencia);
        System.assertEquals('Productor', dto.tipoLicencia);
        System.assertEquals('Aprobada', dto.estado);
        System.assertEquals('test2@test.com', dto.mail);
        System.assertEquals('0987654321', dto.firmanteCelular);
    }


    @IsTest
    static void testGetLicenciasByProductor_cuitVacio() {

        Test.startTest();
        List<LicenciasRelacionadasController.LicenciaDTO> result =
            LicenciasRelacionadasController.getLicenciasByProductor('');
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Debe devolver lista vacía si el CUIT está vacío');
    }
}