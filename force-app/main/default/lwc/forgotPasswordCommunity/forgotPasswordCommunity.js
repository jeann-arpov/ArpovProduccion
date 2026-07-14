import { LightningElement, wire, track } from 'lwc';
import requestResetPassword from '@salesforce/apex/CommunityUser.requestResetPassword';
import getUrlLogoSE from '@salesforce/apex/RegisterCommunityController.getUrlLogoSE';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import { NavigationMixin } from 'lightning/navigation';
import { doRequest, validateInputs, reduceErrors, normalizeCuit, formatCuit } from 'c/utils'; 
export default class ForgotPasswordCommunity extends NavigationMixin(LightningElement) {

    cuit = '';
    email = '';

    variant;
    _message = '';
    showMessage = false;

    @track modal;

    setMessage(value) {
        this._message = value;
        this.showMessage = !!value;
        // Usar setTimeout para asegurar que el DOM se actualice
        setTimeout(() => {
            const messageContainer = this.template.querySelector('[data-message-container]');
            if (messageContainer && this._message) {
                messageContainer.innerHTML = this._message;
            }
        }, 0);
    }

    @wire(getUrlLogoSE)
    urlLogoSe;
    
     get backgroundStyle() {
        return `position: fixed;top: 0;background-position: center;background-repeat: no-repeat;z-index: -1;left: 0;width: 100vw;height: 100vh;background-size: cover;background-image:url(${backgroundUrl})`;
    }

    handleChange(event){
        const label = event.target.placeholder;
        const value = event.target.value.trim();

        if(label == 'Email'){
            this.email = value;
        }else if(label == 'CUIT'){
            this.cuit = normalizeCuit(value);
        }
    }

    handleCuitBlur(event) {
        const normalized = normalizeCuit(event.target.value);
        this.cuit = normalized;
    }

    get cuitFormatted() {
        return formatCuit(this.cuit);
    }

    handleCuitKeydown(event) {
        if (event.key.length === 1 && !/^[0-9\-]$/.test(event.key)) {
            event.preventDefault();
        }
    }

     openModal(){
        this.modal = true;
    }

     closeModal(){
        this.modal = false;
    }

    async resetPassword(){
        this.modal = false;
        if (!validateInputs(this.template.querySelector('.reset-form'))) return;
        doRequest.call(this, async _ => {
            await requestResetPassword({cuit: this.cuit, email: this.email});
            this.showCheckEmail();
        });
    }

    showCheckEmail() {
        window.location = window.location.origin + window.location.pathname.replace('ForgotPassword', 'CheckPasswordResetEmail');
        return false;
    }

    onError(e){
        this.variant = 'error';
        const errors = reduceErrors(e);
        this.setMessage(Array.isArray(errors) ? errors.join('<br>') : errors);
    }

    checkEnterKey(event) {
        if (event.keyCode === 13) this.resetPassword();
    }

    handleNavigate(event) {
        var path = window.location.pathname;
        var newpath =path.replace('s/login2/forgotpassword', 's/login');
        window.location = window.location.origin + newpath;
        return false;
    }

    get messageClass(){
        return this.variant == 'error' ? 'slds-text-align_center slds-text-color_destructive' : 'slds-text-align_center slds-text-color_success';
    }
}