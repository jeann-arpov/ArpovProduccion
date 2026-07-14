public class ReportExporter {
    public static Integer cantidadLicencias;

    @future(callout=true)
    public static void exportReportAndUpload(String reportDevName) {
        List <Report> reportList = [SELECT Id, Name FROM Report WHERE DeveloperName =: reportDevName];

        try {
            // 1️⃣ Obtener el reporte en CSV
            String reportCsv = getReportCsv();

            // 2️⃣ Subir a Google Cloud Storage
            uploadToGoogleCloudStorage(reportCsv, reportList[0].Name + ' - ' +  Datetime.now().format('dd-MM-yyyy') + '.csv');
            sendEmail(reportCsv);
        } catch (Exception e) {
            system.debug(e.getMessage());
        }
    }

    public static String getReportCsv() {
        //Al final no se puede exportar un reporte a csv, se decidio recrearlo con SOQL
        Map<String, Licencia__c> licenciasByCuit = new Map<String, Licencia__c>();
        for(Licencia__c l : [
            SELECT Id, Email__c, Fecha_de_Aprobacion__c, N_CUIT__c 
            FROM Licencia__c 
            WHERE Tipo_de_Licencia__c = 'Productor' AND Tecnologia__c = 'Enlist' AND Estado__c = 'Aprobada' AND N_CUIT__c != ''
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
        cantidadLicencias = licenciasByCuit.keySet().size();

        String csv = 'N° CUIT,Licencia: ID,Email,Fecha de Aprobacion\n';
        for(String key : licenciasByCuit.keySet()){
            Licencia__c lic = licenciasByCuit.get(key);
            if(lic.Fecha_de_Aprobacion__c != null) {
                Datetime fecha =  Datetime.newInstance(lic.Fecha_de_Aprobacion__c.year(), lic.Fecha_de_Aprobacion__c.month(), lic.Fecha_de_Aprobacion__c.day());
                csv += lic.N_CUIT__c + ',' + lic.Id  + ',' + lic.Email__c + ',' + fecha.format('dd/MM/yyyy') + '\n';
            }

        }

        return csv;
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

    public static void sendEmail(String reportCSV) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

        List<String> destinatarios = new List<String>();
        Map<String, Destinatario_Reporte_Licencias__mdt> destinatariosMtd = Destinatario_Reporte_Licencias__mdt.getAll();
        for(String key : destinatariosMtd.keySet()) {
            destinatarios.add(destinatariosMtd.get(key).Email__c);
        }

        mail.setToAddresses(destinatarios);


        //a consultar desde que email deberia enviarse
        OrgWideEmailAddress owd = [SELECT Id, Address, DisplayName FROM OrgWideEmailAddress WHERE Address = 'info@sembraevolucion.com.ar'];

        mail.setOrgWideEmailAddressId(owd.Id);

        mail.setSubject(' Reporte enviado a Magoya – ' +  Datetime.now().format('dd-MM-yyyy'));

        mail.setPlainTextBody('Hola equipo, buen día: \nAdjuntamos el detalle del total de licencias enviadas hoy a Magoya: ' + cantidadLicencias +'. \n(Se incluye archivo adjunto)');

        Messaging.EmailFileAttachment efa = new Messaging.EmailFileAttachment();
        efa.setFileName('Licencias Enlist Aprobadas - ' +  Datetime.now().format('dd-MM-yyyy') + '.csv');
        efa.setBody(Blob.valueOf(reportCSV));

        mail.setFileAttachments(new Messaging.EmailFileAttachment[] {efa});

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}