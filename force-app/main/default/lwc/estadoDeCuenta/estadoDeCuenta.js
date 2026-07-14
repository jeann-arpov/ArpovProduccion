import { LightningElement, wire, track, api } from 'lwc';

import getComprobantes from '@salesforce/apex/EstadoDeCuentaAuraService.getComprobantes';
import getInstructivo from '@salesforce/apex/EstadoDeCuentaAuraService.getInstructivo';


import consultaComprobantes_1 from '@salesforce/label/ERPvs.consultaComprobantes_1';
import consultaComprobantes_2 from '@salesforce/label/ERPvs.consultaComprobantes_2';
import consultaComprobantes_3 from '@salesforce/label/ERPvs.consultaComprobantes_3';
import consultaComprobantes_4 from '@salesforce/label/ERPvs.consultaComprobantes_4';
import modificarProductosCC_2 from '@salesforce/label/ERPvs.modificarProductosCC_2';

export default class EstadoDeCuenta extends LightningElement {

    @track _fechaDesde;
    @track _fechaHasta;
    @track _fechaVencimientoDesde;
    @track _fechaVencimientoHasta;

    comprobantes;
    processing = true;

    label= {
        consultaComprobantes_1,
        consultaComprobantes_2,
        consultaComprobantes_3,
        consultaComprobantes_4,
        modificarProductosCC_2
    }

    @wire(getComprobantes,{fechaDesde:null,fechaHasta:null,fechaVencimientoDesde:null,fechaVencimientoHasta:null})
    wiredGetComprobantes({error, data}){
        this.processing = false;
        if (data) {
            console.log(data);
            this.comprobantes = data;
        }else{
            console.log(error);
        }
    }

    handleOnFechaDesdeChange(event){
        this._fechaDesde = event.target.value;
    }

    handleOnFechaHastaChange(event){
        this._fechaHasta = event.target.value;
    }

    handleOnFechaVencimientoDesde(event){
        this._fechaVencimientoDesde = event.target.value;
    }

    handleOnFechaVencimientoHasta(event){
        this._fechaVencimientoHasta = event.target.value;
    }

    handleOnSearchClick(event){

        this.processing = true;

        console.log(
            this._fechaDesde,
            this._fechaHasta,
            this._fechaVencimientoDesde,
            this._fechaVencimientoHasta
        );

        getComprobantes(
            {
                fechaDesde:this._fechaDesde,
                fechaHasta:this._fechaHasta,
                fechaVencimientoDesde:this._fechaVencimientoDesde,
                fechaVencimientoHasta:this._fechaVencimientoHasta
        })
        .then(result => {
            this.processing = false;
            this.comprobantes = result;
        })
        .catch(error => {
            this.processing = false;
            this.showToast(error.body.message,'error');
        });
    }

    showToast(message,variant) {
        const event = new ShowToastEvent({
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    handleOnInstructivoClick(event){
        
        var obtentor = event.target.dataset.id;

        this.processing = true;

        getInstructivo({
            obtentor : obtentor
        })
        .then(result => {
            console.log(result);
            this.processing = false;
            this.template
            .querySelector('c-pdf-reader')
            .show({
                documentId:result.documentId,
                title:result.obtentor
            });
        })
        .catch(error => {
            this.processing = false;
        });

    }

    handleOnClick(event){
        var comprobanteId = event.target.dataset.id;

        var comprobante = this.comprobantes.find(function(item) {
            return item.id == comprobanteId;
        });

        console.log(comprobanteId, comprobante);

        this.template
        .querySelector('c-pdf-reader')
        .show({
            documentId:comprobante.file.id,
            title:'Factura Eléctronica'
        });
    }

    handleOnPayClick(event){
        var comprobanteId = event.target.dataset.id;

        var comprobante = this.comprobantes.find(function(item) {
            return item.id == comprobanteId;
        });

        console.log(comprobanteId, comprobante);

        this.template
        .querySelector('c-agropago-stand-alone')
        .show({
            amount:comprobante.saldoActualizado,
            recordId:comprobante.opportunityId
        });
    }

    handleOnInformarPagoClick(event){
        var comprobanteId = event.target.dataset.id;

        var comprobante = this.comprobantes.find(function(item) {
            return item.id == comprobanteId;
        });

        console.log(comprobanteId, comprobante);

        this.template
        .querySelector('c-informar-pago')
        .show({
            title:'Informar Pago',
            recordId:comprobanteId,
            cuit: comprobante.cuit,
            comprobante: comprobante.numero
        });

    }

    get totalAdeudado(){

        let total = 0;

        this.comprobantes.forEach(element => {
            total+= element.saldoActualizado;
        });

        return total;

    }

    get totalPorObtentor(){

        let total = {

        };

        let obtentores = [];

        this.comprobantes.forEach(element=>{

            if(!total.hasOwnProperty(element.shortNameSemillero)){
                total[element.shortNameSemillero] = 0;    
            }

            total[element.shortNameSemillero] += element.saldoActualizado;
        
        });

        for(let propt in total){
            obtentores.push({
                key:propt,
                value:total[propt]
            });
        }

        return obtentores;

    }

}