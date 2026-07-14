public without sharing class ReprocesarVentasInformadasController {
    
    private ApexPages.StandardSetController setCon;

    private Integer selectedRecordsAmount;
    private Integer elegiblesParaReprocesar;
    private Integer omitidosPorVentaAsociada;

    public Integer getSelectedRecordsAmount() {
        return selectedRecordsAmount != null ? selectedRecordsAmount : setCon.getSelected().size();
    }

    public Integer getElegiblesParaReprocesar() {
        return elegiblesParaReprocesar != null ? elegiblesParaReprocesar : 0;
    }

    public Integer getOmitidosPorVentaAsociada() {
        return omitidosPorVentaAsociada != null ? omitidosPorVentaAsociada : 0;
    }

    public String getReturnUrl() {
        return VentasInformadasMassActionUtil.getReturnUrl();
    }

    public PageReference cancel() {
        return VentasInformadasMassActionUtil.redirectToReturnUrl();
    }

    public ReprocesarVentasInformadasController(ApexPages.StandardSetController stdController) {
        this.setCon = stdController;
        calcularResumenSeleccion();
    }

    public PageReference reprocesar() {
        Map<Id, Ventas_Informadas__c> ventasSeleccionadas = new Map<Id, Ventas_Informadas__c>(
            (List<Ventas_Informadas__c>) setCon.getSelected()
        );

        if (ventasSeleccionadas.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'No hay registros seleccionados. Volvé al listado, seleccioná ventas informadas y usá Reprocesar.'
            ));
            return null;
        }

        Set<Id> idsElegibles = new Set<Id>();
        for (Ventas_Informadas__c vi : [
            SELECT Id
            FROM Ventas_Informadas__c
            WHERE Id IN :ventasSeleccionadas.keySet()
                AND Venta__c = null
        ]) {
            idsElegibles.add(vi.Id);
        }

        if (idsElegibles.isEmpty()) {
            ApexPages.addMessage(new ApexPages.Message(
                ApexPages.Severity.ERROR,
                'Ninguno de los ' + ventasSeleccionadas.size()
                    + ' registros seleccionados puede reprocesarse porque ya tienen una Venta asociada.'
            ));
            return null;
        }

        Id batchId = Database.executeBatch(
            new BatchApexProcesaVentasInformadas(idsElegibles, true),
            200
        );

        Integer omitidos = ventasSeleccionadas.size() - idsElegibles.size();
        String title = 'Reprocesar Ventas Informadas';
        if (omitidos > 0) {
            title += ' (' + idsElegibles.size() + ' de ' + ventasSeleccionadas.size() + ')';
        }

        return new PageReference(
            '/lightning/cmp/c__batchApexMonitorContainer?c__navigateToList=Ventas_Informadas__c' +
            '&c__batchId=' + batchId +
            '&c__title=' + EncodingUtil.urlEncode(title, 'UTF-8')
        );
    }

    @TestVisible
    private void calcularResumenSeleccion() {
        List<Ventas_Informadas__c> seleccionados = setCon.getSelected();
        selectedRecordsAmount = seleccionados.size();
        if (selectedRecordsAmount == 0) {
            elegiblesParaReprocesar = 0;
            omitidosPorVentaAsociada = 0;
            return;
        }

        Set<Id> ids = new Map<Id, Ventas_Informadas__c>(seleccionados).keySet();
        elegiblesParaReprocesar = [
            SELECT COUNT()
            FROM Ventas_Informadas__c
            WHERE Id IN :ids AND Venta__c = null
        ];
        omitidosPorVentaAsociada = selectedRecordsAmount - elegiblesParaReprocesar;
    }
}