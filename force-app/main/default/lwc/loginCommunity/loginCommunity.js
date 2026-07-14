import { LightningElement, wire } from 'lwc';
import login from '@salesforce/apex/RegisterCommunityController.login';
import confirmLogin from '@salesforce/apex/RegisterCommunityController.confirmLogin';
import loginWithPassword from '@salesforce/apex/RegisterCommunityController.loginWithPassword';
import getUrlLogoSE from '@salesforce/apex/RegisterCommunityController.getUrlLogoSE';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import sitePath from '@salesforce/community/basePath';
import { NavigationMixin } from 'lightning/navigation';
import {reduceErrors, validateInputs, normalizeCuit, formatCuit} from 'c/utils';

//https://github.com/sohalloran/community-passwordless
//https://resources.docs.salesforce.com/216/latest/en-us/sfdc/pdf/salesforce_external_identity_implementation_guide.pdf
export default class LoginCommunity extends NavigationMixin(LightningElement) {

    sitePath = sitePath;
    email = '';
    code = '';
    identifier = '';
    cuit = '';
    variant = '';
    message = '';
    userId = '';
    password = '';

    isLoging = false;
    isConfirming = false;

    @wire(getUrlLogoSE)
    urlLogoSe;

    cancel(event) {
        this.identifier = '';
    }

     get backgroundStyle() {
        return `position: fixed;top: 0;background-position: center;background-repeat: no-repeat;z-index: -1;left: 0;width: 100vw;height: 100vh;background-size: cover;background-image:url(${backgroundUrl})`;
    }

    handleChange(event) {
        const label = event.target.placeholder;
        const value = event.target.value.trim();

        if (label === 'Email') {
            this.email = value;
        } else if (label === 'Código') {
            this.code = value;
        } else if (label == 'CUIT') {
            this.cuit = normalizeCuit(value);
        } else if (label == 'Contraseña'){
            this.password = value;
        }
    }

    async login() {
        if (!validateInputs(this.template.querySelector('.login-form'))) return;
        try {
            this.isLoging = true;
            if(this.isPortalArpov){
                let result = await login({email: this.email, cuit: this.cuit});
                result = JSON.parse(result);
                this.identifier = result.identifier;
                this.userId = result.userId;
                this.showToast('info', `Ingresar el código de seguridad enviado a su correo electrónico`);
            }else{
                let result = await loginWithPassword({email: this.email, cuit: this.cuit, password: this.password});
                window.location = result;
            }
        } catch (e) {
            this.showToast('error', e);
        } finally {
            this.isLoging = false;
        }
    }

    async confirm() {
        if (!validateInputs(this.template.querySelector('.confirmation-form'))) return;
        try {
            this.isConfirming = true;
            let result = await confirmLogin({ userId: this.userId, identifier: this.identifier, code: this.code });
            window.location = result;
        } catch (e) {
            this.showToast('error', e);
        } finally {
            this.isConfirming = false;
        }
    }

    showToast(variant, message) {
        console.log(variant, message)
        this.variant = variant;
        this.message = reduceErrors(message);
    }

    register() {
        var path = window.location.pathname;
        var newpath =path.replace('s/login', 's/login2');
        window.location = window.location.origin + newpath + 'newselfregister';
        return false;
    }

    forgotPassword(){
        var path = window.location.pathname;
        var newpath =path.replace('s/login', 's/login2');
        window.location = window.location.origin + newpath + 'forgotpassword';
        return false;
    }

    get missingMessage() {
        return 'Complete este campo';
    }

    get messageClass() {
        return this.variant == 'error' ? 'slds-text-color_destructive slds-p-horizontal_small' : 'slds-p-horizontal_small';
    }

    get title() { 
        return this.identifier ? 'Confirmación' : "Login";
    }

    get showSpinner() {
        return this.isLoging || this.isConfirming;
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

    checkEnterKey(event) {
        if (event.keyCode === 13) this.login();
    }

    get isPortalArpov(){
        console.log(this.sitePath);
        return this.sitePath.includes('PortalArPOV') || this.sitePath.includes('Distribuidor');
    }
}