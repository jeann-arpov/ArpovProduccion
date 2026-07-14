import { LightningElement, api, wire, track } from 'lwc';

import getPaymentMethods from '@salesforce/apex/AgroPagoAuraController.getPaymentMethods'; 
import pay from '@salesforce/apex/AgroPagoAuraController.pay';
import getAgroPago from '@salesforce/apex/AgroPagoAuraController.getAgroPago';
import agropagoLogo from '@salesforce/resourceUrl/AgroPagoLogo';

export default class AgropagoStandAlone extends LightningElement {
    
    recordId;
    amount;
    operationResult = null;
    showForm = false;
    approved = false;
    loadedAgroPago = false;
    comition = 0;

    logo_url = agropagoLogo;

    @track cardNumberFormating = '';

    _processing = true;
    
    _paymentMethods = null;

    _form ={
        cardNumber : null, 
        cardExpirationMonth : null,
        cardExpirationYear : null,
        securityCode : null, 
        cardHolderName : null, 
        cardHolderIdentificationType : null,
        cardHolderIdentificationNumber : null,
        paymentMethodId : null,
        pmcEstablishmentId: null,
        recordId : null,
        agroToken: null
    };

    renderedCallback() {
        if (!this.initialized) {
            this.initialized = true;
            getAgroPago().then(r => this.updateAgroPago(r)).catch(this.onError.bind(this)).finally(_ => this.loadedAgroPago = true);
        }
    }

    onError(error) {
        this.operationResult = {status: "rejected", reason_error_description: this.getError(error)}
    }

    updateAgroPago(agroPago) {
        this.comition = agroPago.Comision__c || 0;
    }

    @wire(getPaymentMethods,{})
    wiredGetPaymentMethods({error, data}){
        this._processing = false;
        if (data) {
            console.log(data);
            this._paymentMethods = data;
        }else{
            console.log(error);
        }
    }

    handleOnCardNumberChange(event) {
        this._form.cardNumber = event.detail.value.split('-').join('');
        this.reformat(event.detail.value);
    }

    handleOnCardExpirationMonthChange(event){
        this._form.cardExpirationMonth = event.detail.value;
    }

    handleOnCardExpirationYearChange(event){
        this._form.cardExpirationYear = event.detail.value;
    }

    handleOnCardHolderNameChange(event){
        this._form.cardHolderName = event.detail.value;
    }

    handleOnCardHoldeIdentificationTypeChange(event){
        this._form.cardHolderIdentificationType = event.detail.value;
    }

    handleOnCardHoldeIdentificationNumberChange(event){
        this._form.cardHolderIdentificationNumber = event.detail.value;
    }

    handleOnSecurityCodeChange(event){
        this._form.securityCode = event.detail.value;
    }

    handleOnPaymentMethodChange(event){
        if(this._paymentMethods == null){
            return;
        }
        this._selectedPaymentMethod = this._paymentMethods.filter(paymentMethod => event.detail.value == paymentMethod.id+'' )[0];
    }

    handleOnAgroTokenChange(event){
        this._form.agroToken = event.detail.value;
    }

    reformat(value){

        let v = value.replace(/\s+/g, '').replace(/[^0-9]/gi, '');
        let matches = v.match(/\d{4,16}/g);
        let match = matches && matches[0] || '';
        let parts = [];
        
        for (let i=0; i<match.length; i+=4) {
            parts.push(match.substring(i, i+4))
        }

        if(parts.length) {
            this.cardNumberFormating = parts.join('-');
        } else {
            this.cardNumberFormating = value;
        }

    }

    async handleOnPayClick(event){

        if(!this.isFormValid()){
            return;
        }

        this._processing = true;
        this._form.recordId = this.recordId;
        this._form.paymentMethodId = this._selectedPaymentMethod.id;
        this._form.pmcEstablishmentId = this._selectedPaymentMethod.pmcEstablishments[0].id;

        console.log(this._form);

        try {
            let result = await pay({form: this._form});
            this.approved = true;
            this.operationResult = result;
            this.dispatchEvent(new CustomEvent("paymentapproved", {detail: {result, recordId: this.recordId}}));
        } catch (e) {
            this.operationResult = {status: "rejected", reason_error_description: this.getError(e)}
        } finally {
            this._processing = false;
        }
    }

    getError(response) {
        response = response && response.body ? response.body.message : "";
        if (response) {
            try {
                response = JSON.parse(response);
                if (response.validation_errors) response = response.validation_errors.map(v => Object.values(v).join(' - ')).join('\n')
                else if (response.request_errors) response = response.request_errors.map(v => Object.values(v).join(' - ')).join('\n')
                else if (response.request_error_desc) response = response.request_error_desc
                else response = JSON.stringify(response);
            } catch(e) {}
        }
        return response;
    }

    @api
    show(data) {
        this.approved = false;
        this.operationResult = null;
        this.showForm = true;
        this.recordId = data.recordId;
        this.amount = data.amount;
        this.cardNumberFormating = '';
    }

    get totalAmount() {
        return this.amount / (1 - this.comition / 100) ;
    }

    get managementAmount() {
        return this.totalAmount - this.amount;
    }

    isFormValid() {
    
        const allValid = [...this.template.querySelectorAll('lightning-input,lightning-combobox')]
        .reduce((validSoFar, inputCmp) => {
                    inputCmp.reportValidity();
                    return validSoFar && inputCmp.checkValidity();
        }, true);

        return allValid;

    }

    get showSpinner(){
        return this._processing || !this.loadedAgroPago;
    }

    get options() {
        return [
            { label: 'DNI', value: 'dni' }
        ];
    }

    get paymentMethodsOptions(){

        let paymentMethods = [];

        (this._paymentMethods || []).forEach(function(element){
            paymentMethods.push({
                label : element.name,
                value : element.id + ''
            })
        });

        return paymentMethods;
    }

    get showCrediCardForm(){
        return this.operationResult == null;
    }

    get showTransactionResults(){
        return this.operationResult != null;
    }

    get operationSuccess(){
        return this.operationResult.status == 'approved';
    }

    get operationRejected(){
        return !this.operationSuccess;
    }

    handleOnCloseModal() {
        this.showForm = false;
    }

}