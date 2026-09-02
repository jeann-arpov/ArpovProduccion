import { LightningElement, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import apexInitLogin from '@salesforce/apex/RegisterCommunityController.login';
import apexConfirmLogin from '@salesforce/apex/RegisterCommunityController.confirmLogin';
import apexLoginWithPassword from '@salesforce/apex/RegisterCommunityController.loginWithPassword';
import getUrlLogoSE from '@salesforce/apex/RegisterCommunityController.getUrlLogoSE';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import seLogoUrl from '@salesforce/resourceUrl/seLogoHorizontal';
import geneticaIconUrl from '@salesforce/resourceUrl/seIconGenetica';
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
        return true;
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

    geneticaIconUrl = geneticaIconUrl;

    get logoUrl() {
        return seLogoUrl || this.urlLogoSe?.data;
    }

    get showLogo() {
        return Boolean(this.logoUrl);
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

    getDebugState() {
        return {
            sitePath: this.sitePath,
            usesOtpFlow: this.usesOtpFlow,
            showPasswordField: this.showPasswordField,
            cuit: this.cuit,
            email: this.email,
            hasPassword: Boolean(this.password),
            identifier: this.identifier,
            isLoging: this.isLoging
        };
    }

    logLoginClick() {
        this.syncFormState();
        // eslint-disable-next-line no-console
        console.log('[seLogin] click Ingresar', this.getDebugState());
    }

    checkEnterKey(event) {
        if (event.key === 'Enter') {
            event.preventDefault();
            this.handleSubmit(event);
        }
    }

    syncFormState() {
        const cuitInput = this.template.querySelector('#login-cuit');
        const emailInput = this.template.querySelector('#login-email');
        const passwordInput = this.template.querySelector('#login-password');

        if (cuitInput) {
            this.cuit = normalizeCuit(cuitInput.value);
        }
        if (emailInput) {
            this.email = emailInput.value.trim();
        }
        if (passwordInput) {
            this.password = passwordInput.value || this.password;
        }
    }

    isValidEmail(value) {
        return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value || '');
    }

    validateLoginForm() {
        this.syncFormState();

        const errors = [];
        this.cuitError = '';

        if (!this.cuit || this.cuit.length !== 11) {
            this.cuitError = 'Completá tu CUIT con 11 dígitos.';
            errors.push('cuit');
        }

        if (!this.email) {
            errors.push('email-empty');
        } else if (!this.isValidEmail(this.email)) {
            errors.push('email-format');
        }

        if (this.showPasswordField && !this.password) {
            errors.push('password');
        }

        const valid = errors.length === 0;

        // eslint-disable-next-line no-console
        console.log('[seLogin] validateLoginForm', { valid, errors, state: this.getDebugState() });

        if (!valid && (errors.includes('email-empty') || errors.includes('email-format'))) {
            this.showMessage('error', 'Ingresá un email válido.');
        } else if (!valid && errors.includes('password')) {
            this.showMessage('error', 'Completá tu contraseña.');
        }

        return valid;
    }

    validateConfirmForm() {
        const codeInput = this.template.querySelector('#login-code');
        if (codeInput) {
            this.code = codeInput.value.trim();
        }
        if (!this.code) {
            return false;
        }
        return true;
    }

    handleSubmit(event) {
        event?.preventDefault();
        // eslint-disable-next-line no-console
        console.log('[seLogin] handleSubmit', this.getDebugState());
        if (this.identifier) {
            this.confirm();
        } else {
            this.handleLogin();
        }
    }

    async handleLogin() {
        // eslint-disable-next-line no-console
        console.log('[seLogin] handleLogin start', this.getDebugState());

        if (!this.validateLoginForm()) {
            // eslint-disable-next-line no-console
            console.warn('[seLogin] handleLogin abortado: validación falló');
            return;
        }

        try {
            this.isLoging = true;
            if (this.usesOtpFlow) {
                // eslint-disable-next-line no-console
                console.log('[seLogin] llamando apexInitLogin (OTP)');
                const result = await apexInitLogin({ email: this.email, cuit: this.cuit });
                // eslint-disable-next-line no-console
                console.log('[seLogin] apexInitLogin ok', result);
                const parsed = JSON.parse(result);
                this.identifier = parsed.identifier;
                this.userId = parsed.userId;
                this.showMessage('info', 'Te enviamos un código de seguridad a tu correo electrónico.');
            } else {
                // eslint-disable-next-line no-console
                console.log('[seLogin] llamando apexLoginWithPassword');
                const result = await apexLoginWithPassword({
                    email: this.email,
                    cuit: this.cuit,
                    password: this.password
                });
                // eslint-disable-next-line no-console
                console.log('[seLogin] apexLoginWithPassword ok', result);
                if (result) {
                    window.location.assign(result);
                } else {
                    this.showMessage('error', 'No se pudo iniciar sesión. Intentá de nuevo.');
                }
            }
        } catch (e) {
            // eslint-disable-next-line no-console
            console.error('[seLogin] handleLogin error', e);
            this.showMessage('error', e);
        } finally {
            this.isLoging = false;
        }
    }

    async confirm() {
        this.syncFormState();
        if (!this.validateConfirmForm()) return;

        try {
            this.isConfirming = true;
            const result = await apexConfirmLogin({
                userId: this.userId,
                identifier: this.identifier,
                code: this.code
            });
            if (result) {
                window.location.assign(result);
            } else {
                this.showMessage('error', 'No se pudo confirmar el código. Intentá de nuevo.');
            }
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
