import { LightningElement, wire } from 'lwc';
import verifyUserCreation from '@salesforce/apex/RegisterCommunityController.verifyUserCreation';
import confirmUserCreation from '@salesforce/apex/RegisterCommunityController.confirmUserCreation';
import doCreateUser from '@salesforce/apex/RegisterCommunityController.doCreateUser';
import getUrlLogoSE from '@salesforce/apex/RegisterCommunityController.getUrlLogoSE';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import sitePath from '@salesforce/community/basePath';
import { reduceErrors, validateInputs, normalizeCuit, formatCuit } from 'c/utils';

export default class RegisterCommunity extends LightningElement {
    sitePath = sitePath;

    // -------- Campos del formulario --------
    email = '';
    code = '';
    identifier = '';
    lastName = ''; // CORREGIDO: Cambiado de 'lastname' a 'lastName'
    firstName = ''; // CORREGIDO: Cambiado de 'firstname' a 'firstName'
    cuit = '';
    dni = '';
    telefono = '';
    password = '';
    passwordConfirm = '';

    // -------- Estado UI --------
    variant = '';
    _message = '';
    showMessage = false;
    isRegistering = false;

    setMessage(value) {
        this._message = value;
        this.showMessage = !!value;
        setTimeout(() => {
            const messageContainer = this.template.querySelector('[data-message-container]');
            if (messageContainer && this._message) {
                messageContainer.innerHTML = this._message;
            }
        }, 0);
    }
    isConfirming = false;
    helpVisible = false;
    passwordVisible = false;
    passwordConfirmVisible = false;

    @wire(getUrlLogoSE)
    urlLogoSe;

    // -------- Getters para UI dinámica --------
    get passwordType() {
        return this.passwordVisible ? 'text' : 'password';
    }
    get passwordIcon() {
        return this.passwordVisible ? 'utility:hide' : 'utility:preview';
    }
    get passwordAltText() {
        return this.passwordVisible ? 'Ocultar contraseña' : 'Mostrar contraseña';
    }

    get passwordConfirmType() {
        return this.passwordConfirmVisible ? 'text' : 'password';
    }
    get passwordConfirmIcon() {
        return this.passwordConfirmVisible ? 'utility:hide' : 'utility:preview';
    }
    get passwordConfirmAltText() {
        return this.passwordConfirmVisible ? 'Ocultar contraseña' : 'Mostrar contraseña';
    }

    get tooltipClass() {
        return this.helpVisible ? 'tooltip visible' : 'tooltip';
    }

    get backgroundStyle() {
        return `position: fixed;top: 0;background-position: center;background-repeat: no-repeat;z-index: -1;left: 0;width: 100vw;height: 100vh;background-size: cover;background-image:url(${backgroundUrl})`;
    }

    get messageClass() {
        return this.variant === 'error'
            ? 'slds-text-color_destructive slds-p-horizontal_small'
            : 'slds-p-horizontal_small';
    }

    get title() {
        return this.identifier ? 'Confirmación' : 'Registración';
    }

    get showSpinner() {
        return this.isRegistering || this.isConfirming;
    }

    get isPortalArpov() {
        return this.sitePath.includes('PortalArPOV') || this.sitePath.includes('Distribuidor');
    }

    get requirePhoneNumber() {
        return !this.isPortalArpov;
    }

    get errorRegexPhone() {
        return 'Un teléfono celular debe comenzar con +549, seguido del código de ciudad y luego el número de abonado';
    }

    // -------- Eventos UI --------
    cancel() {
        console.log('🔵 cancel() ejecutado');
        this.identifier = '';
    }

    toggleHelp() {
        console.log('🔵 toggleHelp() ejecutado');
        this.helpVisible = !this.helpVisible;
    }

    togglePasswordVisibility() {
        console.log('🔵 togglePasswordVisibility() ejecutado');
        this.passwordVisible = !this.passwordVisible;
    }

    togglePasswordConfirmVisibility() {
        console.log('🔵 togglePasswordConfirmVisibility() ejecutado');
        this.passwordConfirmVisible = !this.passwordConfirmVisible;
    }

    handleChange(event) {
        console.log('🔵 handleChange() ejecutado');
        console.log('🔵 Event target:', event.target);
        console.log('🔵 Placeholder:', event.target.placeholder);
        console.log('🔵 Value:', event.target.value);
        
        const label = event.target.placeholder;
        const value = event.target.value.trim();

        if (label === 'Email') {
            this.email = value;
            console.log('🔵 Email actualizado:', value);
        } else if (label === 'Código') {
            this.code = value;
            console.log('🔵 Código actualizado:', value);
        } else if (label === 'Nombre') {
            this.firstName = value;
            console.log('🔵 FirstName actualizado:', value);
        } else if (label === 'Apellido') {
            this.lastName = value;
            console.log('🔵 LastName actualizado:', value);
        } else if (label === 'CUIT') {
            this.cuit = normalizeCuit(value);
            console.log('🔵 CUIT actualizado:', value);
        } else if (label === 'DNI') {
            this.dni = value;
            console.log('🔵 DNI actualizado:', value);
        } else if (label === 'Contraseña') {
            this.password = value;
            console.log('🔵 Password actualizado:', value);
            const inputCmp = this.template.querySelector('lightning-input[data-id="password"]');

            // Validación manual del patrón
            const regex = /^(?=.*[A-Z])(?=.*\d).{8,}$/;
            if (!regex.test(value)) {
                inputCmp.setCustomValidity('Formato invalido');
                console.log('❌ Password no cumple formato');
            } else {
                inputCmp.setCustomValidity('');
                console.log('✅ Password válido');
            }
            inputCmp.reportValidity();

            // Validar confirmación si ya hay valor
            const confirmCmp = this.template.querySelector('lightning-input[data-id="passconfirm"]');
            if (this.passwordConfirm) {
                if (this.password !== this.passwordConfirm) {
                    confirmCmp.setCustomValidity('Las contraseñas no coinciden');
                    console.log('❌ Passwords no coinciden');
                } else {
                    confirmCmp.setCustomValidity('');
                    console.log('✅ Passwords coinciden');
                }
                confirmCmp.reportValidity();
            }

        } else if (label === 'Número de celular') {
            this.telefono = value;
            console.log('🔵 Teléfono actualizado:', value);
            const inputCmp = this.template.querySelector('lightning-input[data-id="phone"]');
            if (value.includes('+54') && !value.includes('+549')) {
                inputCmp.setCustomValidity(this.errorRegexPhone);
                console.log('❌ Teléfono no cumple formato');
            } else {
                inputCmp.setCustomValidity('');
                console.log('✅ Teléfono válido');
            }
            inputCmp.reportValidity();
        } else if (label === 'Confirmar Contraseña') {
            this.passwordConfirm = value;
            console.log('🔵 PasswordConfirm actualizado:', value);
            const inputCmp = this.template.querySelector('lightning-input[data-id="passconfirm"]');
            if (this.password !== this.passwordConfirm) {
                inputCmp.setCustomValidity('Las contraseñas no coinciden');
                console.log('❌ Passwords no coinciden');
            } else {
                inputCmp.setCustomValidity('');
                console.log('✅ Passwords coinciden');
            }
            inputCmp.reportValidity();
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

    // -------- Registro y confirmación --------
    async register() {
        console.log('🔵🔵🔵 REGISTER() INICIADO 🔵🔵🔵');
        console.log('🔵 Validando formulario...');
        
        if (!validateInputs(this.template.querySelector('.registration-form'))) {
            console.log('❌ Validación de formulario falló');
            return;
        }
        
        console.log('✅ Validación de formulario exitosa');
        
        try {
            this.isRegistering = true;
            console.log('🔵 isRegistering establecido a true');
            
            if (this.isPortalArpov) {
                console.log('🔵 Registro para PortalArPOV');
                const result = await verifyUserCreation({
                    firstName: this.firstName,
                    lastName: this.lastName,
                    email: this.email,
                    cuit: this.cuit,
                    dni: this.dni
                });
                this.identifier = result;
                console.log('✅ verifyUserCreation exitoso, identifier:', result);
                this.showToast('info', 'Ingresar el código de seguridad enviado a su correo electrónico');
            } else {
                console.log('🔵🔵🔵 REGISTRO PARA SEMBRÁ EVOLUCIÓN 🔵🔵🔵');
                console.log('🔵 Datos a enviar:');
                console.log('🔵 firstName:', this.firstName);
                console.log('🔵 lastName:', this.lastName);
                console.log('🔵 email:', this.email);
                console.log('🔵 cuit:', this.cuit);
                console.log('🔵 dni:', this.dni);
                console.log('🔵 telefono:', this.telefono);
                console.log('🔵 password:', '[PROTEGIDO]');
                
                console.log('🔵 Llamando a doCreateUser...');
                const result = await doCreateUser({
                    firstName: this.firstName,
                    lastName: this.lastName,
                    email: this.email,
                    cuit: this.cuit,
                    dni: this.dni,
                    password: this.password,
                    telefono: this.telefono
                });
                
                console.log('✅✅✅ doCreateUser EXITOSO 🔵🔵🔵');
                console.log('✅ Resultado:', result);
                console.log('🔵 Redirigiendo a:', result);
                window.location = result;
            }
        } catch (e) {
            console.error('❌❌❌ ERROR EN REGISTER() ❌❌❌');
            console.error('❌ Error completo:', e);
            console.error('❌ Mensaje:', e.message);
            console.error('❌ Stack:', e.stack);
            this.showToast('error', e);
        } finally {
            this.isRegistering = false;
            console.log('🔵 isRegistering establecido a false');
        }
    }

    async confirm() {
        console.log('🔵 confirm() ejecutado');
        if (!validateInputs(this.template.querySelector('.confirmation-form'))) return;
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
            this.showToast('error', e);
        } finally {
            this.isConfirming = false;
        }
    }

    showToast(variant, message) {
        console.log('🔵 showToast() ejecutado:', variant, message);
        this.variant = variant;
        const errors = reduceErrors(message);
        this.setMessage(Array.isArray(errors) ? errors.join('<br>') : errors);
    }

    login() {
        console.log('🔵 login() ejecutado');
        window.location = window.location.origin + window.location.pathname.replace('/SelfRegister', '') + window.location.search;
        return false;
    }

    handleNavigate() {
        console.log('🔵 handleNavigate() ejecutado');
        const path = window.location.pathname;
        const newpath = path.replace('s/login2/newselfregister', 's/login');
        window.location = window.location.origin + newpath;
        return false;
    }

    handlePasswordBlur(event) {
        console.log('🔵 handlePasswordBlur() ejecutado');
        const inputCmp = event.target;
        const value = inputCmp.value.trim();
        const regex = /^(?=.*[A-Z])(?=.*\d).{8,}$/;
        console.log('🔵 Validación password:', regex.test(value));
        // Si el valor ahora es válido, limpia cualquier mensaje previo
        if (regex.test(value)) {
            inputCmp.setCustomValidity('');
            inputCmp.reportValidity();
        }
    }

    // Método para verificar que el componente se carga
    connectedCallback() {
        console.log('🔵🔵🔵 COMPONENTE REGISTERCOMMUNITY CARGADO 🔵🔵🔵');
        console.log('🔵 sitePath:', this.sitePath);
        console.log('🔵 isPortalArpov:', this.isPortalArpov);
        console.log('🔵 requirePhoneNumber:', this.requirePhoneNumber);
    }
}