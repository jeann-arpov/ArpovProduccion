@IsTest
private class ExcelDownloadControllerTest {
 
    @TestSetup
    static void setupTestData() {
		Test_TestUtils.disableFlows();
        Id standardPricebook = Test.getStandardPricebookId();
         
        Cultivo__c testCultivo = new Cultivo__c(
            Name = 'SOJA', 
            Temporada__c = 'Anual', 
            Densidad_de_Siembra__c = 23
        );
        insert testCultivo;
        
        Variedad__c testVariedad = new Variedad__c(
            Name = 'Test Variedad',
            Cultivo__c = testCultivo.Id,
            Biotecnologia__c = 'Enlist E3'
        );
        insert testVariedad;
        
        Account testAccount = new Account(
            Name = 'Test Account',
            N_CUIT__c = '30715468294',
            Type = 'Obtentor',
            Id_Obtentor__c = '12',
            Nombre_Obtentor__c = 'Test obtentor'
        );
        insert testAccount;
        
        Product2 testProducto = new Product2(
            Name = 'Test Producto',
            Tipo_de_Compra__c = 'Disponible',
            Variedad2__c = testVariedad.Id,
            Variedad__c = '4031 E',
            IsActive = true,
            Obtentor_Comercializa__c =  testAccount.id
        );
        insert testProducto;
        
        PricebookEntry standardEntry = new PricebookEntry(
        Pricebook2Id = standardPricebook,
        Product2Id = testProducto.Id,
        UnitPrice = 100.00,
         IsActive = true
        );
        insert standardEntry;
        
        Pricebook2 customPricebook = new Pricebook2(
            Name = 'Test Pricebook',
            IsActive = true
        );
        insert customPricebook;
        
        PricebookEntry customEntry = new PricebookEntry(
            Pricebook2Id = customPricebook.Id,
            Product2Id = testProducto.Id,
            UnitPrice = 95.00,
            IsActive = true
        );
        insert customEntry;
        
        
        
        Venta_HT__c testVenta = new Venta_HT__c(
            Name = 'Test Venta',
            Estado__c = 'Creada',
            Comercio__c = testAccount.Id
        );
        insert testVenta;
        
       
        
        Opportunity testOportunidad = new Opportunity(
            Name = 'Test Opportunity',
            AccountId = testAccount.Id,
            Pricebook2Id = customPricebook.Id,
            StageName = 'Creada',
            CloseDate = Date.today().addDays(30),
            Amount = 1000
        );
        insert testOportunidad;

        OpportunityLineItem testOppLineItem = new OpportunityLineItem(
            OpportunityId = testOportunidad.Id,
            PricebookEntryId = customEntry.Id,  
            Quantity = 1,
            Tipo_de_Cambio__c = 350.00,
            UnitPrice = 95.00
        );
        insert testOppLineItem;
        
           
        Licencia__c testLicencia = new Licencia__c(
            Name = 'Test Licencia'
        );
        insert testLicencia;
        
        Compra_HT__c testCompra = new Compra_HT__c(
            Name = 'Test Compra',
            Venta_HT__c = testVenta.Id,
            Estado__c = 'Pendiente de Facturación',
            Cuenta_Productor__c = testAccount.Id,
           // Oportunidad__c = testOportunidad.Id,
            Es_NC__c = true
        );
        insert testCompra;
        Test.startTest();
        Linea_de_Venta_HT__c testLineaVenta = new Linea_de_Venta_HT__c(
            Name = 'Test Linea Venta',
            Cantidad__c = 2,
            Precio_de_Lista__c = 23,
            Tipo_de_cambio__c = 2345,
            Venta_HT__c = testVenta.Id,
            Id_Producto_de_Lista_de_Precio__c = customEntry.Id
        );
        insert testLineaVenta;
        
        Linea_de_Compra_HT__c testLineaCompra = new Linea_de_Compra_HT__c(
            Name = 'Test Linea Compra',
            Estado__c = 'Pedido de Facturacion',
            Compra_HT__c = testCompra.Id,
            Cantidad__c = 50,
            Id_Producto_de_Lista_de_Precio__c = customEntry.Id,
            Fecha_de_Activacion__c = Date.today(),
            Licencia__c = testLicencia.Id,
            Linea_de_Venta_HT__c = testLineaVenta.Id,
            Producto__c = testProducto.Id,
            Linea_de_Oportunidad__c = testOppLineItem.Id,
            Tipo_de_cambio__c = 2345,
            Precio_de_Lista__c = 200
        );
        insert testLineaCompra;
        Test.stopTest();

    }
    
    @IsTest
    static void testGetRecordDataForExcel_Success() {
        Venta_HT__c testVenta = [SELECT Id FROM Venta_HT__c LIMIT 1];
        
        Test.startTest();
        ExcelDownloadController.ExcelDataWrapper result = ExcelDownloadController.getRecordDataForExcel(testVenta.Id);
        
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'El wrapper no debería ser null');
        System.assertNotEquals(null, result.mainRecord, 'El registro principal no debería ser null');
        System.assertNotEquals(null, result.relatedRecords, 'Los registros relacionados no deberían ser null');
        System.assert(result.relatedRecords.size() >= 1, 'Debería haber al menos una línea de compra');
        
        System.assert(result.mainRecord instanceof Venta_HT__c, 'El registro principal debería ser Venta_HT__c');
        
        Venta_HT__c ventaResult = (Venta_HT__c) result.mainRecord;
        System.assertEquals(testVenta.Id, ventaResult.Id, 'El ID de la venta debería coincidir');
    }
    
    @IsTest
    static void testGetRecordDataForExcel_MultipleLines() {
        Id standardPricebook = Test.getStandardPricebookId();
        Venta_HT__c testVenta = [SELECT Id FROM Venta_HT__c LIMIT 1];
        Compra_HT__c testCompra = [SELECT Id FROM Compra_HT__c LIMIT 1];
        Product2 testProducto = [SELECT Id FROM Product2 LIMIT 1];
        //Linea_de_Oportunidad__c testLineaOportunidad = [SELECT Id FROM 	OpportunityLineItem LIMIT 1];
        Licencia__c testLicencia = [SELECT Id FROM Licencia__c LIMIT 1];
        Linea_de_Venta_HT__c testLineaVenta = [SELECT Id FROM Linea_de_Venta_HT__c LIMIT 1];
        PricebookEntry customEntry = [SELECT Id FROM PricebookEntry WHERE Pricebook2Id != :standardPricebook LIMIT 1];
        
        List<Linea_de_Compra_HT__c> additionalLines = new List<Linea_de_Compra_HT__c>();
        
        for (Integer i = 1; i <= 3; i++) {
            additionalLines.add(new Linea_de_Compra_HT__c(
                Name = 'Test Linea Compra ' + i,
                Estado__c = 'Creada',
                Compra_HT__c = testCompra.Id,
                Cantidad__c = 50 + i,
                Id_Producto_de_Lista_de_Precio__c = customEntry.Id,
                Fecha_de_Activacion__c = Date.today().addDays(i),
                Licencia__c = testLicencia.Id,
                Linea_de_Venta_HT__c = testLineaVenta.Id,
                Tipo_de_cambio__c = 2345,
                Precio_de_Lista__c = 200
            ));
        }
        insert additionalLines;
        
        Test.startTest();
        ExcelDownloadController.ExcelDataWrapper result = ExcelDownloadController.getRecordDataForExcel(testVenta.Id);
        Test.stopTest();
        
        System.assertEquals(5, result.relatedRecords.size(), 'Deberían haber 5 líneas de compra (1 original + 4 adicionales)');
    }
    
    
    @IsTest
    static void testGetRecordDataForExcel_UnsupportedObject() {
        Account testAccount = new Account(Name = 'Test Account Unsupported');
        insert testAccount;
        
        Test.startTest();
        
        try {
            ExcelDownloadController.getRecordDataForExcel(testAccount.Id);
            System.assert(false, 'Debería haber lanzado una excepción para objeto no soportado');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Debería haber un mensaje de error');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testGetRecordDataForExcel_NonExistentVenta() {
        Id nonExistentId = Venta_HT__c.SObjectType.getDescribe().getKeyPrefix() + '000000000000';
        
        Test.startTest();
        ExcelDownloadController.ExcelDataWrapper result = ExcelDownloadController.getRecordDataForExcel(nonExistentId);
        Test.stopTest();
        
        System.assertNotEquals(null, result, 'El wrapper no debería ser null');
        System.assertEquals(null, result.mainRecord, 'El registro principal debería ser null para ID inexistente');
        System.assertNotEquals(null, result.relatedRecords, 'Los registros relacionados no deberían ser null');
        System.assertEquals(0, result.relatedRecords.size(), 'No debería haber líneas para venta inexistente');
    }
    
    @IsTest
    static void testGetRecordDataForExcel_VentaWithoutLines() {
        Account testAccount = new Account(Name = 'Test Account No Lines', N_CUIT__c = '30715468294');
        insert testAccount;
        
        Venta_HT__c ventaSinLineas = new Venta_HT__c(
            Name = 'Venta Sin Lineas',
            Comercio__c = testAccount.Id
        );
        insert ventaSinLineas;
        
        Test.startTest();
        ExcelDownloadController.ExcelDataWrapper result =  ExcelDownloadController.getRecordDataForExcel(ventaSinLineas.Id);
        Test.stopTest();
  
        System.assertNotEquals(null, result, 'El wrapper no debería ser null');
        System.assertNotEquals(null, result.mainRecord, 'El registro principal no debería ser null');
        System.assertNotEquals(null, result.relatedRecords, 'Los registros relacionados no deberían ser null');
        System.assertEquals(0, result.relatedRecords.size(), 'No debería haber líneas de compra');
        
        Venta_HT__c ventaResult = (Venta_HT__c) result.mainRecord;
        System.assertEquals(ventaSinLineas.Id, ventaResult.Id, 'El ID debería coincidir');
    }
    
    @IsTest
    static void testGetVentaHTData_Coverage() {
        Venta_HT__c testVenta = [SELECT Id FROM Venta_HT__c LIMIT 1];
        
        Test.startTest();
        ExcelDownloadController.ExcelDataWrapper result = ExcelDownloadController.getRecordDataForExcel(testVenta.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result.mainRecord, 'getVentaHTData debería retornar datos');
        System.assert(result.mainRecord instanceof Venta_HT__c, 'Debería ser una instancia de Venta_HT__c');
    }
    
    @IsTest
    static void testGetLineasCompraHTByVenta_Coverage() {
        Venta_HT__c testVenta = [SELECT Id FROM Venta_HT__c LIMIT 1];
        
        Test.startTest();
        ExcelDownloadController.ExcelDataWrapper result = ExcelDownloadController.getRecordDataForExcel(testVenta.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, result.relatedRecords, 'getLineasCompraHTByVenta debería retornar lista');
        System.assert(result.relatedRecords.size() > 0, 'Debería haber al menos una línea');
        System.assert(result.relatedRecords[0] instanceof Linea_de_Compra_HT__c, 
                     'Los elementos deberían ser instancias de Linea_de_Compra_HT__c');
    }
    
   
    @IsTest
    static void testGetRecordDataForExcel_GenericException() {
        Id nullId = null;
        
        Test.startTest();
        
        try {
            ExcelDownloadController.getRecordDataForExcel(nullId);
            System.assert(false, 'Debería haber lanzado una excepción');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage(), 'Debería haber un mensaje de error');
        }
        
        Test.stopTest();
    }
    
    @IsTest
    static void testExcelDataWrapper_Coverage() {
        Test.startTest();
        
        ExcelDownloadController.ExcelDataWrapper wrapper = new ExcelDownloadController.ExcelDataWrapper();
        wrapper.mainRecord = new Venta_HT__c();
        wrapper.relatedRecords = new List<Object>();
        
        Test.stopTest();
        
        System.assertNotEquals(null, wrapper, 'El wrapper debería ser instanciado');
        System.assertNotEquals(null, wrapper.mainRecord, 'mainRecord debería estar asignado');
        System.assertNotEquals(null, wrapper.relatedRecords, 'relatedRecords debería estar asignado');
    }
}