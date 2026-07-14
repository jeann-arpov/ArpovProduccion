import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import registerCuit from '@salesforce/apex/CesionPPH.registerCuit';
import {errorEvent} from 'c/utils';

export default class ModalsPph extends NavigationMixin(LightningElement) {
    @api currentModal;
    @api callback;

    loading = false;

    get showModal() {
        return this.currentModal != null;
    }

    closeModal(event) {
        this.dispatchEvent(new CustomEvent('close'));
    }

    get isDeleteConfirm() {
        return this.currentModal == "confirm-delete";
    }

    get isContinueConfirm() {
        return this.currentModal == "confirm-continue";
    }

    get isContinueConfirmResumen() {
        return this.currentModal == "confirm-continue-resumen";
    }

    get isContinueConfirmRectificar() {
        return this.currentModal == "confirm-continue-rectificar";
    }

    get isAdherido() {
        return this.currentModal == "adherido";
    }

    get isDeleteDestinatarioConfirm() {
        return this.currentModal == "confirm-delete-destinatario";
    }

    get isAddDestinatarioConfirm(){
        return this.currentModal == 'confirm-add-destinatario';
    }

    get isConfirmEnviarSesion() {
        return this.currentModal == "confirm-enviar-cesion" || this.isConfirmEnviarSesionWithoutLicenses;
    }

    get isConfirmEnviarSesionWithoutLicenses() {
        return this.currentModal == "confirm-enviar-cesion-without-licenses"
    }

    get isAdheridoCesion() {
        return this.currentModal == "adherido-cesion";
    }

    get isConfirmEditCesion() {
        return this.currentModal == "confirm-edit-cesion";
    }

    get isConfirmAnularCesion() {
        return this.currentModal == 'confirm-anular-cesion';
    }

    get isRegisterCuit() {
        return this.currentModal.startsWith('register-cuit');
    }

    get isRecordatorioFirmante() {
        return this.currentModal == 'recordatorio-firmante';
    }

    executeCallback() {
        this.callback();
    }

    redirectInicio() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home'
            },
        });
    }

    get cls() {
        return "slds-modal__container" + (this.isContinueConfirmResumen ? ' resumen' : '');
    }

    async registerCuit(e) {
        this.loading = true;

        try {
            const res = await registerCuit({email: this.template.querySelector('.email').value, cuit: this.cuit});
            this.callback(res);
        } catch (e) {
            this.onError(e);
        }

        this.loading = false;
    }

    get cuit() {
        return this.currentModal.split('-').pop();
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }
}