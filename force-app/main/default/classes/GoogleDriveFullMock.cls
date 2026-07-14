@isTest
global class GoogleDriveFullMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        
        // Simular reporte CSV desde Salesforce
        if (req.getEndpoint().contains('/analytics/reports/')) {
            res.setStatusCode(200);
            res.setBody('Id,Nombre,Estado,Fecha\n001,Aprobado,Aprobada,2025-04-09');
            return res;
        }

        // Simular token de Google
        if (req.getEndpoint().contains('oauth2.googleapis.com')) {
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token": "mock_access_token", "expires_in": 3600, "token_type": "Bearer"}');
            return res;
        }

        // Simular subida a Google Drive
        if (req.getEndpoint().contains('drive/v3/files')) {
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id": "fakeGoogleDriveId"}');
            return res;
        }

        // Default
        res.setStatusCode(400);
        res.setBody('Request no esperado: ' + req.getEndpoint());
        return res;
    }
}