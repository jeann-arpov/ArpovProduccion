public class ContactTriggerHandler {
    private static final String ERROR_DEACTIVATE_WITH_ACTIVE_USER =
        'No se puede desactivar el contacto mientras tenga un usuario activo asociado.';

    public static void run() {
        if (Trigger.isBefore && Trigger.isUpdate) {
            validateContactDeactivation(
                (List<Contact>) Trigger.new,
                (Map<Id, Contact>) Trigger.oldMap
            );
        }
    }

    private static void validateContactDeactivation(
        List<Contact> contacts,
        Map<Id, Contact> oldContactsById
    ) {
        Set<Id> contactIdsToCheck = new Set<Id>();

        for (Contact contact : contacts) {
            if (isBeingDeactivated(contact, oldContactsById)) {
                contactIdsToCheck.add(contact.Id);
            }
        }

        if (contactIdsToCheck.isEmpty()) {
            return;
        }

        Set<Id> contactIdsWithActiveUser = new Set<Id>();
        for (User relatedUser : [
            SELECT ContactId
            FROM User
            WHERE ContactId IN :contactIdsToCheck
            AND IsActive = TRUE
        ]) {
            contactIdsWithActiveUser.add(relatedUser.ContactId);
        }

        for (Contact contact : contacts) {
            if (contactIdsWithActiveUser.contains(contact.Id)) {
                contact.addError(ERROR_DEACTIVATE_WITH_ACTIVE_USER);
            }
        }
    }

    private static Boolean isBeingDeactivated(
        Contact contact,
        Map<Id, Contact> oldContactsById
    ) {
        if (contact.Activo__c != false) {
            return false;
        }

        Contact oldContact = oldContactsById.get(contact.Id);
        return oldContact != null && oldContact.Activo__c != contact.Activo__c;
    }
}