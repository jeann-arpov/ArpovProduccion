@isTest
private class Test_EmailTemplateFacturasPAVencerCtrl {
		
	@isTest static void test() {

		Account a = new Account();
		a.Name = 'Test';
		insert a;

        Test.setCurrentPageReference(Page.emailTemplateFacturasProximasAVencer); 
		System.currentPageReference().getParameters().put('accountId',a.Id);
		System.currentPageReference().getParameters().put('dueDate',String.valueOf(Date.today()));
		System.currentPageReference().getParameters().put('nameCultivo','SOJA');

        Test.startTest();

        EmailTemplateFacturasProximasAVencerCtrl ctrl = new EmailTemplateFacturasProximasAVencerCtrl();

        EmailTemplateFacturasProximasAVencerCtrl.Wrapper wp = new EmailTemplateFacturasProximasAVencerCtrl.Wrapper(new Opportunity(Total_Comprobante__c=1111,Saldo_a_Cobrar_Comprobante__c=8181));

        ctrl.getOpportunities();
        ctrl.getAccount();

        Test.stopTest();

    }
	
}