import { LightningElement, api } from 'lwc';
import createEntrada from '@salesforce/apex/ProductoObtentorController.createEntrada';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EntradasPrecioTable extends LightningElement {
    @api precios;
    @api productId;

    showModal = false;

    newEntry = {
        Precio_Unitario__c: null,
        Fecha_Inicio__c: null,
        Fecha_Fin__c: null
    };

    get hasRows() {
        return this.precios && this.precios.length > 0;
    }

    get noRows() {
        return !this.hasRows;
    }

    columns = [
        { label: 'Entrada Precio Obtentor Name', fieldName: 'Name', type: 'text' },
        { label: 'Precio Unitario', fieldName: 'Precio_Unitario__c', type: 'currency' },
        { label: 'Fecha Inicio', fieldName: 'Fecha_Inicio__c', type: 'date' },
        { label: 'Fecha Fin', fieldName: 'Fecha_Fin__c', type: 'date' },
        { label: 'Estado', fieldName: 'Estado__c', type: 'text', cellAttributes: { class: { fieldName: 'estadoClass' }}},
        { label: 'Fecha de creación', fieldName: 'CreatedDate', type: 'date' }
    ];

    openModal() {
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }


    handlePrice(event) {
        let value = event.target.value;

        const num = Number(value);

        if (!isNaN(num)) {
            const fixed = Number(num.toFixed(2)); // ← Número real con 2 decimales
            this.newEntry.Precio_Unitario__c = fixed;
            event.target.value = fixed.toFixed(2); // ← Solo para mostrarlo bonito
        } else {
            this.newEntry.Precio_Unitario__c = null;
        }
    }

    handleInput(event) {
        const field = event.target.dataset.field;
        this.newEntry[field] = event.target.value;
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }

    validate() {
        const today = new Date().toISOString().split('T')[0];

        // Precio ya es un NUMBER real
        const precio = this.newEntry.Precio_Unitario__c;

        if (!precio || precio <= 0) {
            this.showToast('Validación', 'El precio debe ser mayor a 0', 'error');
            return false;
        }

        if (!this.newEntry.Fecha_Inicio__c || this.newEntry.Fecha_Inicio__c < today) {
            this.showToast('Validación', 'La fecha de inicio no puede ser en el pasado', 'error');
            return false;
        }

        if (this.newEntry.Fecha_Fin__c &&
            this.newEntry.Fecha_Fin__c <= this.newEntry.Fecha_Inicio__c) {
            this.showToast('Validación', 'La fecha fin debe ser mayor a la fecha inicio', 'error');
            return false;
        }

        return true;
    }

    

    async save() {
    if (!this.validate()) return;


    const cleanEntry = {
        Precio_Unitario__c: this.newEntry.Precio_Unitario__c,
        Fecha_Inicio__c: this.newEntry.Fecha_Inicio__c || null,
        Fecha_Fin__c: this.newEntry.Fecha_Fin__c || null,
        Producto_Obtentor__c: this.productId
    };

    try {
        
        const createdRecord = await createEntrada({ entrada: cleanEntry });

        this.showToast('Éxito', 'Entrada creada correctamente', 'success');

        // Normalizar para evitar getters/prototipos problemáticos
        const safeRecord = createdRecord ? JSON.parse(JSON.stringify(createdRecord)) : null;

        console.log('Hijo: entrada creada, dispatch refresh con detalle', safeRecord);

        this.dispatchEvent(new CustomEvent('refresh', {
            detail: { nuevaEntrada: safeRecord },
            bubbles: true,
            composed: true
        }));

        this.closeModal();

    } catch (error) {
        console.error(JSON.stringify(error));
        this.showToast('Error', 'Error al guardar la entrada', 'error');
    }
}


}