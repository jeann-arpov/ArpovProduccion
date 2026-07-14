import { LightningElement, api, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getLicenciasByProductor from '@salesforce/apex/LicenciasRelacionadasController.getLicenciasByProductor';

// Ajusta estos imports al objeto real
import EXPEDIENTE_OBJECT from '@salesforce/schema/Expediente_de_Negativos__c';
import CUIT_FIELD from '@salesforce/schema/Expediente_de_Negativos__c.CUIT_cliente__c';

const FIELDS = [CUIT_FIELD];

export default class LicenciasRelacionadas extends LightningElement {
    @api recordId;

    licencias = [];
    error;
    isLoading = true;

    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredExpediente({ data, error }) {
        if (data) {
            const productor = getFieldValue(data, CUIT_FIELD);
            this.fetchLicencias(productor);
        } else if (error) {
            this.error = error;
            this.isLoading = false;
        }
    }

    async fetchLicencias(productor) {
        this.isLoading = true;
        this.error = undefined;
        try {
            const result = await getLicenciasByProductor({ CUIT_cliente: productor });
            this.licencias = result;
        } catch (err) {
            this.error = err;
            this.licencias = [];
        } finally {
            this.isLoading = false;
        }
    }

    get hasLicencias() {
        return this.licencias && this.licencias.length > 0;
    }

    get columns() {
        return [
            { label: 'Código Licencia', fieldName: 'codigoLicencia' },
            { label: 'Semillero', fieldName: 'semillero' },
            { label: 'Tipo Licencia', fieldName: 'tipoLicencia' },
            { label: 'Estado', fieldName: 'estado' },
            { label: 'Mail', fieldName: 'mail' },
            { label: 'Firmante Celular', fieldName: 'firmanteCelular' }
        ];
    }
}