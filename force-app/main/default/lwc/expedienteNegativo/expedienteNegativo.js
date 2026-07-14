import { LightningElement } from 'lwc';
import searchAccounts from '@salesforce/apex/ExpedienteNegativo.searchAccounts';
import getExpedienteNegativosByAccountId from '@salesforce/apex/ExpedienteNegativo.getExpedienteNegativosByAccountId';
import { doRequest, errorEvent } from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ExpedienteNegativo extends LightningElement {

    cuenta;
    expediente;

    async cuentaSelected(event){
        const selection = event.target.getSelection();
        this.cuenta = selection.length ? selection[0].record : null;
        if(this.cuenta){
            await doRequest.call(this, async _=> {
                this.expediente = await getExpedienteNegativosByAccountId({cuentaId: this.cuenta.Id});
                console.log(this.expediente);
            });
        }
    }

    async search(event) {
        const lookup = event.target;
        await searchAccounts(event.detail).then(res => {
            lookup.setSearchResults(res);
        }).catch(e => this.onError(e));
    }

    showMessage(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({title, message, variant}));
    }

    onError(error){
        this.dispatchEvent(errorEvent(error));
    }
}