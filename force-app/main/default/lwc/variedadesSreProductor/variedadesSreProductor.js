import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getVariedadesSRE from '@salesforce/apex/VariedadesSREProductor.getVariedadesSRE';
import searchAccounts from '@salesforce/apex/VariedadesSREProductor.searchAccounts';
import getVariedadesSREProductor from '@salesforce/apex/VariedadesSREProductor.getVariedadesSREProductor';
import doSave from '@salesforce/apex/VariedadesSREProductor.doSave';
import title from '@salesforce/label/c.Variedades_SRE_Productor_1';
import selectOptions from '@salesforce/label/c.Variedades_SRE_Productor_2';
import source from '@salesforce/label/c.Variedades_SRE_Productor_3';
import selected from '@salesforce/label/c.Variedades_SRE_Productor_4';
import lookup from '@salesforce/label/c.Variedades_SRE_Productor_5';
import { doRequest, errorEvent } from 'c/utils';
export default class VariedadesSreProductor extends LightningElement {

    productor;
    variedades;
    seleccionadas = [];

    labels = {
        title,
        selectOptions,
        source,
        selected,
        lookup
    };

    initialized = false;
    loading = false;

    init(){
        this.initialized = true;

        doRequest.call(this, async _ => {
            const variedades = await getVariedadesSRE();
            console.log('variedades: ', variedades);
            this.variedades = variedades.map(v => ({label: v.Name, value: v.Id}));
        });
    }

    async search(event) {
        const lookup = event.target;
        await searchAccounts(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    async productorSelected(event){
        const selection = event.target.getSelection();
        this.productor = selection.length ? selection[0].record : null;
        console.log(this.productor);
        if(this.productor){
            await doRequest.call(this, async _ =>{
                const variedadesProductor = await getVariedadesSREProductor({productorId: this.productor.Id});
                console.log('variedadesProductor: ', variedadesProductor);
                this.seleccionadas = variedadesProductor.map(vp => vp.Variedad__c);
                console.log(this.seleccionadas);
            });
        }else{
            this.seleccionadas = null;
        }
    }

    async save(){
        if(this.productor == null){
            this.onError(new Error('Tiene que seleccionar una cuenta'));
            return;
        }

        await doRequest.call(this, async _=>{
            await doSave({productorId: this.productor.Id, variedadesIds: this.seleccionadas});
            this.dispatchEvent(new ShowToastEvent({message: 'Configuración guardada con éxito', variant: 'success'}))
        });
    }

    variedadSelected(event){
        this.seleccionadas = event.detail.value;
        console.log(this.seleccionadas);
    }

    renderedCallback(){
        if(!this.initialized) this.init();
    }

    onError(error){
        this.dispatchEvent(errorEvent(error));
    }

    get disableListbox(){
        return this.productor == null;
    }
}