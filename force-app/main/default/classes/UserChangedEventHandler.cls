public without sharing class UserChangedEventHandler {
    public static void run() {
        List<Sobject> userstoUpdate = new List<Sobject>();
        Map<Id, String> contactsToUpdate = new Map<Id, String>();

        Set<Id> changed = new Set<Id>();

        for (UserChangeEvent event : (List<UserChangeEvent>) Trigger.New) {
            EventBus.ChangeEventHeader header = event.ChangeEventHeader;
            if(header.changedFields.contains('Email') || Test.isRunningTest()) {
                changed.addAll((List<Id>) new List<String>(header.recordids));
            }
        }

        if (changed.isEmpty() == false) {
            for (User u: [select email, Contact.Account.n_cuit__c, Contact.Email from user where id in: changed and contactId != null]) {
                String username = RegisterCommunityController.generateUsername(u.email, u.Contact.Account.n_cuit__c);
                
                if (u.email != u.Contact.Email) {
                    userstoUpdate.add(new User(Id = u.id, Username = username, Id_Externo__c = username));
                    contactsToUpdate.put(u.ContactId, u.email);
                }
            }

            update userstoUpdate;
            updateContactEmails(contactsToUpdate);
        }
    }

    @future
    public static void updateContactEmails(Map<Id, String> contactsToUpdate) {
        List<Contact> toUpdate = new List<Contact>();

        for (Id id: contactsToUpdate.keySet()) {
            toUpdate.add(new Contact(Id = id, email = contactsToUpdate.get(id)));
        } 

        update toUpdate;
    }
}