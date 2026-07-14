public without sharing class PDFLicenciaController {
    public Licencia__c licencia {get;set;}

    public PDFLicenciaController() {
        init(ApexPages.currentPage().getParameters());
    }

    public static String serializeLicencia(Id licenciaId) {
        Licencia__c licencia = [SELECT Id, 
                                        OwnerId,
                                        Name, 
                                        Created__c, 
                                        Email__c, 
                                        Cuenta_Obtentor__r.BillingAddress, 
                                        Cuenta_Obtentor__r.Name,
                                        Firmante_Licencia__c,
                                        Firmante_First_Name__c,
                                        Firmante_Last_Name__c,
                                        Firmante_Cuit__c,
                                        Firmante_Celular__c,
                                        Firmante_Cargo__c,
                                        Direccion_Fiscal_Firmante__c,
                                        Localidad__c,
                                        Codigo_Postal_Firmante__c,
                                        Provincia_Firmante__c,
                                        Cuenta_Productor__r.Name,
                                        Cuenta_Productor__r.ERPvs__Direccion__c,
                                        Cuenta_Productor__r.ERPvs__Localidad__c,
                                        Cuenta_Productor__r.ERPvs__Codigo_Postal__c,
                                        Cuenta_Productor__r.Provincia_Facturacion__c,
                                        Cuenta_Productor__r.N_Cuit__c
                                FROM Licencia__c 
                                WHERE Id = :licenciaId]; 
        return JSON.serialize(licencia);
    }

    public void init(Map<String, String> parameters){
        if (parameters.get('id') != null) licencia = (Licencia__c) JSON.deserialize(serializeLicencia(parameters.get('id')), SObject.class);
        else licencia = (Licencia__c) JSON.deserialize(parameters.get('licencia'), SObject.class);
    }

    public String getAddressAndDate(){
        return licencia.Localidad__c + ', ' + dateToText(licencia.Created__c);
    }

    public String getTodayDate(){
        Date today = Date.today();
        return dateToText(today);
    }

    public Boolean getIsCuil(){
        return licencia.Cuenta_Productor__r.N_CUIT__c.substring(0,1) == '2';
    }

    /*public String getLocalidad(){
        return licencia.Cuenta_Productor__r.ERPvs__Localidad__c + ' - C.P.' + licencia.Cuenta_Productor__r.ERPvs__Codigo_Postal__c;
    }*/

    public String getNameFirmante(){
        return licencia.Firmante_First_Name__c + ' ' + licencia.Firmante_Last_Name__c;
    }

    public String getDomicilioCompleto(){
        return licencia.Direccion_Fiscal_Firmante__c + ' ' + licencia.Localidad__c + ' - C.P.' + licencia.Codigo_Postal_Firmante__c + ' ' + licencia.Provincia_Firmante__c;
    }

    private String dateToText(Date fecha){
        List<String> meses = new List<String>{'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'};
        return fecha.day() + ' de ' + meses[fecha.month() - 1] + ' de ' + fecha.year();
    }
}