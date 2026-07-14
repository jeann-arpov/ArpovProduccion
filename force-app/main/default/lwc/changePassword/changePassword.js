import { LightningElement } from 'lwc';
import doChangePassword from '@salesforce/apex/CommunityUser.doChangePassword';
import { doRequest, reduceErrors } from 'c/utils';
export default class ChangePassword extends LightningElement {

    oldPassword = '';
    newPassword = '';
    newPasswordConfirm = '';
    message = '';
    variant = '';

    loading = false;

    handleChange(event){
        const value = event.detail.value;
        const label = event.target.placeholder;

        if(label == 'Contraseña Actual'){
            this.oldPassword = value;
        }else if(label == 'Nueva Contraseña'){
            this.newPassword = value;
        }else if(label == 'Confirmar Nueva Contraseña'){
            this.newPasswordConfirm = value;
            let inputCmp = this.template.querySelector('lightning-input[data-id="passconfirm"]');
            if(this.newPasswordConfirm != this.newPassword){
                inputCmp.setCustomValidity('Las contraseñas no coinciden');
            }else{
                inputCmp.setCustomValidity('');
            }
            inputCmp.reportValidity();
        }
    }

    changePassword(){
        doRequest.call(this, async _ => {
            await doChangePassword({oldPassword: this.oldPassword, newPassword: this.newPassword, verifyNewPassword: this.newPasswordConfirm});
            this.variant = 'success';
            this.message = 'La contraseña se modificó con éxito';
        });
    }

    onError(e){
        this.variant = 'error';
        this.message = reduceErrors(e);
    }

    get messageClass(){
        return this.variant == 'error' ? 'slds-text-color_destructive' : 'slds-text-color_success';
    }
}