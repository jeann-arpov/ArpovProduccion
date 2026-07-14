@IsTest
public class ExportEstadoCuentaCyOPdfControllerTest {

    @TestSetup
    static void setupData() {
        Account testAccount = new Account(
            Name = 'Cuenta PDF Test',
            N_CUIT__c = '20166289050'
        );
        insert testAccount;

        Opportunity opp = new Opportunity(
            AccountId = testAccount.Id,
            Name = 'Opp PDF Test',
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Fecha_Vencimiento_Comprobante__c = Date.today().addDays(20),
            Fecha_Emision_Comprobante__c = Date.today().addDays(-10),
            N_de_Comprobante__c = 'TEST-0004-0001',
            Divisa_Comprobante__c = 'ARS',
            Saldo_a_Cobrar_Comprobante__c = 2500.75,
            Total_Comprobante__c = 3735.25
        );
        insert opp;
    }

    @IsTest
    static void testConstructorWithValidParams() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setCurrentPage(Page.ExportEstadoCuentaCyOPdf);
        ApexPages.currentPage().getParameters().put('accountId', String.valueOf(acc.Id));
        ApexPages.currentPage().getParameters().put('fechaDesde', String.valueOf(Date.today().addDays(-1)));
        ApexPages.currentPage().getParameters().put('fechaHasta', String.valueOf(Date.today().addDays(1)));

        Test.startTest();
        ExportEstadoCuentaCyOPdfController ctrl = new ExportEstadoCuentaCyOPdfController();
        Test.stopTest();

        System.assertNotEquals(null, ctrl.tableHeaders, 'Debe inicializar encabezados');
        System.assertNotEquals(null, ctrl.tableRows, 'Debe inicializar filas');
        System.assert(ctrl.tableHeaders.size() > 0, 'Debe tener encabezados para la tabla PDF');
        System.assertEquals('Cuenta PDF Test', ctrl.accountName, 'Debe obtener nombre de cuenta');
        System.assertEquals('20166289050', ctrl.accountCuit, 'Debe obtener CUIT');
        System.assertEquals('2.500,75', ctrl.totalComprobante, 'Debe sumar saldo pendiente y formatearlo');
        System.assert(ctrl.totalRow.size() == ctrl.tableHeaders.size(), 'Fila total debe alinearse con columnas');
    }

    @IsTest
    static void testConstructorWithoutParams() {
        Test.setCurrentPage(Page.ExportEstadoCuentaCyOPdf);

        Test.startTest();
        ExportEstadoCuentaCyOPdfController ctrl = new ExportEstadoCuentaCyOPdfController();
        Test.stopTest();

        System.assertEquals('', ctrl.accountName, 'Sin params no debe cargar datos');
        System.assertEquals('', ctrl.accountCuit, 'Sin params no debe cargar CUIT');
        System.assertEquals(0, ctrl.tableHeaders.size(), 'Sin params no debe construir headers');
        System.assertEquals(0, ctrl.tableRows.size(), 'Sin params no debe construir filas');
        System.assertEquals('0', ctrl.totalComprobante, 'Debe conservar valor inicial');
    }

    @IsTest
    static void testConstructorWithInvalidDateParam() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        Test.setCurrentPage(Page.ExportEstadoCuentaCyOPdf);
        ApexPages.currentPage().getParameters().put('accountId', String.valueOf(acc.Id));
        ApexPages.currentPage().getParameters().put('fechaDesde', 'fecha-invalida');
        ApexPages.currentPage().getParameters().put('fechaHasta', String.valueOf(Date.today()));

        Test.startTest();
        ExportEstadoCuentaCyOPdfController ctrl = new ExportEstadoCuentaCyOPdfController();
        Test.stopTest();

        System.assertEquals('', ctrl.fechaDesde, 'Con fecha inválida debe salir sin procesar');
        System.assertEquals('', ctrl.fechaHasta, 'Con fecha inválida debe salir sin procesar');
        System.assertEquals(0, ctrl.tableHeaders.size(), 'No debe cargar encabezados');
        System.assertEquals(0, ctrl.tableRows.size(), 'No debe cargar filas');
    }
}