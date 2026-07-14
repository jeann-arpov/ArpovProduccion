@isTest
public class MisAsientosContablesControllerTest {
    public static testmethod void main() {
        MisAsientosContablesController.asientosTest = new List<ERPvs__Asientos_Contables__c>{new ERPvs__Asientos_Contables__c()};
        MisAsientosContablesController.attachmentsTest = new List<Attachment>{new Attachment(Body = Blob.valueOf('test'))};

        MisAsientosContablesController.getData(null, null);
    }
}