@isTest
public class BatchGenerarNCTest {
    public static testmethod void main() {
        new BatchGenerarNC().execute(null);
        new BatchGenerarNC().execute(null, new List<ERPvs__Vencimientos__c>{new ERPvs__Vencimientos__c()});
    }
}