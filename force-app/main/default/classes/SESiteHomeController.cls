public with sharing class SESiteHomeController {
    public SESiteHomeController(ApexPages.StandardController cnt) {

    }

    public Boolean getIsAdherido() {
        Id acc = CrearCompraController.getAccount().Id;
        return [select id from Plan_de_siembra__c where Productor__c =: acc].size() > 0;
    }
}