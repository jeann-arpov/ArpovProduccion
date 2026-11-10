import { LightningElement, api, track } from 'lwc';
import getContactInfo from '@salesforce/apex/ContactDeactivationController.getContactInfo';
import deactivatePortalUsers from '@salesforce/apex/ContactDeactivationController.deactivatePortalUsers';
import deactivateContact from '@salesforce/apex/ContactDeactivationController.deactivateContact';
import reactivateContact from '@salesforce/apex/ContactDeactivationController.reactivateContact';
import reactivatePortalUsers from '@salesforce/apex/ContactDeactivationController.reactivatePortalUsers';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ContactDeactivation extends LightningElement {
    @api recordId;
    @track contactName = '';
    @track activo = true;
    @track usuariosPortalActivos = 0;
    @track loading = false;

    connectedCallback() {
        this.cargarInfo();
    }

    cargarInfo() {
        getContactInfo({ contactId: this.recordId })
            .then((result) => {
                this.contactName = result.name;
                this.activo = result.activo;
                this.usuariosPortalActivos = result.usuariosPortalActivos;
            })
            .catch((error) => {
                this.mostrarToast('Error al cargar el contacto', this.extraerMensaje(error), 'error');
            });
    }

    async handleBaja() {
        this.loading = true;
        try {
            const r1 = await deactivatePortalUsers({ contactId: this.recordId });
            if (!r1.success) {
                this.mostrarToast('Error', r1.message, 'error');
                return;
            }
            const r2 = await deactivateContact({ contactId: this.recordId });
            this.mostrarToast(r2.success ? 'Éxito' : 'Error', r2.message, r2.success ? 'success' : 'error');
        } catch (error) {
            this.mostrarToast('Error', this.extraerMensaje(error), 'error');
        } finally {
            this.loading = false;
            this.cargarInfo();
        }
    }

    async handleReactivar() {
        this.loading = true;
        try {
            const r1 = await reactivateContact({ contactId: this.recordId });
            if (!r1.success) {
                this.mostrarToast('Error', r1.message, 'error');
                return;
            }
            const r2 = await reactivatePortalUsers({ contactId: this.recordId });
            this.mostrarToast(r2.success ? 'Éxito' : 'Error', r2.message, r2.success ? 'success' : 'error');
        } catch (error) {
            this.mostrarToast('Error', this.extraerMensaje(error), 'error');
        } finally {
            this.loading = false;
            this.cargarInfo();
        }
    }

    extraerMensaje(error) {
        return (error && error.body && error.body.message) || (error && error.message) || 'Error desconocido';
    }

    mostrarToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
