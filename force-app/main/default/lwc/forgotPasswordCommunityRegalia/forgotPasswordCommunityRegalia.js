import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import handleForgotPassword from '@salesforce/apex/RegisterCommunityRegaliaController.handleForgotPassword';
import { reduceErrors } from 'c/utils';

export default class ForgotPasswordCommunityRegalia extends NavigationMixin(LightningElement) {
    email = '';

    // Estados de UI
    isProcessing = false;
    message = '';
    variant = ''; // 'error' o 'success'

    connectedCallback() {
        console.log('🔵 [ForgotPassword] Componente cargado e inicializado con éxito en el DOM.');
    }

    handleEmailChange(event) {
        this.email = event.target.value.trim();
        console.log('🔵 [ForgotPassword] Cambio en input de Email. Valor actual:', this.email);
    }

    get showSpinner() {
        return this.isProcessing;
    }

    get messageClass() {
        return this.variant === 'error' 
            ? 'slds-text-color_destructive slds-p-vertical_small' 
            : 'slds-text-color_success slds-p-vertical_small slds-font-weight_bold';
    }

    async handleSubmit(event) {
        event.preventDefault(); 
        console.log('🔵🔵🔵 [ForgotPassword] FORMULARIO ENVIADO (handleSubmit iniciado) 🔵🔵🔵');
        
        this.message = '';
        this.variant = '';

        if (!this.email) {
            console.warn('⚠️ [ForgotPassword] Validación fallida: El campo de Email está vacío.');
            this.showToast('error', 'Por favor, ingresa tu correo electrónico.');
            return;
        }

        try {
            this.isProcessing = true;
            console.log('🚀 [ForgotPassword] Intentando llamar a Apex (handleForgotPassword) con el parámetro:', JSON.stringify({ email: this.email }));

            // Llamada al método Apex pasando únicamente el email
            await handleForgotPassword({ email: this.email });

            console.log('✅ [ForgotPassword] RESPUESTA DE APEX: ¡Método ejecutado exitosamente sin excepciones!');

            // Mensaje de éxito estándar de seguridad
            this.showToast('success', 'Si el correo electrónico ingresado corresponde a un usuario activo, recibirás un mensaje con las instrucciones para restablecer tu contraseña en unos minutos.');
            this.email = '';
            
        } catch (error) {
            console.error('❌❌❌ [ForgotPassword] ERROR DETECTADO AL LLAMAR A APEX ❌❌❌');
            console.error('❌ Error Completo:', error);
            console.error('❌ Mensaje Reducido:', reduceErrors(error));
            this.showToast('error', error);
        } finally {
            this.isProcessing = false;
            console.log('🔵 [ForgotPassword] Flujo finalizado, isProcessing establecido a false.');
        }
    }

    handleBackToLogin(event) {
        event.preventDefault();
        console.log('🔵 [ForgotPassword] Click en volver al Login. Ejecutando navegación nativa...');
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                name: 'Login'
            }
        });
    }

    showToast(variant, errorMsg) {
        console.log(`📢 [ForgotPassword] Mostrando mensaje en UI. Variante: [${variant}], Contenido:`, errorMsg);
        this.variant = variant;
        this.message = variant === 'error' ? reduceErrors(errorMsg) : errorMsg;
    }
}