@isTest
public class LicenciaEmailTrigger2Test {
    
    @isTest
    static void testTriggerConEmails() {
        Licencia__c lic = new Licencia__c(
            Name = 'Test Licencia',
            Emails_Adicionales__c = 'uno@mail.com, dos@mail.com, tres@mail.com'
        );
        insert lic;

        // Validaciones
        Licencia__c insertedLic = [SELECT email_adicional_1__c, email_adicional_2__c, email_adicional_3__c FROM Licencia__c WHERE Id = :lic.Id];
        System.assertEquals('uno@mail.com', insertedLic.email_adicional_1__c);
        System.assertEquals('dos@mail.com', insertedLic.email_adicional_2__c);
        System.assertEquals('tres@mail.com', insertedLic.email_adicional_3__c);
    }

    @isTest
    static void testTriggerSinEmails() {
        Licencia__c lic = new Licencia__c(Name = 'Sin Emails');
        insert lic;

        Licencia__c insertedLic = [SELECT email_adicional_1__c FROM Licencia__c WHERE Id = :lic.Id];
        System.assertEquals(null, insertedLic.email_adicional_1__c);
    }
}