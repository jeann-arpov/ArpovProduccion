@isTest
private class Test_DrilldownComprobantesDePago {
	
	@TestSetup static void setup() {
		

        ERPvs.TestUtils.insertDatosGenerales();

        Variedad__c var = new Variedad__c(Name = 'test');
        insert var;

        List<ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

        ERPvs__Categoria_IVA__c cat = new ERPvs__Categoria_IVA__c ();
        cat.Name = 'M';
        cat.Erpvs__Pertenece_A__c = list_dg.get(0).id;
        cat.ERPvs__Letra_Comprobante_Venta__c = 'M';
        insert cat;

            //Obtenemos la lista de precios standard del sitio
        Pricebook2 listaPrecios = new Pricebook2(Id = Utils.getPricebook2Id());

        Provincia__c prov = new Provincia__c();

        prov.Name = 'Test';

        insert prov;

        //Una moneda sera de la compania
        List<Moneda__c> monedas = new List<Moneda__c>();

        monedas.add(Test_TestUtils.crearMoneda('TEST1','TEST1',true, false));
        monedas.add(Test_TestUtils.crearMoneda('TEST2','TEST2',false, false));
        
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
        tcv.Name = 'Comisiones';
        tcv.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        tcv.ERPvs__Empresa__c = emp.id;
        tcv.ERPvs__Cuenta_Contable__c = cc.id;
        tcv.ERPvs__Tipo__c = 'Factura';
        insert tcv;
        
        /*Account acc = new Account ();
        acc.name = 'Proveedor de Prueba';
        acc.ERPvs__Activa__c = true;
        acc.ERPvs__Categoria_IVA__c = categoria.id;
        acc.ERPvs__Denominacion_Y_Razon_Social__c = 'Proveedor de Prueba';
        insert acc;
        */
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
        pf.ERPvs__Empresa__c = emp.id;
        insert pf;

        param = [SELECT Punto_de_Venta_cyo__r.ERPvs__Empresa__c, Canal_de_venta_ARPOV__c,Canal_de_venta_cyo__c,Condicion_Comercial__c,CreatedById,CreatedDate,Datos_Generales__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,Name,OwnerId,Punto_de_Venta_ARPOV__c,Punto_de_Venta_cyo__c FROM Parametros_ERP_y_CRM__c WHERE Id =:param.Id];

        //RecordType que usamos en el Test
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        //Obtenemos la fechaActual
        Date fechaActual = Date.today();
    
        //Creamos un tipo de cambio para la moneda extranjera
        Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(monedas[1],2,fechaActual);
        
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
        
        List<Account> cuentas = new List<Account>();
        
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
        cuentas.add(obtentor);

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
        cuentas.add(productor);

        insert cuentas;

        productor.ERPvs__Activa__c = true;
        update productor;

        List<ERPvs__Percepciones__c> percepciones = new List<ERPvs__Percepciones__c>();

        ERPvs__Percepciones__c percepcion = new ERPvs__Percepciones__c();
        percepcion.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcion.ERPvs__Empresa__c = emp.Id;
        percepcion.ERPvs__Tipo__c = 'IIBB';
        percepcion.ERPvs__Provincia__c = provincia.Id;
        percepciones.add(percepcion);


        ERPvs__Percepciones__c percepcionObtentor = new ERPvs__Percepciones__c();
        percepcionObtentor.ERPvs__A_cuenta_y_orden_de__c = obtentor.Id;
        percepcionObtentor.ERPvs__Empresa__c = emp.Id;
        percepcionObtentor.ERPvs__Tipo__c = 'IIBB';
        percepcionObtentor.ERPvs__Provincia__c = provincia.Id;
        percepciones.add(percepcionObtentor);

        ERPvs__Percepciones__c percepcionIVA = new ERPvs__Percepciones__c();
        percepcionIVA.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcionIVA.ERPvs__Tipo__c = 'IVA';
        percepciones.add(percepcionIVA);

        ERPvs__Percepciones__c percepcionIVAObtentor = new ERPvs__Percepciones__c();
        percepcionIVAObtentor.ERPvs__A_cuenta_y_orden_de__c = productor.Id;
        percepcionIVAObtentor.ERPvs__Tipo__c = 'IVA';
        percepciones.add(percepcionIVAObtentor);

        insert percepciones;

        ERPvs__Definicion_Percepcion_IIBB__c dpIIBB = new ERPvs__Definicion_Percepcion_IIBB__c();
        dpIIBB.ERPvs__Territorialidad__c = 'Prov Incripción';
        dpIIBB.ERPvs__Percepcion__c = 5;
        dpIIBB.ERPvs__Inscripcion__c = 'Local';
        dpIIBB.ERPvs__Percepciones__c = percepcion.Id;
        insert dpIIBB;

        System.assertEquals([SELECT COUNT() FROM Account WHERE Id =:productor.Id AND ERPvs__Activa__c = true],1);
        
        List<Cultivo__c> cultivos = new List<Cultivo__c>();

        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75,false);
        //Creamos un cultivo
        Cultivo__c cultivo1 = Test_TestUtils.crearCultivo('Cultivo Test 1',75,false);
        
        cultivos.add(cultivo);
        cultivos.add(cultivo1);

        insert cultivos;

        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
         
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

        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',monedas[0].Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',monedas[1].Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, var.id, false));
              
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test3',monedas[1].Codigo_Univoco__c, 'Variedad Test 3', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, false));   
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test4',monedas[1].Codigo_Univoco__c, 'Variedad Test 4', cultivo1,  'Regalía Extendida', 2, obtentor, var.id, false));

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
    
        trs[0].Z9_Cambio__c = true;
    
        insert trs;

        List<Opportunity> opps = new List<Opportunity>();

        
        Opportunity factura1 = new Opportunity();
        factura1.N_de_Comprobante__c = 'A-0001-00000001';
        factura1.Name = 'Factura TEST 1';
        factura1.StageName = 'Facturada';
        factura1.CloseDate = Date.today();
        factura1.Obtentor__c = obtentor.Id;
        factura1.Divisa_Comprobante__c = 'ARS';
        factura1.Amount = 10000;
        factura1.Saldo_a_Cobrar_Comprobante__c = 100;
        factura1.Saldo_a_Gestionar__c = 100;
        factura1.Fecha_Pedido_Facturacion__c = Date.newInstance(2014, 11, 21);
        factura1.Fecha_de_Facturacion__c = Date.newInstance(2015, 3, 19);
        factura1.Fecha_Prevista_de_Pago__c = Date.newInstance(2015, 4, 18);
        factura1.Fecha_Emision_Comprobante__c = Date.newInstance(2015, 3, 19);
        factura1.Fecha_Vencimiento_Comprobante__c = Date.newInstance(2015, 4, 18);
        factura1.Fecha_Reclamo_Factura__c = Date.newInstance(2015, 5, 18);
        factura1.Transaccion__c = trs[0].Id;
        factura1.AccountId = productor.Id;
        factura1.Tipo_de_Cambio_Actualizado__c = 10;
        opps.add(factura1);

        insert opps;

        System.debug(LoggingLevel.WARN, [SELECT Saldo_Actualizado__c FROM Opportunity]);

        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();

        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        items.add(Test_TestUtils.crearItemDeDUP(productos[0], trs[0], 1000, 'Uso Propio',1,false));
        items.add(Test_TestUtils.crearItemDeDUP(productos[1], trs[0], 1000, 'Uso Propio',1,false));
    
        insert items;

        trs[0].Factura__c = opps[0].Id;
        update trs;

        UtilsComprobanteVenta.createComprobantesVentaFromDups(new Set<Id>{trs[0].Id}, Date.today());

        Comprobante_de_Pago__c cp = new Comprobante_de_Pago__c();
        cp.Obtentor_Destinatario__c = obtentor.Id;
        cp.Cliente__c = productor.Id;
        cp.Fecha_de_Recepcion_de_Pago__c = Date.today();
        insert cp;

        ERPvs__Documento_Recibido__c dr = new ERPvs__Documento_Recibido__c();
        dr.ERPvs__Cuenta_Contable__c = cc.Id;
        dr.ERPvs__Empresa__c = emp.Id;
        dr.ERPvs__Pertenece_A__c = list_dg.get(4).id;
        insert dr;

        Cuenta_Destinataria__c cd = new Cuenta_Destinataria__c();
        cd.Name = 'Cuenta Destinataria';
        cd.Cuenta_Contable__c = cc.Id;
        cd.Obtentor__c = obtentor.Id;
        cd.Documento_Recibido__c = dr.Id;
        insert cd;

        Valor__c valor = new Valor__c();
        valor.Comprobante_de_Pago__c = cp.Id;
        valor.Importe_Total__c = 1000;
        valor.Importe__c = 1000;
        valor.Identificacion__c = '11111111';
        valor.Forma_de_Pago__c = 'Efectivo';
        valor.Cuenta_Destinataria__c = cd.Id;
        insert valor;

        List<Aplicacion__c> aplicaciones = new List<Aplicacion__c>();

        Aplicacion__c ap1 = new Aplicacion__c();
        ap1.Comprobante_de_Pago__c = cp.Id;
        ap1.Factura__c = factura1.Id;
        ap1.Valor_Aplicado__c = valor.Id;
        ap1.Importe__c = 100;
        ap1.Pago_Intereses_o_Diferencia_de_Cambio__c = false;
        ap1.Tipo_de_Cambio__c = 10;
        ap1.Cuenta_Originante__c = productor.Id;
        
        aplicaciones.add(ap1);


        Aplicacion__c ap2 = new Aplicacion__c();
        ap2.Comprobante_de_Pago__c = cp.Id;
        ap2.Factura__c = factura1.Id;
        ap2.Valor_Aplicado__c = valor.Id;
        ap2.Importe__c = 100;
        ap2.Pago_Intereses_o_Diferencia_de_Cambio__c = false;
        ap2.Tipo_de_Cambio__c = 10;
        ap2.Cuenta_Originante__c = productor.Id;
        
        aplicaciones.add(ap2);

        insert aplicaciones;

	}
	
	@isTest static void test() {
		
		Test.startTest();

        DrilldownComprobantesDePagoController.getColumns();
		
		// Obtenemos la cuenta que figura como cliente
		Account a = [SELECT Id FROM Account WHERE N_CUIT__c = '30641405554'];

		// Instanciamos el standard controller
		ApexPages.StandardController controller = new ApexPages.StandardController(a);

		// Instanciamos el controller de la VF
		DrilldownComprobantesDePagoController ctrl = new DrilldownComprobantesDePagoController(controller);

		List<Comprobante_de_Pago__c> comprobantes = DrilldownComprobantesDePagoController.getData(a.Id);

		// Deberia traer un comprobante
		System.assertEquals(comprobantes.size(),1);

		// Traemos los valores
		List<Valor__c> valores = DrilldownComprobantesDePagoController.getData(comprobantes[0].Id);

		// Deberia traer un valor
		System.assertEquals(valores.size(),1);

		// Traemos las aplicaciones
		List<Aplicacion__c> aplicaciones = DrilldownComprobantesDePagoController.getData(valores[0].Id);

		// Deberia traer dos valores
		System.assertEquals(aplicaciones.size(),2);


		
		Test.stopTest();

	}
	
}