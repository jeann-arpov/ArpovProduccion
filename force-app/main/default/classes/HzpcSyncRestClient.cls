public with sharing class HzpcSyncRestClient {

    public static final String NAMED_CREDENTIAL = 'Hzpc';
    public static final String SF_COLLECTIONS_URI = '/services/data/v61.0/composite/sobjects/';

    public static RestClient getJsonClient(){
        return new RestClient()
        .setTimeout(30000)
        .setHeader(RestClient.HTTP_HEADER_ACCEPTS,RestClient.CONTENT_TYPE_JSON)
        .setHeader(RestClient.HTTP_HEADER_CONTENT_TYPE,RestClient.CONTENT_TYPE_JSON);
    }

    public static List<RecordSyncResponse> doSyncInsert(SyncRequest requestBody){
        return (List<RecordSyncResponse>) JSON.deserialize(
            getJsonClient()
            .setNamedCredential(NAMED_CREDENTIAL + SF_COLLECTIONS_URI)
            .setBody(requestBody)
            .post(),
            List<RecordSyncResponse>.class
        );
    }

    public static List<RecordSyncResponse> doSyncUpdate(SyncRequest requestBody){
        return (List<RecordSyncResponse>) JSON.deserialize(
            getJsonClient()
            .setNamedCredential(NAMED_CREDENTIAL + SF_COLLECTIONS_URI)
            .setBody(requestBody)
            .patch(),
            List<RecordSyncResponse>.class
        );
    }

    public class SyncRequest {
        public Boolean allOrNone;
        public List<Map<String, Object>> records;
    }

    public class RecordSyncResponse{
        public String id;
        public Boolean success;
        public List<ResponseError> errors;
    }

    public class ResponseError {
        public String statusCode;
        public String message;
        public List<String> fields;
    }
}