/**
* @author VCS
* @date 08/06/2020
* @description Clase auxiliar para testear APIS y poder usarla desde multiples UnitTest con multiples APIS
*/
@IsTest
public class HttpMock implements HttpCalloutMock {

    private static final String ANY_URL = null;

    private Map<String, Object> responses = new Map<String, Object>();


    public HttpMock mock(String urlFragment, Object body, Integer statusCode) {
        HttpResponse response = new HttpResponse();
        response.setHeader('Content-Type', 'application/json');
        response.setStatusCode(statusCode);
        response.setBody(JSON.serialize(body));

        responses.put(urlFragment, response);

        return this;
    }


    public HttpMock mock(String urlFragment, Object body) {
        return mock(urlFragment, body, 200);
    }


    public HttpMock mock(Object body, Integer statusCode) {
        return mock(ANY_URL, body, statusCode);
    }


    public void set() {
        Test.setMock(HttpCalloutMock.class, this);
    }

    public HttpResponse respond(HttpRequest request) {
        Object response = null;

        for(String urlFragment : responses.keySet()) {
            if(urlFragment == ANY_URL || request.getEndpoint().containsIgnoreCase(urlFragment)) {
                response = responses.get(urlFragment);

                if(response instanceof Exception) {
                    throw (Exception) response;
                }

                break;
            }
        }

        return (HttpResponse) response;
    }
}