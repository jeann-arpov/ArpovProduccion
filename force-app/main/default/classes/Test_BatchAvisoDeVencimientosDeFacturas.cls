@isTest
private class Test_BatchAvisoDeVencimientosDeFacturas {
	@isTest static void test() {
		Test_TestUtils.disableFlows();

        ERPvs.TestUtils.insertDatosGenerales();
        List<ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

        ERPvs__Categoria_IVA__c categoriaM = new ERPvs__Categoria_IVA__c ();
        categoriaM.Name = 'M';
        categoriaM.Erpvs__Pertenece_A__c = list_dg.get(0).id;
        categoriaM.ERPvs__Letra_Comprobante_Venta__c = 'M';
        insert categoriaM;

        ERPvs__Empresa__c emp = new ERPvs__Empresa__c();
        emp.Name = 'emp';
        emp.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        emp.ERPvs__Denominacion_o_Razon_Social__c = 'emp';
        emp.ERPvs__Identificacion_Tributaria__c = '1234567890';                        
        insert emp;

        ERPvs__Sucursal__c suc = new ERPvs__Sucursal__c();
        suc.Name = 'sucursal';
        suc.ERPvs__Empresa__c = emp.id;    
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
        
        ERPvs__Moneda__c monN = new ERPvs__Moneda__c();
        monN.Name = '1';
        monN.ERPvs__Denominacion__c = 'moneda';
        monN.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        monN.ERPvs__Moneda_Nacional__c = true;
        monN.ERPvs__Moneda_Traducida__c = false;
        insert monN;
        
        ERPvs__Moneda__c monT = new ERPvs__Moneda__c();
        monT.Name = '2';
        monT.ERPvs__Denominacion__c = 'moneda';
        monT.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        monT.ERPvs__Moneda_Nacional__c = false;
        monT.ERPvs__Moneda_Traducida__c = true;
        insert monT;
        
        ERPvs__Auxiliar__c aux = new ERPvs__Auxiliar__c();
        aux.Name = 'auxiliar';
        aux.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        aux.ERPvs__Analisis_por_Cuenta__c = true;
        aux.ERPvs__Analisis_por_Documento__c = true;
        aux.ERPvs__Analisis_por_Vencimiento__c = true;
        insert aux;
        
        ERPvs__Categoria_IVA__c categoria = new ERPvs__Categoria_IVA__c ();
        categoria.Name = '1';
        categoria.ERPvs__Nombre__c = 'uno';
        categoria.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        categoria.ERPvs__Letra_Comprobante_Venta__c = 'A';
        insert categoria;
        
        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;
        
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
        productor.Operador_de_Cobranza__c = UserInfo.getUserId();
        insert productor;

        productor.ERPvs__Activa__c = true;
        update productor;
        
        Contact contacto = new Contact();
        contacto.email = 'test@test.com';
        contacto.LastName = 'Test';
        contacto.AccountID = productor.Id;
        insert contacto;

        List<ERPvs__Cuenta_Contable__c> ccList = new List<ERPvs__Cuenta_Contable__c>();
        ERPvs__Cuenta_Contable__c cc = new ERPvs__Cuenta_Contable__c();
        cc.Name = '1';
        cc.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        cc.ERPvs__Empresa__c = emp.id; 
        cc.ERPvs__Denominacion__c = 'deno';
        cc.ERPvs__Auxiliares__c = aux.id;
        cc.ERPvs__Moneda__c = monN.id; 
        cc.ERPvs__Rubros_Contables__c = rc.id;
        cc.ERPvs__Cuenta_Contable_en_Fondos__c = true;
        cc.ERPvs__Percepciones_IB__c = true;
        cc.ERPvs__Retencion_Ganancias__c = true;
        cc.ERPvs__Cuenta_Contable_en_Fondos__c = true;
        ccList.add(cc); 
        
        ERPvs__Cuenta_Contable__c cc1 = new ERPvs__Cuenta_Contable__c();
        cc1.Name = '2';
        cc1.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        cc1.ERPvs__Empresa__c = emp.id; 
        cc1.ERPvs__Denominacion__c = 'deno';
        cc1.ERPvs__Auxiliares__c = aux.id;
        cc1.ERPvs__Moneda__c = monT.id; 
        cc1.ERPvs__Rubros_Contables__c = rc.id;
        cc1.ERPvs__Percepciones_IB__c = true;
        cc1.ERPvs__Retencion_Ganancias__c = true;
        cc1.ERPvs__Cuenta_Contable_en_Fondos__c = true;
        ccList.add(cc1);
        
        insert ccList; 

        ERPvs__Tipo_Comprobante_Movimiento_Fondo__c tcmf = new ERPvs__Tipo_Comprobante_Movimiento_Fondo__c ();
        tcmf.Name = 'Pago';
        tcmf.ERPvs__Pertenece_A__c = list_dg.get(4).id;
        tcmf.ERPvs__Empresa__c = emp.id;
        tcmf.ERPvs__Tipo__c = 'Pagos';
        tcmf.ERPvs__Documento__c = 'Pago';
        tcmf.ERPvs__Cuenta_Contable__c = cc.id;
        insert tcmf;
        
        ERPvs__Tipo_de_cambio__c tc = new ERPvs__Tipo_de_cambio__c ();
        tc.ERPvs__Moneda__c = monT.id;
        tc.ERPvs__Fecha__c = date.today(); 
        tc.ERPvs__Comprador__c = 1;
        tc.ERPvs__Vendedor__c = 1;
        tc.ERPvs__Comprador_pizarra__c = 1;
        tc.ERPvs__Vendedor_pizarra__c = 1;
        insert tc;

        ERPvs__Parametro_Movimiento_Fondo__c pmf = new ERPvs__Parametro_Movimiento_Fondo__c ();
        pmf.ERPvs__Fecha_de_Cierre__c = date.today() - 10;
        pmf.ERPvs__Pertenece_A__c = list_dg.get(4).id;
        pmf.ERPvs__Empresa__c = emp.id;
        insert pmf;

        ERPvs__Cuenta_Bancaria__c cb2 = new ERPvs__Cuenta_Bancaria__c ();
        cb2.ERPvs__Empresa__c = emp.id;
        cb2.ERPvs__Cuenta_Contable__c = cc1.id;
        cb2.Name = 'Cuenta Bancaria 2';
        cb2.ERPvs__Pertenece_A__c = list_dg.get(4).id;
        cb2.ERPvs__Tipo_Cuenta__c = 'Cuenta Corriente';
        cb2.ERPvs__Nro_Cuenta__c = '345678';
        insert cb2;
        
        ERPvs__Tipo_comprobante_compra__c tcc = new ERPvs__Tipo_comprobante_compra__c ();
        tcc.Name = 'Factura';
        tcc.ERPvs__Pertenece_A__c = list_dg.get(1).id;
        tcc.ERPvs__Empresa__c = emp.id;
        tcc.ERPvs__Cuenta_Contable__c = cc.id;
        tcc.ERPvs__Tipo__c = 'Factura';
        insert tcc; 
        
        ERPvs__Modelo_de_Compra__c mc = new ERPvs__Modelo_de_Compra__c ();
        mc.Name = 'modelo de prueba';
        mc.ERPvs__Pertenece_A__c = list_dg.get(1).id;
        mc.ERPvs__Empresa__c = emp.id;
        insert mc; 
        
        ERPvs__Condicion_Comercial__c cond_comercial = new ERPvs__Condicion_Comercial__c ();
        cond_comercial.Name = 'condicion comercial';
        cond_comercial.ERPvs__Denominacion__c = 'condicion comercial'; 
        cond_comercial.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        insert cond_comercial; 
        
        ERPvs__Concepto_de_Compra__c conc_compra = new ERPvs__Concepto_de_Compra__c ();
        conc_compra.Name = 'concepto';
        conc_compra.ERPvs__Pertenece_A__c = list_dg.get(1).id;
        conc_compra.ERPvs__Empresa__c = emp.id;
        conc_compra.ERPvs__Cuenta_Contable__c = cc.id;
        //conc_compra.Denominacion_CC__c = 'Denominacion_CC__c';
        insert conc_compra; 
        
        ERPvs__Tasa_de_Iva__c ti1 = new ERPvs__Tasa_de_Iva__c ();
        ti1.Name = '10 %';
        ti1.ERPvs__Porcentaje__c = 10;
        ti1.ERPvs__Cuenta_Contable_Facturacion__c = cc.id;
        ti1.ERPvs__Cuenta_Contable_Compra__c = cc.id;
        ti1.ERPvs__Empresa__c = emp.id;
        ti1.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        ti1.ERPvs__Lugar__c = 1;
        ti1.ERPvs__Tasa_por_defecto__c = true;
        insert ti1;
        
        ERPvs__Parametro_Compra__c pc = new ERPvs__Parametro_Compra__c ();
        pc.ERPvs__Fecha_de_Cierre__c = date.today() - 10;
        pc.ERPvs__Pertenece_A__c = list_dg.get(1).id;
        pc.ERPvs__Concepto_de_Compra_LP__c = conc_compra.Id;
        pc.ERPvs__Tasa_de_Iva_LP__c = ti1.Id;
        pc.ERPvs__Empresa__c = emp.Id;
        insert pc;
        
        ERPvs__Modelo_Compra_Proveedor__c mcp = new ERPvs__Modelo_Compra_Proveedor__c();
        mcp.ERPvs__Modelo_de_Compra__c = mc.Id;
        mcp.ERPvs__Cuenta__c = productor.id;
        insert mcp;
        
        ERPvs__Pais__c pais = new ERPvs__Pais__c();
        pais.Name = 'Pais';
        pais.ERPvs__Nombre__c = 'Denominacion';
        pais.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        insert pais;
        
        Provincia__c prov = new Provincia__c();
        prov.Name = 'Test';
        insert prov;
        
        ERPvs__Provincia_Departamento_Estado__c provincia = new ERPvs__Provincia_Departamento_Estado__c();
        provincia.Name = '1';
        provincia.ERPvs__Nombre__c = 'uno';
        provincia.ERPvs__Pais__c = pais.id;
        provincia.ARP_Provincia__c = prov.Id;
        insert provincia;
        
        ERPvs__Ingresos_Brutos_MC__c iibbMC = new ERPvs__Ingresos_Brutos_MC__c();
        iibbMC.ERPvs__Provincia__c = provincia.Id;
        iibbMC.ERPvs__Porcentaje__c = 10;
        iibbMC.ERPvs__Modelo_de_Compra__c = mc.Id;
        iibbMC.ERPvs__Cuenta_Contable__c = cc1.Id;
        insert iibbMC;
        
        ERPvs__Tabla_de_ganancia__c tg = new ERPvs__Tabla_de_ganancia__c();
        tg.ERPvs__Pertenece_A__c = list_dg.get(4).id;
        tg.Name = 'Prueba';
        tg.ERPvs__Porc_retencion__c = 10;
        tg.ERPvs__Importe_minimo_a_retener__c = 10;
        tg.ERPvs__Monto_no_imponible__c = 10;
        insert tg;
        
        ERPvs__Vencimientos__c venc1 = new ERPvs__Vencimientos__c ();
        venc1.ERPvs__Fecha__c = date.today() - 30;
        venc1.ERPvs__Cuenta_Contable__c = cc.id;
        venc1.ERPvs__Cheque_Terceros__c = true;
        venc1.ERPvs__Importe_MN__c = 1;
        venc1.ERPvs__Importe_MO__c = 1;
        venc1.ERPvs__Empresa__c = emp.id;
        venc1.ERPvs__Sucursal_Empresa__c = suc.id;
        venc1.ERPvs__Moneda__c = monN.id;
        venc1.ERPvs__Cuenta__c = productor.Id;
        venc1.ERPvs__Numero_Documento__c = 1;
        venc1.ERPvs__Sucursal_Documento__c = 1;
        venc1.ERPvs__Serie_Documento__c = 'A';
        venc1.ERPvs__Tipo_Documento__c = 'Factura';
        insert venc1;
        
        ERPvs__Letra_Comprobante_Venta__c letra = new ERPvs__Letra_Comprobante_Venta__c();
        letra.ERPvs__Categoria_IVA__c = categoria.id;
        letra.ERPvs__Categoria_IVA_Facturada__c = categoria.id;
        letra.ERPvs__Letra__c = 'A';
        insert letra;
        
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

        ERPvs__Condicion_Comercial__c condC = new ERPvs__Condicion_Comercial__c ();
        condC.Name = '1';
        condC.ERPvs__Denominacion__c = 'uno';
        condC.ERPvs__Pertenece_A__c = list_dg.get(0).id;
        insert condC;
        
        ERPvs__Automatizacion_Comprobante_Venta__c acv = new ERPvs__Automatizacion_Comprobante_Venta__c ();
        acv.ERPvs__Sucursal_Empresa__c = suc.id;
        acv.ERPvs__Tipo_de_comprobante_de_venta__c = tcv.id;
        acv.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        acv.ERPvs__Vendedor__c = vend.id;
        acv.ERPvs__Canal_de_venta__c = canal.id;
        acv.ERPvs__Condicion_Comercial__c = condC.id;
        acv.ERPvs__Usuario__c = UserInfo.getUserId();
        insert acv;
        
        ERPvs__Parametro_Facturacion__c pf = new ERPvs__Parametro_Facturacion__c ();
        pf.ERPvs__Fecha_de_Cierre__c = date.today() - 10;
        pf.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        pf.ERPvs__Empresa__c = emp.id;
        insert pf;
        
        ERPvs__Automatizacion_Comprobante_Compra__c auto0 = new ERPvs__Automatizacion_Comprobante_Compra__c();
        auto0.ERPvs__Letra__c = 'A';
        auto0.ERPvs__Sucursal__c = suc.id;
        auto0.ERPvs__Tipo_comprobante_compra__c = tcc.id;
        auto0.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        auto0.ERPvs__Usuario__c = userinfo.getUserId();
        
        Test.startTest();
        
        ERPvs__Comprobante_Compra__c c_compra = new ERPvs__Comprobante_Compra__c ();
        c_compra.ERPvs__Sucursal_Empresa__c = suc.id;
        c_compra.ERPvs__Letra__c = 'A';
        c_compra.ERPvs__Sucursal__c = 9999;
        c_compra.ERPvs__Numero__c = 999999;
        c_compra.ERPvs__Fecha__c = date.today();
        c_compra.ERPvs__Tipo_comprobante__c = tcc.id;
        c_compra.ERPvs__Proveedor__c = productor.id;
        c_compra.ERPvs__Modelos_de_Compra__c = mc.id;
        c_compra.ERPvs__Monotributista__c = 100;
        c_compra.ERPvs__Gravado__c = 100;
        c_compra.Asignacion_Directa__c = 'NO';
        insert c_compra;

        Account obtentor = Test_TestUtils.crearObtentor();
        obtentor.Operador_de_Cobranza__c = UserInfo.getUserId();
        obtentor.Factura_por_Cuenta_y_Orden__c = true;
        update obtentor;

        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);

        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, Date.today(), Date.today().addDays(1), '2014 - Test',false);
        
        campanaAgricola.Template_Aviso_de_Vencimientos__c = '/apex/emailTemplateFacturasProximasAVencer';

        insert campanaAgricola;

        Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');

        //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
        Transaccion__c t = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),null,obtentor , cultivo, campanaAgricola, productor, 'Respondida', Date.today(), false);
      		
      	insert t;

        //Obtenemos la lista de precios standard del sitio
        Id idPricebook2 = Utils.getPricebook2Id();

        Pricebook2 listaPrecios = new Pricebook2(Id = idPricebook2);

        //Creamos una Opportunidad para la Transaccion 1
        Opportunity oportunidad = Test_TestUtils.crearOpportunity(listaPrecios, 'Test', Date.today(), 'Test', t, 'FC');
        
        //Agregamos el Número de Comprobante
        oportunidad.N_de_Comprobante__c = '123456';
        oportunidad.Fecha_Vencimiento_Comprobante__c = Date.today().addDays(1);
        oportunidad.Saldo_a_Cobrar_Comprobante__c = 10;
        oportunidad.Total_Comprobante__c = 10;
        oportunidad.Transaccion__c = t.Id;
        
        update oportunidad;
        
        List<ERPvs__Comprobante_Venta__c> cvs = new List<ERPvs__Comprobante_Venta__c>();
        
        ERPvs__Comprobante_Venta__c c_venta = new ERPvs__Comprobante_Venta__c ();
        c_venta.ERPvs__Fecha__c = date.today();
        c_venta.ERPvs__Letra__c = 'A';
        c_venta.ERPvs__Sucursal__c = 9999;
        c_venta.ERPvs__Numero__c = 999999;
        c_venta.ERPvs__Cliente_1__c = 'cliente de prueba';
        c_venta.ERPvs__Codigo_Postal_1__c = '1234';
        c_venta.ERPvs__Razon_Social_1__c = 'razón social';
        c_venta.ERPvs__Generar_alta_de_cliente__c = true;
        c_venta.ERPvs__Categoria_IVA_1__c = categoria.id;
        c_venta.ERPvs__Empresa_Sucursal__c = suc.id;
        c_venta.ERPvs__A_cuenta_y_orden_de__c = productor.id;
        c_venta.ERPvs__Liquido_producto__c = c_compra.id;
        c_venta.ERPvs__Cliente__c = productor.id;
        c_venta.Oportunidad__c = oportunidad.Id;
        cvs.add(c_venta);
        
        insert cvs;

        Attachment att = new Attachment();
        att.ParentId = c_venta.id;
        att.Body = Blob.valueOf('test');
        att.ContentType = 'application/pdf';
        att.Name = 'test';
        insert att;

        SchedulableAvisoDeVencimientosDeFacturas.start(0,11,30);

        Test.stopTest();

	}

    @isTest static void testError(){

        Test.startTest();
        BatchAvisoDeVencimientosDeFacturas b = new BatchAvisoDeVencimientosDeFacturas(false,Date.today(),Date.today());
        b.errors.add('Test!');
        Database.executeBatch(b,100);
        Test.stopTest();

    }
	
}