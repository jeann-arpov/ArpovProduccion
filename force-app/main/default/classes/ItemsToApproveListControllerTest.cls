@isTest
public with sharing class ItemsToApproveListControllerTest {
    @TestSetup 
	static void setup(){

        ERPvs.TestUtils.insertDatosGenerales();

        List<ERPvs__Datos_Generales__c> list_dg = [SELECT id FROM ERPvs__Datos_Generales__c ORDER BY name];

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

        monedas[0].Moneda_ERP__c = monN.Id;
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
        cc.ERPvs__Moneda__c = monT.id; 
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
        
        ERPvs__Parametro_Facturacion__c pf = new ERPvs__Parametro_Facturacion__c ();
        pf.ERPvs__Fecha_de_Cierre__c = date.today() - 10;
        pf.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        insert pf;

        //RecordType que usamos en el Test
        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        //Obtenemos la fechaActual
        Date fechaActual = Date.today();
    
        //Creamos un tipo de cambio para la moneda extranjera
        Tipo_de_Cambio__c tipoCambio = Test_TestUtils.crearTipodeCambio(monedas[1],2,fechaActual);
        
        //Account obtentor = Test_TestUtils.crearObtentor();
        
        ERPvs__Tipo_de_cambio__c tdc2 = new ERPvs__Tipo_de_cambio__c();
        tdc2.ERPvs__Moneda__c = monN.id;
        tdc2.ERPvs__Vendedor__c = 1;
        tdc2.ERPvs__Vendedor_pizarra__c = 1;
        tdc2.ERPvs__Fecha__c = Date.today();
        tdc2.Tipo_de_Cambio_CRM__c = tipoCambio.Id;
        insert tdc2;
        
        ERPvs__Tipo_de_cambio__c tdc = new ERPvs__Tipo_de_cambio__c();
        tdc.ERPvs__Moneda__c = monT.id;
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
        obtentor.Factura_por_Cuenta_y_Orden__c = true;
        obtentor.Estado__c = 'Activo';
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

        // NUEVO

        List<ERPvs__Cuenta_Contable__c> ccList = new List<ERPvs__Cuenta_Contable__c>();

        
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

        ERPvs__Parametro_Movimiento_Fondo__c pmf = new ERPvs__Parametro_Movimiento_Fondo__c ();
        pmf.ERPvs__Fecha_de_Cierre__c = date.today() - 10;
        pmf.ERPvs__Pertenece_A__c = list_dg.get(4).id;
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
            
        /*ERPvs__Automatizacion_Comprobante_Venta__c acv = new ERPvs__Automatizacion_Comprobante_Venta__c ();
        acv.ERPvs__Sucursal_Empresa__c = suc.id;
        acv.ERPvs__Tipo_de_comprobante_de_venta__c = tcv.id;
        acv.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        acv.ERPvs__Vendedor__c = vend.id;
        acv.ERPvs__Canal_de_venta__c = canal.id;
        acv.ERPvs__Condicion_Comercial__c = condC.id;
        acv.ERPvs__Usuario__c = UserInfo.getUserId();
        insert acv;*/
        
    
        ERPvs__Automatizacion_Comprobante_Compra__c auto0 = new ERPvs__Automatizacion_Comprobante_Compra__c();
        auto0.ERPvs__Letra__c = 'A';
        auto0.ERPvs__Sucursal__c = suc.id;
        auto0.ERPvs__Tipo_comprobante_compra__c = tcc.id;
        auto0.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        auto0.ERPvs__Usuario__c = userinfo.getUserId();
        
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

        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',monedas[0].Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, obtentor, false));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',monedas[1].Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Regalía Extendida', 2, obtentor, false));
              
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test3',monedas[1].Codigo_Univoco__c, 'Variedad Test 3', cultivo1,  'Regalía Extendida', 2, obtentor, false));   
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test4',monedas[1].Codigo_Univoco__c, 'Variedad Test 4', cultivo1,  'Regalía Extendida', 2, obtentor, false));

        insert productos;

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

        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();

        //Creamos dos Item_de_Dup con estado Uso Propio y Cantidad >  0 para la primera transaccion
        items.add(Test_TestUtils.crearItemDeDUP(productos[0], trs[0], 1000, 'Uso Propio',1,false, prov.Id));
    
        insert items;
        
        Approval.ProcessSubmitRequest req1 =  new Approval.ProcessSubmitRequest();
        req1.setComments('Testing');
        req1.setObjectId([SELECT Id FROM Item_de_DUP__c LIMIT 1].Id);
        req1.setSubmitterId(UserInfo.getUserId()); 
        req1.setProcessDefinitionNameOrId('Aprobar_No_Facturacion_de_Item');
        req1.setSkipEntryCriteria(true);
        Approval.ProcessResult result = Approval.process(req1);

    }
    
    @isTest static void testGetItemsToApprove(){

        String fieldSetName = 'ItemsToApproveList';
        String sObjectName = 'ERPvs__Comprobante_Compra__c';

        Test.startTest();

        List<ERPvs__Comprobante_Compra__c> itemsToApprove = ItemsToApproveListController.getItemsToApprove(sObjectName,fieldSetName);

        Test.stopTest();

    }

    @isTest static void testApprove(){

        Test.startTest();
        
        String results = ItemsToApproveListController.processApproveRejectReasign(new List<Id>{[SELECT Id FROM Item_de_DUP__c LIMIT 1].Id},'Test',null,'approve');

        Test.stopTest();

    }

    @isTest static void testReject(){

        Test.startTest();
        
        String results = ItemsToApproveListController.processApproveRejectReasign(new List<Id>{[SELECT Id FROM Item_de_DUP__c LIMIT 1].Id},'Test',null,'reject');

        Test.stopTest();


    }

    @isTest static void testReasign(){
        
        Test.startTest();
        
        String results = ItemsToApproveListController.processApproveRejectReasign(new List<Id>{[SELECT Id FROM Item_de_DUP__c LIMIT 1].Id},'Test',UserInfo.getUserId(),'reasign');

        Test.stopTest();

    }

}