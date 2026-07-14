import { LightningElement, api, wire } from 'lwc';
import getProductoObtentorData from '@salesforce/apex/ProductoObtentorController.getProductoObtentorData';
import { CurrentPageReference } from 'lightning/navigation';

export default class ProductoObtentorContainer extends LightningElement {
    productId;

    producto;
    precios = [];
    error;
    isLoading = true;

    // Obtener productId desde la URL y cargar datos cuando llegue
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const newProductId = currentPageReference.state.productId;
            if (newProductId && newProductId !== this.productId) {
                this.productId = newProductId;
                console.log('ProductId recibido:', this.productId);
                this.loadData();
            }
        }
    }

    // Cargar datos manualmente (imperativo)
    loadData() {
        if (!this.productId) {
            console.warn('loadData: productId no definido');
            return;
        }

        console.log('loadData llamado — productId:', this.productId);
        this.isLoading = true;

        getProductoObtentorData({ productId: this.productId })
            .then(result => {
                console.log('loadData result:', result);
                // Forzar nuevas referencias para que LWC re-renderice
                this.producto = result.producto ? { ...result.producto } : null;
                this.precios = result.precios ? [ ...result.precios ] : [];
                this.error = null;
                console.log('producto y precios actualizados, entradasCount:', this.entradasCount, 'precios length:', this.precios.length);
            })
            .catch(error => {
                console.error('loadData error:', error);
                this.error = error;
                this.producto = null;
                this.precios = [];
            })
            .finally(() => {
                this.isLoading = false;
                console.log('loadData finalizado');
            });
    }

    // Handler que recibe el evento del hijo
    handleRefresh(event) {
        try {
            console.log('handleRefresh recibido, detail:', event.detail);

            const nueva = event.detail?.nuevaEntrada ?? null;

            if (nueva) {
                // Normalizar y añadir localmente para actualización instantánea
                const nuevaCopia = { ...JSON.parse(JSON.stringify(nueva)) };
                this.precios = [...(this.precios || []), nuevaCopia];
                console.log('Entrada añadida localmente, entradasCount:', this.entradasCount, 'precios length:', this.precios.length);
                return;
            }

            // Si no viene detalle, recargar desde servidor
            this.loadData();
        } catch (err) {
            console.error('handleRefresh error:', err);
            // Fallback seguro
            this.loadData();
        }
    }

    get hasData() {
        return this.producto && this.producto.Id;
    }

    get vigenteLabel() {
        return this.producto?.Vigente__c ? 'Vigente' : 'No vigente';
    }

    get vigenteIconClass() {
        return this.producto?.Vigente__c
            ? 'vigente-icon vigente-icon--ok'
            : 'vigente-icon vigente-icon--no';
    }

    get entradasCount() {
        return this.precios ? this.precios.length : 0;
    }
}