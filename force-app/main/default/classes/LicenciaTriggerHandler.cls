public class LicenciaTriggerHandler {
    public static void run() {
        if (Trigger.isUpdate) {
            generatePDF((List<Licencia__c>) Trigger.new, (Map<Id, Licencia__c>) Trigger.oldMap);
        }
    }

    public static void generatePDF(List<Licencia__c> licencias, Map<Id, Licencia__c> old) {
        List<Id> licenciasRequierenCartaAceptacion = new List<Id>();

        for (Licencia__c licencia: licencias) {
            if (licencia.Estado__c == 'Licencia Firmada' && old.get(licencia.id).Estado__c != licencia.Estado__c && licencia.Origen_SGL__c == false && licencia.Origen__c != 'SGL' && licencia.Emite_Carta_de_Aceptacion__c == true) {
                licenciasRequierenCartaAceptacion.add(licencia.id);
            }
        }

        if(!licenciasRequierenCartaAceptacion.isEmpty()) {
            generatePDF(licenciasRequierenCartaAceptacion);
        }    
    }

    @Future(callout=true)
    public static void generatePDF(List<iD> licenciaIds) {
        SolicitarLicencia.generarPDFCartaAceptacion([select id, name, Origen_SGL__c, Origen__c from Licencia__c where id in: licenciaIds]);
    }
}