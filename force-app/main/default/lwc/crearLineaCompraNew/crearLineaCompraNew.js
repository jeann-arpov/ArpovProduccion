import { LightningElement, track, api } from 'lwc';
import saveItem from '@salesforce/apex/CrearCompraController.saveItem';
import deleteItem from '@salesforce/apex/CrearCompraController.deleteItem';
import searchVariedades from '@salesforce/apex/CrearCompraController.searchVariedades';
import { LineaCompraVentaMixin } from 'c/utilsHT';

export default class CrearLineaCompraNew extends LineaCompraVentaMixin(LightningElement) {
    @api loadingSppiner = false;
    @api tipoCompraSeleccionado;
    @track selectedValue;
    @track isModalOpen = false;
    @track precioLista = 0;

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
        return deleteItem({ itemId: this._record.Id, compraId: recordId });
    }

    async saveItem(recordId, cultivo) {
        const record = await saveItem({
            compraId: recordId,
            itemJson: JSON.stringify(this._record),
            cultivo
        });
        this.dispatchEvent(new CustomEvent('record', { detail: record }));
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

    closeModal() {
        this.isModalOpen = false;
    }
}