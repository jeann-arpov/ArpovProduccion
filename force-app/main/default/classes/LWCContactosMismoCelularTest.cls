@isTest
public class LWCContactosMismoCelularTest {
    public static testmethod void main() {
        LWCContactosMismoCelular.saveRecords(new list<Contact>());
        LWCContactosMismoCelular.getContacts(getFakeId(Contact.SobjectType));
        LWCContactosMismoCelular.getContacts(getFakeId(MessagingSession.SobjectType));
        LWCContactosMismoCelular.getContacts(getFakeId(MessagingEndUser.SobjectType));
    }

   static Integer s_num = 1;
   public static String getFakeId(Schema.SObjectType sot) {
      String result = String.valueOf(s_num++);
      return sot.getDescribe().getKeyPrefix() + 
         '0'.repeat(12-result.length()) + result;
   }
}