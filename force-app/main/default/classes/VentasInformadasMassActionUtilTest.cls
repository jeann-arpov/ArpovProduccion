@IsTest
private class VentasInformadasMassActionUtilTest {

    @IsTest
    static void getReturnUrlUsaParametrosTest() {
        PageReference pageRef = Page.ConvertirVentasInformadasSeleccionadas;
        pageRef.getParameters().put(
            'vfRetURLInSFX',
            'https://arpov-test.sandbox.lightning.force.com/lightning/o/Ventas_Informadas__c/list'
        );
        Test.setCurrentPage(pageRef);

        System.assertEquals(
            'https://arpov-test.sandbox.lightning.force.com/lightning/o/Ventas_Informadas__c/list',
            VentasInformadasMassActionUtil.getReturnUrl()
        );

        pageRef.getParameters().remove('vfRetURLInSFX');
        pageRef.getParameters().put('retURL', '/lightning/o/Ventas_Informadas__c/list');
        System.assertEquals(
            '/lightning/o/Ventas_Informadas__c/list',
            VentasInformadasMassActionUtil.getReturnUrl()
        );
    }
}