public with sharing class PasswordResetController {

    private static void validateReadAccessForUserSearch() {
        if (!Schema.sObjectType.User.isAccessible() ||
            !Schema.sObjectType.Contact.isAccessible() ||
            !Schema.sObjectType.Account.isAccessible()) {
            throw new AuraHandledException('No tiene permisos para consultar usuarios.');
        }
    }
    
    /**
     * Busca usuarios activos por email y CUIT de la cuenta
     * @param email Email del usuario a buscar
     * @param cuit CUIT de la cuenta asociada al contacto
     * @return List<Map<String, String>> Lista de usuarios encontrados con datos relevantes
     */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> searchUsersByEmail(String email, String cuit) {
        try {
            validateReadAccessForUserSearch();

            if (String.isBlank(email) || String.isBlank(cuit)) {
                return new List<Map<String, String>>();
            }

            String normalizedEmail = email.trim().toLowerCase();
            String normalizedCuit = cuit.trim();

            if (normalizedCuit.length() != 11 || !Pattern.matches('^[0-9]{11}$', normalizedCuit)) {
                throw new AuraHandledException('El CUIT debe contener exactamente 11 digitos numericos.');
            }
            
            List<User> users = [
                SELECT Id, Name, Username, Email, IsActive,
                       ContactId, Contact.Name, Contact.Email, Contact.AccountId, Contact.Account.N_CUIT__c
                FROM User
                WHERE IsActive = true
                AND ContactId != null
                AND Contact.Email = :normalizedEmail
                AND Contact.Account.N_CUIT__c = :normalizedCuit
                LIMIT 10
            ];
            
            List<Map<String, String>> results = new List<Map<String, String>>();
            for (User u : users) {
                Map<String, String> userData = new Map<String, String>();
                userData.put('id', u.Id);
                userData.put('name', u.Name);
                userData.put('email', u.Email);
                userData.put('username', u.Username);
                userData.put('contactName', u.Contact?.Name ?? '');
                userData.put('cuit', u.Contact?.Account?.N_CUIT__c ?? '');
                results.add(userData);
            }
            
            return results;
        } catch (Exception e) {
            throw new AuraHandledException('Error en búsqueda: ' + e.getMessage());
        }
    }
    
    /**
     * Obtiene detalles completos de un usuario
     * @param userId ID del usuario
     * @return Map<String, String> Información del usuario
     */
    @AuraEnabled(cacheable=false)
    public static Map<String, String> getUserDetails(String userId) {
        try {
            validateReadAccessForUserSearch();

            User u = [
                SELECT Id, Name, Username, Email, IsActive,
                       ContactId, Contact.Name, Contact.Email, Contact.AccountId, Contact.Account.N_CUIT__c
                FROM User
                WHERE Id = :userId
                AND IsActive = true
                LIMIT 1
            ];
            
            Map<String, String> userData = new Map<String, String>();
            userData.put('id', u.Id);
            userData.put('name', u.Name);
            userData.put('email', u.Email);
            userData.put('username', u.Username);
            userData.put('contactName', u.Contact?.Name ?? '');
            userData.put('contactEmail', u.Contact?.Email ?? '');
            userData.put('cuit', u.Contact?.Account?.N_CUIT__c ?? '');
            
            return userData;
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener usuario: ' + e.getMessage());
        }
    }
    
    /**
     * Actualiza la contraseña de un usuario
     * @param userId ID del usuario
     * @param newPassword Nueva contraseña
     * @return Map<String, String> Resultado de la operación
     */
    @AuraEnabled
    public static Map<String, String> resetUserPassword(String userId, String newPassword) {
        try {
            if (!Schema.sObjectType.User.isAccessible()) {
                throw new AuraHandledException('No tiene permisos para consultar usuarios.');
            }

            if (String.isBlank(userId) || String.isBlank(newPassword)) {
                throw new IllegalArgumentException('Usuario y contraseña son requeridos');
            }
            
            // Validación básica de contraseña
            if (newPassword.length() < 8) {
                throw new IllegalArgumentException('La contraseña debe tener mínimo 8 caracteres');
            }
            
            User u = [
                SELECT Id, Name, Username, Email
                FROM User
                WHERE Id = :userId
                AND IsActive = true
                LIMIT 1
            ];
            
            // Establecer la nueva contraseña
            System.setPassword(u.Id, newPassword);
            
            Map<String, String> result = new Map<String, String>();
            result.put('success', 'true');
            result.put('message', 'Contraseña actualizada correctamente para ' + u.Name);
            result.put('username', u.Username);
            result.put('email', u.Email);
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error al actualizar contraseña: ' + e.getMessage());
        }
    }
}