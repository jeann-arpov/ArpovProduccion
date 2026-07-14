@isTest
private class Test_DesaplicarController {
	
	@TestSetup static void setDatosGenerales() {
        ERPvs.TestUtils.insertDatosGenerales();
    }

    @isTest static void test(){
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
        
        Comprobante_de_Pago__c cp = new Comprobante_de_Pago__c();
        cp.Obtentor_Destinatario__c = obtentor.Id;
        cp.Cliente__c = productor.Id;
        cp.Fecha_de_Recepcion_de_Pago__c = Date.today();
        insert cp;

        //RecordType que usamos en el Test 
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        //Fecha Inicio
        Date hoy = Date.today();

        //Fecha Fin
        Date manana = hoy.addDays(1);

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

        
        //Creamos un tipo de cambio para la moneda extranjera
        Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(moneda2,2,hoy);
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);

        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola1 = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');

        //Creamos un par de productos
        List<Product2> productos = new List<Product2>();
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor));

        Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id = rtDup),'00000001', obtentor, cultivo, campanaAgricola1, productor, 'Creada', hoy);

        //Creamos algunos items de dup
        /**
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        items.add(Test_TestUtils.crearItemDeDUP(productos.get(0), t1, 0, 'Uso Propio',null));
        **/
        
        Opportunity factura = new Opportunity();
        factura.N_de_Comprobante__c = 'A-0001-00000001';
        factura.Name = 'Factura TEST';
        factura.StageName = 'Facturada';
        factura.CloseDate = Date.today();
        factura.Obtentor__c = obtentor.Id;
        factura.Divisa_Comprobante__c = 'ARS';
        factura.Amount = 10000;
        factura.Saldo_a_Cobrar_Comprobante__c = 10000;
        factura.Fecha_Pedido_Facturacion__c = Date.newInstance(2014, 11, 21);
        factura.Fecha_de_Facturacion__c = Date.newInstance(2015, 3, 19);
        factura.Fecha_Prevista_de_Pago__c = Date.newInstance(2015, 4, 18);
        factura.Fecha_Emision_Comprobante__c = Date.newInstance(2015, 3, 19);
        factura.Fecha_Vencimiento_Comprobante__c = Date.newInstance(2015, 4, 18);
        factura.Fecha_Reclamo_Factura__c = Date.newInstance(2015, 5, 18);
        factura.Transaccion__c = t1.Id;
        factura.AccountId = productor.Id;
        factura.Tipo_de_Cambio_Actualizado__c = 10;
        insert factura;
        
        ERPvs__Letra_Comprobante_Venta__c letra = new ERPvs__Letra_Comprobante_Venta__c();
        letra.ERPvs__Categoria_IVA__c = categoria.id;
        letra.ERPvs__Categoria_IVA_Facturada__c = categoria.id;
        letra.ERPvs__Letra__c = 'A';
        insert letra;
        
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
        insert pf;
        
        List<ERPvs__Comprobante_Venta__c> cvs = new List<ERPvs__Comprobante_Venta__c>();
        
        ERPvs__Comprobante_Venta__c c_venta = new ERPvs__Comprobante_Venta__c ();
        c_venta.ERPvs__Fecha__c = date.today();
        c_venta.ERPvs__Letra__c = 'A';
        c_venta.ERPvs__Sucursal__c = 1;
        c_venta.ERPvs__Numero__c = 1;
        c_venta.ERPvs__Cliente_1__c = 'cliente de prueba';
        c_venta.ERPvs__Codigo_Postal_1__c = '1234';
        c_venta.ERPvs__Razon_Social_1__c = 'razón social';
        c_venta.ERPvs__Generar_alta_de_cliente__c = true;
        c_venta.ERPvs__Categoria_IVA_1__c = categoria.id;
        c_venta.ERPvs__Empresa_Sucursal__c = suc.id;
        c_venta.ERPvs__A_cuenta_y_orden_de__c = productor.id;
        c_venta.ERPvs__Cliente__c = productor.id;
        cvs.add(c_venta);
        
        insert cvs;

        ERPvs__Vencimientos__c v = new ERPvs__Vencimientos__c();
        v.ERPvs__Cuenta__c = productor.Id;
        v.ERPvs__A_cuenta_y_orden_de__c = obtentor.Id;
        v.ERPvs__Serie_Documento__c = 'A';
        v.ERPvs__Sucursal_Documento__c = 1;
        v.ERPvs__Numero_Documento__c = 1;
        v.ERPvs__Importe_MO__c = 1000;
        v.ERPvs__Comprobante_Venta__c = c_venta.Id;
        insert v;
        
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
        
        Aplicacion__c ap = new Aplicacion__c();
        ap.Comprobante_de_Pago__c = cp.Id;
        ap.Factura__c = factura.Id;
        ap.Valor_Aplicado__c = valor.Id;
        ap.Importe__c = 100;
        ap.Pago_Intereses_o_Diferencia_de_Cambio__c = false;
        ap.Tipo_de_Cambio__c = 10;
        ap.Cuenta_Originante__c = productor.Id;
        aplicaciones.add(ap);

        insert aplicaciones;

        ApexPages.StandardSetController stdSetController = new ApexPages.StandardSetController(aplicaciones);
		stdSetController.setSelected(aplicaciones);
  		DesaplicarController ctrl = new DesaplicarController(stdSetController);

  		Test.startTest();
  		ctrl.desaplicar();
  		Test.stopTest();

    }
	
}