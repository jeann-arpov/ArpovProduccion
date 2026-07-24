public class ReportExporter {
    public static Integer cantidadLicencias;

    @future(callout=true)
    public static void exportReportAndUpload(String reportDevName) {
        List <Report> reportList = [SELECT Id, Name FROM Report WHERE DeveloperName =: reportDevName];

        try {
            Map<String, Licencia__c> licenciasByCuit = getLicenciasByCuit();
            cantidadLicencias = licenciasByCuit.keySet().size();
            String fechaArchivo = Datetime.now().format('dd-MM-yyyy');
            String reportName = reportList[0].Name;

            // Reporte 1: original → carpeta licencias
            String reportCsv = buildCsvBasico(licenciasByCuit);
            uploadToGoogleCloudStorage(reportCsv, 'licencias/' + reportName + ' - ' + fechaArchivo + '.csv');

            // Reporte 2: emails adicionales → carpeta contactos
            String reportCsvEmails = buildCsvConEmailsAdicionales(licenciasByCuit);
            licenciasByCuit = null;
            uploadToGoogleCloudStorage(
                reportCsvEmails,
                'contactos/' + reportName + ' Emails - ' + fechaArchivo + '.csv'
            );

            sendEmailReportes(reportCsv, reportCsvEmails);
        } catch (Exception e) {
            system.debug(e.getMessage());
        }
    }

    /** Solo genera CSVs y envía correo (sin subir a Google). Útil para pruebas. */
    @future
    public static void sendReportsEmailOnly() {
        try {
            Map<String, Licencia__c> licenciasByCuit = getLicenciasByCuit();
            cantidadLicencias = licenciasByCuit.keySet().size();
            System.debug('sendReportsEmailOnly cantidadLicencias=' + cantidadLicencias);

            String reportCsv = buildCsvBasico(licenciasByCuit);
            String reportCsvEmails = buildCsvConEmailsAdicionales(licenciasByCuit);
            licenciasByCuit = null;
            sendEmailReportes(reportCsv, reportCsvEmails);
            System.debug('sendReportsEmailOnly OK - email enviado');
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'sendReportsEmailOnly ERROR: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getStackTraceString());
            throw e;
        }
    }

    public static String getReportCsv() {
        Map<String, Licencia__c> licenciasByCuit = getLicenciasByCuit();
        cantidadLicencias = licenciasByCuit.keySet().size();
        return buildCsvBasico(licenciasByCuit);
    }

    public static String getReportCsvConEmailsAdicionales() {
        Map<String, Licencia__c> licenciasByCuit = getLicenciasByCuit();
        cantidadLicencias = licenciasByCuit.keySet().size();
        return buildCsvConEmailsAdicionales(licenciasByCuit);
    }

    private static Map<String, Licencia__c> getLicenciasByCuit() {
        Map<String, Licencia__c> licenciasByCuit = new Map<String, Licencia__c>();
        for(Licencia__c l : [
            SELECT Id, Email__c, Fecha_de_Aprobacion__c, N_CUIT__c,
                Emails_Adicionales__c, email_adicional_1__c, email_adicional_2__c,
                email_adicional_3__c, email_adicional_4__c, email_adicional_5__c
            FROM Licencia__c
            WHERE Tipo_de_Licencia__c = 'Productor'
                AND Tecnologia__c = 'Enlist'
                AND Estado__c = 'Aprobada'
                AND N_CUIT__c != ''
        ]) {
            if(!licenciasByCuit.containsKey(l.N_CUIT__c)) {
                licenciasByCuit.put(l.N_CUIT__c, l);
            } else {
                Licencia__c licActual = licenciasByCuit.get(l.N_CUIT__c);
                if (l.Fecha_de_Aprobacion__c < licActual.Fecha_de_Aprobacion__c){ //solo procesamos la ultima aprobada
                    licenciasByCuit.put(l.N_CUIT__c, l);
                }
            }
        }
        return licenciasByCuit;
    }

    private static String buildCsvBasico(Map<String, Licencia__c> licenciasByCuit) {
        String csv = 'N° CUIT,Licencia: ID,Email,Fecha de Aprobacion\n';
        for(String key : licenciasByCuit.keySet()){
            Licencia__c lic = licenciasByCuit.get(key);
            if(lic.Fecha_de_Aprobacion__c != null) {
                csv += csvValue(lic.N_CUIT__c) + ','
                    + csvValue(lic.Id) + ','
                    + csvValue(lic.Email__c) + ','
                    + csvValue(formatFecha(lic.Fecha_de_Aprobacion__c)) + '\n';
            }
        }
        return csv;
    }

    private static String buildCsvConEmailsAdicionales(Map<String, Licencia__c> licenciasByCuit) {
        String csv = 'N° CUIT,Licencia: ID,Email,Fecha de Aprobacion,Emails Adicionales,Email Adicional 1,Email Adicional 2,Email Adicional 3,Email Adicional 4,Email Adicional 5\n';
        for(String key : licenciasByCuit.keySet()){
            Licencia__c lic = licenciasByCuit.get(key);
            if(lic.Fecha_de_Aprobacion__c != null) {
                csv += csvValue(lic.N_CUIT__c) + ','
                    + csvValue(lic.Id) + ','
                    + csvValue(lic.Email__c) + ','
                    + csvValue(formatFecha(lic.Fecha_de_Aprobacion__c)) + ','
                    + csvValue(lic.Emails_Adicionales__c) + ','
                    + csvValue(lic.email_adicional_1__c) + ','
                    + csvValue(lic.email_adicional_2__c) + ','
                    + csvValue(lic.email_adicional_3__c) + ','
                    + csvValue(lic.email_adicional_4__c) + ','
                    + csvValue(lic.email_adicional_5__c) + '\n';
            }
        }
        return csv;
    }

    private static String formatFecha(Date fecha) {
        Datetime dt = Datetime.newInstance(fecha.year(), fecha.month(), fecha.day());
        return dt.format('dd/MM/yyyy');
    }

    private static String csvValue(String value) {
        if (value == null) {
            return '';
        }
        String escaped = value.replace('"', '""');
        if (escaped.contains(',') || escaped.contains('"') || escaped.contains('\n') || escaped.contains('\r')) {
            return '"' + escaped + '"';
        }
        return escaped;
    }

    private static void uploadToGoogleCloudStorage(String fileContent, String fileName) {
        String bucketName = 'bt-se-passthru';

        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://storage.googleapis.com/upload/storage/v1/b/' + bucketName + '/o?uploadType=media&name=' + EncodingUtil.urlEncode(fileName, 'UTF-8'));
        req.setMethod('POST');
        req.setHeader('Authorization', 'Bearer ' + getGoogleAccessToken());
        req.setHeader('Content-Type', 'text/csv');
        req.setBodyAsBlob(Blob.valueOf(fileContent));

        Http http = new Http();
        HttpResponse res = http.send(req);

        system.debug(res.getBody());
    }

    public static String getGoogleAccessToken() {
        StaticResource sr = [SELECT Body FROM StaticResource WHERE Name = 'GoogleServiceAccount'];
        String jsonText = sr.Body.toString();
        Map<String, Object> creds = (Map<String, Object>) JSON.deserializeUntyped(jsonText);

        String privateKeyPem = (String) creds.get('private_key');
        String clientEmail = (String) creds.get('client_email');
        String tokenUri = (String) creds.get('token_uri');

        Long now = DateTime.now().getTime() / 1000;
        Long exp = now + 3600;

        Blob privateKeyBlob = EncodingUtil.base64Decode(privateKeyPem);
        String iss = clientEmail;
        String aud = tokenUri;

        String jwtHeader = '{"typ":"JWT","alg":"RS256"}';
        String jwtPayload = String.format('\'{\'"iss":"{0}","scope":"https://www.googleapis.com/auth/devstorage.read_write","aud":"{1}","exp":{2}, "iat":{3}\'}\'', new List<Object>{iss, aud, exp, now});

        String jwtClearPart = String.format('{0}.{1}', new List<Object>{
            System.EncodingUtil.base64Encode(Blob.valueOf(jwtHeader)).replace('+', '-').replace('/', '_'),
            System.EncodingUtil.base64Encode(Blob.valueOf(jwtPayload)).replace('+', '-').replace('/', '_')
        });

        Blob jwtSig = Crypto.sign('RSA-SHA256', Blob.valueOf(jwtClearPart), privateKeyBlob);

        String jwt = String.format('{0}.{1}', new List<Object>{jwtClearPart, System.EncodingUtil.base64Encode(jwtSig).replace('+', '-').replace('/', '_')});

        HttpRequest req = new HttpRequest();
        req.setEndpoint(tokenUri);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        req.setBody('grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=' + jwt);

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> tokenResp = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) tokenResp.get('access_token');
        } else {
            throw new CalloutException('Error obteniendo access token: ' + res.getBody());
        }
    }

    public static void sendEmailReportes(String reportCsv, String reportCsvEmails) {
        String fecha = Datetime.now().format('dd-MM-yyyy');
        Messaging.SingleEmailMessage mail = buildMailBase();
        mail.setSubject('Reporte enviado a Magoya – ' + fecha);
        mail.setPlainTextBody(
            'Hola equipo, buen día:\n'
            + 'Adjuntamos el detalle del total de licencias enviadas hoy a Magoya: ' + cantidadLicencias + '.\n'
            + 'Se incluyen dos archivos adjuntos:\n'
            + '- Licencias Enlist Aprobadas\n'
            + '- Licencias Enlist Aprobadas (Emails Adicionales)'
        );

        Messaging.EmailFileAttachment efaLicencias = new Messaging.EmailFileAttachment();
        efaLicencias.setFileName('Licencias Enlist Aprobadas - ' + fecha + '.csv');
        efaLicencias.setBody(Blob.valueOf(reportCsv));

        Messaging.EmailFileAttachment efaContactos = new Messaging.EmailFileAttachment();
        efaContactos.setFileName('Licencias Enlist Aprobadas Emails Adicionales - ' + fecha + '.csv');
        efaContactos.setBody(Blob.valueOf(reportCsvEmails));

        mail.setFileAttachments(new Messaging.EmailFileAttachment[] { efaLicencias, efaContactos });

        Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail }, false);
        assertEmailResults(results, 'sendEmailReportes');
    }

    private static void assertEmailResults(Messaging.SendEmailResult[] results, String context) {
        for (Messaging.SendEmailResult r : results) {
            if (!r.isSuccess()) {
                String errors = '';
                for (Messaging.SendEmailError err : r.getErrors()) {
                    errors += err.getStatusCode() + ' ' + err.getMessage() + '; ';
                }
                throw new AuraHandledException(context + ' falló: ' + errors);
            }
        }
    }

    private static Messaging.SingleEmailMessage buildMailBase() {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        List<String> destinatarios = new List<String>();
        Map<String, Destinatario_Reporte_Licencias__mdt> destinatariosMtd = Destinatario_Reporte_Licencias__mdt.getAll();
        for(String key : destinatariosMtd.keySet()) {
            destinatarios.add(destinatariosMtd.get(key).Email__c);
        }
        if (!destinatarios.contains('alexandercr@epidataconsulting.com')) {
            destinatarios.add('alexandercr@epidataconsulting.com');
        }
        if (!destinatarios.contains('lisandro.chazarreta@arpov.org.ar')) {
            destinatarios.add('lisandro.chazarreta@arpov.org.ar');
        }
        mail.setToAddresses(destinatarios);
        mail.setSaveAsActivity(false);

        List<OrgWideEmailAddress> owea = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress
            WHERE Address = 'info@sembraevolucion.com.ar'
            LIMIT 1
        ];
        if (!owea.isEmpty()) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        } else {
            System.debug(LoggingLevel.WARN, 'OrgWideEmailAddress info@sembraevolucion.com.ar no encontrado; se envía sin OWD');
        }
        return mail;
    }
}
