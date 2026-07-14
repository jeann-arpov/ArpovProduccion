@IsTest
private class UserControllerComunidadTest {

    private static Integer fakeIdCounter = 1;

    // Genera un Id falso con el prefijo correcto del objeto referenciado por el campo lookup.
    private static Id fakeId(Schema.SObjectField field) {
        String prefix = field.getDescribe().getReferenceTo()[0].getDescribe().getKeyPrefix();
        String suffix = String.valueOf(fakeIdCounter++);
        suffix = '000000000000'.substring(suffix.length()) + suffix;
        return Id.valueOf(prefix + suffix);
    }

    @IsTest
    static void testHTMetricasComercioConstructors() {
        UserControllerComunidad.HTMetricasComercio empty = new UserControllerComunidad.HTMetricasComercio();
        System.assertEquals(0, empty.htVendidas);
        System.assertEquals(0, empty.htPendientesDePago);

        UserControllerComunidad.HTMetricasComercio withNulls =
            new UserControllerComunidad.HTMetricasComercio(null, null);
        System.assertEquals(0, withNulls.htVendidas);
        System.assertEquals(0, withNulls.htPendientesDePago);
    }

    @IsTest(SeeAllData=true)
    static void testGetHTMetricasComercioConUsuarioPortal() {
        List<User> portalUsers = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND ContactId != NULL
              AND Contact.AccountId != NULL
            LIMIT 1
        ];
        if (portalUsers.isEmpty()) {
            return;
        }

        Test.startTest();
        System.runAs(portalUsers[0]) {
            UserControllerComunidad.HTMetricasComercio metrics =
                UserControllerComunidad.getHTMetricasComercio();
            System.assertNotEquals(null, metrics);
            System.assert(metrics.htVendidas >= 0);
            System.assert(metrics.htPendientesDePago >= 0);
        }
        Test.stopTest();
    }

    @IsTest
    static void testGetHTMetricasComercioSinComercio() {
        List<User> usersSinContacto = [
            SELECT Id
            FROM User
            WHERE IsActive = TRUE
              AND ContactId = NULL
            LIMIT 1
        ];
        if (usersSinContacto.isEmpty()) {
            return;
        }

        Boolean lanzoError = false;
        Test.startTest();
        try {
            System.runAs(usersSinContacto[0]) {
                UserControllerComunidad.getHTMetricasComercio();
            }
        } catch (AuraHandledException e) {
            lanzoError = true;
        }
        Test.stopTest();
        System.assert(lanzoError, 'Debía lanzar error si el usuario no tiene comercio');
    }

    @IsTest
    static void testControllers() {
        UserControllerComunidad.getCultivos();
        UserControllerComunidad.getCurrentUserData();
        UserControllerComunidad.getLicenciasContadas();
        UserControllerComunidad.getCalendarioUrl();
        UserControllerComunidad.getBolsasObtentorCampaniaActiva();
        UserControllerComunidad.getBolsasObtentorCampaniaActivaList();
        UserControllerComunidad.getBolsasPrimeraMultiplicacionActual();
        UserControllerComunidad.getBolsasPrimeraMultiplicacionActualList();
    }

    @IsTest
    static void testRepeleFC() {
        // getNcKeyMap ejecuta la SOQL (vacía en test) y devuelve un mapa vacío.
        Map<String, Date> vacio = UserControllerComunidad.getNcKeyMap(null, new Set<Id>());
        System.assertEquals(0, vacio.size(), 'Sin NC el mapa debe estar vacío');

        Id productor = fakeId(Venta__c.Destinatario__c);
        Id producto  = fakeId(Venta__c.Producto__c);
        Id campana   = fakeId(Venta__c.Campana_Agricola__c);

        String key = VentaListController.buildReversoKey(productor, producto, 40, campana);
        Map<String, Date> ncKeyToFecha = new Map<String, Date>{
            key => Date.newInstance(2026, 1, 24)
        };

        // FC revertida por la NC -> debe repelerse.
        Venta__c fc = new Venta__c(
            Tipo_de_Comprobante__c = 'FC',
            Destinatario__c = productor,
            Producto__c = producto,
            Cantidad__c = 40,
            Campana_Agricola__c = campana,
            Fecha__c = Date.newInstance(2026, 1, 15)
        );
        System.assertEquals(true, UserControllerComunidad.repeleFC(fc, ncKeyToFecha),
            'Una FC con NC coincidente debe repelerse');

        // Un registro que no es FC (ej. DPD) no se repele aunque coincida la clave.
        Venta__c dpd = fc.clone(false, true);
        dpd.Tipo_de_Comprobante__c = 'NC';
        System.assertEquals(false, UserControllerComunidad.repeleFC(dpd, ncKeyToFecha),
            'Solo se repelen registros FC');

        // FC sin NC coincidente se mantiene.
        System.assertEquals(false, UserControllerComunidad.repeleFC(fc, new Map<String, Date>()),
            'Una FC sin NC no se repele');
    }
}