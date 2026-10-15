public with sharing class EnvioCorreoMbtInicialService {
    public static final String PROCESO = 'MBT inicial de campaña';
    public static final String OBJETO = 'Movimiento_BolsaTech__c';
    public static final String REMITENTE = 'info@sembraevolucion.com.ar';
    public static final String ASUNTO = 'Verificación de toneladas disponibles';
    public static final String PLANTILLA = 'PositivoEnlistCorteva';
    public static final String TECNOLOGIA = 'ENLIST';
    private static final String MERGE_RAZON_SOCIAL = '*|RAZONSOC|*';

    public static void procesar(Set<Id> movimientoIds) {
        if (movimientoIds == null || movimientoIds.isEmpty()) {
            return;
        }

        List<Movimiento_BolsaTech__c> candidatos = [
            SELECT Id, Name, Titular__c, Titular__r.Name, Titular__r.N_CUIT__c,
                Cosecha__c, Cultivo__c, Tecnologia__c, CreatedDate
            FROM Movimiento_BolsaTech__c
            WHERE Id IN :movimientoIds
            AND Titular__c != null
            AND Cosecha__c != null
            AND Tecnologia__c = :TECNOLOGIA
        ];
        if (candidatos.isEmpty()) {
            return;
        }

        Map<String, Id> primerMovimientoPorClave = primerosPorClave(candidatos);
        List<Movimiento_BolsaTech__c> primeros = new List<Movimiento_BolsaTech__c>();
        Set<Id> titularIds = new Set<Id>();
        Set<String> cosechas = new Set<String>();
        Set<String> cultivos = new Set<String>();
        for (Movimiento_BolsaTech__c movimiento : candidatos) {
            if (String.isBlank(movimiento.Cultivo__c) || anioDeCosecha(movimiento.Cosecha__c) == null) {
                continue;
            }
            if (primerMovimientoPorClave.get(clave(movimiento)) != movimiento.Id) {
                continue;
            }
            primeros.add(movimiento);
            titularIds.add(movimiento.Titular__c);
            cosechas.add(movimiento.Cosecha__c);
            cultivos.add(movimiento.Cultivo__c);
        }
        if (primeros.isEmpty()) {
            return;
        }

        Set<String> clavesNotificadas = clavesYaNotificadas(titularIds);
        Map<String, Envio_Correo__c> envioExistentePorRegistro = enviosExistentes(primeros);
        Map<Id, List<String>> correosPorTitular = correosEnlist(titularIds);
        Map<String, CampaniaInfo> campaniaPorCultivoAnio = campanias(cultivos, anios(cosechas));
        Map<String, Id> cultivoPorNombre = cultivosPorNombre(cultivos);
        String htmlPlantilla = plantillaHtml();
        OrgWideEmailAddress casilla = casillaRemitente();

        List<Envio_Correo__c> aGuardar = new List<Envio_Correo__c>();
        List<Messaging.SingleEmailMessage> correos = new List<Messaging.SingleEmailMessage>();
        List<Integer> indiceEnvioPorCorreo = new List<Integer>();

        for (Movimiento_BolsaTech__c movimiento : primeros) {
            if (clavesNotificadas.contains(clave(movimiento))) {
                continue;
            }

            Envio_Correo__c envio = envioExistentePorRegistro.get(String.valueOf(movimiento.Id));
            if (envio != null && envio.Estado__c == 'Enviado') {
                continue;
            }
            if (envio == null) {
                envio = nuevoEnvio(movimiento, campaniaPorCultivoAnio, cultivoPorNombre);
            } else {
                completarEnvio(envio, movimiento, campaniaPorCultivoAnio, cultivoPorNombre);
            }

            List<String> destinatarios = correosPorTitular.get(movimiento.Titular__c);
            if (casilla == null) {
                marcarError(envio, 'No está configurada la casilla ' + REMITENTE + '.');
            } else if (String.isBlank(htmlPlantilla)) {
                marcarError(envio, 'No se encontró la plantilla ' + PLANTILLA + '.');
            } else if (destinatarios == null || destinatarios.isEmpty()) {
                marcarError(envio, 'El productor no tiene un firmante en una licencia Enlist aprobada.');
            } else {
                String html = armarCuerpo(htmlPlantilla, movimiento.Titular__r.Name);
                String asuntoCorreo = ASUNTO + ' - ' + nombreCampania(movimiento, campaniaPorCultivoAnio);
                envio.Para__c = String.join(destinatarios, ', ');
                envio.Asunto__c = asuntoCorreo;
                envio.Cuerpo_HTML__c = html;
                envio.De__c = REMITENTE;
                envio.Estado__c = 'Enviado';
                envio.Mensaje_Error__c = null;
                envio.Fecha_Envio__c = System.now();
                correos.add(armarCorreo(casilla, destinatarios, asuntoCorreo, html));
                indiceEnvioPorCorreo.add(aGuardar.size());
            }
            aGuardar.add(envio);
        }

        if (!correos.isEmpty()) {
            Messaging.SendEmailResult[] resultados = Messaging.sendEmail(correos, false);
            for (Integer i = 0; i < resultados.size(); i++) {
                if (resultados[i].isSuccess()) {
                    continue;
                }
                Envio_Correo__c envio = aGuardar[indiceEnvioPorCorreo[i]];
                marcarError(envio, mensajeError(resultados[i]));
            }
        }

        if (aGuardar.isEmpty()) {
            return;
        }
        upsert aGuardar;
        vincularCorreos(aGuardar);
    }

    private static Map<String, Id> primerosPorClave(List<Movimiento_BolsaTech__c> candidatos) {
        Set<Id> titularIds = new Set<Id>();
        Set<String> cultivos = new Set<String>();
        Set<String> prefijos = new Set<String>();
        for (Movimiento_BolsaTech__c movimiento : candidatos) {
            String anio = anioDeCosecha(movimiento.Cosecha__c);
            if (movimiento.Titular__c == null || String.isBlank(movimiento.Cultivo__c) || anio == null) {
                continue;
            }
            titularIds.add(movimiento.Titular__c);
            cultivos.add(movimiento.Cultivo__c);
            prefijos.add(anio.substring(2));
        }

        Map<String, Id> primerId = new Map<String, Id>();
        if (titularIds.isEmpty()) {
            return primerId;
        }

        List<String> filtrosAnio = new List<String>();
        for (String prefijo : prefijos) {
            filtrosAnio.add('Cosecha__c LIKE \'' + String.escapeSingleQuotes(prefijo) + '%\'');
        }
        String tecnologia = TECNOLOGIA;
        String consulta =
            'SELECT Id, Titular__c, Cosecha__c, Cultivo__c, CreatedDate ' +
            'FROM Movimiento_BolsaTech__c ' +
            'WHERE Titular__c IN :titularIds ' +
            'AND Cultivo__c IN :cultivos ' +
            'AND Tecnologia__c = :tecnologia ' +
            'AND (' + String.join(filtrosAnio, ' OR ') + ') ' +
            'ORDER BY CreatedDate ASC, Id ASC';
        for (Movimiento_BolsaTech__c movimiento : Database.query(consulta)) {
            if (primerId.containsKey(clave(movimiento))) {
                continue;
            }
            primerId.put(clave(movimiento), movimiento.Id);
        }
        return primerId;
    }

    private static Set<String> clavesYaNotificadas(Set<Id> titularIds) {
        Set<String> claves = new Set<String>();
        Map<Id, Id> productorPorRegistro = new Map<Id, Id>();
        for (Envio_Correo__c envio : [
            SELECT Productor__c, Campania__r.Ano__c, Campania__r.Cultivo__r.Name, Id_Registro__c
            FROM Envio_Correo__c
            WHERE Proceso__c = :PROCESO
            AND Estado__c = 'Enviado'
            AND Productor__c IN :titularIds
        ]) {
            if (envio.Campania__c != null && String.isNotBlank(envio.Campania__r.Ano__c) && envio.Campania__r.Cultivo__r != null) {
                claves.add(clave(envio.Productor__c, envio.Campania__r.Cultivo__r.Name, envio.Campania__r.Ano__c));
                continue;
            }
            if (esId(envio.Id_Registro__c)) {
                productorPorRegistro.put((Id) envio.Id_Registro__c, envio.Productor__c);
            }
        }
        if (productorPorRegistro.isEmpty()) {
            return claves;
        }
        for (Movimiento_BolsaTech__c movimiento : [
            SELECT Id, Cosecha__c, Cultivo__c
            FROM Movimiento_BolsaTech__c
            WHERE Id IN :productorPorRegistro.keySet()
        ]) {
            String anio = anioDeCosecha(movimiento.Cosecha__c);
            if (String.isBlank(movimiento.Cultivo__c) || anio == null) {
                continue;
            }
            claves.add(clave(productorPorRegistro.get(movimiento.Id), movimiento.Cultivo__c, anio));
        }
        return claves;
    }

    private static Map<String, Envio_Correo__c> enviosExistentes(List<Movimiento_BolsaTech__c> movimientos) {
        Set<String> registroIds = new Set<String>();
        for (Movimiento_BolsaTech__c movimiento : movimientos) {
            registroIds.add(String.valueOf(movimiento.Id));
        }
        Map<String, Envio_Correo__c> porRegistro = new Map<String, Envio_Correo__c>();
        for (Envio_Correo__c envio : [
            SELECT Id, Id_Registro__c, Estado__c, Asunto__c
            FROM Envio_Correo__c
            WHERE Proceso__c = :PROCESO
            AND Id_Registro__c IN :registroIds
        ]) {
            porRegistro.put(envio.Id_Registro__c, envio);
        }
        return porRegistro;
    }

    private static Map<Id, List<String>> correosEnlist(Set<Id> titularIds) {
        Map<Id, List<String>> correos = new Map<Id, List<String>>();
        Map<Id, Set<String>> vistos = new Map<Id, Set<String>>();
        for (Licencia__c licencia : [
            SELECT Cuenta_Productor__c, Firmante_Carta_de_Aceptacion__c
            FROM Licencia__c
            WHERE Cuenta_Productor__c IN :titularIds
            AND Tecnologia__c = 'Enlist'
            AND Estado__c = 'Aprobada'
            AND Tipo_de_Licencia__c = 'Productor'
            AND Firmante_Carta_de_Aceptacion__c != null
        ]) {
            String correo = licencia.Firmante_Carta_de_Aceptacion__c.trim().toLowerCase();
            if (!vistos.containsKey(licencia.Cuenta_Productor__c)) {
                vistos.put(licencia.Cuenta_Productor__c, new Set<String>());
                correos.put(licencia.Cuenta_Productor__c, new List<String>());
            }
            if (vistos.get(licencia.Cuenta_Productor__c).add(correo)) {
                correos.get(licencia.Cuenta_Productor__c).add(licencia.Firmante_Carta_de_Aceptacion__c.trim());
            }
        }
        return correos;
    }

    private static Set<String> anios(Set<String> cosechas) {
        Set<String> anios = new Set<String>();
        for (String cosecha : cosechas) {
            if (cosecha != null && cosecha.length() >= 2) {
                anios.add('20' + cosecha.substring(0, 2));
            }
        }
        return anios;
    }

    private class CampaniaInfo {
        public Id registroId;
        public String nombre;

        public CampaniaInfo(Campana_Agricola__c campania) {
            registroId = campania.Id;
            nombre = campania.Name;
        }
    }

    private static Map<String, CampaniaInfo> campanias(Set<String> cultivos, Set<String> anios) {
        Map<String, CampaniaInfo> campaniaPorCultivoAnio = new Map<String, CampaniaInfo>();
        if (cultivos.isEmpty() || anios.isEmpty()) {
            return campaniaPorCultivoAnio;
        }
        for (Campana_Agricola__c campania : [
            SELECT Id, Name, Ano__c, Cultivo__r.Name
            FROM Campana_Agricola__c
            WHERE Ano__c IN :anios
            AND Cultivo__r.Name IN :cultivos
        ]) {
            campaniaPorCultivoAnio.put(campania.Cultivo__r.Name + '|' + campania.Ano__c, new CampaniaInfo(campania));
        }
        return campaniaPorCultivoAnio;
    }

    private static Map<String, Id> cultivosPorNombre(Set<String> nombres) {
        Map<String, Id> cultivoPorNombre = new Map<String, Id>();
        if (nombres.isEmpty()) {
            return cultivoPorNombre;
        }
        for (Cultivo__c cultivo : [SELECT Id, Name FROM Cultivo__c WHERE Name IN :nombres]) {
            cultivoPorNombre.put(cultivo.Name, cultivo.Id);
        }
        return cultivoPorNombre;
    }

    private static Envio_Correo__c nuevoEnvio(
        Movimiento_BolsaTech__c movimiento,
        Map<String, CampaniaInfo> campaniaPorCultivoAnio,
        Map<String, Id> cultivoPorNombre
    ) {
        Envio_Correo__c envio = new Envio_Correo__c(
            Proceso__c = PROCESO,
            Objeto__c = OBJETO,
            Id_Registro__c = String.valueOf(movimiento.Id),
            Nombre_Registro__c = movimiento.Name
        );
        completarEnvio(envio, movimiento, campaniaPorCultivoAnio, cultivoPorNombre);
        return envio;
    }

    private static void completarEnvio(
        Envio_Correo__c envio,
        Movimiento_BolsaTech__c movimiento,
        Map<String, CampaniaInfo> campaniaPorCultivoAnio,
        Map<String, Id> cultivoPorNombre
    ) {
        String anio = anioDeCosecha(movimiento.Cosecha__c);
        CampaniaInfo campania = campaniaPorCultivoAnio.get(movimiento.Cultivo__c + '|' + anio);
        envio.Productor__c = movimiento.Titular__c;
        envio.CUIT__c = acotar(movimiento.Titular__r.N_CUIT__c, 11);
        envio.Tecnologia__c = movimiento.Tecnologia__c;
        envio.Cultivo__c = cultivoPorNombre.get(movimiento.Cultivo__c);
        envio.Campania__c = campania == null ? null : campania.registroId;
        envio.Nombre_Registro__c = movimiento.Name;
        envio.Fecha_Envio__c = System.now();
    }

    private static void marcarError(Envio_Correo__c envio, String mensaje) {
        envio.Estado__c = 'Error';
        envio.Mensaje_Error__c = mensaje;
        envio.Fecha_Envio__c = System.now();
        if (String.isBlank(envio.Asunto__c)) {
            envio.Asunto__c = ASUNTO;
        }
    }

    private static String plantillaHtml() {
        List<StaticResource> recursos = [
            SELECT Body
            FROM StaticResource
            WHERE Name = :PLANTILLA
            LIMIT 1
        ];
        if (recursos.isEmpty() || recursos[0].Body == null) {
            return null;
        }
        String html = recursos[0].Body.toString();
        html = html.replaceAll(
            '(?i)<a\\b[^>]*href="[^"]*(?:mailchi\\.mp|list-manage\\.com)[^"]*"[^>]*>.*?</a>',
            ''
        );
        html = html.replace('Want to change how you receive these emails?', '');
        html = html.replace('You can  or .', '');
        return html;
    }

    private static String armarCuerpo(String plantilla, String razonSocial) {
        String nombre = String.isBlank(razonSocial) ? '' : razonSocial;
        nombre = nombre.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;');
        return plantilla.replace(MERGE_RAZON_SOCIAL, nombre);
    }

    private static OrgWideEmailAddress casillaRemitente() {
        List<OrgWideEmailAddress> casillas = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE Address = :REMITENTE
            LIMIT 1
        ];
        return casillas.isEmpty() ? null : casillas[0];
    }

    private static Messaging.SingleEmailMessage armarCorreo(
        OrgWideEmailAddress remitente,
        List<String> destinatarios,
        String asunto,
        String cuerpo
    ) {
        Messaging.SingleEmailMessage correo = new Messaging.SingleEmailMessage();
        correo.setOrgWideEmailAddressId(remitente.Id);
        correo.setToAddresses(destinatarios);
        correo.setSubject(asunto);
        correo.setHtmlBody(cuerpo);
        correo.setSaveAsActivity(false);
        correo.setUseSignature(false);
        return correo;
    }

    private static String mensajeError(Messaging.SendEmailResult resultado) {
        if (resultado.getErrors().isEmpty()) {
            return 'El envío fue rechazado.';
        }
        return resultado.getErrors()[0].getMessage();
    }

    private static void vincularCorreos(List<Envio_Correo__c> envios) {
        List<EmailMessage> mensajes = new List<EmailMessage>();
        List<Envio_Correo__c> enviados = new List<Envio_Correo__c>();
        for (Envio_Correo__c envio : envios) {
            if (envio.Estado__c != 'Enviado' || String.isBlank(envio.Para__c)) {
                continue;
            }
            mensajes.add(new EmailMessage(
                Subject = envio.Asunto__c,
                ToAddress = envio.Para__c,
                RelatedToId = envio.Id,
                Status = '3',
                MessageDate = envio.Fecha_Envio__c
            ));
            enviados.add(envio);
        }
        if (mensajes.isEmpty()) {
            return;
        }
        insert mensajes;
        for (Integer i = 0; i < mensajes.size(); i++) {
            enviados[i].Id_Correo__c = String.valueOf(mensajes[i].Id);
        }
        update enviados;
    }

    private static String nombreCampania(Movimiento_BolsaTech__c movimiento, Map<String, CampaniaInfo> campaniaPorCultivoAnio) {
        String anio = anioDeCosecha(movimiento.Cosecha__c);
        CampaniaInfo campania = campaniaPorCultivoAnio.get(movimiento.Cultivo__c + '|' + anio);
        if (campania != null && String.isNotBlank(campania.nombre)) {
            return campania.nombre;
        }
        return anio + ' - ' + movimiento.Cultivo__c;
    }

    private static String anioDeCosecha(String cosecha) {
        if (String.isBlank(cosecha) || cosecha.length() < 2) {
            return null;
        }
        return '20' + cosecha.substring(0, 2);
    }

    private static String clave(Movimiento_BolsaTech__c movimiento) {
        return clave(movimiento.Titular__c, movimiento.Cultivo__c, anioDeCosecha(movimiento.Cosecha__c));
    }

    private static String clave(Id titularId, String cultivo, String anio) {
        return String.valueOf(titularId) + '|' + cultivo + '|' + anio;
    }

    private static Boolean esId(String valor) {
        if (String.isBlank(valor) || (valor.length() != 15 && valor.length() != 18)) {
            return false;
        }
        try {
            Id.valueOf(valor);
            return true;
        } catch (Exception error) {
            return false;
        }
    }

    private static String acotar(String valor, Integer largo) {
        if (String.isBlank(valor) || valor.length() <= largo) {
            return valor;
        }
        return valor.left(largo);
    }
}
