import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import verifyUserCreation from '@salesforce/apex/RegisterCommunityController.verifyUserCreation';
import confirmUserCreation from '@salesforce/apex/RegisterCommunityController.confirmUserCreation';
import doCreateUser from '@salesforce/apex/RegisterCommunityController.doCreateUser';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import seLogoUrl from '@salesforce/resourceUrl/seLogoHorizontal';
import geneticaIconUrl from '@salesforce/resourceUrl/seIconGenetica';
import TOKENS from '@salesforce/resourceUrl/seTokens';
import sitePath from '@salesforce/community/basePath';
import { reduceErrors, normalizeCuit, formatCuit } from 'c/utils';

const PASSWORD_REGEX = /^(?=.*[A-Z])(?=.*\d).{8,}$/;

export default class SeRegister extends LightningElement {
    sitePath = sitePath;
    email = '';
    code = '';
    identifier = '';
    lastName = '';
    firstName = '';
    cuit = '';
    dni = '';
    telefono = '';
    password = '';
    passwordConfirm = '';
    message = '';
    messageVariant = '';
    focusedField = '';
    cuitError = '';
    fieldErrors = {};

    isRegistering = false;
    isConfirming = false;
    helpVisible = false;
    showPassword = false;
    showPasswordConfirm = false;

    geneticaIconUrl = geneticaIconUrl;

    connectedCallback() {
        document.documentElement.classList.add('se-chrome', 'se-register-guest');
        document.body.classList.add('se-chrome', 'se-register-guest');
        loadStyle(this, TOKENS).catch((error) => {
            // eslint-disable-next-line no-console
            console.error('seTokens', error);
        });
    }

    disconnectedCallback() {
        document.documentElement.classList.remove('se-chrome', 'se-register-guest');
        document.body.classList.remove('se-chrome', 'se-register-guest');
    }

    get isProductorPortal() {
        return this.sitePath.includes('PortalArPOV');
    }

    get isPortalArpov() {
        return this.sitePath.includes('PortalArPOV') || this.sitePath.includes('Distribuidor');
    }

    get rootClass() {
        return this.isProductorPortal
            ? 'se-login-root se-login-root--gradient'
            : 'se-login-root';
    }

    get backgroundStyle() {
        if (this.isProductorPortal) {
            return '';
        }
        return `background-image:url(${backgroundUrl})`;
    }

    get logoUrl() {
        return seLogoUrl;
    }

    get showLogo() {
        return Boolean(this.logoUrl);
    }

    get showSpinner() {
        return this.isRegistering || this.isConfirming;
    }

    get requirePhoneNumber() {
        return !this.isPortalArpov;
    }

    get showPasswordFields() {
        return !this.isPortalArpov;
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

    get passwordInputType() {
        return this.showPassword ? 'text' : 'password';
    }

    get passwordConfirmInputType() {
        return this.showPasswordConfirm ? 'text' : 'password';
    }

    get passwordToggleIcon() {
        return this.showPassword ? 'utility:hide' : 'utility:preview';
    }

    get passwordConfirmToggleIcon() {
        return this.showPasswordConfirm ? 'utility:hide' : 'utility:preview';
    }

    get helpTooltipClass() {
        return 'se-password-help-panel' + (this.helpVisible ? ' is-visible' : '');
    }

    fieldClass(name, value) {
        let cls = 'se-fl-field';
        if (name === 'password' || name === 'passwordConfirm') {
            cls += ' se-fl-field--password';
        }
        if (name === 'password') {
            cls += ' se-fl-field--password-help';
        }
        if (this.focusedField === name || (value && String(value).length > 0)) {
            cls += ' is-floated';
        }
        if (this.focusedField === name) {
            cls += ' is-focus';
        }
        if (this.fieldErrors[name]) {
            cls += ' has-error';
        }
        if (name === 'cuit' && this.cuitError) {
            cls += ' has-error';
        }
        return cls;
    }

    get cuitFieldClass() {
        return this.fieldClass('cuit', this.cuit);
    }

    get dniFieldClass() {
        return this.fieldClass('dni', this.dni);
    }

    get firstNameFieldClass() {
        return this.fieldClass('firstName', this.firstName);
    }

    get lastNameFieldClass() {
        return this.fieldClass('lastName', this.lastName);
    }

    get phoneFieldClass() {
        return this.fieldClass('telefono', this.telefono);
    }

    get emailFieldClass() {
        return this.fieldClass('email', this.email);
    }

    get passwordFieldClass() {
        return this.fieldClass('password', this.password);
    }

    get passwordConfirmFieldClass() {
        return this.fieldClass('passwordConfirm', this.passwordConfirm);
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

    clearFieldError(name) {
        if (this.fieldErrors[name]) {
            const next = { ...this.fieldErrors };
            delete next[name];
            this.fieldErrors = next;
        }
    }

    setFieldError(name, text) {
        this.fieldErrors = { ...this.fieldErrors, [name]: text };
    }

    handleCuitInput(event) {
        this.cuit = normalizeCuit(event.target.value);
        this.cuitError = '';
        this.clearFieldError('cuit');
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

    handleCodeInput(event) {
        this.code = event.target.value.trim();
        this.clearFieldError('code');
        this.clearMessage();
    }

    handleTextInput(event) {
        const { name, value } = event.target;
        this[name] = value.trim();
        this.clearFieldError(name);
        this.clearMessage();
    }

    handlePhoneInput(event) {
        this.telefono = event.target.value.trim();
        this.clearFieldError('telefono');
        this.clearMessage();
    }

    handlePasswordInput(event) {
        this.password = event.target.value;
        this.clearFieldError('password');
        this.clearMessage();
        if (this.passwordConfirm) {
            this.validatePasswordMatch();
        }
    }

    handlePasswordConfirmInput(event) {
        this.passwordConfirm = event.target.value;
        this.clearFieldError('passwordConfirm');
        this.clearMessage();
        this.validatePasswordMatch();
    }

    handlePasswordBlur() {
        if (this.password && !PASSWORD_REGEX.test(this.password)) {
            this.setFieldError('password', 'Mínimo 8 caracteres, una mayúscula y un número.');
        }
    }

    validatePasswordMatch() {
        if (!this.passwordConfirm) {
            return;
        }
        if (this.password !== this.passwordConfirm) {
            this.setFieldError('passwordConfirm', 'Las contraseñas no coinciden.');
        } else {
            this.clearFieldError('passwordConfirm');
        }
    }

    togglePasswordVisibility() {
        this.showPassword = !this.showPassword;
    }

    togglePasswordConfirmVisibility() {
        this.showPasswordConfirm = !this.showPasswordConfirm;
    }

    toggleHelp() {
        this.helpVisible = !this.helpVisible;
    }

    validateRegisterForm() {
        let valid = true;
        this.cuitError = '';
        this.fieldErrors = {};

        if (!this.cuit || this.cuit.length !== 11) {
            this.cuitError = 'Completá tu CUIT con 11 dígitos.';
            valid = false;
        }

        const required = [
            { name: 'dni', value: this.dni, label: 'DNI' },
            { name: 'firstName', value: this.firstName, label: 'Nombre' },
            { name: 'lastName', value: this.lastName, label: 'Apellido' },
            { name: 'email', value: this.email, label: 'Email' }
        ];

        if (this.requirePhoneNumber) {
            required.push({ name: 'telefono', value: this.telefono, label: 'Número de celular' });
        }

        required.forEach((field) => {
            if (!field.value) {
                this.setFieldError(field.name, `Completá ${field.label.toLowerCase()}.`);
                valid = false;
            }
        });

        if (this.requirePhoneNumber && this.telefono) {
            const phonePattern = /^\+[1-9]{1}[0-9]{3,14}$/;
            if (this.telefono.includes('+54') && !this.telefono.includes('+549')) {
                this.setFieldError(
                    'telefono',
                    'Un teléfono celular debe comenzar con +549, seguido del código de ciudad y el número.'
                );
                valid = false;
            } else if (!phonePattern.test(this.telefono)) {
                this.setFieldError('telefono', 'Ingresá un teléfono válido con formato internacional (+...).');
                valid = false;
            }
        }

        const emailInput = this.template.querySelector('#register-email');
        if (emailInput) {
            if (!emailInput.value?.trim()) {
                valid = false;
            } else if (!emailInput.checkValidity()) {
                this.setFieldError('email', 'Ingresá un email válido.');
                valid = false;
            }
        }

        if (this.showPasswordFields) {
            if (!this.password) {
                this.setFieldError('password', 'Completá la contraseña.');
                valid = false;
            } else if (!PASSWORD_REGEX.test(this.password)) {
                this.setFieldError('password', 'Mínimo 8 caracteres, una mayúscula y un número.');
                valid = false;
            }

            if (!this.passwordConfirm) {
                this.setFieldError('passwordConfirm', 'Confirmá la contraseña.');
                valid = false;
            } else if (this.password !== this.passwordConfirm) {
                this.setFieldError('passwordConfirm', 'Las contraseñas no coinciden.');
                valid = false;
            }
        }

        return valid;
    }

    validateConfirmForm() {
        if (!this.code?.trim()) {
            this.setFieldError('code', 'Completá el código.');
            return false;
        }
        this.clearFieldError('code');
        return true;
    }

    async register() {
        if (!this.validateRegisterForm()) {
            return;
        }

        try {
            this.isRegistering = true;
            if (this.isPortalArpov) {
                this.identifier = await verifyUserCreation({
                    firstName: this.firstName,
                    lastName: this.lastName,
                    email: this.email,
                    cuit: this.cuit,
                    dni: this.dni
                });
                this.showMessage('info', 'Te enviamos un código de seguridad a tu correo electrónico.');
            } else {
                const result = await doCreateUser({
                    firstName: this.firstName,
                    lastName: this.lastName,
                    email: this.email,
                    cuit: this.cuit,
                    dni: this.dni,
                    password: this.password,
                    telefono: this.telefono
                });
                window.location = result;
            }
        } catch (e) {
            this.showMessage('error', e);
        } finally {
            this.isRegistering = false;
        }
    }

    async confirm() {
        if (!this.validateConfirmForm()) {
            return;
        }

        try {
            this.isConfirming = true;
            const result = await confirmUserCreation({
                identifier: this.identifier,
                code: this.code,
                email: this.email,
                cuit: this.cuit
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

    goToLogin(event) {
        event.preventDefault();
        const path = window.location.pathname.replace('s/login2/newselfregister', 's/login');
        window.location = `${window.location.origin}${path}`;
        return false;
    }
}
