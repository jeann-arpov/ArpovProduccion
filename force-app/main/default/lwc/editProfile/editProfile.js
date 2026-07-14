import { LightningElement, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import doChangePassword from '@salesforce/apex/editProfileController.changeUserPassword';
import getProfileInfo from '@salesforce/apex/editProfileController.getUserInfo';
import UpdateUser from '@salesforce/apex/editProfileController.editUser';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

const SUCCESS_PASSWORD_MSG = 'Success: Your password has been changed successfully.';

export default class EditProfile extends NavigationMixin(LightningElement) {

    userId = USER_ID;
    userName;
    oldPassword = '';
    newPassword = '';
    newPasswordConfirm = '';

    @track fullName;
    @track businessName;
    @track documentId;
    @track cuit;
    @track mobilePhone;
    @track email;
    @track modal = false;
    @track modalpass = false;
    @track isUpdating = false;
    @track isChangingPassword = false;

    @track showOldPassword = false;
    @track showNewPassword = false;
    @track showConfirmPassword = false;

    @wire(getProfileInfo)
    wiredInfo({ error, data }) {
        if (data) {
            this.fullName = data[0].Nombre_Completo__c;
            this.businessName = data[0].Razon_Social__c;
            this.documentId = data[0].Numero_de_Documento__c;
            this.cuit = data[0].Account.N_CUIT__c;
            this.email = data[0].Email;
            this.mobilePhone = data[0].MobilePhone;
        } else if (error) {
            console.error('Error loading profile:', error);
        }
    }

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD);
        } else if (error) {
            console.error('Error fetching user details:', error);
        }
    }

    get oldPasswordType() {
        return this.showOldPassword ? 'text' : 'password';
    }

    get newPasswordType() {
        return this.showNewPassword ? 'text' : 'password';
    }

    get confirmPasswordType() {
        return this.showConfirmPassword ? 'text' : 'password';
    }

    get oldPasswordToggleIcon() {
        return this.showOldPassword ? 'utility:preview' : 'utility:hide';
    }

    get newPasswordToggleIcon() {
        return this.showNewPassword ? 'utility:preview' : 'utility:hide';
    }

    get confirmPasswordToggleIcon() {
        return this.showConfirmPassword ? 'utility:preview' : 'utility:hide';
    }

    handleEmail(event) {
        this.email = event.target.value;
    }

    handlePhone(event) {
        this.mobilePhone = event.target.value;
    }

    openModal() {
        this.modal = true;
    }

    openModalPass() {
        if (!this.validatePasswordForm()) {
            return;
        }
        this.modalpass = true;
    }

    closeModal() {
        this.modal = false;
        this.modalpass = false;
    }

    handleBackdropClick() {
        if (!this.isUpdating && !this.isChangingPassword) {
            this.closeModal();
        }
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    validatePhoneNumber(phone) {
        return /^\+549\d{10}$/.test(phone);
    }

    validatePasswordForm() {
        if (!this.oldPassword?.trim()) {
            this.showToast('Datos incompletos', 'Ingresá tu contraseña actual.', 'warning');
            return false;
        }
        if (!this.newPassword?.trim()) {
            this.showToast('Datos incompletos', 'Ingresá la nueva contraseña.', 'warning');
            return false;
        }
        if (!this.newPasswordConfirm?.trim()) {
            this.showToast('Datos incompletos', 'Confirmá la nueva contraseña.', 'warning');
            return false;
        }
        if (this.newPassword !== this.newPasswordConfirm) {
            this.showToast('Error', 'Las contraseñas no coinciden.', 'error');
            const inputCmp = this.template.querySelector('lightning-input[data-id="newPasswordConfirm"]');
            if (inputCmp) {
                inputCmp.setCustomValidity('Las contraseñas no coinciden');
                inputCmp.reportValidity();
            }
            return false;
        }
        return true;
    }

    clearPasswordFields() {
        this.oldPassword = '';
        this.newPassword = '';
        this.newPasswordConfirm = '';
        this.showOldPassword = false;
        this.showNewPassword = false;
        this.showConfirmPassword = false;
    }

    handleUpdate() {
        if (!this.validatePhoneNumber(this.mobilePhone)) {
            this.showToast('Error', 'El celular debe iniciar con +549 seguido de 10 dígitos.', 'error');
            this.closeModal();
            return;
        }

        this.isUpdating = true;
        UpdateUser({ Email: this.email, MobilePhone: this.mobilePhone })
            .then((result) => {
                this.showToast('Éxito', 'Datos modificados de manera exitosa.', 'success');
                this.mobilePhone = result.mobilePhone;
                this.email = result.Email;
                this.closeModal();
            })
            .catch(() => {
                this.showToast('Error', 'Ocurrió un error al actualizar los datos.', 'error');
                this.closeModal();
            })
            .finally(() => {
                this.isUpdating = false;
            });
    }

    handleChange(event) {
        const value = event.target.value;
        const fieldId = event.target.dataset.id;

        if (fieldId === 'oldPassword') {
            this.oldPassword = value;
        } else if (fieldId === 'newPassword') {
            this.newPassword = value;
        } else if (fieldId === 'newPasswordConfirm') {
            this.newPasswordConfirm = value;
            const inputCmp = this.template.querySelector('lightning-input[data-id="newPasswordConfirm"]');
            if (inputCmp) {
                if (this.newPasswordConfirm !== this.newPassword) {
                    inputCmp.setCustomValidity('Las contraseñas no coinciden');
                } else {
                    inputCmp.setCustomValidity('');
                }
                inputCmp.reportValidity();
            }
        }
    }

    handleChangePassword() {
        if (!this.validatePasswordForm()) {
            this.closeModal();
            return;
        }

        this.isChangingPassword = true;
        doChangePassword({
            oldPassword: this.oldPassword,
            newPassword: this.newPassword,
            verifyNewPassword: this.newPasswordConfirm
        })
            .then((result) => {
                if (result === SUCCESS_PASSWORD_MSG) {
                    this.showToast('Éxito', 'La contraseña se modificó con éxito.', 'success');
                    this.clearPasswordFields();
                    this.closeModal();
                } else {
                    this.showToast('Error', result, 'error');
                    this.closeModal();
                }
            })
            .catch((error) => {
                const message = error?.body?.message || 'Ocurrió un error al cambiar la contraseña.';
                this.showToast('Error', message, 'error');
                this.closeModal();
            })
            .finally(() => {
                this.isChangingPassword = false;
            });
    }

    togglePasswordVisibility(event) {
        const field = event.currentTarget.dataset.field;
        if (field === 'oldPassword') {
            this.showOldPassword = !this.showOldPassword;
        } else if (field === 'newPassword') {
            this.showNewPassword = !this.showNewPassword;
        } else if (field === 'newPasswordConfirm') {
            this.showConfirmPassword = !this.showConfirmPassword;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(
            new ShowToastEvent({ title, message, variant })
        );
    }
}