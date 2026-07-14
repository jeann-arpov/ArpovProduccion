@isTest
private class Test_AccountColorSelectionController {
	
	@TestSetup static void setDatosGenerales() {
        ERPvs.TestUtils.insertDatosGenerales();
    }

	@isTest static void test() {

        Map<String, String> headers = new Map<String,String>{'Content-Type'=>'application/json'};

		List<ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

        ERPvs__Empresa__c emp = new ERPvs__Empresa__c();
        emp.Name = 'emp';
        emp.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        emp.ERPvs__Denominacion_o_Razon_Social__c = 'emp';
        emp.ERPvs__Identificacion_Tributaria__c = '1234567890';                        
        insert emp;

        ERPvs__Sucursal__c suc = new ERPvs__Sucursal__c();
        suc.Name = 'sucursal';
        suc.ERPvs__Empresa__c = emp.id;       
        suc.ERPvs__Nro_Sucursal__c = 1;                 
        insert suc;
        
        ERPvs__Plan_de_Cuentas__c planc = new ERPvs__Plan_de_Cuentas__c();
        planc.Name = 'plan';
        planc.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        planc.ERPvs__Denominacion__c = 'plan';
        planc.ERPvs__Empresa__c = emp.id;                      
        insert planc;

        ERPvs__Rubro_Contable__c rc = new ERPvs__Rubro_Contable__c();
        rc.Name = 'rubro';
        rc.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        rc.ERPvs__Denominacion__c = 'rubro';
        rc.ERPvs__Empresa__c = emp.id; 
        rc.ERPvs__Plan_de_Cuentas__c = planc.id;
        rc.ERPvs__Nivel__c = 1;
        rc.ERPvs__Referente_A__c = 'Activo';
        rc.ERPvs__Siguiente_Nivel__c = 'Rubro';
        insert rc;
        
        ERPvs__Moneda__c monN = new ERPvs__Moneda__c();
        monN.Name = '2';
        monN.ERPvs__Denominacion__c = 'moneda';
        monN.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        monN.ERPvs__Moneda_Nacional__c = true;
        monN.ERPvs__Moneda_Traducida__c = false;
        insert monN;
        
        ERPvs__Moneda__c monT = new ERPvs__Moneda__c();
        monT.Name = '1';
        monT.ERPvs__Denominacion__c = 'moneda';
        monT.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        monT.ERPvs__Moneda_Nacional__c = false;
        monT.ERPvs__Moneda_Traducida__c = true;
        insert monT;

        //Una moneda sera de la compania
        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));

        monedas[0].Moneda_ERP__c = monT.Id;
        monedas[1].Moneda_ERP__c = monT.Id;

        insert monedas;
        
        ERPvs__Auxiliar__c aux = new ERPvs__Auxiliar__c();
        aux.Name = 'auxiliar';
        aux.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        aux.ERPvs__Analisis_por_Cuenta__c = true;
        aux.ERPvs__Analisis_por_Documento__c = true;
        aux.ERPvs__Analisis_por_Vencimiento__c = true;
        insert aux;

        ERPvs__Cuenta_Contable__c cc = new ERPvs__Cuenta_Contable__c();
        cc.Name = '1';
        cc.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        cc.ERPvs__Empresa__c = emp.id; 
        cc.ERPvs__Denominacion__c = 'deno';
        cc.ERPvs__Auxiliares__c = aux.id;
        cc.ERPvs__Moneda__c = monN.id; 
        cc.ERPvs__Rubros_Contables__c = rc.id;
        cc.ERPvs__Cuenta_Contable_en_Fondos__c = true;
        insert cc;
        
        ERPvs__Tipo_de_cambio__c tc = new ERPvs__Tipo_de_cambio__c ();
        tc.ERPvs__Moneda__c = monT.id;
        tc.ERPvs__Fecha__c = date.today(); 
        tc.ERPvs__Comprador__c = 1;
        tc.ERPvs__Vendedor__c = 1;
        tc.ERPvs__Comprador_pizarra__c = 1;
        tc.ERPvs__Vendedor_pizarra__c = 1;
        insert tc;
        
        ERPvs__Tipo_Comprobante_Movimiento_Fondo__c tcmf = new ERPvs__Tipo_Comprobante_Movimiento_Fondo__c ();
        tcmf.Name = 'Pago';
        tcmf.ERPvs__Pertenece_A__c = list_dg.get(4).id;
        tcmf.ERPvs__Empresa__c = emp.id;
        tcmf.ERPvs__Tipo__c = 'Pagos';
        tcmf.ERPvs__Documento__c = 'Pago';
        tcmf.ERPvs__Cuenta_Contable__c = cc.id;
        insert tcmf;
        
        
        ERPvs__Tipo_Comprobante_Movimiento_Fondo__c tcmfC = new ERPvs__Tipo_Comprobante_Movimiento_Fondo__c ();
        tcmfC.Name = 'Cobranzas';
        tcmfC.ERPvs__Pertenece_A__c = list_dg.get(4).id;
        tcmfC.ERPvs__Empresa__c = emp.id;
        tcmfC.ERPvs__Tipo__c = 'Cobranzas';
        tcmfC.ERPvs__Documento__c = 'Cobranzas';
        tcmfC.ERPvs__Cuenta_Contable__c = cc.id;
        insert tcmfC;
        
        Account acc = new Account ();
        acc.name = 'Proveedor de Prueba';
        acc.ERPvs__Activa__c = true;
        insert acc;
        
        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;
        
        ERPvs__Categoria_IVA__c categoria = new ERPvs__Categoria_IVA__c ();
        categoria.Name = '1';
        categoria.ERPvs__Nombre__c = 'uno';
        categoria.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        categoria.ERPvs__Letra_Comprobante_Venta__c = 'A';
        insert categoria;
        
        ERPvs__Tipo_comprobante_venta__c tcv = new ERPvs__Tipo_comprobante_venta__c ();
        tcv.Name = 'Factura';
        tcv.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        tcv.ERPvs__Empresa__c = emp.id;
        tcv.ERPvs__Cuenta_Contable__c = cc.id;
        tcv.ERPvs__Tipo__c = 'Factura';
        insert tcv;

        Account obtentor = new Account();
        obtentor.Name = 'Socio';
        obtentor.Es_Socio__c = true;
        obtentor.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
        obtentor.Clave_Unica__c = 'socio';
        obtentor.N_CUIT__c = '33693450239';
        obtentor.Condicion_Impositiva__c = 'No Aplica';
        obtentor.Localidad_Envio__c = localidad.Id;
        obtentor.Type = 'Obtentor';
        obtentor.Id_Obtentor__c = '1';
        obtentor.Nombre_Obtentor__c = 'Obtentor';
        obtentor.ERPvs__Categoria_IVA__c = categoria.Id;
        obtentor.Tipo_comprobante_venta__c = tcv.Id;
        obtentor.Cuenta_Activa__c = true;
        obtentor.ERPvs__Activa__c = true;
        obtentor.Factura_por_Cuenta_y_Orden__c = true;
        obtentor.Estado__c = 'Activo';
        obtentor.Umbral_Importe__c = 100;
        obtentor.Umbral_Porcentaje__c = 10;
        obtentor.Diferencia_de_cambio__c = 'Con impuestos incluídos';
        insert obtentor;

        System.assertEquals([SELECT COUNT() FROM Account WHERE RecordTypeId = :RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor')],1);
        
        Account productor = new Account();
        productor.Name = 'Productor';
        productor.Es_Socio__c = true;
        productor.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor');
        productor.Clave_Unica__c = 'productor';
        productor.N_CUIT__c = '30641405554';
        productor.Condicion_Impositiva__c = 'No Aplica';
        productor.Localidad_Envio__c = localidad.Id;
        productor.Type = 'Productor';
        productor.ERPvs__Categoria_IVA__c = categoria.Id;
        productor.Cuenta_Activa__c = true;
        productor.Estado__c = 'Activo';
        insert productor;

        productor.ERPvs__Activa__c = true;
        update productor;
		
		ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(new List<Account>{obtentor,productor});
		stdSetController.setSelected(new List<Account>{obtentor,productor});
		
        Test.startTest();
        Test.setMock(HttpCalloutMock.class, new Test_SalesforceRestClient.TestCalloutMock(headers,200,'{"columns":[{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Estado_Gestion_Cobranza_IMG__c","hidden":false,"label":"Gestión Cobranza","searchable":false,"selectListItem":"Estado_Gestion_Cobranza_IMG__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"N_CUIT__c","hidden":false,"label":"N° CUIT","searchable":true,"selectListItem":"N_CUIT__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Name","hidden":false,"label":"Nombre de la cuenta","searchable":true,"selectListItem":"Name","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"Z-A","descendingLabel":"A-Z","fieldNameOrPath":"Provincia_Envio__c","hidden":false,"label":"Provincia Envio","searchable":false,"selectListItem":"Provincia_Envio__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"string"},{"ascendingLabel":"Ascendente","descendingLabel":"Descendente","fieldNameOrPath":"Localidad_Envio__r.Name","hidden":false,"label":"Localidad Envio","searchable":false,"selectListItem":"Localidad_Envio__r.Name","sortDirection":null,"sortIndex":null,"sortable":true,"type":"reference"},{"ascendingLabel":"Nuevo a antiguo","descendingLabel":"Antiguo a nuevo","fieldNameOrPath":"Ultima_Gestion_de_Cobranza__c","hidden":false,"label":"Ult. Gestión de Cobranza","searchable":false,"selectListItem":"Ultima_Gestion_de_Cobranza__c","sortDirection":"descending","sortIndex":0,"sortable":true,"type":"date"},{"ascendingLabel":"9-0","descendingLabel":"0-9","fieldNameOrPath":"Deuda_Total_ARS__c","hidden":false,"label":"Deuda Total ARS","searchable":false,"selectListItem":"Deuda_Total_ARS__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"double"},{"ascendingLabel":"9-0","descendingLabel":"0-9","fieldNameOrPath":"Deuda_Rango_30__c","hidden":false,"label":"Deuda Rango 30","searchable":false,"selectListItem":"Deuda_Rango_30__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"double"},{"ascendingLabel":"9-0","descendingLabel":"0-9","fieldNameOrPath":"Deuda_Rango_60__c","hidden":false,"label":"Deuda Rango 60","searchable":false,"selectListItem":"Deuda_Rango_60__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"double"},{"ascendingLabel":"9-0","descendingLabel":"0-9","fieldNameOrPath":"Deuda_Rango_90__c","hidden":false,"label":"Deuda Rango 90","searchable":false,"selectListItem":"Deuda_Rango_90__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"double"},{"ascendingLabel":"9-0","descendingLabel":"0-9","fieldNameOrPath":"Deuda_Fuera_de_Rango__c","hidden":false,"label":"Deuda Fuera de Rango","searchable":false,"selectListItem":"Deuda_Fuera_de_Rango__c","sortDirection":null,"sortIndex":null,"sortable":true,"type":"double"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"Id","hidden":true,"label":"Id. de la cuenta","searchable":false,"selectListItem":"Id","sortDirection":null,"sortIndex":null,"sortable":false,"type":"id"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"RecordTypeId","hidden":true,"label":"Id. de tipo de registro","searchable":false,"selectListItem":"RecordTypeId","sortDirection":null,"sortIndex":null,"sortable":false,"type":"reference"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"CreatedDate","hidden":true,"label":"Fecha de creación","searchable":false,"selectListItem":"CreatedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"LastModifiedDate","hidden":true,"label":"Fecha de la última modificación","searchable":false,"selectListItem":"LastModifiedDate","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"SystemModstamp","hidden":true,"label":"Modstamp del sistema","searchable":false,"selectListItem":"SystemModstamp","sortDirection":null,"sortIndex":null,"sortable":false,"type":"datetime"},{"ascendingLabel":null,"descendingLabel":null,"fieldNameOrPath":"Localidad_Envio__c","hidden":true,"label":"Localidad Envio","searchable":false,"selectListItem":"Localidad_Envio__c","sortDirection":null,"sortIndex":null,"sortable":false,"type":"reference"}],"id":"00B0f000009g5yM","orderBy":[{"fieldNameOrPath":"Ultima_Gestion_de_Cobranza__c","nullsPosition":"last","sortDirection":"descending"},{"fieldNameOrPath":"Id","nullsPosition":"first","sortDirection":"ascending"}],"query":"SELECT Estado_Gestion_Cobranza_IMG__c, N_CUIT__c, Name, Provincia_Envio__c, Localidad_Envio__r.Name, Ultima_Gestion_de_Cobranza__c, Deuda_Total_ARS__c, Deuda_Rango_30__c, Deuda_Rango_60__c, Deuda_Rango_90__c, Deuda_Fuera_de_Rango__c, Id, RecordTypeId, CreatedDate, LastModifiedDate, SystemModstamp, Localidad_Envio__c FROM Account WHERE RecordTypeId = \'012G0000001B3jD\' OR RecordTypeId = \'012G0000001B3j8\' OR RecordTypeId = \'012G0000001B3jI\' OR RecordTypeId = \'012G0000001B3j3\' ORDER BY Ultima_Gestion_de_Cobranza__c DESC NULLS LAST, Id ASC NULLS FIRST","relatedEntityId":null,"scope":"everything","scopeEntityId":null,"sobjectType":"Account","whereCondition":{"conditions":[{"field":"RecordTypeId","operator":"equals","values":["\'012G0000001B3jD\'"]},{"field":"RecordTypeId","operator":"equals","values":["\'012G0000001B3j8\'"]},{"field":"RecordTypeId","operator":"equals","values":["\'012G0000001B3jI\'"]},{"field":"RecordTypeId","operator":"equals","values":["\'012G0000001B3j3\'"]}],"conjunction":"or"}}'));
        AccountColorSelectionController ctrl = new AccountColorSelectionController(stdSetController);
        ctrl.changeColor();
        Test.stopTest();

	}
	
}