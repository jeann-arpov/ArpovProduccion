import { LightningElement, track } from 'lwc';
import doCreateUser from '@salesforce/apex/RegisterCommunityRegaliaController.doCreateUser';
import loginWithPassword from '@salesforce/apex/RegisterCommunityRegaliaController.loginWithPassword';
import backgroundUrl from '@salesforce/resourceUrl/LoginSiembraEvolucion';
import LOGO_REGALIA_PRODUCTOR from '@salesforce/resourceUrl/LogoRegaliaProductor';
import { NavigationMixin } from 'lightning/navigation';
import { reduceErrors, validateInputs } from 'c/utils';

export default class RegisterCommunity extends NavigationMixin(LightningElement) {

    logoProductor = LOGO_REGALIA_PRODUCTOR;

    // Campos del Formulario
    email = '';
    cuit = '';
    firstName = '';
    lastName = '';
    dni = '';
    password = '';
    passwordConfirm = ''; // Agregado para hacer match con el HTML
    telefono = '';
    code = ''; // Agregado para el flujo de confirmación si existiera

    // Estados de Mensajes y Carga
    variant = '';
    message = '';
    isRegistering = false;
    identifier = ''; // Controla el renderizado del bloque de confirmación en el HTML

    // --- PROPIEDADES PARA EL CONTROL DEL "OJITO" (Contraseña Principal) ---
    showPassword = false;
    get passwordType() {
        return this.showPassword ? 'text' : 'password';
    }
    get passwordIcon() {
        return this.showPassword ? 'utility:preview' : 'utility:hide';
    }
    get passwordAltText() {
        return this.showPassword ? 'Ocultar contraseña' : 'Mostrar contraseña';
    }

    // --- PROPIEDADES PARA EL CONTROL DEL "OJITO" (Confirmar Contraseña) ---
    showPasswordConfirm = false;
    get passwordConfirmType() {
        return this.showPasswordConfirm ? 'text' : 'password';
    }
    get passwordConfirmIcon() {
        return this.showPasswordConfirm ? 'utility:preview' : 'utility:hide';
    }
    get passwordConfirmAltText() {
        return this.showPasswordConfirm ? 'Ocultar confirmación' : 'Mostrar confirmación';
    }

    get backgroundStyle() {
        return `position: fixed;top: 0;background-position: center;background-repeat: no-repeat;z-index: -1;left: 0;width: 100vw;height: 100vh;background-size: cover;background-image:url(${backgroundUrl})`;
    }

    // --- FUNCIONES PARA ALTERNAR VISIBILIDAD (Disparadas por los botones del HTML) ---
    togglePasswordVisibility() {
        this.showPassword = !this.showPassword;
    }

    togglePasswordConfirmVisibility() {
        this.showPasswordConfirm = !this.showPasswordConfirm;
    }

    // Captura de datos en los inputs
    handleChange(event) {
        const fieldName = event.target.name;
        const value = event.target.value.trim();

        if (fieldName === 'email') {
            this.email = value;
        } else if (fieldName === 'cuit') {
            this.cuit = value;
        } else if (fieldName === 'firstName') {
            this.firstName = value;
        } else if (fieldName === 'lastName') {
            this.lastName = value;
        } else if (fieldName === 'dni') {
            this.dni = value;
        } else if (fieldName === 'code') {
            this.code = value;
        } else {
            // Evaluamos por data-id para los campos que no tienen atributo name directo en tu HTML
            const dataId = event.target.dataset.id;
            if (dataId === 'password') {
                this.password = value;
            } else if (dataId === 'passconfirm') {
                this.passwordConfirm = value;
            } else if (dataId === 'phone') {
                this.telefono = value;
            }
        }
    }

    handlePasswordBlur() {
        // Reservado por si ejecutas validaciones complejas de fuerza de clave al salir del campo
    }

    // Nombre de función mapeado exactamente al onclick={register} de tu HTML
    async register() {
        this.variant = '';
        this.message = '';

        // Validamos visualmente que los campos requeridos estén completos
        if (!validateInputs(this.template.querySelector('.registration-form'))) return;

        // Validación lógica: que las contraseñas coincidan antes de ir a Salesforce
        if (this.password !== this.passwordConfirm) {
            this.showToast('error', 'Las contraseñas ingresadas no coinciden.');
            return;
        }

        try {
            this.isRegistering = true;

            // Paso 1: Creación del registro en Apex
           let creationResult = await doCreateUser({
            email: this.email,
            cuit: this.cuit,
            firstName: this.firstName,
            lastName: this.lastName,
            dni: this.dni,
            password: this.password,
            telefono: this.telefono,
            portalContext: 'RegaliaExtendida' 
        });

            // Paso 2: Autenticación e inicio de sesión inmediato si la respuesta es exitosa
            if (creationResult === 'USER_CREATED_SUCCESSFULLY') {
                let redirectUrl = await loginWithPassword({
                    email: this.email,
                    cuit: this.cuit,
                    password: this.password
                });

                if (redirectUrl) {
                    window.location.href = redirectUrl;
                }
            }
        } catch (e) {
            this.showToast('error', e);
        } finally {
            this.isRegistering = false;
        }
    }

    // Funciones adicionales requeridas por las acciones del HTML
    confirm() {
        // Lógica para verificar el código SMS/Email si fuese necesario
    }

    cancel() {
        this.identifier = '';
    }

    login() {
        window.location.href = window.location.origin + '/s/login';
        return false;
    }

    showToast(variant, message) {
        this.variant = variant;
        this.message = reduceErrors(message);
    }

    get messageClass() {
        return this.variant === 'error' ? 'slds-text-color_destructive slds-p-horizontal_small slds-p-bottom_small' : 'slds-p-horizontal_small slds-p-bottom_small';
    }

    get showSpinner() {
        return this.isRegistering;
    }
}