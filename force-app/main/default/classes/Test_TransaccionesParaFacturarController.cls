/**
* @author Maximo Martinez
* @date 22/12/2015
* @description Clase de Test de la Clase Controladora TransaccionesParaFacturarController
*/
@isTest
private class Test_TransaccionesParaFacturarController {
	
	/**
	* @author Maximo Martinez
	* @date 22/12/2015
	* @description Metodo que da de Alta los Datos que necesita el Test
	*/
	@TestSetup static void setup(){

        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());

        //Una moneda sera de la compania
        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));


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

        List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];
        
        ERPvs__Categoria_IVA__c categoria = new ERPvs__Categoria_IVA__c ();
        categoria.Name = '1';
        categoria.ERPvs__Nombre__c = 'uno';
        categoria.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        categoria.ERPvs__Letra_Comprobante_Venta__c = 'A';
        insert categoria;
        
        ERPvs__Empresa__c emp = new ERPvs__Empresa__c();
        emp.Name = 'emp';
        emp.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        emp.ERPvs__Denominacion_o_Razon_Social__c = 'emp';
        emp.ERPvs__Identificacion_Tributaria__c = '30573652084';    
        emp.ERPvs__Categoria_IVA__c = categoria.id;
        insert emp;

        ERPvs__Deposito__c dep = new ERPvs__Deposito__c ();
        dep.Name = '1';
        dep.ERPvs__Empresa__c = emp.id;
        insert dep;

        ERPvs__Sucursal__c suc = new ERPvs__Sucursal__c();
        suc.Name = 'sucursal';
        suc.ERPvs__Deposito__c = dep.id;
        suc.ERPvs__Empresa__c = emp.id;
        suc.ERPvs__Factura_Electronica__c = true;
        suc.ERPvs__Envio_mail_factura_electronica__c = true;
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
        cc.ERPvs__Moneda__c = mon.id; 
        cc.ERPvs__Rubros_Contables__c = rc.id;
        insert cc; 

        ERPvs__Tipo_comprobante_venta__c tcv = new ERPvs__Tipo_comprobante_venta__c ();
        tcv.Name = 'Factura';
        tcv.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        tcv.ERPvs__Empresa__c = emp.id;
        tcv.ERPvs__Cuenta_Contable__c = cc.id;
        tcv.ERPvs__Tipo__c = 'Factura';
        insert tcv;
        
        ERPvs__Vendedor__c vend = new ERPvs__Vendedor__c ();
        vend.ERPvs__Empresa__c = emp.id;
        vend.name = 'vendedor';
        vend.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        insert vend;
        
        ERPvs__Canal_de_venta__c canal = new ERPvs__Canal_de_venta__c ();
        canal.name = 'canal de venta';
        canal.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        insert canal;
        
        Parametros_ERP_y_CRM__c param = new Parametros_ERP_y_CRM__c();
        param.Punto_de_Venta_ARPOV__c = suc.Id;
        param.Canal_de_venta_ARPOV__c = canal.Id;
        param.Punto_de_Venta_cyo__c = suc.Id;
        insert param;

        ERPvs__Condicion_Comercial__c condC = new ERPvs__Condicion_Comercial__c();
        condC.Name = '1';
        condC.ERPvs__Denominacion__c = 'uno';
        condC.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        insert condC;

        ERPvs__Automatizacion_Comprobante_Venta__c acpv = new ERPvs__Automatizacion_Comprobante_Venta__c ();
        acpv.ERPvs__Sucursal_Empresa__c = suc.id;
        acpv.ERPvs__Vendedor__c = vend.id;
        acpv.ERPvs__Canal_de_venta__c = canal.id;
        acpv.ERPvs__Condicion_Comercial__c = condC.id;
        acpv.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        acpv.ERPvs__Usuario__c = UserInfo.getUserId();
        insert acpv;

        ERPvs__Moneda__c monedaNacional = new ERPvs__Moneda__c();
        monedaNacional.Name = 'Peso';
        monedaNacional.ERPvs__Denominacion__c = 'moneda nacional';
        monedaNacional.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        monedaNacional.ERPvs__Moneda_Nacional__c = true;
        monedaNacional.ERPvs__Moneda_Traducida__c = false;
        insert monedaNacional;
        
        ERPvs__Parametro_Facturacion__c pf = new ERPvs__Parametro_Facturacion__c ();
        pf.ERPvs__Fecha_de_Cierre__c = date.today() - 10;
        pf.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        insert pf;

        param = [SELECT Punto_de_Venta_cyo__r.ERPvs__Empresa__c, Canal_de_venta_ARPOV__c,Canal_de_venta_cyo__c,Condicion_Comercial__c,CreatedById,CreatedDate,Datos_Generales__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,Name,OwnerId,Punto_de_Venta_ARPOV__c,Punto_de_Venta_cyo__c FROM Parametros_ERP_y_CRM__c WHERE Id =:param.Id];

        //RecordType que usamos en el Test
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        //RecordType que usamos en el Test
        Id rtAuditorias = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
        

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
        
        //Account obtentor = Test_TestUtils.crearObtentor();
        
        ERPvs__Tipo_de_cambio__c tdc2 = new ERPvs__Tipo_de_cambio__c();
        tdc2.ERPvs__Moneda__c = monedaNacional.id;
        tdc2.ERPvs__Vendedor__c = 1;
        tdc2.ERPvs__Vendedor_pizarra__c = 1;
        tdc2.ERPvs__Fecha__c = Date.today();
        tdc2.Tipo_de_Cambio_CRM__c = tipoCambio.Id;
        insert tdc2;
        
        ERPvs__Tipo_de_cambio__c tdc = new ERPvs__Tipo_de_cambio__c();
        tdc.ERPvs__Moneda__c = mon.id;
        tdc.ERPvs__Vendedor__c = 1;
        tdc.ERPvs__Vendedor_pizarra__c = 1;
        tdc.ERPvs__Fecha__c = Date.today();
        tdc.Tipo_de_Cambio_CRM__c = tipoCambio.Id;
        insert tdc;

        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;

        ERPvs__Letra_Comprobante_Venta__c letra = new ERPvs__Letra_Comprobante_Venta__c();
        letra.ERPvs__Categoria_IVA__c = categoria.id;
        letra.ERPvs__Categoria_IVA_Facturada__c = categoria.id;
        letra.ERPvs__Letra__c = 'A';
        insert letra;

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
        insert obtentor;

        //System.assertEquals([SELECT COUNT() FROM Account WHERE Id =:obtentor.Id AND ERPvs__Activa__c = true],1);

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

        System.assertEquals([SELECT COUNT() FROM Account WHERE Id =:productor.Id AND ERPvs__Activa__c = true],1);
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);

        //Creamos un cultivo
        Cultivo__c cultivo1 = Test_TestUtils.crearCultivo('Cultivo Test 1',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        Campana_Agricola__c campanaAgricola2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo, hoy, manana, '2015 - Test');
        
        ERPvs__Tasa_de_Iva__c ti1 = new ERPvs__Tasa_de_Iva__c ();
        ti1.Name = '10 %';
        ti1.ERPvs__Porcentaje__c = 10;
        ti1.ERPvs__Cuenta_Contable_Facturacion__c = cc.id;
        ti1.ERPvs__Cuenta_Contable_Compra__c = cc.id;
        ti1.ERPvs__Empresa__c = emp.id;
        ti1.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        ti1.ERPvs__Lugar__c = 1;
        insert ti1;

        ERPvs__Unidad__c uni = new ERPvs__Unidad__c ();
        uni.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        uni.name = 'UNI';
        uni.ERPvs__Denominacion__c = 'UNIDAD';
        uni.ERPvs__Usar_por_defecto__c = true;
        insert uni;
        
        ERPvs__Familia_de_Productos__c familia = new ERPvs__Familia_de_Productos__c();
        familia.Name = 'Regalía Extendida';
        familia.ERPvs__Pertenece_A__c = list_dg.get(5).id;
        insert familia;
        
        ERPvs__Marca__c marca = new ERPvs__Marca__c();
        marca.Name = 'Test MP';
        marca.ERPvs__Pertenece_A__c = list_dg.get(5).id;
        insert marca;
        
        //Creamos un par de productos
        List<Product2> productos = new List<Product2>();

        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, false));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, false));
              
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test3',moneda2.Codigo_Univoco__c, 'Variedad Test 3', cultivo1,  'Regalía Extendida', 2, obtentor, false));   
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test4',moneda2.Codigo_Univoco__c, 'Variedad Test 4', cultivo1,  'Regalía Extendida', 2, obtentor, false));

        insert productos;

        System.debug([SELECT ERPvs_Producto__c FROM Product2]);

        System.debug([SELECT ERPvs__Empresa__c FROM ERPvs__Producto__c]);
        
        ERPvs__Producto__c prod = new ERPvs__Producto__c ();
        prod.Name = 'concepto1';
        prod.ERPvs__Empresa__c = emp.Id;
        prod.ERPvs__Cuenta_Contable_Facturacion__c = cc.id;
        prod.ERPvs__Tasa_de_Iva__c = ti1.id;
        prod.ERPvs__Activo__c = true;
        prod.ERPvs__Unidad__c = uni.id;
        prod.ERPvs__Familia__c = familia.id;
        prod.ERPvs__Modelo__c = 'Test M';
        prod.ERPvs__Marca_Producto__c = marca.id;
        prod.CRM_Producto__c = productos[0].Id;
        insert prod;

        productos[0].ERPvs_Producto__c = prod.Id;
		productos[1].ERPvs_Producto__c = prod.Id;
        productos[2].ERPvs_Producto__c = prod.Id;
        productos[3].ERPvs_Producto__c = prod.Id;
        update productos;

        List<Transaccion__c> trs = new List<Transaccion__c>();

        // Creamos Transacciones DUPS

        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        trs.add(Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola, productor, 'Creada', hoy, false));
         
        //Creamos una transaccion de tipo Auditoria 
        trs.add(Test_TestUtils.crearTransaccion(new RecordType(Id = rtAuditorias),'00000002', obtentor, cultivo, null, productor, 'Completa', hoy, false));
        
    
        trs[0].Z9_Cambio__c = true;
        trs[1].Z9_Cambio__c = true;
    
        insert trs;

        List<Opportunity> opps = new List<Opportunity>();

        opps.add(Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', trs[0], 'FC', false));
        opps.add(Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', trs[1], 'FC', false));
        
        insert opps;

        trs[0].Factura__c = opps[0].Id;
        trs[1].Factura__c = opps[1].Id;

        update trs;

        Provincia__c prov = new Provincia__c();
        prov.Name = 'Test';
        insert prov;

        List<Item_de_DUP__c> itemsDUP = new List<Item_de_DUP__c>();

        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        itemsDUP.add(Test_TestUtils.crearItemDeDUP(productos[0], trs[0], 100, 'Uso Propio',1,false,prov.Id));
        itemsDUP.add(Test_TestUtils.crearItemDeDUP(productos[1], trs[0], 100, 'Uso Propio',1,false,prov.Id)); 

        insert itemsDUP;

        //Creamos una transaccion de tipo Auditoria 
        
        List<Item_Auditoria__c> itemsAUD = new List<Item_Auditoria__c>();

        //Creamos un par de items de auditoria para la Transaccion t1
        itemsAUD.add(Test_TestUtils.crearItemAuditoria(productos[0], trs[1], campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        itemsAUD.add(Test_TestUtils.crearItemAuditoria(productos[1], trs[1], campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        
        itemsAUD.get(0).Lugar_de_Siembra__c = prov.Id;
        itemsAUD.get(1).Lugar_de_Siembra__c = prov.Id;

        insert itemsAUD;

        System.debug(LoggingLevel.DEBUG, [SELECT Nombre_de_la_cuenta__r.Estado__c, Obtentor__r.Factura_por_Cuenta_y_Orden__c, Id, Estado__c, Z9_Cambio__c, Z9_Items_Auditoria_Facturar__c, Z9_Items_Dup_Facturar__c, (SELECT Id FROM Items_Auditorias__r), (SELECT Id FROM Item_de_DUP__r) FROM Transaccion__c]);

	}

	@isTest static void test() {

        System.debug(LoggingLevel.DEBUG, [SELECT Z9_Cambio__c FROM Transaccion__c WHERE ((RecordType.DeveloperName = 'Auditorias' AND Z9_Items_Auditoria_Facturar__c > 0 AND Estado__c = 'Completa') OR (RecordType.DeveloperName = 'DUP' AND Z9_Items_Dup_Facturar__c > 0 AND ((Estado__c = 'Respondida' OR Estado__c = 'Respondida Parcialmente') AND (Respondida_via_Minisitio__c = false OR (Respondida_via_Minisitio__c = true AND Resultado_Validacion_Analista__c = 'Positiva') ) ) ) ) AND Z9_Cambio__c = true AND Obtentor__r.Factura_por_Cuenta_y_Orden__c = true AND Nombre_de_la_cuenta__r.Estado__c = 'Activo' AND Tiene_CV__c = false]);

		TransaccionesParaFacturarController ctrl = new TransaccionesParaFacturarController();

		List<TransaccionesParaFacturarController.Transaccion> trs = ctrl.transacciones;

		System.assertEquals(trs.size(),2);

        List<SelectOption> obtentores = ctrl.getObtentores();

        System.assertNotEquals(obtentores.size(),0);

        List<SelectOption> razonSocial = ctrl.getRazonSocial();

        System.assertNotEquals(razonSocial.size(),0);

        ctrl.selectedObtentor = obtentores[0].getValue();
        
        ctrl.selectedRazon = razonSocial[0].getValue();

        ctrl.applyFilter();

        trs = ctrl.transacciones;

        System.assertNotEquals(trs.size(),0);

        trs[0].isSelected = true;

        ctrl.facturar();

        // Ejecutamos metodos del paginador
        ctrl.firstPage();
        ctrl.next();
        
        System.assertEquals(ctrl.hasNext,false);
        
        System.assertEquals(ctrl.hasPrevious, false);
        
        ctrl.prev();

        ctrl.lastPage();

	}
	
}