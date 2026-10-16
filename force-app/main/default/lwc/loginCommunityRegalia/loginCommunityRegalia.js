import { LightningElement, track } from 'lwc';
import loginWithPassword from '@salesforce/apex/RegisterCommunityRegaliaController.loginWithPassword';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import LOGO_REGALIA_PRODUCTOR from '@salesforce/resourceUrl/LogoRegaliaProductor';
import { NavigationMixin } from 'lightning/navigation';
import { reduceErrors, validateInputs } from 'c/utils';

export default class LoginCommunityRegalia extends NavigationMixin(LightningElement) {

    logoProductor = LOGO_REGALIA_PRODUCTOR;

    email = '';
    cuit = '';
    password = '';
    
    variant = '';
    message = '';
    isLoging = false;

    get backgroundStyle() {
        return `position: fixed;top: 0;background-position: center;background-repeat: no-repeat;z-index: -1;left: 0;width: 100vw;height: 100vh;background-size: cover;background-image:url(${backgroundUrl})`;
    }

    handleChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value.trim();

        if (fieldName === 'email') {
            this.email = value;
        } else if (fieldName === 'cuit') {
            this.cuit = value;
        } else if (fieldName === 'password') {
            this.password = value;
        }
    }

    async login() {
        // Validamos que los inputs del formulario cumplan con los requerimientos visuales
        if (!validateInputs(this.template.querySelector('.login-form'))) return;
        
        // Limpiamos mensajes de error o alertas previas
        this.variant = '';
        this.message = '';

        try {
            this.isLoging = true;

            // Invocación directa y exclusiva al método con contraseña
            let result = await loginWithPassword({ 
                email: this.email, 
                cuit: this.cuit, 
                password: this.password 
            });

            if (result) {
                window.location.href = result;
            }
        } catch (e) {
            this.showToast('error', e);
        } finally {
            this.isLoging = false;
        }
    }

    showToast(variant, message) {
        console.log(variant, message);
        this.variant = variant;
        this.message = reduceErrors(message);
    }

    register() {
        window.location.href = window.location.origin + '/s/newselfregister';
        return false;
    }

    forgotPassword() {
        window.location.href = window.location.origin + '/s/newforgotpassword';
        return false;
    }

    get messageClass() {
        return this.variant === 'error' ? 'slds-text-color_destructive slds-p-horizontal_small' : 'slds-p-horizontal_small';
    }

    get showSpinner() {
        return this.isLoging;
    }

    checkEnterKey(event) {
        if (event.keyCode === 13) this.login();
    }
}