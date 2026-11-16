public without sharing class PortalUserContactHandler {
    public static void afterInsert(List<User> users) {
        Set<Id> contactIds = new Set<Id>();
        for (User portalUser : users) {
            if (portalUser.ContactId != null) {
                contactIds.add(portalUser.ContactId);
            }
        }
        if (contactIds.isEmpty()) {
            return;
        }

        try {
            markPortalContactsAsync(contactIds);
        } catch (Exception e) {
            System.debug('No se pudo encolar la marca de contacto de portal: ' + e.getMessage());
        }
    }

    @future
    public static void markPortalContactsAsync(Set<Id> contactIds) {
        markPortalContacts(contactIds);
    }

    public static void markPortalContacts(Set<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return;
        }

        List<Contact> contacts = new List<Contact>();
        for (Id contactId : contactIds) {
            contacts.add(new Contact(Id = contactId, Es_Usuario_de_Portal__c = true));
        }

        for (Database.SaveResult result : Database.update(contacts, false)) {
            if (result.isSuccess()) {
                continue;
            }
            for (Database.Error err : result.getErrors()) {
                System.debug('No se marcó el contacto de portal: ' + err.getMessage());
            }
        }
    }
}
