import { LightningElement, api, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getToneladas from '@salesforce/apex/CuentaGranariaToneladasController.getToneladas';
import generarConsumoHT from '@salesforce/apex/CuentaGranariaToneladasController.generarConsumoHT';

export default class CuentaGranariaToneladas extends NavigationMixin(LightningElement) {
    @api recordId; // ID de la Cuenta Granaria desde el contexto de la página

    toneladas = [];
    total = 0;
    totalPositivo = 0;
    totalNegativo = 0;
    cuentaInfo = {};
    wiredToneladasResult;

    isLoading = true;
    isGenerandoConsumo = false;
    error = undefined;

    @wire(getToneladas, { cuentaGranariaId: '$recordId' })
    wiredToneladas(result) {
        this.wiredToneladasResult = result;
        this.isLoading = true;

        if (result.data) {
            this.procesarDatos(result.data);
            this.isLoading = false;
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error.body ? result.error.body.message : 'Error desconocido';
            this.toneladas = [];
            this.isLoading = false;
        }
    }

    procesarDatos(data) {
        // Toneladas con clase CSS para positivo/negativo
        this.toneladas = data.toneladas.map(tn => {
            return {
                ...tn,
                cantidadFormatted: this.formatearNumero(tn.cantidad),
                esPositivo: tn.cantidad >= 0 ? 'positivo' : 'negativo'
            };
        });

        // Totales
        this.total = data.total || 0;
        this.totalPositivo = data.totalPositivo || 0;
        this.totalNegativo = data.totalNegativo || 0;

        // Info de la cuenta
        this.cuentaInfo = data.cuenta || {};
    }

    // Getters para formateo y condiciones

    get hasData() {
        return !this.isLoading && !this.error && this.toneladas && this.toneladas.length > 0;
    }

    get sinDatos() {
        return !this.isLoading && !this.error && (!this.toneladas || this.toneladas.length === 0);
    }

    get totalLabel() {
        return `Total: ${this.formatearNumero(this.total)} tn`;
    }

    get totalFormatted() {
        return this.formatearNumero(this.total);
    }

    get totalPositivoFormatted() {
        return this.formatearNumero(this.totalPositivo);
    }

    get totalNegativoFormatted() {
        return this.formatearNumero(this.totalNegativo);
    }

    get positivoLabel() {
        return `Positivo: ${this.formatearNumero(this.totalPositivo)} tn`;
    }

    get negativoLabel() {
        return `Negativo: ${this.formatearNumero(this.totalNegativo)} tn`;
    }

    get totalClass() {
        return this.total >= 0 ? 'positivo' : 'negativo';
    }

    get esTotalPositivo() {
        return this.total >= 0;
    }

    get totalRegistros() {
        return this.toneladas ? this.toneladas.length : 0;
    }

    get saldoCuentaFormatted() {
        return this.formatearNumero(this.cuentaInfo.saldo);
    }

    get esCompraHT() {
        return this.cuentaInfo && this.cuentaInfo.esCompraHT === true;
    }

    get saldoCompraHTFormatted() {
        return this.formatearNumero(this.cuentaInfo.saldoCompraHT);
    }

    get cuentasRelacionadas() {
        if (!this.cuentaInfo || !this.cuentaInfo.cuentasRelacionadas) return [];
        return this.cuentaInfo.cuentasRelacionadas.map(cg => ({
            ...cg,
            saldoFormatted: this.formatearNumero(cg.saldo),
            saldoClass: cg.saldo >= 0 ? 'positivo' : 'negativo'
        }));
    }

    get tieneCuentasRelacionadas() {
        return this.esCompraHT && this.cuentasRelacionadas.length > 0;
    }

    get puedeGenerarConsumo() {
        return this.cuentaInfo && this.cuentaInfo.puedeGenerarConsumo === true;
    }

    get generarConsumoDisabled() {
        return this.isLoading || this.isGenerandoConsumo;
    }

    // Formatear números con 2 decimales y separadores
    formatearNumero(valor) {
        if (valor === null || valor === undefined) {
            return '0.00';
        }
        
        const numero = parseFloat(valor);
        
        if (isNaN(numero)) {
            return '0.00';
        }

        return numero.toLocaleString('es-AR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        });
    }

    // Navegación al registro de tonelada
    navigateToRecord(event) {
        event.preventDefault();
        const recordId = event.currentTarget.dataset.id;
        
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Tonelada__c',
                actionName: 'view'
            }
        });
    }

    // Navegación a la cuenta granaria de Compra HT
    navigateToCompraHT() {
        if (this.cuentaInfo && this.cuentaInfo.compraHTId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: this.cuentaInfo.compraHTId,
                    objectApiName: 'Cuenta_Granaria__c',
                    actionName: 'view'
                }
            });
        }
    }

    // Navegación a una cuenta granaria relacionada
    navigateToCuentaGranaria(event) {
        const recordId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Cuenta_Granaria__c',
                actionName: 'view'
            }
        });
    }

    async handleGenerarConsumo() {
        if (!this.recordId || !this.puedeGenerarConsumo) {
            return;
        }

        this.isGenerandoConsumo = true;
        try {
            const result = await generarConsumoHT({ cuentaGranariaId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Consumo generado',
                    message: result?.message || 'Se generó el consumo HT correctamente.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredToneladasResult);
        } catch (error) {
            const message = error?.body?.message || error?.message || 'No se pudo generar el consumo.';
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message,
                    variant: 'error'
                })
            );
        } finally {
            this.isGenerandoConsumo = false;
        }
    }
}