public with sharing class editProfileController {
    private static final Pattern MOBILE_PATTERN = Pattern.compile('^\\+549\\d{10}$');
    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$');

    @AuraEnabled(cacheable=true)
    public static List<User> getUserInfo() {
        return new List<User>{ getCurrentUserProfile() };
    }
    
    @AuraEnabled
    public static User editUser(string Email, string MobilePhone) {
        String newEmail = String.isBlank(Email) ? null : Email.trim();
        String newMobile = String.isBlank(MobilePhone) ? null : MobilePhone.trim();

        String mobileError = getMobilePhoneError(newMobile);
        if (mobileError != null) {
            throw buildException(mobileError);
        }
        if (newEmail == null || !EMAIL_PATTERN.matcher(newEmail).matches()) {
            throw buildException('Ingresá un email válido.');
        }

        try {
            User usuario = [
                SELECT Id, ContactId, Email, MobilePhone
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (usuario.ContactId != null) {
                new ContactUpdater().updateContactData(usuario.ContactId, newEmail, newMobile);
            }

            Boolean userChanged = false;
            if (usuario.MobilePhone != newMobile) {
                usuario.MobilePhone = newMobile;
                userChanged = true;
            }
            if (usuario.Email != newEmail) {
                usuario.Email = newEmail;
                userChanged = true;
            }
            if (userChanged) {
                update usuario;
            }

            return getCurrentUserProfile();
        } catch (DmlException e) {
            throw buildException('No se pudieron guardar los datos: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw buildException('No se pudieron guardar los datos: ' + e.getMessage());
        }
    }

    // Mantener alineado con getMobilePhoneError de c/utils (validación en pantalla).
    @TestVisible
    private static String getMobilePhoneError(String mobile) {
        if (String.isBlank(mobile)) {
            return 'Ingresá tu número de celular.';
        }
        if (!MOBILE_PATTERN.matcher(mobile).matches()) {
            return 'El celular debe tener el formato +549 seguido de 10 dígitos, sin espacios ni guiones (ej. +5491123456789).';
        }
        String digits = mobile.substring(4);
        if (digits.replace(digits.left(1), '').length() == 0) {
            return 'El número no puede tener todos los dígitos iguales.';
        }
        if (isSecuenciaConsecutiva(digits, 1) || isSecuenciaConsecutiva(digits, -1)) {
            return 'El número no puede ser una secuencia de dígitos consecutivos.';
        }
        return null;
    }

    private static Boolean isSecuenciaConsecutiva(String digits, Integer step) {
        for (Integer i = 1; i < digits.length(); i++) {
            Integer prev = Integer.valueOf(digits.substring(i - 1, i));
            Integer curr = Integer.valueOf(digits.substring(i, i + 1));
            if (Math.mod(prev + step + 10, 10) != curr) {
                return false;
            }
        }
        return true;
    }

    private static AuraHandledException buildException(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }

    private static User getCurrentUserProfile() {
        User usr = [
            SELECT Id, ContactId, Nombre_Completo__c, Razon_Social__c, Numero_de_Documento__c, Account.N_CUIT__c, Email, MobilePhone
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        if (usr.ContactId != null) {
            Contact contacto = new ContactUpdater().getContactData(usr.ContactId);
            if (contacto != null) {
                if (String.isNotBlank(contacto.MobilePhone)) {
                    usr.MobilePhone = contacto.MobilePhone;
                }
                if (String.isNotBlank(contacto.Email)) {
                    usr.Email = contacto.Email;
                }
            }
        }
        return usr;
    }

    // Portal users have no edit access to their own Contact; access is limited to the running user's ContactId.
    private without sharing class ContactUpdater {
        public Contact getContactData(Id contactId) {
            List<Contact> contactos = [
                SELECT Id, Email, MobilePhone
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            return contactos.isEmpty() ? null : contactos[0];
        }

        public void updateContactData(Id contactId, String email, String mobilePhone) {
            update new Contact(Id = contactId, Email = email, MobilePhone = mobilePhone);
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
