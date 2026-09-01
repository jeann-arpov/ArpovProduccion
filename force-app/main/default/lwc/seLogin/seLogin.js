import { LightningElement, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import login from '@salesforce/apex/RegisterCommunityController.login';
import confirmLogin from '@salesforce/apex/RegisterCommunityController.confirmLogin';
import loginWithPassword from '@salesforce/apex/RegisterCommunityController.loginWithPassword';
import getUrlLogoSE from '@salesforce/apex/RegisterCommunityController.getUrlLogoSE';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import TOKENS from '@salesforce/resourceUrl/seTokens';
import sitePath from '@salesforce/community/basePath';
import { reduceErrors, normalizeCuit, formatCuit } from 'c/utils';

export default class SeLogin extends LightningElement {
    sitePath = sitePath;
    email = '';
    code = '';
    identifier = '';
    cuit = '';
    password = '';
    message = '';
    messageVariant = '';
    userId = '';
    focusedField = '';
    cuitError = '';
    showPassword = false;

    isLoging = false;
    isConfirming = false;

    @wire(getUrlLogoSE)
    urlLogoSe;

    connectedCallback() {
        document.documentElement.classList.add('se-chrome', 'se-login-guest');
        document.body.classList.add('se-chrome', 'se-login-guest');
        loadStyle(this, TOKENS).catch((error) => {
            // eslint-disable-next-line no-console
            console.error('seTokens', error);
        });
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-chrome', 'se-login-guest');
        document.body.classList.remove('se-chrome', 'se-login-guest');
    }

    get isProductorPortal() {
        return this.sitePath.includes('PortalArPOV');
    }

    get rootClass() {
        return this.isProductorPortal ? 'se-login-root se-login-root--gradient' : 'se-login-root';
    }

    get backgroundStyle() {
        if (this.isProductorPortal) {
            return '';
        }
        return `background-image:url(${backgroundUrl})`;
    }

    get showSpinner() {
        return this.isLoging || this.isConfirming;
    }

    get usesOtpFlow() {
        return this.sitePath.includes('PortalArPOV') || this.sitePath.includes('Distribuidor');
    }

    get showPasswordField() {
        return !this.usesOtpFlow;
    }

    get showLogo() {
        return Boolean(this.urlLogoSe?.data);
    }

    get cuitFormatted() {
        return formatCuit(this.cuit);
    }

    get isErrorMessage() {
        return this.messageVariant === 'error';
    }

    get messageBannerClass() {
        return 'se-login-banner' + (this.isErrorMessage ? ' se-login-banner--error' : ' se-login-banner--info');
    }

    get cuitInvalid() {
        return Boolean(this.cuitError);
    }

    get cuitErrorId() {
        return this.cuitError ? 'login-cuit-error' : null;
    }

    get passwordInputType() {
        return this.showPassword ? 'text' : 'password';
    }

    get passwordToggleIcon() {
        return this.showPassword ? 'utility:hide' : 'utility:preview';
    }

    get passwordToggleLabel() {
        return this.showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña';
    }

    fieldClass(name, value) {
        let cls = 'se-fl-field';
        if (name === 'password') {
            cls += ' se-fl-field--password';
        }
        if (this.focusedField === name || (value && String(value).length > 0)) {
            cls += ' is-floated';
        }
        if (this.focusedField === name) {
            cls += ' is-focus';
        }
        if (name === 'cuit' && this.cuitError) {
            cls += ' has-error';
        }
        return cls;
    }

    get cuitFieldClass() {
        return this.fieldClass('cuit', this.cuit);
    }

    get emailFieldClass() {
        return this.fieldClass('email', this.email);
    }

    get passwordFieldClass() {
        return this.fieldClass('password', this.password);
    }

    get codeFieldClass() {
        return this.fieldClass('code', this.code);
    }

    handleFieldFocus(event) {
        this.focusedField = event.target.name;
    }

    handleFieldBlur(event) {
        if (this.focusedField === event.target.name) {
            this.focusedField = '';
        }
    }

    handleCuitInput(event) {
        this.cuit = normalizeCuit(event.target.value);
        this.cuitError = '';
        this.clearMessage();
    }

    handleCuitBlur(event) {
        this.handleFieldBlur(event);
        this.cuit = normalizeCuit(event.target.value);
        if (this.cuit && this.cuit.length !== 11) {
            this.cuitError = 'El CUIT debe tener 11 dígitos.';
        }
    }

    handleCuitKeydown(event) {
        if (event.key.length === 1 && !/^[0-9\-]$/.test(event.key)) {
            event.preventDefault();
        }
    }

    handleEmailInput(event) {
        this.email = event.target.value.trim();
        this.clearMessage();
    }

    handlePasswordInput(event) {
        this.password = event.target.value;
        this.clearMessage();
    }

    handleCodeInput(event) {
        this.code = event.target.value.trim();
        this.clearMessage();
    }

    togglePasswordVisibility() {
        this.showPassword = !this.showPassword;
    }

    checkEnterKey(event) {
        if (event.key === 'Enter') {
            if (this.identifier) {
                this.confirm();
            } else {
                this.login();
            }
        }
    }

    validateLoginForm() {
        let valid = true;
        this.cuitError = '';

        if (!this.cuit || this.cuit.length !== 11) {
            this.cuitError = 'Completá tu CUIT con 11 dígitos.';
            valid = false;
        }

        const emailInput = this.template.querySelector('#login-email');
        if (!emailInput?.value?.trim()) {
            emailInput?.setCustomValidity('Completá este campo.');
            emailInput?.reportValidity();
            valid = false;
        } else {
            emailInput.setCustomValidity('');
        }

        if (this.showPasswordField) {
            const passwordInput = this.template.querySelector('#login-password');
            if (!passwordInput?.value) {
                passwordInput?.setCustomValidity('Completá este campo.');
                passwordInput?.reportValidity();
                valid = false;
            } else {
                passwordInput.setCustomValidity('');
            }
        }

        return valid;
    }

    validateConfirmForm() {
        const codeInput = this.template.querySelector('#login-code');
        if (!codeInput?.value?.trim()) {
            codeInput?.setCustomValidity('Completá este campo.');
            codeInput?.reportValidity();
            return false;
        }
        codeInput.setCustomValidity('');
        return true;
    }

    async login() {
        if (!this.validateLoginForm()) return;

        try {
            this.isLoging = true;
            if (this.usesOtpFlow) {
                const result = await login({ email: this.email, cuit: this.cuit });
                const parsed = JSON.parse(result);
                this.identifier = parsed.identifier;
                this.userId = parsed.userId;
                this.showMessage('info', 'Te enviamos un código de seguridad a tu correo electrónico.');
            } else {
                const result = await loginWithPassword({
                    email: this.email,
                    cuit: this.cuit,
                    password: this.password
                });
                window.location = result;
            }
        } catch (e) {
            this.showMessage('error', e);
        } finally {
            this.isLoging = false;
        }
    }

    async confirm() {
        if (!this.validateConfirmForm()) return;

        try {
            this.isConfirming = true;
            const result = await confirmLogin({
                userId: this.userId,
                identifier: this.identifier,
                code: this.code
            });
            window.location = result;
        } catch (e) {
            this.showMessage('error', e);
        } finally {
            this.isConfirming = false;
        }
    }

    cancel() {
        this.identifier = '';
        this.code = '';
        this.clearMessage();
    }

    showMessage(variant, message) {
        this.messageVariant = variant;
        this.message = reduceErrors(message);
    }

    clearMessage() {
        this.message = '';
        this.messageVariant = '';
    }

    register(event) {
        event.preventDefault();
        const path = window.location.pathname.replace('s/login', 's/login2');
        window.location = `${window.location.origin}${path}newselfregister`;
        return false;
    }

    forgotPassword(event) {
        event.preventDefault();
        const path = window.location.pathname.replace('s/login', 's/login2');
        window.location = `${window.location.origin}${path}forgotpassword`;
        return false;
    }
}
