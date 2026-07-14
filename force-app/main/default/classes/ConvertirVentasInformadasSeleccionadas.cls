public with sharing class ConvertirVentasInformadasSeleccionadas {
    private ApexPages.StandardSetController setCon;

    public Integer getSelectedRecordsAmount() {
        return setCon.getSelected().size();
    }

    public ConvertirVentasInformadasSeleccionadas(ApexPages.StandardSetController stdController) {
        this.setCon = stdController;
    }

    public PageReference procesar() {
        Lote__c lote = ConvertirVentasInformadasController.getLote();
        insert lote;

        Id batchId = Database.executeBatch(new BatchApexConvertirVentasInformadas(lote, new Map<Id, Ventas_Informadas__c>((List<Ventas_Informadas__c>) setCon.getSelected()).keySet()),1000);

        return new PageReference('/lightning/cmp/c__batchApexMonitorContainer?c__navigateToSobject='+lote.Id+'&c__batchId='+batchId+'&c__title=Convertir Ventas Informadas en Ventas');

    }
}