@isTest
global class GoogleCloudStorageMock implements HttpCalloutMock {
    global HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();

        if (req.getEndpoint().contains('/analytics/reports/')) {
            res.setStatusCode(200);
            res.setBody('Id,Nombre,Estado,Fecha\n001,Aprobado,Aprobada,2025-04-09');
            return res;
        }

        if (req.getEndpoint().contains('oauth2.googleapis.com')) {
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"access_token": "mock_token", "expires_in": 3600, "token_type": "Bearer"}');
            return res;
        }

        if (req.getEndpoint().contains('storage.googleapis.com')) {
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"id": "mock_file_id"}');
            return res;
        }

        res.setStatusCode(400);
        res.setBody('Endpoint no esperado');
        return res;
    }
}