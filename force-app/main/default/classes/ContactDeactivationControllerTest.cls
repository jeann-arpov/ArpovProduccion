@isTest
private class ContactDeactivationControllerTest {

    @isTest
    static void testDeactivateAndReactivateContact() {
        Account acc = new Account(Name = 'Test Baja Contacto');
        insert acc;

        Contact c = new Contact(
            LastName = 'Test Baja',
            AccountId = acc.Id,
            Activo__c = true
        );
        insert c;

        Test.startTest();
        ContactDeactivationController.ResultadoOperacion rBaja =
            ContactDeactivationController.deactivateContact(c.Id);
        Test.stopTest();

        System.assert(rBaja.success, 'La baja debería tener éxito: ' + rBaja.message);
        Contact contactoInactivo = [SELECT Activo__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals(false, contactoInactivo.Activo__c, 'El contacto debería quedar inactivo');

        ContactDeactivationController.ResultadoOperacion rAlta =
            ContactDeactivationController.reactivateContact(c.Id);
        System.assert(rAlta.success, 'La reactivación debería tener éxito: ' + rAlta.message);
        Contact contactoActivo = [SELECT Activo__c FROM Contact WHERE Id = :c.Id];
        System.assertEquals(true, contactoActivo.Activo__c, 'El contacto debería quedar activo');
    }

    @isTest
    static void testPortalUsersSinUsuarios() {
        Account acc = new Account(Name = 'Test Baja Contacto Portal');
        insert acc;

        Contact c = new Contact(
            LastName = 'Test Portal',
            AccountId = acc.Id,
            Activo__c = true
        );
        insert c;

        ContactDeactivationController.ResultadoOperacion rBajaUsers =
            ContactDeactivationController.deactivatePortalUsers(c.Id);
        System.assert(rBajaUsers.success, 'No debería fallar sin usuarios: ' + rBajaUsers.message);

        ContactDeactivationController.ResultadoOperacion rAltaUsers =
            ContactDeactivationController.reactivatePortalUsers(c.Id);
        System.assert(rAltaUsers.success, 'No debería fallar sin usuarios: ' + rAltaUsers.message);
    }

    @isTest
    static void testGetContactInfo() {
        Account acc = new Account(Name = 'Test Baja Contacto Info');
        insert acc;

        Contact c = new Contact(
            LastName = 'Test Info',
            AccountId = acc.Id,
            Activo__c = true
        );
        insert c;

        ContactDeactivationController.InfoContacto info =
            ContactDeactivationController.getContactInfo(c.Id);

        System.assertEquals(c.Id, info.contactId, 'Debe devolver el id del contacto');
        System.assertEquals(true, info.activo, 'El contacto debería estar activo');
        System.assertEquals(0, info.usuariosPortalActivos, 'No debería haber usuarios de portal activos');
    }
}
