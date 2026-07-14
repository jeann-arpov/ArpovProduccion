import { LightningElement } from 'lwc';
import getLoadData from '@salesforce/apex/CuentaGranaria.getLoadData';
import getHectareasTecnologicas from '@salesforce/apex/ComprasHTController.getHectareasTecnologicas';
import {reduceErrors} from 'c/utils';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

import IMAGENES from '@salesforce/resourceUrl/CuentaGranariaIcons';

const columns = [
    {
        type: 'text',
        fieldName: 'cultivo',
        label: 'Cultivo'
    },
    {
        type: 'text',
        fieldName: 'biotecnologia',
        label: 'Biotecnología'
    },
    {
        type: 'text',
        fieldName: 'comercio',
        label: 'Comercio'
    },
    {
        type: 'date-local',
        fieldName: 'fechaTransaccion',
        label: 'Fecha Transacción',
        typeAttributes: {
            year: "numeric",
            day: "2-digit",
            month: "2-digit"
        }
    },
    {
        type: 'number',
        fieldName: 'debito',
        label: 'Débito'
    },
    {
        type: 'number',
        fieldName: 'credito',
        label: 'Crédito'
    },
    {
        type: 'text',
        fieldName: 'origen',
        label: 'Origen'
    }/*,
    {
        type: 'text',
        fieldName: 'nombre',
        label: 'Nombre HT'
    },
    {
        type: 'text',
        fieldName: 'obtentor',
        label: 'Nombre Obtentor'
    },
    {
        type: 'text',
        fieldName: 'variedad',
        label: 'Variedad'
    },
    {
        type: 'text',
        fieldName: 'nroComprobante',
        label: 'Nro Comprobante'
    }*/
]

export default class ComprasHT extends NavigationMixin(LightningElement) {
    initialized = false;
    processing = true;
    hectareasTecnologicas = [];
    groups = [];
    columns = columns;
    total = 0;
    cultivos;
    cultivoId;

    iconoCultivo = IMAGENES + '/cultivo.svg';

    get paramCultivo(){
        const parametro = new URL(window.location.href).searchParams.get("cultivoId");
        return parametro;
    }

    async init() {
        this.initialized = true;
        
        try {
            const data = await getLoadData();
            this.cultivos = data.cultivos.map(c => ({label: c.Name, value: c.Id}));
            if(this.paramCultivo){
                this.cultivoId = this.paramCultivo;
                await this.getHTs();
            }
        } catch (e) {
            this.onError(e);
        }

        this.processing = false;
    }

    selectCultivo(event){
        this.cultivoId = event.detail.value;
        this.getHTs();
    }

    async getHTs(){
        this.processing = true;
        try {
            this.hectareasTecnologicas = await getHectareasTecnologicas({cultivoId: this.cultivoId});
            this.updateGroups();
        } catch (e) {
            this.onError(e);
        }
        this.processing = false;
    }
    
    renderedCallback() {
        if (!this.initialized) this.init();
    }

    updateGroups() {
        const groups = {};

        for (const record of this.hectareasTecnologicas) {
            const key = record.biotecnologia + ',' + record.cultivo + ',' + record.fechaTransaccion + ',' + record.origen;
            groups[key] = groups[key] || [];
            groups[key].push(record);
        }

        this.groups = Object.values(groups).map(group => {
            const data = {origen: group[0].origen, id: group[0].id, comercio: group[0].comercio, cultivo: group[0].cultivo, biotecnologia: group[0].biotecnologia, fechaTransaccion: group[0].fechaTransaccion, debito: group.reduce((a, b) => a + (b.debito || 0), 0), credito: group.reduce((a, b) => a + (b.credito || 0), 0)}
            //if (group.length > 1) data._children = group;
            console.log(data,group)
            return data;
        });

        console.log(JSON.stringify(this.groups))
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }

    get totalPorBiotecnologia() {
        const groups = {};
        this.total = 0

        for (const vencimiento of this.hectareasTecnologicas) {
            const key = vencimiento.biotecnologia;
            groups[key] = groups[key] || {key: vencimiento.biotecnologia, value: 0};
            groups[key].value += vencimiento.credito || 0;
            this.total += vencimiento.credito || 0;
        }

        return Object.values(groups);
    }

    viewRecord(event) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                "recordId": event.target.value,
                "objectApiName": "Hectareas_Tecnologicas__c",
                "actionName": "view"
            },
        });
    }
}