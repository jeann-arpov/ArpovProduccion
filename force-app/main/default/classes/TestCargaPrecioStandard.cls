@isTest
private class TestCargaPrecioStandard {

    @TestSetup 
    static void setup(){
        List <ERPvs__Datos_Generales__c> dg_insertar = new List<ERPvs__Datos_Generales__c> ();
        
        for (RecordType rtID :[select id, name from RecordType where SobjectType = 'ERPvs__Datos_Generales__c' order by name]) {
            if (rtID.Name == 'General') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'Común a todas las aplicaciones', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Compras') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Compras', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Contabilidad') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Contabilidad', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Ventas') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Facturación', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Fondos') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Fondos', RecordTypeId = rtID.id));
            }
            if (rtID.Name == 'Stock') {
                dg_insertar.add (new ERPvs__Datos_Generales__c(Name = 'De Inventarios', RecordTypeId = rtID.id));
            }
        }
        insert dg_insertar;

    }

    // Methods for testing
    @isTest static void test() {
        
        //Variable que contendra la moneda de la compania
        Moneda__c moneda1 = null;
        
        for(Moneda__c moneda : [SELECT Codigo_Univoco__c,Moneda_de_la_compania__c FROM Moneda__c WHERE Moneda_de_la_compania__c = true LIMIT 1]){
            moneda1 = moneda;
        }
        
        //Si no existe la moneda de la compania
        if(moneda1 == null){ 

            //Una moneda sera de la compania
            moneda1 = Test_TestUtils.crearMoneda('TEST1','TEST1',true, false);

            List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

            ERPvs__Moneda__c mon = new ERPvs__Moneda__c();
            mon.Name = '1';
            mon.ERPvs__Denominacion__c = 'moneda';
            mon.ERPvs__Pertenece_A__c = list_dg.get(0).id;
            mon.ERPvs__Moneda_Nacional__c = false;
            mon.ERPvs__Moneda_Traducida__c = true;
            insert mon;

            moneda1.Moneda_ERP__c = mon.Id;

        }   
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        Account obtentor = Test_TestUtils.crearObtentor();
        
        //Creamos un par de productos
        Product2 producto1 = Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor);
        
    }
    
}