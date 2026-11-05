@isTest
private class EnvioCorreoAperturaServiceTest {
    @isTest
    static void registraLaPrimeraAperturaYConservaEsaFecha() {
        String token = EnvioCorreoAperturaService.nuevoToken();
        Destinatario_Envio_Correo__c fila = destinatario(token);

        Test.startTest();
        EnvioCorreoAperturaService.registrar(token);
        Datetime primera = [
            SELECT Fecha_Primera_Apertura__c
            FROM Destinatario_Envio_Correo__c
            WHERE Id = :fila.Id
        ].Fecha_Primera_Apertura__c;
        fila.Fecha_Primera_Apertura__c = Datetime.newInstance(2026, 1, 1, 8, 0, 0);
        fila.Fecha_Ultima_Apertura__c = fila.Fecha_Primera_Apertura__c;
        update fila;
        EnvioCorreoAperturaService.registrar(token);
        Test.stopTest();

        fila = [
            SELECT Abierto__c, Fecha_Primera_Apertura__c, Fecha_Ultima_Apertura__c
            FROM Destinatario_Envio_Correo__c
            WHERE Id = :fila.Id
        ];
        System.assertEquals(true, fila.Abierto__c);
        System.assertEquals(Datetime.newInstance(2026, 1, 1, 8, 0, 0), fila.Fecha_Primera_Apertura__c);
        System.assert(fila.Fecha_Ultima_Apertura__c > fila.Fecha_Primera_Apertura__c);
        System.assertNotEquals(null, primera);
    }

    @isTest
    static void ignoraUnTokenInvalidoODesconocido() {
        String token = EnvioCorreoAperturaService.nuevoToken();
        Destinatario_Envio_Correo__c fila = destinatario(token);

        Test.startTest();
        EnvioCorreoAperturaService.registrar((String) null);
        EnvioCorreoAperturaService.registrar('no-es-un-token');
        EnvioCorreoAperturaService.registrar('a'.repeat(EnvioCorreoAperturaService.LARGO_TOKEN));
        Test.stopTest();

        fila = [
            SELECT Abierto__c
            FROM Destinatario_Envio_Correo__c
            WHERE Id = :fila.Id
        ];
        System.assertEquals(false, fila.Abierto__c);
    }

    @isTest
    static void elPixelQuedaAntesDelCierreDelCuerpo() {
        String token = EnvioCorreoAperturaService.nuevoToken();
        String html = EnvioCorreoAperturaService.agregarPixel('<html><body>Hola</body></html>', token);
        System.assert(html.contains(EnvioCorreoAperturaService.RUTA + token));
        System.assert(html.indexOf(token) < html.toLowerCase().indexOf('</body>'));
        System.assert(EnvioCorreoAperturaService.urlPixel(token).contains('.my.salesforce-sites.com' + EnvioCorreoAperturaService.RUTA));
        System.assertEquals('<img', EnvioCorreoAperturaService.agregarPixel(null, token).left(4));
    }

    @isTest
    static void laPaginaPublicaRegistraLaApertura() {
        String token = EnvioCorreoAperturaService.nuevoToken();
        Destinatario_Envio_Correo__c fila = destinatario(token);
        Test.setCurrentPage(new PageReference('/apex/EnvioCorreoApertura?t=' + token));

        Test.startTest();
        new EnvioCorreoAperturaController().registrar();
        Test.stopTest();

        fila = [
            SELECT Abierto__c
            FROM Destinatario_Envio_Correo__c
            WHERE Id = :fila.Id
        ];
        System.assertEquals(true, fila.Abierto__c);
    }

    @isTest
    static void cadaFirmanteConservaSuPropiaApertura() {
        Envio_Correo__c envio = new Envio_Correo__c(
            Proceso__c = 'Prueba de apertura',
            Objeto__c = 'Movimiento_BolsaTech__c',
            Asunto__c = 'Prueba',
            Estado__c = 'Enviado'
        );
        insert envio;
        String tokenUno = EnvioCorreoAperturaService.nuevoToken();
        String tokenDos = EnvioCorreoAperturaService.nuevoToken();
        insert new List<Destinatario_Envio_Correo__c>{
            new Destinatario_Envio_Correo__c(
                Envio_Correo__c = envio.Id,
                Correo__c = 'uno@firma.test',
                Token_Apertura__c = tokenUno
            ),
            new Destinatario_Envio_Correo__c(
                Envio_Correo__c = envio.Id,
                Correo__c = 'dos@firma.test',
                Token_Apertura__c = tokenDos
            )
        };

        Test.startTest();
        EnvioCorreoAperturaService.registrar(tokenUno);
        Map<String, Destinatario_Envio_Correo__c> parcial = new Map<String, Destinatario_Envio_Correo__c>();
        for (Destinatario_Envio_Correo__c fila : [
            SELECT Correo__c, Abierto__c
            FROM Destinatario_Envio_Correo__c
            WHERE Envio_Correo__c = :envio.Id
        ]) {
            parcial.put(fila.Correo__c, fila);
        }
        EnvioCorreoAperturaService.registrar(tokenDos);
        Test.stopTest();

        System.assertEquals(true, parcial.get('uno@firma.test').Abierto__c);
        System.assertEquals(false, parcial.get('dos@firma.test').Abierto__c);
        Map<String, Destinatario_Envio_Correo__c> porCorreo = new Map<String, Destinatario_Envio_Correo__c>();
        for (Destinatario_Envio_Correo__c fila : [
            SELECT Correo__c, Abierto__c, Fecha_Primera_Apertura__c
            FROM Destinatario_Envio_Correo__c
            WHERE Envio_Correo__c = :envio.Id
        ]) {
            porCorreo.put(fila.Correo__c, fila);
        }
        System.assertEquals(true, porCorreo.get('uno@firma.test').Abierto__c);
        System.assertEquals(true, porCorreo.get('dos@firma.test').Abierto__c);
        System.assertNotEquals(null, porCorreo.get('uno@firma.test').Fecha_Primera_Apertura__c);
        System.assertNotEquals(null, porCorreo.get('dos@firma.test').Fecha_Primera_Apertura__c);
    }

    private static Destinatario_Envio_Correo__c destinatario(String token) {
        Envio_Correo__c envio = new Envio_Correo__c(
            Proceso__c = 'Prueba de apertura',
            Objeto__c = 'Movimiento_BolsaTech__c',
            Asunto__c = 'Prueba',
            Estado__c = 'Enviado'
        );
        insert envio;
        Destinatario_Envio_Correo__c fila = new Destinatario_Envio_Correo__c(
            Envio_Correo__c = envio.Id,
            Correo__c = 'uno@firma.test',
            Token_Apertura__c = token
        );
        insert fila;
        return fila;
    }
}
