@isTest
private class EnvioCorreoAperturaServiceTest {
    @isTest
    static void registraLaPrimeraAperturaYConservaEsaFecha() {
        String token = EnvioCorreoAperturaService.nuevoToken();
        Envio_Correo__c envio = envio(token);
        insert envio;

        Test.startTest();
        EnvioCorreoAperturaService.registrar(token);
        Datetime primera = [
            SELECT Fecha_Primera_Apertura__c
            FROM Envio_Correo__c
            WHERE Id = :envio.Id
        ].Fecha_Primera_Apertura__c;
        envio.Fecha_Primera_Apertura__c = Datetime.newInstance(2026, 1, 1, 8, 0, 0);
        envio.Fecha_Ultima_Apertura__c = envio.Fecha_Primera_Apertura__c;
        update envio;
        EnvioCorreoAperturaService.registrar(token);
        Test.stopTest();

        envio = [
            SELECT Abierto__c, Fecha_Primera_Apertura__c, Fecha_Ultima_Apertura__c
            FROM Envio_Correo__c
            WHERE Id = :envio.Id
        ];
        System.assertEquals(true, envio.Abierto__c);
        System.assertEquals(Datetime.newInstance(2026, 1, 1, 8, 0, 0), envio.Fecha_Primera_Apertura__c);
        System.assert(envio.Fecha_Ultima_Apertura__c > envio.Fecha_Primera_Apertura__c);
        System.assertNotEquals(null, primera);
    }

    @isTest
    static void ignoraUnTokenInvalidoODesconocido() {
        String token = EnvioCorreoAperturaService.nuevoToken();
        insert envio(token);

        Test.startTest();
        EnvioCorreoAperturaService.registrar((String) null);
        EnvioCorreoAperturaService.registrar('no-es-un-token');
        EnvioCorreoAperturaService.registrar('a'.repeat(EnvioCorreoAperturaService.LARGO_TOKEN));
        Test.stopTest();

        Envio_Correo__c envio = [
            SELECT Abierto__c
            FROM Envio_Correo__c
            WHERE Token_Apertura__c = :token
        ];
        System.assertEquals(false, envio.Abierto__c);
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
        insert envio(token);
        Test.setCurrentPage(new PageReference('/apex/EnvioCorreoApertura?t=' + token));

        Test.startTest();
        new EnvioCorreoAperturaController().registrar();
        Test.stopTest();

        Envio_Correo__c envio = [
            SELECT Abierto__c
            FROM Envio_Correo__c
            WHERE Token_Apertura__c = :token
        ];
        System.assertEquals(true, envio.Abierto__c);
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
        Test.stopTest();

        Map<String, Destinatario_Envio_Correo__c> porCorreo = new Map<String, Destinatario_Envio_Correo__c>();
        for (Destinatario_Envio_Correo__c fila : [
            SELECT Correo__c, Abierto__c
            FROM Destinatario_Envio_Correo__c
            WHERE Envio_Correo__c = :envio.Id
        ]) {
            porCorreo.put(fila.Correo__c, fila);
        }
        System.assertEquals(true, porCorreo.get('uno@firma.test').Abierto__c);
        System.assertEquals(false, porCorreo.get('dos@firma.test').Abierto__c);
        envio = [SELECT Abierto__c FROM Envio_Correo__c WHERE Id = :envio.Id];
        System.assertEquals(true, envio.Abierto__c);
    }

    private static Envio_Correo__c envio(String token) {
        return new Envio_Correo__c(
            Proceso__c = 'Prueba de apertura',
            Objeto__c = 'Movimiento_BolsaTech__c',
            Asunto__c = 'Prueba',
            Estado__c = 'Enviado',
            Token_Apertura__c = token
        );
    }
}
