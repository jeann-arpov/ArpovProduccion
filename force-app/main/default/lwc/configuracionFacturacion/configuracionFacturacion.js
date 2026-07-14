import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchAccounts from '@salesforce/apex/ConfiguracionFacturacion.searchAccounts';
import getData from '@salesforce/apex/ConfiguracionFacturacion.getData';
import doSave from '@salesforce/apex/ConfiguracionFacturacion.doSave';
import doDelete from '@salesforce/apex/ConfiguracionFacturacion.doDelete';

import { doRequest, errorEvent, warningEvent } from 'c/utils';

const COLUMNS = [
    {label: 'Nombre de Cuenta', fieldName: 'cuenta'},
    {label: 'N° CUIT', fieldName: 'cuit'},
    {label: 'Marca', fieldName: 'marca'},
    {label: 'Ultima Modificación', fieldName: 'lastModifiedDate', type: 'date', typeAttributes:{year: "numeric", month: "2-digit",day: "2-digit",hour: "2-digit", minute: "2-digit"}}
];


export default class ConfiguracionFacturacion extends NavigationMixin(LightningElement) {

    account;

    cuentasPv;
    columns = COLUMNS;
    marcas;

    cuenta;
    marca;

    selectedConfig;

    initialized = false;
    loading = false;

    init(){
        this.initialized = true;

        this.doRequest = doRequest.bind(this);

        this.getData(true);
    }
    
    getData(isFirstLoad){        
        this.doRequest(async _ => {
            const data = await getData({isFirstLoad});
            if(isFirstLoad){
                this.marcas = data.marcas;
                this.account = data.cuenta;
            }

            this.cuentasPv = data.cuentasPv.map(pv => {
                return {
                    id: pv.Id, 
                    cuentaId: pv.Cuenta__c, 
                    cuenta: pv.Cuenta__r.Name, 
                    marcaId: pv.Marca__c, 
                    marca: pv.Marca__r.Nombre_Obtentor__c, 
                    cuit: pv.Cuenta__r.N_CUIT__c, 
                    lastModifiedDate: pv.LastModifiedDate, 
                    puntoVenta: pv.Punto_de_Venta__c
                };
            });
        });
    }

    renderedCallback(){
        if(this.initialized == false) this.init();
    }

    cuentaSelected(event){
        const selection = event.target.getSelection();
        this.cuenta = selection.length ? selection[0] : null;
        if(this.marca) this.autoSetConfig();
    }

    marcaSelected(event){
        this.marca = event.detail.value;
        if(this.cuenta) this.autoSetConfig();
    }

    configSelected(event){
        const selection = event.detail.value;
        this.selectedConfig = selection;
    }

    autoSetConfig(){
        const configPv = this.cuentasPv.find(pv => pv.cuentaId == this.cuenta.record.Id && pv.marcaId == this.marca);
        this.selectedConfig = configPv ? 'pv' : 'co'; 
        const options = this.refs.options;
        options.setValue(this.selectedConfig);
    }

    async search(event) {
        const lookup = event.target;
        await searchAccounts(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    onError(error){
        this.dispatchEvent(errorEvent(error));
    }

    async save(){
        if(!this.cuenta){
            this.dispatchEvent(warningEvent(new Error('Debe seleccionar una cuenta')));
            return;
        }
        if(!this.marca){
            this.dispatchEvent(warningEvent(new Error('Debe seleccionar una marca')));
            return;
        }

        await this.doRequest(async _ => {
            const pvConfig = this.cuentasPv.find(pv => pv.cuentaId == this.cuenta.record.Id && pv.marcaId == this.marca);
            if(this.puntoVenta == false){
                if(!pvConfig){
                    this.dispatchEvent(warningEvent(new Error('La cuenta y marca seleccionadas ya están configuradas para facturar por cuenta y orden')));
                    return;
                }
                await doDelete({pvConfigId: pvConfig.id});
            }else{
                if(pvConfig){
                    this.dispatchEvent(warningEvent(new Error('La cuenta y marca seleccionadas ya están configuradas para facturar por punto de venta')));
                    return;
                }
                await doSave({cuentaId: this.cuenta.record.Id, marcaId: this.marca});
            }

            this.dispatchEvent(new ShowToastEvent({message: 'Configuración guardada con éxito', variant: 'success'}));
            this.getData(false);
        });
    }

    cancel(){
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home'
            },
        });
    }

    get options(){
        return [
            {label: 'Facturación por cuenta y orden', value: 'co'},
            {label: 'Facturación por punto de venta', value: 'pv'}
        ];
    }

    get selectedOption(){
        return this.puntoVenta == false ? 'co' : 'pv';
    }

    get puntoVenta(){
        return this.selectedConfig == 'pv';
    }
}