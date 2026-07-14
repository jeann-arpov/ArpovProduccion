import { LightningElement, api, wire } from 'lwc';

import getFieldSetFieldsByFieldSetName from '@salesforce/apex/AuraHelper.getFieldSetFieldsByFieldSetName';
import createCase from '@salesforce/apex/InformarPagoController.createCase';
import createCasePPH from '@salesforce/apex/InformarPagoController.createCasePPH';
import deleteDocument from '@salesforce/apex/InformarPagoController.deleteDocument';
import sendEmail from '@salesforce/apex/InformarPagoController.sendEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {reduceErrors} from 'c/utils'
import { NavigationMixin } from 'lightning/navigation';

export default class InformarPago extends NavigationMixin(LightningElement) {

    subject = 'Informar Pago';

    showModal = false;
    title;

    fieldSetMembers = null;
    _extraFields = {}
    _processing = true;
    recordId;
    reason;
    accountId;

    contentVersionIds = [];
    docs = [];

    @wire(getFieldSetFieldsByFieldSetName,{objectApiName: 'Case', fieldSetName: 'Informar_Pago'})
    wiredGetFieldSetFieldsByFieldSetName({error,data}){
        console.log(data,error);
        if(data){
            this.fieldSetMembers = data;
        }else if(error){
            this.showToast(reduceErrors(error)[0],'error');
        }
    }

    @api
    show(data) {
        this._extraFields = {};
        this.subject = data.subject || ('CUIT: ' + data.cuit + ' - ' + data.comprobante + ' - Informar Pago');
        console.log(this.subject);
        this._extraFields['Subject'] = this.subject;
        this._processing = true;
        this.title = data.title
        this.showModal = true;
        this.recordId = data.recordId;
        this.accountId = data.accountId;
        this.contentVersionIds = [];
        this.docs = [];
    }

    @api
    hide() {
        this.showModal = true;
    }

    handleOnCloseModal() {
        this.showModal = false;
    }

    showToast(message,variant) {
        const event = new ShowToastEvent({
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(event);
    }

    handleOnInputFieldChange(event){
        this._extraFields[event.target.fieldName]=event.target.value;
    }

    handleOnRecordEditFormLoad(event){
        this._processing = false;
    }

    handleOnUploadFinished(event) {

        let docs = this.docs;
        this.docs = [];
        // Get the list of uploaded files
        const uploadedFiles = event.detail.files;

        console.log(uploadedFiles);
        uploadedFiles.forEach(file => {
            docs.push({
                Id: file.documentId,
                ContentDocumentId: file.documentId,
                Title: file.name,
                VersionId: file.contentVersionId
            });
            this.contentVersionIds.push(file.contentVersionId);
        });

        this.docs = docs;
    }

    handleOnCreateCase(event){

        if(this.isRequiredMappedFieldsAreEmpty()){
            return;
        }

        if(!this.accountId && !this.contentVersionIds){
            return this.dispatchEvent(
                new ShowToastEvent({
                    // title: 'Error!!',
                    message: 'Debe cargar el archivo del comprobante.',
                    variant: 'error',
                }),
            );    
        }

        this._processing = true;

        // calling apex class

        sendEmail({   
            caseFields : this._extraFields,
            versionIds : this.contentVersionIds
        }).then(_ => {
            this._processing = false;
            this.showSuccess();
            this.showModal = false;
        }).catch(error => {
            this._processing = false;
            this.processError(error);
        });

        // if(!this.accountId){
        //     createCase({   
        //         caseFields : this._extraFields,
        //         opportunityId : this.recordId,
        //         contentDocumentId : this.documentId
        //     }).then(_ => {
        //         this._processing = false;
        //         this.showSuccess();
        //         this.showModal = false;
        //     }).catch(error => {
        //         this._processing = false;
        //         this.processError(error);
        //     });
        // }else{
        //     createCasePPH({
        //         caseFields: this._extraFields,
        //         contentDocumentId: this.documentId,
        //         accountId: this.accountId
        //     }).then(_ => {
        //         this._processing = false;
        //         this.showSuccess();
        //         this.showModal = false;
        //     }).catch(error => {
        //         this._processing = false;
        //         this.processError(error);
        //     });
        // }


    }

    showSuccess(){
        this.dispatchEvent(
            new ShowToastEvent({
                message: 'Información de pago registrada éxitosamente.',
                variant: 'success'
            })
        );
    }

    processError(error){
        this.error = reduceErrors(error).join('\n');
        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Error!!',
                message: this.error,
                variant: 'error',
            }),
        );     
    }

    isRequiredMappedFieldsAreEmpty(){
        
        let emptyLightningCombobox = [];
        
        this.template.querySelectorAll('lightning-input-field').forEach(element => {
            if(element.required && !element.value){
                element.reportValidity();
                emptyLightningCombobox.push(element);
            }
        });

        return emptyLightningCombobox.length > 0;

    }


    handleDelete(event) {
        this._processing = true;
        let elementId = event.currentTarget.dataset.id;

        deleteDocument({docId: elementId})
        .then(response => {
            let element = this.docs.find(doc => doc.Id == elementId);
            this.docs = this.docs.filter(doc => doc.Id !== elementId);
            this.contentVersionIds = this.contentVersionIds.filter(version => version !== element.VersionId);

            const evt = new ShowToastEvent({
                title:  '¡Documento eliminado!',
                message: 'El documento se ha eliminado satisfactoriamente.',
                variant: 'success',
            });
            this.dispatchEvent(evt);
        })
        .catch(error => {
            console.log(error);
            const evt = new ShowToastEvent({
                title:  'Error',
                message: error.message,
                variant: 'error',
              });
              this.dispatchEvent(evt);
        })
        .finally(() => {
            this._processing = false;
        })
    }

    get acceptedFormats() {
        return ['.pdf', '.png','.jpg','.jpeg'];
    }

    get showSpinner(){
        return this._processing;
    }

}