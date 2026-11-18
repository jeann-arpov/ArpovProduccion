@IsTest
private class ContactosCortevaServiceTest {
    @IsTest
    static void exigeNombreApellidoYUnDatoDeContacto() {
        Account cuenta = new Account(Name = 'Cuenta Corteva Test');
        insert cuenta;
        Integer contactosAntes = [SELECT COUNT() FROM Contact];

        UsuariosdeCorteva__c sinContacto = contacto(cuenta.Id, 'Ana', 'Perez', null, null);
        assertFalla(sinContacto, 'Correo');

        UsuariosdeCorteva__c sinNombre = contacto(cuenta.Id, null, 'Perez', 'ana@test.com', null);
        assertFalla(sinNombre, 'Nombre');

        UsuariosdeCorteva__c valido = contacto(cuenta.Id, 'Ana', 'Perez', null, '1112345678');
        insert valido;

        valido = [SELECT Name, Correo__c, Celular__c FROM UsuariosdeCorteva__c WHERE Id = :valido.Id];
        System.assert(valido.Name.startsWith('CC-'), valido.Name);
        System.assertEquals(null, valido.Correo__c);
        System.assertEquals(contactosAntes, [SELECT COUNT() FROM Contact]);
    }

    @IsTest
    static void noRepiteCorreoEnLaMismaCuenta() {
        Account cuenta = new Account(Name = 'Cuenta Corteva A');
        Account otra = new Account(Name = 'Cuenta Corteva B');
        insert new List<Account>{ cuenta, otra };

        insert contacto(cuenta.Id, 'Ana', 'Perez', 'ana@test.com', null);

        UsuariosdeCorteva__c duplicado = contacto(cuenta.Id, 'Ana', 'Gomez', 'ANA@test.com', '111');
        assertFalla(duplicado, 'misma cuenta');

        UsuariosdeCorteva__c enOtraCuenta = contacto(otra.Id, 'Ana', 'Perez', 'ana@test.com', null);
        insert enOtraCuenta;

        UsuariosdeCorteva__c soloCelular = contacto(cuenta.Id, 'Luis', 'Diaz', null, '111');
        insert soloCelular;

        enOtraCuenta.Correo__c = 'ANA@test.com';
        enOtraCuenta.Cuenta__c = cuenta.Id;
        assertFalla(enOtraCuenta, 'misma cuenta');
    }

    private static UsuariosdeCorteva__c contacto(
        Id cuentaId,
        String nombre,
        String apellido,
        String correo,
        String celular
    ) {
        return new UsuariosdeCorteva__c(
            Cuenta__c = cuentaId,
            Nombre__c = nombre,
            Apellido__c = apellido,
            Correo__c = correo,
            Celular__c = celular
        );
    }

    private static void assertFalla(SObject registro, String texto) {
        try {
            upsert registro;
            System.assert(false, 'El guardado debía rechazarse');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains(texto), e.getMessage());
        }
    }
}
