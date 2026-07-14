public with sharing class editProfileController {
    @AuraEnabled(cacheable=true)
    public static List<User> getUserInfo() {
        list<user> userInfo = [
            SELECT Id, Nombre_Completo__c, Razon_Social__c, Numero_de_Documento__c, Account.N_CUIT__c ,Email,MobilePhone
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        return  userInfo;
    }
    
    @AuraEnabled
    public static User editUser(string Email, string MobilePhone) {
        try {
            user usuario = [
            SELECT Id, Nombre_Completo__c, Razon_Social__c, Numero_de_Documento__c, Account.N_CUIT__c,Email,MobilePhone
            FROM User
            WHERE Id = :UserInfo.getUserId() limit 1
        ];
            usuario.Email = Email;
            usuario.MobilePhone = MobilePhone;
            update usuario;
            user usr = [
            SELECT Id, Nombre_Completo__c, Razon_Social__c, Numero_de_Documento__c, Account.N_CUIT__c,Email,MobilePhone
            FROM User
            WHERE Id = :UserInfo.getUserId() limit 1];
            return usr;
        } catch (Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static String changeUserPassword(String oldPassword, String newPassword, String verifyNewPassword) {

        // 1. Basic validation: Ensure required fields are not empty.
        if (String.isBlank(oldPassword) || String.isBlank(newPassword) || String.isBlank(verifyNewPassword)) {
            return 'Error: All password fields are required.';
        }

        // 2. Basic validation: Ensure the new password and confirmation match.
        if (newPassword != verifyNewPassword) {
            return 'Error: The new passwords you entered do not match.';
        }

        try {
            // 3. Call the Site.changePassword method.
            System.Site.changePassword(newPassword, verifyNewPassword, oldPassword);

            // 4. Return success message if no exception is thrown.
            return 'Success: Your password has been changed successfully.';

        } catch (Exception e) {
            System.debug('Password change failed for user ' + UserInfo.getUserId() + '. Error: ' + e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }

}