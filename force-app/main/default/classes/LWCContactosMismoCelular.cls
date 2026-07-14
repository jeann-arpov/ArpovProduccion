public with sharing class LWCContactosMismoCelular {
    
    @auraEnabled
    public static Map<String, Object> getContacts(Id recordId) {
        List<MessagingSession> sessions = new List<MessagingSession>();
        List<Contact> contacts = new List<Contact>();

        if (recordId.getSobjectType() == Contact.SobjectType) {
            sessions = [select ChannelType, MessagingEndUser.Movil__c, MessagingEndUser.Name,  EndUserContact.Email, EndUserContact.MobilePhone, Status from MessagingSession where EndUserContactId =: recordId order by createddate desc limit 1];
        } else if (recordId.getSobjectType() == MessagingSession.SobjectType) {
            sessions = [select ChannelType, MessagingEndUser.Movil__c, MessagingEndUser.Name,  EndUserContact.Email, EndUserContact.MobilePhone, Status from MessagingSession where id =: recordId];
        }  else if (recordId.getSobjectType() == MessagingEndUser.SobjectType) {
            sessions = [select ChannelType, MessagingEndUser.Movil__c, MessagingEndUser.Name, EndUserContact.Email, EndUserContact.MobilePhone, Status from MessagingSession where MessagingEndUserId =: recordId order by createddate desc limit 1];
        }

        if (!sessions.isEmpty()) {
            if (sessions[0].ChannelType == 'WhatsApp' && sessions[0].EndUserContact.MobilePhone != null) contacts = [select Contacto_Usuario_Mensajeria__c, Account.Name, Name, MobilePhone from contact where MobilePhone =: sessions[0].EndUserContact.MobilePhone order by Account.Name, Name];
            else if (sessions[0].ChannelType != 'WhatsApp' && sessions[0].EndUserContact.Email != null) contacts =  [select Contacto_Usuario_Mensajeria__c, Account.Name, Name, Email from contact where Email =: sessions[0].EndUserContact.Email  order by Account.Name, Name];
        }

        return new Map<String, Object>{'contacts' => contacts, 'session' => sessions.isEmpty() ? null : sessions[0]};
    }


    @auraEnabled
    public static void saveRecords(List<Contact> contacts) {
        update contacts;
    }

}