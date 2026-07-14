import { api, LightningElement, track } from 'lwc';
import saveItem from '@salesforce/apex/CrearVentaController.saveItem';
import deleteItem from '@salesforce/apex/CrearVentaController.deleteItem';
import searchVariedades from '@salesforce/apex/CrearCompraController.searchVariedades';
import { LineaCompraVentaMixin } from 'c/utilsHT';
import { NavigationMixin } from 'lightning/navigation';

export default class CrearLineaVentaNew extends LineaCompraVentaMixin(LightningElement) {

    @api loadingSppiner = false;
    @api tipoCompraSeleccionado;
    @api preCampaign;
    @api isFuturaFlag;
    @track selectedValue;
    @track precioLista = 0;
    @track isGlobalLoading = false;
    @track loading = false;

    get isFutura() {
        if (this.isFuturaFlag !== undefined) {
            return this.isFuturaFlag;
        }
        return this.preCampaign === 'Futura';
    }

    variedadChange(event) {
        const selection = event.target.getSelection();
        this.variedad = selection.length ? selection[0].record.Id : null;

        if (this.tipoCompraSeleccionado) {
            this.preCampaign = this.tipoCompraSeleccionado;
            const dt = new Date();
            this.record.Fecha_de_Activacion__c = this.preCampaign === 'Disponible'
                ? dt.getFullYear() + '-' + ('0' + (dt.getMonth() + 1)).slice(-2) + '-' + ('0' + dt.getDate()).slice(-2)
                : this.getFechaActivacion();
        } else {
            this.preCampaign = null;
        }

        this.productChange();
        this.dispatchPromoLineChange(false, false);
        this.dispatchEvent(new CustomEvent('tipohtchange', {
            detail: { isFutura: this.preCampaign === 'Futura' },
            bubbles: true,
            composed: true
        }));
    }

    syncCantidad(event) {
        super.syncCantidad(event);
        this.dispatchEvent(new CustomEvent('cantidadchange', { bubbles: true, composed: true }));
    }

    deleteItem(recordId) {
        return deleteItem({ itemId: this._record.Id, ventaId: recordId });
    }

    async saveItem(recordId, cultivo, productorId) {
        this.loadingSppiner = true;
        const record = await saveItem({
            ventaId: recordId,
            itemJson: JSON.stringify(this._record),
            productorId,
            cultivo
        });

        this.dispatchEvent(new CustomEvent('record', { detail: record }));
        this.loadingSppiner = false;
        this.loading = false;
        this.isGlobalLoading = true;
    }

    async searchVariedades(event) {
        const lookup = event.target;
        await searchVariedades({
            searchTerm: event.detail.searchTerm,
            selectedIds: event.detail.selectedIds,
            disponiblesIds: this.priceBookEntries.reduce((ids, p) => [...ids, p.record.Product2.Variedad2__c], [])
        })
        .then(res => lookup.setSearchResults(res))
        .catch(e => this.onError(e));
    }

    redirectMisLicencias() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'consulta-de-licencias-del-productor',
            }
        });
    }

    handleLoadingChange(event) {
        this.isGlobalLoading = event.detail.isLoading;
    }
}