@isTest
public with sharing class SESiteHomeControllerTest {
    public static testmethod void main() {
        Account productor = Test_TestUtils.crearProductor();
        SESiteHomeController cont = new SESiteHomeController(null);
        System.assert(!cont.getIsAdherido());
    }
}