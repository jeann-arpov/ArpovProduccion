public with sharing class ConvertirVentasInformadasController {
    
    private ApexPages.StandardSetController setCon;

    public ConvertirVentasInformadasController(ApexPages.StandardSetController stdController) {
        this.setCon = stdController;
    }

    public static Lote__c getLote() {
        Lote__c lote = new Lote__c();

        lote.Descripcion__c = 'Generacion Ventas a Partir de Ventas Informadas ' + String.valueOf(Date.today());
        lote.Tipo__c = 'Ventas';
        lote.Tipo_de_Lote__c = 'Ventas';

        return lote;
    }

    public PageReference procesar() {
        Lote__c lote = getLote();
        insert lote;

        Id batchId = Database.executeBatch(new BatchApexConvertirVentasInformadas(lote),1000);

        return new PageReference('/lightning/cmp/c__batchApexMonitorContainer?c__navigateToSobject='+lote.Id+'&c__batchId='+batchId+'&c__title=Convertir Ventas Informadas en Ventas');

    }


}