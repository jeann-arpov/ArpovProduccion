/**
 * Controlador para dar de baja / reactivar un contacto y su acceso al portal.
 *
 * Cada método corre en su propia transacción (llamados secuencialmente desde el LWC)
 * para evitar MIXED_DML_OPERATION: User es objeto "setup" y Contact "non-setup".
 *
 * Orden correcto de baja (lo orquesta el LWC):
 *   1) deactivatePortalUsers  -> desactiva el/los usuario(s) del portal
 *   2) deactivateContact      -> desactiva el contacto
 *
 * Orden de reactivación:
 *   1) reactivateContact      -> reactiva el contacto
 *   2) reactivatePortalUsers  -> reactiva el/los usuario(s)
 */
public without sharing class ContactDeactivationController {

    @AuraEnabled
    public static ResultadoOperacion deactivatePortalUsers(Id contactId) {
        try {
            List<User> usuariosActivos = [
                SELECT Id, IsActive
                FROM User
                WHERE ContactId = :contactId AND IsActive = TRUE
            ];
            for (User u : usuariosActivos) {
                u.IsActive = false;
            }
            if (!usuariosActivos.isEmpty()) {
                update usuariosActivos;
            }
            return new ResultadoOperacion(
                true,
                usuariosActivos.isEmpty()
                    ? 'No había usuarios de portal activos.'
                    : 'Se revocó el acceso al portal (' + usuariosActivos.size() + ' usuario/s).'
            );
        } catch (Exception e) {
            return new ResultadoOperacion(false, 'Error al revocar el acceso: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ResultadoOperacion deactivateContact(Id contactId) {
        try {
            Contact c = [SELECT Id, Activo__c FROM Contact WHERE Id = :contactId];
            c.Activo__c = false;
            update c;
            return new ResultadoOperacion(true, 'Contacto dado de baja correctamente.');
        } catch (Exception e) {
            return new ResultadoOperacion(false, 'Error al dar de baja el contacto: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ResultadoOperacion reactivateContact(Id contactId) {
        try {
            Contact c = [SELECT Id, Activo__c FROM Contact WHERE Id = :contactId];
            c.Activo__c = true;
            update c;
            return new ResultadoOperacion(true, 'Contacto reactivado correctamente.');
        } catch (Exception e) {
            return new ResultadoOperacion(false, 'Error al reactivar el contacto: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static ResultadoOperacion reactivatePortalUsers(Id contactId) {
        try {
            List<User> usuarios = [
                SELECT Id, IsActive
                FROM User
                WHERE ContactId = :contactId
            ];
            for (User u : usuarios) {
                u.IsActive = true;
            }
            if (!usuarios.isEmpty()) {
                update usuarios;
            }
            return new ResultadoOperacion(
                true,
                usuarios.isEmpty()
                    ? 'No había usuarios de portal para reactivar.'
                    : 'Acceso al portal restaurado (' + usuarios.size() + ' usuario/s).'
            );
        } catch (Exception e) {
            return new ResultadoOperacion(false, 'Error al restaurar el acceso: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static InfoContacto getContactInfo(Id contactId) {
        Contact c = [
            SELECT Id, Name, Activo__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ];
        Integer usuariosActivos = [
            SELECT COUNT()
            FROM User
            WHERE ContactId = :contactId AND IsActive = TRUE
        ];
        return new InfoContacto(c.Id, c.Name, c.Activo__c, usuariosActivos);
    }

    public class InfoContacto {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public Boolean activo;
        @AuraEnabled public Integer usuariosPortalActivos;

        public InfoContacto(Id contactId, String name, Boolean activo, Integer usuariosPortalActivos) {
            this.contactId = contactId;
            this.name = name;
            this.activo = activo;
            this.usuariosPortalActivos = usuariosPortalActivos;
        }
    }

    public class ResultadoOperacion {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;

        public ResultadoOperacion(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
}
