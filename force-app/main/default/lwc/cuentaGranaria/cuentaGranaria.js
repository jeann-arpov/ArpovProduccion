import { LightningElement } from 'lwc';
import getAdhesion from '@salesforce/apex/CuentaGranaria.getAdhesion';
import getToneladas from '@salesforce/apex/CuentaGranaria.getToneladas';
import getLoadData from '@salesforce/apex/CuentaGranaria.getLoadData';
import getDetalleBT from '@salesforce/apex/CuentaGranaria.getDetalleBT';
import IMAGENES from '@salesforce/resourceUrl/CuentaGranariaIcons';
import { doRequest, errorEvent, warningEvent } from 'c/utils';

export default class CuentaGranaria extends LightningElement {

    cultivos;
    cultivo;
    toneladas;
    totales;
    adhesion;
    biotecnologia;

    tecnologias = {
        SOJA: [
            {label: 'Enlist / Conkesta', value: 'Enlist E3/Conkesta E3'}, {label: 'RR', value: 'RR1/RR2 - BT/Convencional'}
        ],
        TRIGO: [
            {label: 'Convencional', value: 'Convencional'}
        ],
        CEBADA: [
            {label: 'Convencional', value: 'Convencional'}
        ]
    }

    images = {
        cultivo: IMAGENES + '/cultivo.svg',
        tecnologia: IMAGENES + '/tecnologia.png',
        pph: IMAGENES + '/PPH.png'
    }

    initialized;
    loading = false;

    get paramCultivo(){
        const parametro = new URL(window.location.href).searchParams.get("cultivoId");
        return parametro;
    }

    init(){
        this.initialized = true;

        doRequest.call(this, async _ => {
            const data = await getLoadData();
            this.cultivos = data.cultivos;
            if(this.paramCultivo){
                this.cultivo = this.paramCultivo;
                this.verificarAdhesion();
            }
        });
    }

    selectCultivo(event){
        this.cultivo = event.detail.value;
        this.reset();
        this.verificarAdhesion();
    }
    
    verificarAdhesion(){        
        doRequest.call(this, async _ => {
            this.adhesion = await getAdhesion({cultivoId: this.cultivo});
            console.log(this.adhesion);
        });
    }

    selectTech(event){
        this.biotecnologia = event.detail.value;
        this.getData();
    }

    getData(){
        doRequest.call(this, async _ => {
            const results = await getToneladas({cultivoId: this.cultivo, tecnologias: this.biotecnologia});
            console.log(results);

            this.toneladas = results;

            const totales = {};

            for(const tn of results){
                let key = tn.Origen__c;
                if(key == 'Semilla Original' || key == 'Semilla Pre Básica') key = 'Compra SF';

                if(!totales[key] && ['Regalía Enlist', 'BolsaTech', 'Balance Anual'].includes(key) == false){
                    totales[key] = {label: this.origenLabels[key], value: 0, origen: key};
                }

                if(totales[key]) totales[key].value += tn.Cantidad_con_Signo__c;
            }

            for(const origen in this.origenLabels){
                if(['BolsaTech', 'Balance Anual'].includes(origen) == false && totales.hasOwnProperty(origen) == false){
                    totales[origen] = {label: this.origenLabels[origen], value: 0};
                }
            }

            console.log(totales);
            this.totales = Object.values(totales);
        });
    }

    descargarDetalle(event){
        const origen = event.currentTarget.dataset.name;

        const ids = this.toneladas.filter(tn => tn.Origen__c == origen).reduce((ids, tn) => [...ids, tn.Id], []);
        console.log(ids);

        if(ids.length){
            doRequest.call(this, async _ => {
                const result = await getDetalleBT({toneladasIds: ids});
                const downLink = document.createElement('a');
                downLink.href = 'data:text/csv;charset=utf-8,'+ encodeURI(result);
                downLink.target = '_blank';
                downLink.download = `detalle_toneladas_${origen}.csv`.toLowerCase().replace(' ', '_');
                downLink.click();
            });
        }else{
            this.dispatchEvent(warningEvent(new Error('No hay registros de toneladas para descargar')));
        }
    }

    reset(){
        this.totales = null;
        this.biotecnologia = null;
    }

    onError(e){
        this.dispatchEvent(errorEvent(e));
    }

    renderedCallback(){
        if(!this.initialized){
          this.init();  
        }
    }

    getTotal(origen){
        const value = this.toneladas.filter(tn => tn.Origen__c == origen).reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return {label: this.origenLabels[origen], value, origen: origen};
    }

    get totalBolsatech(){
        return this.getTotal('BolsaTech');
    }

    get totalBalanceAnual(){
        return this.getTotal('Balance Anual');
    }

    get totalRegaliaEnlistPagada(){
        const value = this.toneladas.filter(tn => tn.Origen__c == 'Regalía Enlist' && tn.Etapa__c == 'Cobrada').reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return {label: 'Regalía Enlist pagada', value, origen: 'Regalía Enlist'};
    }

    get totalTodo(){
        return this.totales.reduce((total, t) => total += t.value, 0) + this.totalBolsatech.value + this.totalBalanceAnual.value + this.totalRegaliaEnlistPagada.value;
    }

    get showFilterTech(){
        return this.cultivo && !this.adhesion;
    }

    get biotecnologias(){
        return this.tecnologias[this.cultivoOptions.find(c => c.value == this.cultivo).label];
    }

    get fechaVencimientoPPH(){
        return this.adhesion.Parametro_PPH__r.Fecha_Vencimiento_PPH__c;
    }

    get cultivoOptions(){
        return this.cultivos.map(c => ({label: c.Name, value: c.Id}));
    }

    get origenLabels(){
        return {
            'Compra SF': 'Semilla Fiscalizada',
            'Cesión HT': 'Cesión',
            'Compra HT': 'Compra de Hectáreas Tecnológicas',
            'Ensayo': 'Ensayos',
            'BolsaTech': 'Entregas Bolsatech',
            'Balance Anual': 'Saldo Campaña Anterior'
        };
    }

    get showInfoRegaliaEnlist(){
        return this.biotecnologia == 'Enlist E3/Conkesta E3';
    }

    get totalDisponibles(){
        const total = this.toneladas.reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return total > 0 ? total : 0;
    }

    get totalEntregadas(){
        return this.toneladas.filter(tn => tn.Origen__c == 'BolsaTech' && this.toLocalDate(tn.Fecha_Inicio__c).toISOString() >= this.fechaEntregadas.toISOString()).reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0) * -1;
    }

    get totalVencer(){
        let total = this.toneladas.filter(tn => this.toLocalDate(tn.Fecha_Fin__c).toISOString() == this.fechaVencimiento.toISOString() && (tn.Origen__c != 'Regalía Enlist' || tn.Etapa__c != 'Facturada')).reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return total > 0 ? total : 0;
    }

    get totalToneladasRegularizar(){
        const total = this.toneladas.reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
        return total < 0 ? total * -1 : 0;
    }

    get totalRegaliaEnlistPendientes(){
        return this.toneladas.filter(tn => tn.Origen__c == 'Regalía Enlist' && tn.Etapa__c == 'Facturada').reduce((total, tn) => total += tn.Cantidad_con_Signo__c, 0);
    }

    toLocalDate(fecha){
        const formmatedDate = new Date(fecha);
        formmatedDate.setHours(formmatedDate.getHours() + 3);
        return formmatedDate;
    }

    get fechaEntregadas(){
        const cultivo = this.cultivos.find(c => c.Id == this.cultivo);
        const formmatedDate = new Date(cultivo.Fecha_Vencimiento_de_Tonelada__c);
        formmatedDate.setHours(formmatedDate.getHours() + 3);
        const date = new Date();
        if(date < formmatedDate) {
            formmatedDate.setFullYear(formmatedDate.getFullYear() - 1);
        }

        return formmatedDate;
    }

    get fechaEntregadasWithFormat(){
        return this.fechaEntregadas.toLocaleDateString('es-AR');
    }

    get fechaVencimiento(){
        const cultivo = this.cultivos.find(c => c.Id == this.cultivo);
        const formmatedDate = new Date(cultivo.Fecha_Vencimiento_de_Tonelada__c);
        formmatedDate.setHours(formmatedDate.getHours() + 3);
        const date = new Date();
        if(date > formmatedDate) {
            formmatedDate.setFullYear(formmatedDate.getFullYear() + 1);
        }        
        return formmatedDate;
    }

    get fechaVencimientoToDisplay(){
        return this.fechaVencimiento.toLocaleDateString('es-AR');
    }
}