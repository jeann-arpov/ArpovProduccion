@isTest
public with sharing class Test_BatchApexGeneracionMovimientos{

    @testSetup static void setDatosGenerales() {
        ERPvs.TestUtils.insertDatosGenerales();
    }

    @isTest static void testBatchApexGeneracionMovimientos(){
        
        BatchApexGeneracionMovimientos b = new BatchApexGeneracionMovimientos();
        Database.executeBatch(b);

        b = new BatchApexGeneracionMovimientos(Date.today(), Date.today());
        Database.executeBatch(b);
        
    }
    
}