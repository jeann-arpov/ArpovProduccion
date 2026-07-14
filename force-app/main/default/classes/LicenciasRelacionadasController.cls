public with sharing class LicenciasRelacionadasController {

    public class LicenciaDTO {
        @AuraEnabled public String codigoLicencia;
        @AuraEnabled public String semillero;
        @AuraEnabled public String tipoLicencia;
        @AuraEnabled public String estado;
        @AuraEnabled public String mail;
        @AuraEnabled public String firmanteCelular;
    }

    @AuraEnabled(cacheable=true)
    public static List<LicenciaDTO> getLicenciasByProductor(String CUIT_cliente) {
        if (String.isBlank(CUIT_cliente)) {
            return new List<LicenciaDTO>();
        }

        List<Licencia__c> licencias = [
            SELECT
                CodigoLicenciaTexto__c,
                Nombres_Marcas__c,
                Tipo_de_Licencia__c,
                Estado__c,
                Email_Licencia__c,
                Firmante_Celular__c,
                Tecnologia__c,
                N_CUIT__c
            FROM Licencia__c
            WHERE
                N_CUIT__c = :CUIT_cliente
                AND Tecnologia__c IN ('enlist', 'conkesta')
            	AND Estado__c = 'Aprobada'
        ];

        List<LicenciaDTO> result = new List<LicenciaDTO>();
        for (Licencia__c lic : licencias) {
            LicenciaDTO dto = new LicenciaDTO();
            dto.codigoLicencia   = lic.CodigoLicenciaTexto__c;
            dto.semillero        = lic.Nombres_Marcas__c;
            dto.tipoLicencia     = lic.Tipo_de_Licencia__c;
            dto.estado           = lic.Estado__c;
            dto.mail             = lic.Email_Licencia__c;
            dto.firmanteCelular  = lic.Firmante_Celular__c;
            result.add(dto);
        }
        return result;
    }
}