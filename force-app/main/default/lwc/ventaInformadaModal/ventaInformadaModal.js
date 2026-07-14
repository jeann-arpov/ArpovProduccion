import { LightningElement, api } from 'lwc';
import LightningModal from 'lightning/modal';
import { CloseActionScreenEvent } from "lightning/actions";

export default class VentaInformadaModal extends LightningModal {
    @api
    isModal;
    @api
    prefillData;
    @api
    originanteAccountId;
    @api
    modalTitle = 'Nueva Venta Informada';
    handleCancel(){
        this.close();
    }

    handleSave(){
        this.template.querySelector("c-crear-venta-informada-l-w-c").parentSave();
    }
}