@isTest
private class EnvioCorreoMbtInicialServiceTest {
    @isTest
    static void enviaUnaVezAlPrimerMovimientoYNoRepite() {
        Account productor = Test_TestUtils.crearProductor();
        Cultivo__c cultivo = cultivoSoja();
        Test_TestUtils.crearCampanaAgricola(
            '2025',
            cultivo,
            Date.newInstance(2025, 1, 1),
            Date.newInstance(2025, 12, 31),
            '2025 - SOJA'
        );
        insert new List<Licencia__c>{
            licencia(productor.Id, 'LIC-ENLIST-1', 'uno@productor.test'),
            licencia(productor.Id, 'LIC-ENLIST-2', 'dos@productor.test'),
            licencia(productor.Id, 'LIC-ENLIST-3', 'uno@productor.test')
        };

        Movimiento_BolsaTech__c primero = movimiento(productor, '2526');
        insert primero;
        Movimiento_BolsaTech__c siguiente = movimiento(productor, '2526');
        insert siguiente;

        Test.startTest();
        EnvioCorreoMbtInicialService.procesar(new Set<Id>{ primero.Id, siguiente.Id });
        Integer enviosDeCorreo = Limits.getEmailInvocations();
        EnvioCorreoMbtInicialService.procesar(new Set<Id>{ primero.Id, siguiente.Id });
        System.assertEquals(enviosDeCorreo, Limits.getEmailInvocations());
        Test.stopTest();

        List<Envio_Correo__c> envios = [
            SELECT Estado__c, Para__c, Asunto__c, Cuerpo_HTML__c, Productor__c, Campania__c,
                Cultivo__c, Nombre_Registro__c, Id_Correo__c, Proceso__c
            FROM Envio_Correo__c
            WHERE Productor__c = :productor.Id
        ];
        System.assertEquals(1, envios.size());
        System.assertEquals('Enviado', envios[0].Estado__c);
        System.assertEquals(EnvioCorreoMbtInicialService.PROCESO, envios[0].Proceso__c);
        System.assert(envios[0].Para__c.contains('uno@productor.test'));
        System.assert(envios[0].Para__c.contains('dos@productor.test'));
        System.assertEquals(1, envios[0].Para__c.countMatches('uno@productor.test'));
        System.assert(envios[0].Cuerpo_HTML__c.contains(productor.Name));
        System.assert(!envios[0].Cuerpo_HTML__c.contains('mailchi.mp'));
        System.assert(!envios[0].Cuerpo_HTML__c.contains('list-manage.com'));
        primero = [SELECT Name FROM Movimiento_BolsaTech__c WHERE Id = :primero.Id];
        System.assertEquals(primero.Name, envios[0].Nombre_Registro__c);
        System.assertNotEquals(null, envios[0].Campania__c);
        System.assertNotEquals(null, envios[0].Cultivo__c);
        System.assertNotEquals(null, envios[0].Id_Correo__c);
        System.assert(envios[0].Asunto__c.contains('2025 - SOJA'));
    }

    @isTest
    static void unaCampaniaAgrupaCosechasDelMismoAnio() {
        Account productor = Test_TestUtils.crearProductor();
        Cultivo__c cultivo = cultivoSoja();
        Test_TestUtils.crearCampanaAgricola(
            '2025',
            cultivo,
            Date.newInstance(2025, 1, 1),
            Date.newInstance(2025, 12, 31),
            '2025 - SOJA'
        );
        insert licencia(productor.Id, 'LIC-ENLIST-7', 'campania@productor.test');
        Movimiento_BolsaTech__c primero = movimiento(productor, '2526');
        insert primero;
        Movimiento_BolsaTech__c mismaCampania = movimiento(productor, '2530');
        insert mismaCampania;

        Test.startTest();
        EnvioCorreoMbtInicialService.procesar(new Set<Id>{ primero.Id, mismaCampania.Id });
        Test.stopTest();

        List<Envio_Correo__c> envios = [
            SELECT Id_Registro__c, Campania__r.Name
            FROM Envio_Correo__c
            WHERE Productor__c = :productor.Id
        ];
        System.assertEquals(1, envios.size());
        System.assertEquals(String.valueOf(primero.Id), envios[0].Id_Registro__c);
        System.assertEquals('2025 - SOJA', envios[0].Campania__r.Name);
    }

    @isTest
    static void cultivosDistintosDeLaMismaCosechaSonCampaniasDistintas() {
        Account productor = Test_TestUtils.crearProductor();
        Cultivo__c soja = cultivoSoja();
        Cultivo__c maiz = new Cultivo__c(Name = 'MAIZ', Temporada__c = 'Anual', Densidad_de_Siembra__c = 23);
        insert maiz;
        Test_TestUtils.crearCampanaAgricola(
            '2025',
            soja,
            Date.newInstance(2025, 1, 1),
            Date.newInstance(2025, 12, 31),
            '2025 - SOJA'
        );
        Test_TestUtils.crearCampanaAgricola(
            '2025',
            maiz,
            Date.newInstance(2025, 1, 1),
            Date.newInstance(2025, 12, 31),
            '2025 - MAIZ'
        );
        insert licencia(productor.Id, 'LIC-ENLIST-8', 'cultivo@productor.test');
        Movimiento_BolsaTech__c sojaMbt = movimiento(productor, '2526');
        Movimiento_BolsaTech__c maizMbt = movimiento(productor, '2526');
        maizMbt.Cultivo__c = 'MAIZ';
        insert new List<Movimiento_BolsaTech__c>{ sojaMbt, maizMbt };

        Test.startTest();
        EnvioCorreoMbtInicialService.procesar(new Set<Id>{ sojaMbt.Id, maizMbt.Id });
        Test.stopTest();

        System.assertEquals(
            2,
            [SELECT COUNT() FROM Envio_Correo__c WHERE Productor__c = :productor.Id AND Estado__c = 'Enviado']
        );
    }

    @isTest
    static void registraErrorSiNoHayFirmante() {
        Account productor = Test_TestUtils.crearProductor();
        cultivoSoja();
        Movimiento_BolsaTech__c primero = movimiento(productor, '2526');
        insert primero;

        Test.startTest();
        EnvioCorreoMbtInicialService.procesar(new Set<Id>{ primero.Id });
        Test.stopTest();

        Envio_Correo__c envio = [
            SELECT Estado__c, Mensaje_Error__c, Id_Correo__c
            FROM Envio_Correo__c
            WHERE Productor__c = :productor.Id
        ];
        System.assertEquals('Error', envio.Estado__c);
        System.assert(envio.Mensaje_Error__c.contains('firmante'));
        System.assertEquals(null, envio.Id_Correo__c);
    }

    @isTest
    static void ignoraMovimientoQueNoEsEnlist() {
        Account productor = Test_TestUtils.crearProductor();
        cultivoSoja();

        Test.startTest();
        insert new Movimiento_BolsaTech__c(
            Titular__c = productor.Id,
            Estado__c = 'Creado',
            Fecha_de_Analisis__c = '15/10/2025',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'RR',
            CTG__c = '123',
            Codigo_de_Muestra__c = '123',
            Peso_Neto__c = 100,
            CUIT_Titular__c = productor.N_CUIT__c,
            Cuit_Destinatario__c = productor.N_CUIT__c,
            Cosecha__c = '2526'
        );
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM Envio_Correo__c WHERE Productor__c = :productor.Id]);
    }

    @isTest
    static void alCrearElMovimientoValidaMbtYCorreoPrevio() {
        Account productor = Test_TestUtils.crearProductor();
        cultivoSoja();
        insert licencia(productor.Id, 'LIC-ENLIST-6', 'trigger@productor.test');

        Test.startTest();
        insert movimiento(productor, '2526');
        insert movimiento(productor, '2526');
        Test.stopTest();

        List<Envio_Correo__c> envios = [
            SELECT Estado__c, Para__c
            FROM Envio_Correo__c
            WHERE Productor__c = :productor.Id
        ];
        System.assertEquals(1, envios.size());
        System.assertEquals('Enviado', envios[0].Estado__c);
        System.assert(envios[0].Para__c.contains('trigger@productor.test'));
    }

    @isTest
    static void elBatchTomaLaCosechaIndicada() {
        Account productor = Test_TestUtils.crearProductor();
        cultivoSoja();
        insert licencia(productor.Id, 'LIC-ENLIST-5', 'batch@productor.test');
        insert movimiento(productor, '2526');
        insert movimiento(productor, '2425');

        Test.startTest();
        Database.executeBatch(new EnvioCorreoMbtInicialBatch('2526'), 20);
        Test.stopTest();

        List<Envio_Correo__c> envios = [
            SELECT Asunto__c
            FROM Envio_Correo__c
            WHERE Productor__c = :productor.Id
            AND Asunto__c LIKE '%2025%'
        ];
        System.assertEquals(1, envios.size());
    }

    @isTest
    static void ignoraUnMovimientoQueNoEsElPrimero() {
        Account productor = Test_TestUtils.crearProductor();
        cultivoSoja();
        insert licencia(productor.Id, 'LIC-ENLIST-4', 'uno@productor.test');
        Movimiento_BolsaTech__c primero = movimiento(productor, '2526');
        insert primero;
        Movimiento_BolsaTech__c siguiente = movimiento(productor, '2526');
        insert siguiente;

        Test.startTest();
        EnvioCorreoMbtInicialService.procesar(new Set<Id>{ siguiente.Id });
        Test.stopTest();

        List<Envio_Correo__c> envios = [
            SELECT Id_Registro__c
            FROM Envio_Correo__c
            WHERE Productor__c = :productor.Id
        ];
        System.assertEquals(1, envios.size());
        System.assertEquals(String.valueOf(primero.Id), envios[0].Id_Registro__c);
    }

    private static Cultivo__c cultivoSoja() {
        Cultivo__c cultivo = new Cultivo__c(
            Name = 'SOJA',
            Temporada__c = 'Anual',
            Densidad_de_Siembra__c = 23
        );
        insert cultivo;
        return cultivo;
    }

    private static Licencia__c licencia(Id productorId, String codigo, String firmante) {
        return new Licencia__c(
            Name = codigo,
            Tipo_de_Licencia__c = 'Productor',
            Estado__c = 'Aprobada',
            Tecnologia__c = 'Enlist',
            Cuenta_Productor__c = productorId,
            Firmante_Carta_de_Aceptacion__c = firmante
        );
    }

    private static Movimiento_BolsaTech__c movimiento(Account productor, String cosecha) {
        return new Movimiento_BolsaTech__c(
            Titular__c = productor.Id,
            Estado__c = 'Creado',
            Fecha_de_Analisis__c = '15/10/2025',
            Cultivo__c = 'SOJA',
            Tecnologia__c = 'ENLIST',
            CTG__c = '123',
            Codigo_de_Muestra__c = '123',
            Peso_Neto__c = 100,
            CUIT_Titular__c = productor.N_CUIT__c,
            Cuit_Destinatario__c = productor.N_CUIT__c,
            Cosecha__c = cosecha
        );
    }
}
