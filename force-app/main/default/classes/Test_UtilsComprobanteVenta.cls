@isTest
private class Test_UtilsComprobanteVenta {
	
	@isTest static void testCreateComprobantesVentaFromDups() {
        Test_TestUtils.disableFlows();
        Variedad__c var = new Variedad__c(Name = 'test');
        insert var;
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());

        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;

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
        
        Account acc = new Account ();
        acc.name = 'Proveedor de Prueba';
        acc.ERPvs__Activa__c = true;
        acc.ERPvs__Categoria_IVA__c = categoria.id;
        acc.ERPvs__Denominacion_Y_Razon_Social__c = 'Proveedor de Prueba';
        insert acc;

        //System.assertEquals([SELECT COUNT() FROM Account WHERE Id =:acc.Id AND ERPvs__Activa__c = true],1);

        
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


        ERPvs__Pais__c pais = new ERPvs__Pais__c();
        pais.Name = 'Pais';
        pais.ERPvs__Nombre__c = 'Denominacion';
        pais.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        insert pais;
        
        ERPvs__Provincia_Departamento_Estado__c provincia = new ERPvs__Provincia_Departamento_Estado__c();
        provincia.Name = '1';
        provincia.ERPvs__Nombre__c = 'uno';
        provincia.ERPvs__Pais__c = pais.id;
        provincia.ARP_Provincia__c = prov.Id;
        insert provincia;
        
        
        


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
        insert productor;

        productor.ERPvs__Activa__c = true;
        update productor;

        ERPvs__Percepciones__c percepcion = new ERPvs__Percepciones__c();
        percepcion.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcion.ERPvs__Empresa__c = emp.Id;
        percepcion.ERPvs__Tipo__c = 'IIBB';
        percepcion.ERPvs__Provincia__c = provincia.Id;
        insert percepcion;


        ERPvs__Percepciones__c percepcionObtentor = new ERPvs__Percepciones__c();
        percepcionObtentor.ERPvs__A_cuenta_y_orden_de__c = obtentor.Id;
        percepcionObtentor.ERPvs__Empresa__c = emp.Id;
        percepcionObtentor.ERPvs__Tipo__c = 'IIBB';
        percepcionObtentor.ERPvs__Provincia__c = provincia.Id;
        insert percepcionObtentor;

        ERPvs__Definicion_Percepcion_IIBB__c dpIIBB = new ERPvs__Definicion_Percepcion_IIBB__c();
        dpIIBB.ERPvs__Territorialidad__c = 'Prov Incripción';
        dpIIBB.ERPvs__Percepcion__c = 5;
        dpIIBB.ERPvs__Inscripcion__c = 'Local';
        dpIIBB.ERPvs__Percepciones__c = percepcion.Id;
        insert dpIIBB;

        ERPvs__Percepciones__c percepcionIVA = new ERPvs__Percepciones__c();
        percepcionIVA.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcionIVA.ERPvs__Tipo__c = 'IVA';
        insert percepcionIVA;

        ERPvs__Percepciones__c percepcionIVAObtentor = new ERPvs__Percepciones__c();
        percepcionIVAObtentor.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcionIVAObtentor.ERPvs__Tipo__c = 'IVA';
        insert percepcionIVAObtentor;

        System.assertEquals([SELECT id FROM Account WHERE Id =:productor.Id AND ERPvs__Activa__c = true limit 2].size(),1);
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);

        //Creamos un cultivo
        Cultivo__c cultivo1 = Test_TestUtils.crearCultivo('Cultivo Test 1',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test', false);
        campanaAgricola.Estado__c = 'Completa';
        insert campanaAgricola;
                
        ERPvs__Tasa_de_Iva__c ti1 = new ERPvs__Tasa_de_Iva__c ();
        ti1.Name = '10 %';
        ti1.ERPvs__Porcentaje__c = 10;
        ti1.ERPvs__Cuenta_Contable_Facturacion__c = cc.id;
        ti1.ERPvs__Cuenta_Contable_Compra__c = cc.id;
        ti1.ERPvs__Empresa__c = emp.id;
        ti1.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        ti1.ERPvs__Lugar__c = 1;
        insert ti1;

        ERPvs__Definicion_Percepcion_IVA__c dpIVA = new ERPvs__Definicion_Percepcion_IVA__c();
        dpIVA.ERPvs__Retencion__c = 5;
        dpIVA.ERPvs__Tasa_de_Iva__c = ti1.Id;
        dpIVA.ERPvs__Percepciones__c = percepcionIVA.Id;
        insert dpIVA;

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

        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false));
              
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test3',moneda2.Codigo_Univoco__c, 'Variedad Test 3', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, false));   
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test4',moneda2.Codigo_Univoco__c, 'Variedad Test 4', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, false));

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
        trs.add(Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000002', obtentor, cultivo1, campanaAgricola, productor, 'Creada', hoy, false));

        trs.add(Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000003', obtentor, cultivo1, campanaAgricola, productor, 'Creada', hoy, false));

    
        trs[0].Z9_Cambio__c = true;
        trs[1].Z9_Cambio__c = true;

        insert trs;    

        List<Opportunity> opps = new List<Opportunity>();

        opps.add(Test_TestUtils.crearOpportunity(listaPrecios, 'TestTest', Date.today(), 'TestTest', trs[0], 'NC', false));
        opps.add(Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', trs[1], 'FC', false));
        
        insert opps;

        trs[0].Factura__c = opps[0].Id;
        trs[1].Factura__c = opps[1].Id;
        trs[2].Factura__c = opps[1].Id;

        update trs;

        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();

        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        items.add(Test_TestUtils.crearItemDeDUP(productos[0], trs[0], 100, 'Uso Propio',1,false));
        items.add(Test_TestUtils.crearItemDeDUP(productos[1], trs[0], 100, 'Uso Propio',1,false));
        
        //Creamos dos Item_de_Dup con estado No Informada
        items.add(Test_TestUtils.crearItemDeDUP(productos[2], trs[1], null, 'No Informada',1,false));
        items.add(Test_TestUtils.crearItemDeDUP(productos[3], trs[1], null, 'No Informada',1,false));   

        insert items;

        trs[2].Subestado__c = 'Negativa';
        trs[2].DUP_Original__c = trs[1].id; 

        update trs[2];

        UtilsComprobanteVenta.createComprobantesVentaFromDups(new Set<Id>{trs[0].Id,trs[1].Id}, Date.today());

	}

	@isTest static void testCreateComprobantesVentaFromAuds(){
        Test_TestUtils.disableFlows();
        Variedad__c var = new Variedad__c(Name = 'test');
        insert var;
        //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());

        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;

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
        
        Account acc = new Account ();
        acc.name = 'Proveedor de Prueba';
        acc.ERPvs__Activa__c = true;
        acc.ERPvs__Categoria_IVA__c = categoria.id;
        acc.ERPvs__Denominacion_Y_Razon_Social__c = 'Proveedor de Prueba';
        insert acc;

        //System.assertEquals([SELECT COUNT() FROM Account WHERE Id =:acc.Id AND ERPvs__Activa__c = true],1);

        
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


        ERPvs__Pais__c pais = new ERPvs__Pais__c();
        pais.Name = 'Pais';
        pais.ERPvs__Nombre__c = 'Denominacion';
        pais.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        insert pais;
        
        ERPvs__Provincia_Departamento_Estado__c provincia = new ERPvs__Provincia_Departamento_Estado__c();
        provincia.Name = '1';
        provincia.ERPvs__Nombre__c = 'uno';
        provincia.ERPvs__Pais__c = pais.id;
        provincia.ARP_Provincia__c = prov.Id;
        insert provincia;
        

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
        insert productor;

        productor.ERPvs__Activa__c = true;
        update productor;


        ERPvs__Percepciones__c percepcion = new ERPvs__Percepciones__c();
        percepcion.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcion.ERPvs__Empresa__c = emp.Id;
        percepcion.ERPvs__Tipo__c = 'IIBB';
        percepcion.ERPvs__Provincia__c = provincia.Id;
        insert percepcion;


        ERPvs__Percepciones__c percepcionObtentor = new ERPvs__Percepciones__c();
        percepcionObtentor.ERPvs__A_cuenta_y_orden_de__c = obtentor.Id;
        percepcionObtentor.ERPvs__Empresa__c = emp.Id;
        percepcionObtentor.ERPvs__Tipo__c = 'IIBB';
        percepcionObtentor.ERPvs__Provincia__c = provincia.Id;
        insert percepcionObtentor;

        ERPvs__Definicion_Percepcion_IIBB__c dpIIBB = new ERPvs__Definicion_Percepcion_IIBB__c();
        dpIIBB.ERPvs__Territorialidad__c = 'Prov Incripción';
        dpIIBB.ERPvs__Percepcion__c = 5;
        dpIIBB.ERPvs__Inscripcion__c = 'Local';
        dpIIBB.ERPvs__Percepciones__c = percepcion.Id;
        insert dpIIBB;

        ERPvs__Percepciones__c percepcionIVA = new ERPvs__Percepciones__c();
        percepcionIVA.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcionIVA.ERPvs__Tipo__c = 'IVA';
        insert percepcionIVA;

        ERPvs__Percepciones__c percepcionIVAObtentor = new ERPvs__Percepciones__c();
        percepcionIVAObtentor.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcionIVAObtentor.ERPvs__Tipo__c = 'IVA';
        insert percepcionIVAObtentor;

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
        
        Campana_Agricola__c campanaAgricola2 = Test_TestUtils.crearCampanaAgricola('2015', cultivo1, hoy, manana, '2015 - Test');
        
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

        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',moneda2.Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false));
              
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test3',moneda2.Codigo_Univoco__c, 'Variedad Test 3', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, false));   
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test4',moneda2.Codigo_Univoco__c, 'Variedad Test 4', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, false));

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
        trs.add(Test_TestUtils.crearTransaccion(new RecordType(Id = rtAuditorias),'00000001', obtentor, cultivo, null, productor, 'Creada', hoy, false));

        trs[0].Z9_Cambio__c = true;
        

        insert trs[0];

        List<Opportunity> opps = new List<Opportunity>();

        opps.add(Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', trs[0], 'FC', false));
        
        insert opps[0];

        trs[0].Factura__c = opps[0].Id;

        UtilsComprobanteVenta.setOportunidad(new Set<Id>{opps[0].Id});

        update trs;


        List<Item_Auditoria__c> items = new List<Item_Auditoria__c>();

        //Creamos un par de items de auditoria para la Transaccion t1
        items.add(Test_TestUtils.crearItemAuditoria(productos[0], trs[0], campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        items.add(Test_TestUtils.crearItemAuditoria(productos[1], trs[0], campanaAgricola, 'Irregular', 'Granel', 1,1, false));
        
        items.get(0).Lugar_de_Siembra__c = prov.Id;
        items.get(1).Lugar_de_Siembra__c = prov.Id;

        insert items;

        ERPvs.ApexLogger.debug(LoggingLevel.WARN,'ERROR');

        UtilsComprobanteVenta.createComprobantesVentaFromAuditorias(new Set<Id>{trs[0].Id}, Date.today());
	        
        //Creamos una transaccion de tipo Auditoria 
        trs.add(Test_TestUtils.crearTransaccion(new RecordType(Id = rtAuditorias),'00000002', obtentor, cultivo1, null, productor, 'Creada', hoy, false));
        trs[0].Estado__c = 'Facturada';
        update trs[0];
        trs[1].Z9_Cambio__c = true;
        trs[1].Subestado__c = 'Negativa';
        trs[1].Auditoria__c = trs[0].id; 
        insert trs[1];    

        opps.add(Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', trs[1], 'FC', false));
        trs[1].Factura__c = opps[1].Id;
        insert opps[1];

        items = new List<Item_Auditoria__c>();
        //Creamos un par de item de auditoria para la Transaccion t2
        items.add(Test_TestUtils.crearItemAuditoria(productos[2], trs[1], campanaAgricola2, 'Irregular', 'Granel', 1,1, false));
        items.add(Test_TestUtils.crearItemAuditoria(productos[3], trs[1], campanaAgricola2, 'Irregular', 'Granel', 1,1, false));

        items.get(0).Lugar_de_Siembra__c = prov.Id;
        items.get(1).Lugar_de_Siembra__c = prov.Id;
        insert items;
        UtilsComprobanteVenta.createComprobantesVentaFromAuditorias(new Set<Id>{trs[1].Id}, Date.today());

    } 

    public static testmethod void cvsFromOpps() {
        Test_TestUtils.disableFlows();
        Profile p = [SELECT Id FROM Profile WHERE Name='Administrador' LIMIT 1]; 
        User u = new User(
            Alias = 'testVsc', Email='testVsc@testarPov.com', 
            EmailEncodingKey='UTF-8', LastName='VCS Admin', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='testVsc@testarPov.com');
        insert u;
        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.Factura_por_Cuenta_y_Orden_SE__c = true;
        obtentor.ERPvs__Activa__c = true;
        update obtentor;

        // Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Sembra_Evolucion__C = true, Biotecnologia__c = 'RR1');
        // insert var;

        Erpvs.TestUtils.insertDatosGenerales();

        List <ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

        ERPvs__Moneda__c mon = new ERPvs__Moneda__c();
        mon.Name = '1';
        mon.ERPvs__Denominacion__c = 'moneda';
        mon.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        mon.ERPvs__Moneda_Nacional__c = false;
        mon.ERPvs__Moneda_Traducida__c = true;
        insert mon;

        Moneda__c moneda = Test_TestUtils.crearMoneda('USD','USD',true, false);
        moneda.Moneda_ERP__c = mon.id;
        insert moneda;

        Test_TestUtils.crearTipodeCambio(moneda,2,Date.today());

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Sembra_Evolucion__C = true, Biotecnologia__c = 'RR1', Cultivo__c = cultivo.Id);
        insert var;
        Product2 prod = Test_TestUtils.crearProducto(true,'ProductoTest 1',moneda.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, true);

        PricebookEntry entry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id,
            UnitPrice = 10000, IsActive = true);

        insert entry;

        Compra_HT__c compra = new Compra_HT__c(Lista_de_Precios__c = Test.getStandardPricebookId(), Cuenta_Productor__c = obtentor.id, Estado__c = 'Creada');
        insert compra;

        compra.Estado__c = 'Pendiente de Facturación';
        update compra;

        Linea_de_Compra_HT__c linea = new Linea_de_Compra_HT__c(Id_Producto_de_Lista_de_Precio__c = entry.id, Cantidad__c = 1, Precio_de_Lista__c = 10, Compra_HT__c = compra.id, Estado__c = 'Creada', Producto__c = prod.Id);
        insert linea;

        linea.Estado__C = 'Facturable';
        update linea;

        insert new Parametros_ERP_y_CRM__c();

        insert new Erpvs__Deshabilitacion_triggers__c(Erpvs__Comprobante_de_Venta__c = true);

        UtilsComprobanteVenta.createComprobantesVentaFromOpps(new Set<Id>{[select id from opportunity limit 1].id}, System.today());
    }

    public static testmethod void coverage() {
        ERPvs__Productos_Comprobante_de_Venta__c comp = new ERPvs__Productos_Comprobante_de_Venta__c();
        List<ERPvs__Productos_Comprobante_de_Venta__c> comps = new List<ERPvs__Productos_Comprobante_de_Venta__c>{comp};
        UtilsComprobanteVenta.checkErrors(Database.update(comps, false), comps);

        Id prov1 = getFakeId(ERPvs__Provincia_Departamento_Estado__c.SobjectType);
        Id prov2 = getFakeId(ERPvs__Provincia_Departamento_Estado__c.SobjectType);
        Id prov3 = getFakeId(ERPvs__Provincia_Departamento_Estado__c.SobjectType);
        Id prov4 = getFakeId(ERPvs__Provincia_Departamento_Estado__c.SobjectType);
        Id acc = getFakeId(Account.SobjectType);

        ERPvs__Percepciones_de_IB__c ib = new ERPvs__Percepciones_de_IB__c(ERPvs__Porcentaje__c = 3, ERPvs__Coeficiente_padron__c = 1, ERPvs__Provincia__c = prov1);
        ERPvs__Percepciones_de_IB__c ib2 = new ERPvs__Percepciones_de_IB__c(ERPvs__Porcentaje__c = 3, ERPvs__Coeficiente_padron__c = 1, ERPvs__Provincia__c = prov2);
        ERPvs__Percepciones_de_IB__c ib3 = new ERPvs__Percepciones_de_IB__c(ERPvs__Porcentaje__c = 3, ERPvs__Coeficiente_padron__c = 1, ERPvs__Provincia__c = prov3);
        ERPvs__Percepciones_de_IB__c ib4 = new ERPvs__Percepciones_de_IB__c(ERPvs__Porcentaje__c = 3, ERPvs__Coeficiente_padron__c = 1, ERPvs__Provincia__c = prov4);
        ERPvs__Percepciones_de_IB__c ib5 = new ERPvs__Percepciones_de_IB__c(ERPvs__Porcentaje__c = 3, ERPvs__Coeficiente_padron__c = 1);

        ERPvs__Comprobante_Venta__c cv = new ERPvs__Comprobante_Venta__c(Oportunidad__c = null, ERPvs__Fecha__c = System.today(), ERPvs__A_cuenta_y_orden_de__c = acc, id = getFakeId(ERPvs__Comprobante_Venta__c.SobjectType));
        
        cv = (ERPvs__Comprobante_Venta__c) hydrateChildRecordList('ERPvs__Percepciones_de_IB__r', cv, new list<ERPvs__Percepciones_de_IB__c>{ib, ib2, ib3, ib4, ib5});
        cv = (ERPvs__Comprobante_Venta__c) setFormulafield(cv, ERPvs__Comprobante_Venta__c.ERPvs__Subtotal__c.getDescribe().getName(), 3);

        Parametros_ERP_y_CRM__c param = new Parametros_ERP_y_CRM__c(Punto_de_Venta_ARPOV__c = null, Canal_de_venta_ARPOV__c = null, Punto_de_Venta_cyo__c = null);

        Map<String, ERPvs__Comprobante_Venta__c> cvs = new Map<String, ERPvs__Comprobante_Venta__c>{cv.id => cv};

        Map<String, ERPvs__Percepciones__c> percepciones = new Map<String, ERPvs__Percepciones__c>{
            acc + String.valueOf(prov1) => new ERPvs__Percepciones__c(ERPvs__Devoluciones__c = 'Mismo mes'),
            acc + String.valueOf(prov2) => new ERPvs__Percepciones__c(ERPvs__Devoluciones__c = '1 año'),
            acc + String.valueOf(prov3) => new ERPvs__Percepciones__c(ERPvs__Devoluciones__c = '6 Quicenas'),
            acc + String.valueOf(prov4) => new ERPvs__Percepciones__c(ERPvs__Devoluciones__c = '???')
        };

        try {
            UtilsComprobanteVenta.processCvs(cvs, new Map<String, ERPvs__Comprobante_Venta__c>{null => cv}, percepciones, param, new Set<String>());
            System.assert(false, 'Deberia llegar hasta el insert');             
        } catch (System.DmlException e) {}

        UtilsComprobanteVenta.obtenerNrosComprobantesAplicaciones(cvs.values(), new Map<Id, ERPvs__Comprobante_Venta__c>{cv.id => cv});
    }
	
    private static SObject hydrateChildRecordList(String relationshipName, SObject parent, List<SObject> children) {
        String recordJson = JSON.serialize(parent);
        String childrenJson = '"' + relationshipName + '": {'
            + '"totalSize": ' + children.size() + ', '
            + '"done": true,'
            + '"records": ' + JSON.serialize(children)
            + '}';
        recordJson = recordJson.substring(0, recordJson.length() - 1) + ',' + childrenJson + '}';
    
        return (SObject) JSON.deserialize(recordJson, SObject.class);
    }

    private static SObject setFormulafield(SObject sObj, String fieldName, Object value) {
        String jsonString = JSON.serialize(sObj);
        Map<String,Object> dataMap = (Map<String,Object>)JSON.deserializeUntyped(jsonString);
        dataMap.put(fieldName, value);
        jsonString = JSON.serialize(dataMap);
        return (SObject)JSON.deserialize(jsonString, SObject.class);
    }

   static Integer s_num = 1;
   public static String getFakeId(Schema.SObjectType sot) {
      String result = String.valueOf(s_num++);
      return sot.getDescribe().getKeyPrefix() + 
         '0'.repeat(12-result.length()) + result;
   }

}