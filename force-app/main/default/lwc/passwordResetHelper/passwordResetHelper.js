import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import searchUsersByEmail from '@salesforce/apex/PasswordResetController.searchUsersByEmail';
import getUserDetails from '@salesforce/apex/PasswordResetController.getUserDetails';
import resetUserPassword from '@salesforce/apex/PasswordResetController.resetUserPassword';

export default class PasswordResetHelper extends LightningElement {
    @track searchEmail = '';
    @track searchCuit = '';
    @track searchResults = [];
    @track selectedUser = null;
    @track newPassword = '';
    @track confirmPassword = '';
    @track isLoading = false;
    @track showResult = false;
    @track isSuccess = false;
    @track resultMessage = {};
    @track errorMessage = '';
    @track showNoResults = false;

    /**
     * Maneja el cambio en el campo de email de búsqueda
     */
    handleEmailChange(event) {
        this.searchEmail = event.target.value.trim();
        this.searchResults = [];
        this.showNoResults = false;
    }

    handleCuitChange(event) {
        const digitsOnly = (event.target.value || '').replace(/\D/g, '');
        this.searchCuit = digitsOnly.slice(0, 11);
        this.searchResults = [];
        this.showNoResults = false;
    }

    handleSearchByEnter(event) {
        if (event.key === 'Enter' && !this.isSearchDisabled) {
            this.performSearch();
        }
    }

    handleSearchClick() {
        this.performSearch();
    }

    /**
     * Realiza la búsqueda de usuarios
     */
    performSearch() {
        if (this.isSearchDisabled) {
            return;
        }

        this.isLoading = true;
        
        searchUsersByEmail({ email: this.searchEmail, cuit: this.searchCuit })
            .then(results => {
                this.searchResults = results || [];
                this.showNoResults = this.searchResults.length === 0;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error en búsqueda:', error);
                this.showNotification('Error', error.body?.message || 'Error en la búsqueda', 'error');
                this.isLoading = false;
            });
    }

    /**
     * Maneja la selección de un usuario de la lista
     */
    handleSelectUser(event) {
        const userId = event.currentTarget.dataset.userId;
        
        this.isLoading = true;
        
        getUserDetails({ userId: userId })
            .then(user => {
                this.selectedUser = user;
                this.searchResults = [];
                this.showNoResults = false;
                this.newPassword = '';
                this.confirmPassword = '';
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error al obtener usuario:', error);
                this.showNotification('Error', error.body?.message || 'Error al obtener usuario', 'error');
                this.isLoading = false;
            });
    }

    /**
     * Maneja el cambio en el campo de nueva contraseña
     */
    handlePasswordChange(event) {
        this.newPassword = event.target.value;
    }

    /**
     * Maneja el cambio en el campo de confirmación
     */
    handleConfirmPasswordChange(event) {
        this.confirmPassword = event.target.value;
    }

    /**
     * Valida que las contraseñas cumplan requisitos mínimos
     */
    get isPasswordValid() {
        return !this.newPassword || this.newPassword.length >= 8;
    }

    /**
     * Valida que las contraseñas coincidan
     */
    get passwordsMatch() {
        return !this.confirmPassword || this.newPassword === this.confirmPassword;
    }

    /**
     * Valida que el formulario sea válido
     */
    get isFormValid() {
        return Boolean(
            this.newPassword &&
            this.confirmPassword &&
            this.passwordsMatch &&
            this.isPasswordValid
        );
    }

    get isSaveDisabled() {
        return this.isLoading || !this.isFormValid;
    }

    get isCuitValid() {
        return this.searchCuit.length === 0 || this.searchCuit.length === 11;
    }

    get canSearch() {
        return this.searchEmail.length >= 5 && this.searchCuit.length === 11;
    }

    get isSearchDisabled() {
        return this.isLoading || !this.canSearch;
    }

    /**
     * Valida que el usuario esté seleccionado
     */
    get userSelected() {
        return this.selectedUser !== null && !this.showResult;
    }

    /**
     * Obtiene la clase CSS para el contenedor de resultado
     */
    get getResultContainerClass() {
        return `result-container ${this.isSuccess ? 'success-state' : 'error-state'}`;
    }

    /**
     * Clases de pasos para binding en template (LWC no permite invocar funciones con argumentos)
     */
    get searchStepContainerClass() {
        return `step-container ${this.userSelected ? 'completed' : 'active'}`;
    }

    get passwordStepContainerClass() {
        return 'step-container active';
    }

    get stepOneBadgeClass() {
        return `step-badge ${this.userSelected ? 'completed-step' : 'active-step'}`;
    }

    get stepTwoBadgeClass() {
        return 'step-badge active-step';
    }

    /**
     * Maneja el reset de contraseña
     */
    handleResetPassword() {
        this.isLoading = true;
        
        resetUserPassword({ 
            userId: this.selectedUser.id, 
            newPassword: this.newPassword 
        })
            .then(result => {
                this.isSuccess = true;
                this.resultMessage = result;
                this.showResult = true;
                this.isLoading = false;
                this.showNotification('Éxito', result.message, 'success');
            })
            .catch(error => {
                this.isSuccess = false;
                this.errorMessage = error.body?.message || error.message || 'Error desconocido';
                this.showResult = true;
                this.isLoading = false;
                this.showNotification('Error', this.errorMessage, 'error');
            });
    }

    /**
     * Regresa a la búsqueda inicial
     */
    handleBackToSearch() {
        this.selectedUser = null;
        this.newPassword = '';
        this.confirmPassword = '';
        this.showResult = false;
        this.errorMessage = '';
    }

    /**
     * Reinicia el componente completo
     */
    handleReset() {
        this.searchEmail = '';
        this.searchCuit = '';
        this.searchResults = [];
        this.selectedUser = null;
        this.newPassword = '';
        this.confirmPassword = '';
        this.showResult = false;
        this.isSuccess = false;
        this.resultMessage = {};
        this.errorMessage = '';
        this.showNoResults = false;
    }

    /**
     * Muestra una notificación
     */
    showNotification(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({
                title,
                message,
                variant
            })
        );
    }
}