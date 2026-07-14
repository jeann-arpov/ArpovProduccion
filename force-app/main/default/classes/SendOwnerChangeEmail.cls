public with sharing class SendOwnerChangeEmail {

    public static void sendEmail(List<Id> caseIds) {
        if (caseIds == null || caseIds.isEmpty()) return;

        // RecordType Regalía Extendida (DeveloperName)
        Id regaliaRecordTypeId = Schema.SObjectType.Case
            .getRecordTypeInfosByDeveloperName()
            .get('Regalia_Extendida')
            .getRecordTypeId();

        // Casos válidos
        List<Case> cases = [
            SELECT Id, Subject, Owner.Email, Owner.Name, RecordTypeId
            FROM Case
            WHERE Id IN :caseIds
              AND RecordTypeId = :regaliaRecordTypeId
              AND Owner.Email != null
        ];
        if (cases.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Case c : cases) {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{ c.Owner.Email });
            email.setReplyTo('soporte@arpov.org.ar');
            email.setSenderDisplayName('Soporte ArPOV');
            email.setSubject('Nuevo Caso Asignado - Regalía Extendida (' + c.Id + ')');
            email.setPlainTextBody(
                'Hola ' + c.Owner.Name + ',\n\n' +
                'Se te asignó un nuevo Caso de Regalía Extendida.\n' +
                'ID del Caso: ' + c.Id + '\n' +
                'Asunto: ' + (c.Subject == null ? '(sin asunto)' : c.Subject) + '\n\n' +
                'Por favor revísalo lo antes posible.\n\n' +
                'Saludos,\nEquipo de Soporte ArPOV'
            );
            emails.add(email);
        }
        if (!emails.isEmpty()) Messaging.sendEmail(emails, false);
    }
}