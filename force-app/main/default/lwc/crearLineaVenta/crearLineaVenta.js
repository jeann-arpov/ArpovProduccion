import { api, LightningElement, track } from 'lwc';
import saveItem from '@salesforce/apex/CrearVentaController.saveItem'; 
import deleteItem from '@salesforce/apex/CrearVentaController.deleteItem'; 
import searchVariedades from '@salesforce/apex/CrearCompraController.searchVariedades';
import { LineaCompraVentaMixin } from 'c/utilsHT';
import { NavigationMixin } from 'lightning/navigation';

export default class CrearLineaVenta extends LineaCompraVentaMixin(LightningElement) {

    @api loadingSppiner = false;
    @track selectedValue;
    @track isModalOpen = false;
    @track precioLista = 0;
    //@track tipoFinanciamiento;

    // comercio
   /* get tiposDePago() {
        return [
            { label: 'Contado', value: 'Contado' },
            { label: 'Financiado', value: 'Financiado' }
        ];
    }*/

    get isFutura() {
        if (this.isFuturaFlag !== undefined) {
            return this.isFuturaFlag;
        }
        return this.preCampaign === 'Futura';
    }

    get momentoEntregaCompleto() {
        return this.preCampaign != null && this.preCampaign !== '';
    }

    /*
    get tipoFinanciamientoCompleto() {
        return this._record?.Tipo_de_Pago__c != null && this._record.Tipo_de_Pago__c !== '';
    }

    get camposFinanciamientoCompletos() {
        if (this.isFutura) {
            return this.momentoEntregaCompleto && this.tipoFinanciamientoCompleto;
        }
        return this.momentoEntregaCompleto;
    }

    get camposFinanciamientoIncompletos() {
        return !this.camposFinanciamientoCompletos;
    }*/

    deleteItem(recordId) {
        console.log('[CrearLineaVenta] deleteItem()', { recordId, _record: this._record });
        return deleteItem({ itemId: this._record.Id, ventaId: recordId });
    }

    async saveItem(recordId, cultivo, productorId) {
        console.log('[CrearLineaVenta] saveItem()', { recordId, cultivo, productorId, _record: this._record });

        this.loadingSppiner = true;
        const record = await saveItem({
            ventaId: recordId,
            itemJson: JSON.stringify(this._record),
            productorId,
            cultivo
        });

        if (record.record && record.record.Lineas_de_Venta_HT__r) {
            console.log('[DEBUG] Lineas from response:', record.record.Lineas_de_Venta_HT__r.map(l => ({
                Id: l.Id,
                Tipo_de_Pago__c: l.Tipo_de_Pago__c
            })));
        }
        this.dispatchEvent(new CustomEvent('record', { detail: record }));
        console.log('[CrearLineaVenta] saveItem() -> finalizado OK');
        this.loadingSppiner = false;
        this.loading = false;
        this.isGlobalLoading = true;
    }

    async searchVariedades(event) {
        console.log('[CrearLineaVenta] searchVariedades()', { detail: event.detail, priceBookEntries: this.priceBookEntries });
        const lookup = event.target;
        await searchVariedades({
            searchTerm: event.detail.searchTerm,
            selectedIds: event.detail.selectedIds,
            disponiblesIds: this.priceBookEntries.reduce((ids, p) => [...ids, p.record.Product2.Variedad2__c], [])
        })
        .then(res => {
            console.log('[CrearLineaVenta] searchVariedades() -> resultados', res);
            lookup.setSearchResults(res);
        })
        .catch(e => this.onError(e));
    }

    redirectMisLicencias() {
        console.log('[CrearLineaVenta] redirectMisLicencias()');
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { pageName: 'consulta-de-licencias-del-productor' }
        });
    }

    handleLoadingChange(event) {
        const { isLoading, source, index } = event.detail;
        console.log(`Loading de ${source} en índice ${index}: ${isLoading}`);
        this.isGlobalLoading = isLoading;
    }

    /*
    tipoFinanciamientoChange(event) {
        const newValue = event.target.value;
        this._record = { ...this._record, Tipo_de_Pago__c: newValue }; // << clave
        this.tipoFinanciamiento = newValue;
        console.log('Valor seleccionado:', this._record.Tipo_de_Pago__c);
        this.updatePriceBasedOnTipoCompra();
        this.openModal(newValue);
        this.checkAutoSave();
    }

    openModal(value) {
        this.selectedValue = value;
        if (this.selectedValue === 'Contado') {
            this.isModalOpen = true;
        }
    }

    closeModal() {
        this.isModalOpen = false;
    }*/
}