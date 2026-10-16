import { LightningElement, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { NavigationMixin } from 'lightning/navigation'; // <-- Importante

import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import doChangePassword from '@salesforce/apex/editProfileController.changeUserPassword';
import getProfileInfo from '@salesforce/apex/editProfileController.getUserInfo';
import UpdateUser from '@salesforce/apex/editProfileController.editUser';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class EditProfileRegaliaProductor extends NavigationMixin(LightningElement) {
    
    userId = USER_ID;
    userName = '';
    oldPassword = '';
    newPassword = '';
    newPasswordConfirm = '';

    @track fullName;
    @track businessName;
    @track documentId;
    @track cuit;
    @track mobilePhone;
    @track email;

    @track passwordInputType = 'password';
    @track toggleIconName = 'utility:hide';

    // Redirección dinámica y robusta al inicio de la comunidad
    navigateToHome(event) {
        if (event) {
            event.preventDefault();
            event.stopPropagation();
        }

        // Intento 1: Usar NavigationMixin apuntando a la página web relativa (Raíz de la comunidad)
        try {
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/'
                }
            });
        } catch (e) {
            // Intento 2 (Fallback): Redirección directa vía browser si falla la API de navegación
            window.location.href = window.location.origin + window.location.pathname.split('/s/')[0] + '/s/';
        }
    }

    @wire(getProfileInfo)
    wiredInfo({ error, data }) {
        if (data && data.length > 0) {
            this.fullName = data[0].Nombre_Completo__c;
            this.businessName = data[0].Razon_Social__c;
            this.documentId = data[0].Numero_de_Documento__c;
            this.cuit = data[0].Account?.N_CUIT__c;
            this.email = data[0].Email;
            this.mobilePhone = data[0].MobilePhone;
        } else if (error) {
            console.error('Error al cargar info del perfil:', error);
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

    handleEmail(event) {
        this.email = event.target.value;
    }

    handlePhone(event) {
        this.mobilePhone = event.target.value;
    }

    validatePhoneNumber(phone) {
        const regex = /^\+549\d{10}$/;
        return regex.test(phone);
    }
    
    handleUpdate() {
        const isValidPhone = this.validatePhoneNumber(this.mobilePhone);
        
        if (isValidPhone) {
            UpdateUser({ Email: this.email, MobilePhone: this.mobilePhone })
                .then(result => {
                    this.showToast('Éxito', '¡Datos modificados de manera exitosa!', 'success');
                    this.mobilePhone = result.MobilePhone || this.mobilePhone;
                    this.email = result.Email || this.email;
                })
                .catch(error => {
                    this.showToast('Error', 'Ocurrió un error al actualizar los datos.', 'error');
                    console.error(error);
                });
        } else {
            this.showToast('Error', 'El campo celular debe iniciar con +549 seguido de 10 dígitos.', 'error');
        }
    }

    handleChange(event) {
        const value = event.target.value;
        const targetId = event.target.dataset.id;
        
        if (targetId === 'oldpass') {
            this.oldPassword = value;
        } else if (targetId === 'newpass') {
            this.newPassword = value;
        } else if (targetId === 'passconfirm') {
            this.newPasswordConfirm = value;
            
            let inputCmp = this.template.querySelector('lightning-input[data-id="passconfirm"]');
            if (this.newPasswordConfirm !== this.newPassword) {
                inputCmp.setCustomValidity('Las contraseñas no coinciden');
            } else {
                inputCmp.setCustomValidity('');
            }
            inputCmp.reportValidity();
        }
    }

    handleChangePassword() {
        if (!this.oldPassword || !this.newPassword || !this.newPasswordConfirm) {
            this.showToast('Atención', 'Por favor, completa todos los campos de contraseña.', 'warning');
            return;
        }

        if (this.newPassword !== this.newPasswordConfirm) {
            this.showToast('Error', 'Las contraseñas no coinciden.', 'error');
            return;
        }

        doChangePassword({ 
            oldPassword: this.oldPassword, 
            newPassword: this.newPassword, 
            verifyNewPassword: this.newPasswordConfirm 
        })
        .then(result => {
            if (result === 'Success: Your password has been changed successfully.') {
                this.showToast('Éxito', '¡La contraseña se modificó con éxito!', 'success');
                this.clearPasswordFields();
            } else {
                this.showToast('Error', result, 'error');
            }
        })
        .catch(error => {
            this.showToast('Error', error.body?.message || 'Error al cambiar contraseña', 'error');
        });
    }

    clearPasswordFields() {
        this.oldPassword = '';
        this.newPassword = '';
        this.newPasswordConfirm = '';
        this.template.querySelectorAll('lightning-input[type="password"], lightning-input[type="text"]').forEach(input => {
            if(input.dataset.id && input.dataset.id.includes('pass')) {
                input.value = '';
            }
        });
    }

    togglePasswordVisibility() {
        if (this.passwordInputType === 'password') {
            this.passwordInputType = 'text';
            this.toggleIconName = 'utility:preview';
        } else {
            this.passwordInputType = 'password';
            this.toggleIconName = 'utility:hide';
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}