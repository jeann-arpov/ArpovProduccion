@isTest
public with sharing class AgroPagoAuraControllerTest {
    
    @TestSetup
    public static void setup() {        
        Test_TestUtils.disableFlows();
        
        AgroPago__c agro = new AgroPago__c();

        agro.Token_Type__c = 'e';
        agro.ApiKey__c = 'ads';
        agro.Token__c = 'test';
        agro.Timeout__c = 10000;
        agro.Comision__c = 0.1;
        agro.Comision_Bancaria__c = 0.05;
        agro.Comision_Plataforma__c = 0.05;

        insert agro;

        Erpvs.TestUtils.insertDatosGenerales();

        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));

        List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

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

         //Obtenemos la lista de precios standard del sitio
         Id idPricebook2 = Utils.getPricebook2Id();

         Pricebook2 listaPrecios = new Pricebook2(Id = idPricebook2);
         
         //Creamos datos de Test
         
         Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
         
         Account obtentor = Test_TestUtils.crearObtentor();
         
         Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id);
         insert var;

         Account productor = Test_TestUtils.crearProductor();
         
         //Variable que contendra la moneda de la compania
         Moneda__c moneda1 = null;
         Moneda__c moneda2 = null;
         
         for(Moneda__c moneda : [SELECT Codigo_Univoco__c,Moneda_de_la_compania__c FROM Moneda__c]){
             if(moneda.Moneda_de_la_compania__c == true){
                 moneda1 = moneda;
             }else{
                 moneda2 = moneda;
             }
         }
         
         //Obtenemos la fechaActual
         Date fechaActual = Date.today();
     
         //Creamos un tipo de cambio para la moneda extranjera
         Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(moneda2,2,fechaActual);
           
         //Creamos un cultivo
         Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
         
         //Fecha Inicio
         Date hoy = Date.today();
         
         //Fecha Fin
         Date manana = hoy.addDays(1);
         
         //Creamos una campaña agricola
         Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
         
         //Creamos un par de productos
         List<Product2> productos = new List<Product2>();
         
         productos.add(Test_TestUtils.crearProducto(true,'ProductoTest1',moneda1.Codigo_Univoco__c, 'Variedad Test1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
         
         productos.add(Test_TestUtils.crearProducto(true,'ProductoTest2',moneda2.Codigo_Univoco__c, 'Variedad Test2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true));
         
         //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),null,obtentor , cultivo, campanaAgricola, productor, 'Respondida', hoy, false);
      		
      	insert t;

        //Creamos una Opportunidad para la Transaccion 1
        Opportunity oportunidad = Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t, 'FC');
        
        //Agregamos el Número de Comprobante
        oportunidad.N_de_Comprobante__c = '123456';
        oportunidad.Transaccion__c = t.Id;
        oportunidad.Fecha_Vencimiento_Comprobante__c = Date.today().addDays(1);
        oportunidad.Saldo_a_Cobrar_Comprobante__c = 10;
        oportunidad.Total_Comprobante__c = 10;
        oportunidad.Divisa_Comprobante__c = 'ARS';
        oportunidad.Tipo_de_Cambio_Actualizado__c = 100;
        
        update oportunidad;

        Cuenta_Destinataria__c cd = new Cuenta_Destinataria__c();
        cd.Name = 'AgroPago';
        cd.Obtentor__c = obtentor.Id;
        insert cd;
    }

    public static testmethod void opp() {
        Test.setMock(HttpCalloutMock.class, new YourHttpCalloutMockImpl());

        AgroPagoAuraController.FormData form = new AgroPagoAuraController.FormData();
        form.recordId = [select id from Opportunity].Id;
        
        Test.startTest();
        AgroPagoRestClient.PaymentsAgroResponse response = AgroPagoAuraController.pay(form);
        Test.stopTest();

        System.assertEquals([select id from Aplicacion__c].size(), 1); 
    }

    public static testmethod void vencimiento() {
        Test.setMock(HttpCalloutMock.class, new YourHttpCalloutMockImpl());

        AgroPagoAuraController.FormData form = new AgroPagoAuraController.FormData();
        form.recordId = ERPvs__Vencimientos__c.getSobjectType().getDescribe().getKeyPrefix() + '0'.repeat(12);
        
        Test.startTest();
        AgroPagoRestClient.PaymentsAgroResponse response = AgroPagoAuraController.pay(form);
        Test.stopTest();
    }

    public static testmethod void fail() {
        Opportunity opp = [select id from Opportunity];
        opp.Divisa_Comprobante__c = null;
        opp.Tipo_de_Cambio_Actualizado__c = null;
        update opp;

        Test.setMock(HttpCalloutMock.class, new YourHttpCalloutMockImpl());

        AgroPagoAuraController.FormData form = new AgroPagoAuraController.FormData();
        form.recordId = opp.Id;
        
        Test.startTest();
        AgroPagoRestClient.PaymentsAgroResponse response = AgroPagoAuraController.pay(form);
        Integer invocations = BatchErrorHelper.sentEmails;
        Test.stopTest();

        System.assertEquals(invocations, 1);        
    }

    public class YourHttpCalloutMockImpl implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setBody('{"amount":11000,"authorization_code":"","bin":"448459","card_brand":"Santander Rio Agro","currency_x":"ars","date":"2020-11-09T11:40Z","email":"testa@gmail.com","installments":1,"operation_id":"arpov0060f00000uyYJtAAM2807135","payment_id":9856099,"payment_method_id":80,"reason_error_description":"TARJETA VENCIDA","reason_error_id":54,"status":"approved","status_error":"expired_card","ticket":"9390","transaction_id":10761}');
            res.setStatusCode(200);
            return res;
        }
    }

}