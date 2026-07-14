/**
* @author Maximo Martinez
* @date 10/02/2016
* @description Clase Unit Test de la Clase LiquidacionesDownloadController
*/
@isTest
private class Test_LiquidacionesDownloadController {
	
	@testSetup static void setDatosGenerales() {
        ERPvs.TestUtils.insertDatosGenerales();
    }

	@isTest static void test() {
		
		List<ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

		//Creamos los Datos Necesarios
        
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());
        
        //Seteamos variables para almacenar los recordtypes que necesitaremos
        RecordType rtDUP = null;
        RecordType rtAud = null;
        RecordType rtObtentor = null;
        
        //Obtenemos los RecordType que necesitamos
        for( RecordType recordType : [SELECT DeveloperName FROM RecordType WHERE SObjectType IN ('Transaccion__c','Account')]){
            if(recordType.DeveloperName == 'DUP'){
                rtDUP = recordType;
            }else if( recordType.DeveloperName == 'Auditorias' ){
                rtAud = recordType;
            }else if(recordType.DeveloperName == 'Obtentor'){
                rtObtentor = recordType;
            }
        }

        //Una moneda sera de la compania
        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));

        ERPvs__Moneda__c mon = new ERPvs__Moneda__c();
        mon.Name = '1';
        mon.ERPvs__Denominacion__c = 'moneda';
        mon.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        mon.ERPvs__Moneda_Nacional__c = false;
        mon.ERPvs__Moneda_Traducida__c = true;
        insert mon;

        monedas[0].Moneda_ERP__c = mon.Id;
        monedas[1].Moneda_ERP__c = mon.Id;

        insert monedas;
        
        
        //Obtenemos la fechaActual
        Date fechaActual = Date.today();
    
        //Creamos un tipo de cambio para la moneda extranjera
        Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(monedas[1],2,fechaActual);
              
         //Creamos una cuenta de tipo Obtentor
        Account obtentor = Test_TestUtils.crearObtentor();
    
   
        //Creamos un distribuidor
        Account distribuidor = Test_TestUtils.crearDistribuidor();
    
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        Product2 producto1 = Test_TestUtils.crearProducto(true,'ProductoTest 1',monedas[0].Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor);
        
        Product2 producto2 = Test_TestUtils.crearProducto(true,'ProductoTest 2',monedas[1].Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor);
        
        //Verificamos si se ha creado un pricebookentry
        
        List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE (Product2Id = :producto1.Id) OR (Product2Id = :producto2.Id)];
        
        if(pbes.size() == 0){
        
            List<Product2> productos = new List<Product2>(); 
        
            productos.add(producto1);
        
            productos.add(producto2);
        
            //Creamos un pricebook entry para cada producto
            pbes = Test_TestUtils.crearPricebookEntry( productos, listaPrecios);
        
        }    
          
        
        //Creamos una transaccion de tipo Auditoria
        Transaccion__c t1 = Test_TestUtils.crearTransaccion(rtDUP,'00000001', obtentor, cultivo, campanaAgricola, distribuidor, 'Respondida', hoy);
        
        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;

        //Creamos dos Items para la auditoria
        Item_Auditoria__c item1= Test_TestUtils.crearItemAuditoria(producto1, t1,  campanaAgricola, 'Irregular', 'Granel', 1, null, false);    
    
        Item_Auditoria__c item2= Test_TestUtils.crearItemAuditoria(producto2, t1,  campanaAgricola, 'Irregular', 'Granel', 1, null, false);    
        
        item1.Lugar_de_Siembra__c = prov.Id;
        item2.Lugar_de_Siembra__c = prov.Id;

        insert item1;

        insert item2;

        //Generamos una oportunidad y dos item de oportunidad (uno por cada item de la transaccion)
        Opportunity opp =  Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t1, 'FC');
        
        OpportunityLineItem opl1 = Test_TestUtils.crearOpportunityLineItem(opp, pbes.get(0), 1, 10, 10);
        OpportunityLineItem opl2 = Test_TestUtils.crearOpportunityLineItem(opp, pbes.get(1), 1, 10, 10);
       	
       	Test.setCurrentPageReference(new PageReference('Page.printSalesElectronicInvoice')); 
		System.currentPageReference().getParameters().put('retURL', '/test/test');

		ApexPages.StandardSetController ssc = new ApexPages.StandardSetController(Database.getQueryLocator([SELECT Name,CloseDate FROM Opportunity]));
		
		LiquidacionesDownloadController ctrl = new LiquidacionesDownloadController(ssc);

		ctrl.doDownload();

		ctrl.doCancel();

	}
	
}