import { LightningElement, track,api } from 'lwc';
import saveItem from '@salesforce/apex/CrearCompraController.saveItem'; 
import deleteItem from '@salesforce/apex/CrearCompraController.deleteItem'; 
import searchVariedades from '@salesforce/apex/CrearCompraController.searchVariedades';
import {LineaCompraVentaMixin} from 'c/utilsHT';


export default class CrearLineaCompra extends LineaCompraVentaMixin(LightningElement) {
    @api loadingSppiner = false;
    @track selectedValue;
    @track isModalOpen = false;
    @track precioLista = 0;
    //@track tipoFinanciamiento;


    
    /*get tiposDePago() {
        return [
            { label: 'Contado', value: 'Contado' },
            { label: 'Financiado', value: 'Financiado' }
        ];
    }*/
    get isFutura() {
        return this.preCampaign === 'Futura';
    }
    deleteItem(recordId) {
        return deleteItem({itemId: this._record.Id, compraId: recordId});
    }

    async saveItem(recordId, cultivo,productorId) {
        console.log('[CrearLineaCompra] saveItem()', { recordId, cultivo, productorId, _record: this._record });
        console.log('[DEBUG] Tipo_de_Pago__c BEFORE saving:', this._record.Tipo_de_Pago__c);
        const record = await saveItem({compraId: recordId, itemJson: JSON.stringify(this._record), cultivo});
        console.log('[DEBUG] RESPONSE from server:', JSON.stringify(record));
        console.log('[DEBUG] record.record:', JSON.stringify(record.record));
    
        // returned data has the Tipo_de_Pago__c
        if (record.record && record.record.Lineas_de_Compra_HT__r) {
            console.log('[DEBUG] Lineas from response:', record.record.Lineas_de_Compra_HT__r.map(l => ({
                Id: l.Id, 
                Tipo_de_Pago__c: l.Tipo_de_Pago__c
            })));
        }
        this.dispatchEvent(new CustomEvent('record', {detail:record}));
        console.log('[CrearLineaCompra] saveItem() -> finalizado OK');
        console.log('[CrearLineaCompra] saveItem() -> finalizado OK , valor de tipo de pago:',this._record.Tipo_de_Pago__c);
    }

    async searchVariedades(event){
        const lookup = event.target;
        await searchVariedades({searchTerm: event.detail.searchTerm, selectedIds: event.detail.selectedIds, disponiblesIds: this.priceBookEntries.reduce((ids, p) => [...ids, p.record.Product2.Variedad2__c],[])}).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    tipoFinanciamientoChange(event) {
        const newValue = event.target.value;
        this._record.Tipo_de_Pago__c = newValue;
        console.log('Valor seleccionado:',this._record.Tipo_de_Pago__c);
        this.updatePriceBasedOnTipoCompra();
        this.checkAutoSave();
        this.openModal(newValue);
    }
    openModal(value) {
    this.selectedValue = value;

        if (this.selectedValue === 'Contado') {
            this.isModalOpen = true;
        }
    }
    closeModal() {
      this.isModalOpen = false;
    }
    
}