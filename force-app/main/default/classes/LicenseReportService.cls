public with sharing class LicenseReportService {
    
    // Wrapper class para la respuesta del servicio
    public class ServiceResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Object data;
        @AuraEnabled public Integer statusCode;
        
        public ServiceResponse(Boolean success, String message, Object data, Integer statusCode) {
            this.success = success;
            this.message = message;
            this.data = data;
            this.statusCode = statusCode;
        }
    }
    
    // Wrapper class para el reporte de licencias
    public class LicenseReportData {
        @AuraEnabled public String reportId;
        @AuraEnabled public String status;
        @AuraEnabled public List<LicenseItem> licenses;
        @AuraEnabled public String generatedDate;
    }
    
    public class LicenseItem {
        @AuraEnabled public String licenseCode;
        @AuraEnabled public String description;
        @AuraEnabled public String status;
        @AuraEnabled public String expiryDate;
    }
    
    
    @AuraEnabled
    public static ServiceResponse getLicensesReport(String userId, String contactId) {
        try {
            if (String.isBlank(userId) || String.isBlank(contactId)) {
                return new ServiceResponse(false, 'Los parámetros userId y contactId son requeridos', null, null);
            }
            
            String jwtToken = CustomJWTSigner.singleNewLicenseRequestJWTSigner(userId, contactId);
            if (String.isBlank(jwtToken)) {
                return new ServiceResponse(false, 'Error al generar el token de autenticación', null, null);
            }
            return performCallout(jwtToken);
            
        } catch (Exception e) {
            System.debug('Error in getLicensesReport: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            return new ServiceResponse(false, 'Error interno: ' + e.getMessage(), null, null);
        }
    }
    
    private static ServiceResponse performCallout(String jwtToken) {
        try {
            HttpRequest request = new HttpRequest();
            
            String endpoint = 'callout:SGL_Report/api/Report/LicensesReport?token=' + EncodingUtil.urlEncode(jwtToken, 'UTF-8');            
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            
            request.setTimeout(30000); // 30 segundos
            
            Http http = new Http();
            HttpResponse response = http.send(request);
            
            return processHttpResponse(response);
            
        } catch (System.CalloutException e) {
            System.debug('Callout Exception: ' + e.getMessage());
            return new ServiceResponse(false, 'Error de conectividad con el servicio externo: ' + e.getMessage(), null, null);
        } catch (Exception e) {
            System.debug('General Exception in performCallout: ' + e.getMessage());
            return new ServiceResponse(false, 'Error inesperado en el callout: ' + e.getMessage(), null, null);
        }
    }
    
    private static ServiceResponse processHttpResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        
        System.debug('HTTP Status Code: ' + statusCode);
        System.debug('Response Body: ' + responseBody);
        
        switch on statusCode {
            when 200{
                try {
                    //  JSON estructurado
                    Object parsedData = JSON.deserializeUntyped(responseBody);
                    return new ServiceResponse(true, 'Reporte generado exitosamente', parsedData, statusCode);
                    
                    
                } catch (JSONException e) {
                    return new ServiceResponse(true, 'Reporte generado exitosamente', responseBody, statusCode);
                }
            }
            
            when 401 {
                return new ServiceResponse(false, 'Token de autenticación inválido o expirado.', responseBody, statusCode);
            }
            
            when 500 {
                return new ServiceResponse(false, 'Error interno del servidor externo.', responseBody, statusCode);
            }
            when else {
                return new ServiceResponse(false, 'Error inesperado del servicio (Código: ' + statusCode + ')', responseBody, statusCode);
            }
        }
    }
    
}