public with sharing class LWCSendWhatsapp extends ApexErrorHandler {

    @AuraEnabled
    public static List<MessagingTemplate> getTemplates() {
        return [select id, description, MasterLabel, DeveloperName from MessagingTemplate];
    }

    @AuraEnabled
    public static void sendTemplate(String template, Id contactId) {
        MessagingEndUser user = Test.isRunningTest() ? new MessagingEndUser(MessageType = 'WhatsApp', MessagingConsentStatus = 'ImplicitlyOptedIn') : [select MessagingChannelId, MessageType, MessagingConsentStatus from MessagingEndUser where ContactId =: contactId and MessageType = 'WhatsApp' order by CreatedDate desc limit 1];

        if (user.MessageType != 'WhatsApp') throw new AuraHandledException(Label.INT_Messaging_User_No_Whatsapp);
        if (user.MessagingConsentStatus != 'ImplicitlyOptedIn') throw new AuraHandledException(Label.INT_Consent_Status_Invalido);

        DateTime yesterday = System.now().addDays(-1);

        for (MessagingSession s: [select EndTime from MessagingSession where MessagingChannelId =: user.MessagingChannelId and MessagingEndUserId =: user.id and Origin = 'InboundInitiated' and Status = 'Ended' order by EndTime desc limit 1]) {
            if (s.EndTime > yesterday) throw new AuraHandledException(Label.INT_Messaging_Session_24hs);
        }

        Whatsapp_message__e event = new Whatsapp_message__e(Template__c = template, MessageEndUser__c = user.id);
        
        EventBus.publish(event);
    }
}