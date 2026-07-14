import { api, LightningElement, wire } from 'lwc';
import getData from '@salesforce/apex/GraficoObtentor.getData';

export default class GraficoObtentor extends LightningElement {

    @api cssStyle;
    @api recordId;

    gridData;

    gridColumns = [
        {
            type: 'text',
            fieldName: 'campana',
            label: 'Campaña Agricola',
        },
        {
            type: 'text',
            fieldName: 'obtentor',
            label: 'Obtentor',
        },
        {
            type: 'text',
            fieldName: 'variedad',
            label: 'Variedad',
        },
        {
            type: 'number',
            fieldName: 'sumaBolsasUP',
            label: 'UP Bolsas 50Kg',
        },
        {
            type: 'number',
            fieldName: 'sumaBolsasSF',
            label: 'SF Bolsas 40Kg',
        },
        {
            type: 'number',
            fieldName: 'cantidad',
            label: '# Total SF y UP (kgs)',
        },
    ];

    renderedCallback() {
        if (!this.init) {
            this.init = true;
            getData({accountId: this.recordId}).then(d => this.gridData = JSON.parse(JSON.stringify(d).replaceAll('children','_children'))).catch(e => this.error = e);
        }
    }
}