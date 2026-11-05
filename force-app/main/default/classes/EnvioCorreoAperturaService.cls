// Mail clients request the pixel without a Salesforce session.
public without sharing class EnvioCorreoAperturaService {
    public static final Integer LARGO_TOKEN = 64;
    public static final String RUTA = '/apertura/?t=';

    public static String nuevoToken() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(256));
    }

    public static String urlPixel(String token) {
        String dominio = URL.getOrgDomainUrl().toExternalForm();
        dominio = dominio.replace('.my.salesforce.com', '.my.salesforce-sites.com');
        return dominio + RUTA + token;
    }

    public static String agregarPixel(String html, String token) {
        String etiqueta =
            '<img src="' + urlPixel(token) + '" width="1" height="1" alt="" ' +
            'style="display:block;width:1px;height:1px;border:0;overflow:hidden;" />';
        if (String.isBlank(html)) {
            return etiqueta;
        }
        Matcher cierre = Pattern.compile('(?i)</body>').matcher(html);
        Integer indice = -1;
        while (cierre.find()) {
            indice = cierre.start();
        }
        if (indice < 0) {
            return html + etiqueta;
        }
        return html.substring(0, indice) + etiqueta + html.substring(indice);
    }

    public static void solicitar(String token) {
        if (!esToken(token)) {
            return;
        }
        EventBus.publish(new Apertura_Correo__e(Token__c = token));
    }

    public static void registrar(String token) {
        if (!esToken(token)) {
            return;
        }
        registrar(new Set<String>{ token });
    }

    public static void registrar(Set<String> tokens) {
        Set<String> validos = new Set<String>();
        if (tokens != null) {
            for (String token : tokens) {
                if (esToken(token)) {
                    validos.add(token);
                }
            }
        }
        if (validos.isEmpty()) {
            return;
        }
        Datetime ahora = System.now();
        List<Destinatario_Envio_Correo__c> destinatarios = [
            SELECT Id, Envio_Correo__c, Token_Apertura__c, Fecha_Primera_Apertura__c
            FROM Destinatario_Envio_Correo__c
            WHERE Token_Apertura__c IN :validos
        ];
        Set<Id> envioIds = new Set<Id>();
        for (Destinatario_Envio_Correo__c destinatario : destinatarios) {
            validos.remove(destinatario.Token_Apertura__c);
            destinatario.Abierto__c = true;
            if (destinatario.Fecha_Primera_Apertura__c == null) {
                destinatario.Fecha_Primera_Apertura__c = ahora;
            }
            destinatario.Fecha_Ultima_Apertura__c = ahora;
            envioIds.add(destinatario.Envio_Correo__c);
        }
        if (!destinatarios.isEmpty()) {
            update destinatarios;
        }
        List<Envio_Correo__c> envios = [
            SELECT Id, Fecha_Primera_Apertura__c
            FROM Envio_Correo__c
            WHERE Id IN :envioIds OR Token_Apertura__c IN :validos
        ];
        for (Envio_Correo__c envio : envios) {
            envio.Abierto__c = true;
            if (envio.Fecha_Primera_Apertura__c == null) {
                envio.Fecha_Primera_Apertura__c = ahora;
            }
            envio.Fecha_Ultima_Apertura__c = ahora;
        }
        if (!envios.isEmpty()) {
            update envios;
        }
    }

    private static Boolean esToken(String token) {
        return String.isNotBlank(token) && Pattern.matches('[0-9a-fA-F]{' + LARGO_TOKEN + '}', token);
    }
}
