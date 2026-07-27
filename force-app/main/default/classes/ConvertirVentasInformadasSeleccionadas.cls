public with sharing class ConvertirVentasInformadasSeleccionadas {
    private ApexPages.StandardSetController setCon;

    public Integer getSelectedRecordsAmount() {
        return setCon.getSelected().size();
    }

    public ConvertirVentasInformadasSeleccionadas(ApexPages.StandardSetController stdController) {
        this.setCon = stdController;
    }

    public PageReference cancel() {
        return VentasInformadasMassActionUtil.redirectToReturnUrl();
    }

    public PageReference procesar() {
        Set<Id> idsSeleccionados = new Map<Id, Ventas_Informadas__c>(
            (List<Ventas_Informadas__c>) setCon.getSelected()
        ).keySet();

        // Checkbox en el registro → Tipo Material + Producto Family Regalía Comercial.
        VentasInformadasTipoMaterialUtil.aplicarDesdeCheckbox(idsSeleccionados);

        Lote__c lote = ConvertirVentasInformadasController.getLote();
        insert lote;

        Id batchId = Database.executeBatch(
            new BatchApexConvertirVentasInformadas(lote, idsSeleccionados),
            1000
        );

        return new PageReference(
            '/lightning/cmp/c__batchApexMonitorContainer?c__navigateToSobject=' + lote.Id
                + '&c__batchId=' + batchId
                + '&c__title=Convertir Ventas Informadas en Ventas'
        );
    }
}
