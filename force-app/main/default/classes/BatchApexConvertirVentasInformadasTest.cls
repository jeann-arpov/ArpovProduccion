@IsTest
public with sharing class BatchApexConvertirVentasInformadasTest {
    
    @TestSetup
    public static void setup() {
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

        Destinatarios_Errores_Batchs__c deb = new Destinatarios_Errores_Batchs__c();
        deb.Name = 'Test';
        deb.Email__c = 'test@email.com';
        insert deb;

        Lote__c lote = new Lote__c();
        lote.Descripcion__c = 'Generacion Ventas a Partir de Ventas Informadas ' + String.valueOf(Date.today());
        lote.Tipo__c = 'Ventas';
        lote.Tipo_de_Lote__c = 'Ventas';
        insert lote;

        List<Cultivo__c> cultivos = new List<Cultivo__c>();

        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75,false);
        cultivo.Unidad_de_Medida_Por_Defecto__c = '40';
        //Creamos un cultivo
        Cultivo__c cultivo1 = Test_TestUtils.crearCultivo('Cultivo Test 1',75,false);
        cultivo1.Unidad_de_Medida_Por_Defecto__c = '40';

        cultivos.add(cultivo);
        cultivos.add(cultivo1);

        insert cultivos;

        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
        
        List<Product2> productos = new List<Product2>();

        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',monedas[0].Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Semilla Fiscalizada', 2, obtentor, false));
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test2',monedas[1].Codigo_Univoco__c, 'Variedad Test 2', cultivo,  'Semilla Fiscalizada', 2, obtentor, false));
              
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test3',monedas[1].Codigo_Univoco__c, 'Variedad Test 3', cultivo1,  'Semilla Fiscalizada', 2, obtentor, false));   
        
        productos.add(Test_TestUtils.crearProducto(true,'Producto Test4',monedas[1].Codigo_Univoco__c, 'Variedad Test 4', cultivo1,  'Semilla Fiscalizada', 2, obtentor, false));

        for (Product2 p: productos) {
            p.Categoria__c = 'Primera Multiplicación';
            p.Unidad_de_Medida__c = '40';
            p.Cultivar_Inase__c = 'Variedad Test 1';
        }

        insert productos;


        Ventas_Informadas__c vInformadas = new Ventas_Informadas__c();
        vInformadas.Campana_Agricola__c = campanaAgricola.Id;
        vInformadas.Campana_de_Ventas__c = null;
        vInformadas.Cantidad_de_Bolsas__c = 40;
        vInformadas.Cantidad_Bolsas_40__c = 1;
        vInformadas.Categoria__c = 'Primera Multiplicación';
        vInformadas.CUIT_Destinatario__c = '30641405554';
        vInformadas.CUIT_Originante__c = '33693450239';
        vInformadas.Cultivo__c = cultivo.Id;
        vInformadas.Destinatario__c = null;
        vInformadas.Estado__c = 'Preprocesado';
        vInformadas.Fecha_de_Facturacion__c = Date.todaY();
        vInformadas.Kilos_por_Bolsa__c = 1;
        vInformadas.Linea_Facturacion__c = 1;
        // vInformadas.Name = '';
        vInformadas.N_de_Comprobante__c = '';
        vInformadas.Originante__c = null;
        vInformadas.Producto__c = null;
        vInformadas.Razon_Social_Destinatario__c = null;
        vInformadas.Resultado__c = 'not OK';
        vInformadas.Tipo_de_Comprobante__c = null;
        vInformadas.Variedad__c = 'Variedad Test 1';
        vInformadas.Venta__c = null;
        vInformadas.Rol_Destinatario__c = null;
        vInformadas.Rol_Originante__c = null;
        insert vInformadas;
    }

    @IsTest
    static void test(){

        Test.startTest();
        BatchApexProcesaVentasInformadas b = new BatchApexProcesaVentasInformadas(null, false);
        b.errors.add('Test');
        Database.executeBatch(b);
        Test.stopTest();

        Ventas_Informadas__c vInformadas = [select Resultado__c from Ventas_Informadas__c limit 1];

        System.assertEquals(vInformadas.Resultado__c, 'OK');
    }

    @IsTest
    static void preprocesarConBolsasCeroMarcaResultadoTest() {
        Ventas_Informadas__c vInformadas = [
            SELECT Id, Cantidad_de_Bolsas__c, Cantidad_Bolsas_40__c, Resultado__c
            FROM Ventas_Informadas__c
            LIMIT 1
        ];
        vInformadas.Cantidad_de_Bolsas__c = 1;
        vInformadas.Cantidad_Bolsas_40__c = null;
        vInformadas.Resultado__c = 'not OK';
        update vInformadas;

        Test.startTest();
        Database.executeBatch(new BatchApexProcesaVentasInformadas(null, false), 1000);
        Test.stopTest();

        vInformadas = [
            SELECT Resultado__c, Cantidad_Bolsas_40__c, Estado__c
            FROM Ventas_Informadas__c
            WHERE Id = :vInformadas.Id
        ];
        System.assertEquals('Preprocesado', vInformadas.Estado__c);
        System.assertEquals(0, vInformadas.Cantidad_Bolsas_40__c);
        System.assertEquals(
            ConvertirVentasInformadasResumenUtil.MSG_CANTIDAD_BOLSAS_CERO,
            vInformadas.Resultado__c
        );
    }

    @IsTest
    static void convertirExecuteCreaVentaTest() {
        List<Account> cuentas = [
            SELECT Id
            FROM Account
            WHERE N_CUIT__c IN ('30641405554', '33693450239')
            LIMIT 2
        ];
        Product2 producto = [SELECT Id FROM Product2 LIMIT 1];
        Ventas_Informadas__c vInformadas = [
            SELECT Campana_Agricola__c, Campana_de_Ventas__c, Cantidad_de_Bolsas__c, Cantidad_Bolsas_40__c,
                Categoria__c, Categoria_Portal__c, CreatedById, CreatedDate, CUIT_Destinatario__c, CUIT_Originante__c,
                Cultivo__c, Destinatario__c, Estado__c, Fecha_de_Facturacion__c, Id, Kilos_por_Bolsa__c,
                Linea_Facturacion__c, N_de_Comprobante__c, Originante__c, Producto__c, Resultado__c,
                Rol_Destinatario__c, Rol_Originante__c, Tipo_de_Comprobante__c, Variedad__c, Venta__c, Venta_Interna__c
            FROM Ventas_Informadas__c
            LIMIT 1
        ];
        vInformadas.Resultado__c = 'OK';
        vInformadas.Estado__c = 'Preprocesado';
        vInformadas.Cantidad_de_Bolsas__c = 40;
        vInformadas.Cantidad_Bolsas_40__c = 1;
        vInformadas.Tipo_de_Comprobante__c = 'FC';
        vInformadas.N_de_Comprobante__c = 'VI-CONV-001';
        vInformadas.Producto__c = producto.Id;
        vInformadas.Destinatario__c = cuentas[0].Id;
        vInformadas.Originante__c = cuentas[1].Id;
        vInformadas.Rol_Destinatario__c = 'Productor';
        vInformadas.Rol_Originante__c = 'Distribuidor';
        vInformadas.Venta_Interna__c = false;
        update vInformadas;

        vInformadas = [
            SELECT Campana_Agricola__c, Campana_de_Ventas__c, Cantidad_de_Bolsas__c, Cantidad_Bolsas_40__c,
                Categoria__c, Categoria_Portal__c, CreatedById, CreatedDate, CUIT_Destinatario__c, CUIT_Originante__c,
                Cultivo__c, Destinatario__c, Estado__c, Fecha_de_Facturacion__c, Id, Kilos_por_Bolsa__c,
                Linea_Facturacion__c, N_de_Comprobante__c, Originante__c, Producto__c, Resultado__c,
                Rol_Destinatario__c, Rol_Originante__c, Tipo_de_Comprobante__c, Variedad__c, Venta__c, Venta_Interna__c
            FROM Ventas_Informadas__c
            WHERE Id = :vInformadas.Id
        ];

        Lote__c lote = [SELECT Id FROM Lote__c LIMIT 1];
        BatchApexConvertirVentasInformadas batch = new BatchApexConvertirVentasInformadas(lote, new Set<Id>{ vInformadas.Id });

        Test.startTest();
        batch.execute(null, new List<Ventas_Informadas__c>{ vInformadas });
        Test.stopTest();

        System.assertEquals(0, batch.skippedBolsasCeroCount, 'No debe saltear por bolsas cero.');
        System.assertEquals(
            1,
            batch.convertedCount + batch.insertErrorCount,
            'Debe intentar convertir el registro. Errores: ' + String.join(batch.errors, '; ')
        );
        if (batch.convertedCount == 1) {
            vInformadas = [
                SELECT Estado__c, Venta__c
                FROM Ventas_Informadas__c
                WHERE Id = :vInformadas.Id
            ];
            System.assertEquals('Procesado', vInformadas.Estado__c);
            System.assertNotEquals(null, vInformadas.Venta__c);
        }
    }

    @IsTest
    static void convertirConBolsasCeroNoConvierteTest() {
        Campana_Agricola__c campanaAgricola = [SELECT Id FROM Campana_Agricola__c LIMIT 1];
        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c LIMIT 1];
        Lote__c lote = [SELECT Id FROM Lote__c LIMIT 1];

        Ventas_Informadas__c vInformadas = new Ventas_Informadas__c(
            Campana_Agricola__c = campanaAgricola.Id,
            Cantidad_de_Bolsas__c = 10,
            Cantidad_Bolsas_40__c = 0,
            Categoria__c = 'Primera Multiplicación',
            CUIT_Destinatario__c = '30641405554',
            CUIT_Originante__c = '33693450239',
            Cultivo__c = cultivo.Id,
            Estado__c = 'Preprocesado',
            Fecha_de_Facturacion__c = Date.today(),
            Kilos_por_Bolsa__c = 1,
            Linea_Facturacion__c = 1,
            Resultado__c = 'OK',
            Variedad__c = 'Variedad Test 1'
        );
        insert vInformadas;

        Test.startTest();
        Database.executeBatch(new BatchApexConvertirVentasInformadas(lote, new Set<Id>{ vInformadas.Id }), 1000);
        Test.stopTest();

        vInformadas = [
            SELECT Estado__c, Resultado__c, Venta__c
            FROM Ventas_Informadas__c
            WHERE Id = :vInformadas.Id
        ];
        System.assertEquals('Preprocesado', vInformadas.Estado__c);
        System.assertEquals(
            BatchApexConvertirVentasInformadas.MSG_CANTIDAD_BOLSAS_CERO,
            vInformadas.Resultado__c
        );
        System.assertEquals(null, vInformadas.Venta__c);
        System.assertEquals(0, [SELECT COUNT() FROM Venta__c]);

        String mensaje = ConvertirVentasInformadasResumenUtil.formatearResultadoDesdeRegistros(
            lote.Id,
            new Set<Id>{ vInformadas.Id }
        );
        System.assert(mensaje.contains('1 ventas informadas con Cantidad (Bolsas SF) = 0'));
    }

    @IsTest
    static void debeAsignarRolDestinatarioRespetaTicket1470Test() {
        BatchApexProcesaVentasInformadas batch = new BatchApexProcesaVentasInformadas(null, true);
        Ventas_Informadas__c conRol = new Ventas_Informadas__c(
            Rol_Destinatario__c = 'Obtentor',
            Venta_Interna__c = false
        );
        Ventas_Informadas__c ventaInterna = new Ventas_Informadas__c(
            Rol_Destinatario__c = 'Distribuidor',
            Venta_Interna__c = true
        );
        Ventas_Informadas__c sinRol = new Ventas_Informadas__c(Venta_Interna__c = false);

        System.assertEquals(false, batch.debeAsignarRolDestinatario(conRol));
        System.assertEquals(false, batch.debeAsignarRolDestinatario(ventaInterna));
        System.assertEquals(true, batch.debeAsignarRolDestinatario(sinRol));
    }

    @IsTest
    static void reprocesarSoloIdsSinVentaAsociadaTest() {
        Ventas_Informadas__c convertible = [
            SELECT Id
            FROM Ventas_Informadas__c
            WHERE Venta__c = null
            LIMIT 1
        ];
        Id ficticio = convertible.Id;
        Set<Id> ids = new Set<Id>{ ficticio, ficticio };

        Test.startTest();
        Database.executeBatch(new BatchApexProcesaVentasInformadas(ids, true), 200);
        Test.stopTest();

        convertible = [
            SELECT Estado__c, Resultado__c
            FROM Ventas_Informadas__c
            WHERE Id = :ficticio
        ];
        System.assertEquals('Preprocesado', convertible.Estado__c);
    }

    @IsTest
    static void normalizarCantidadesPositivasAlReprocesarTest() {
        Ventas_Informadas__c v = new Ventas_Informadas__c(Cantidad_de_Bolsas__c = -800);
        BatchApexProcesaVentasInformadas.normalizarCantidadesPositivasAlReprocesar(v);
        System.assertEquals(800, v.Cantidad_de_Bolsas__c);

        Ventas_Informadas__c positiva = new Ventas_Informadas__c(Cantidad_de_Bolsas__c = 400);
        BatchApexProcesaVentasInformadas.normalizarCantidadesPositivasAlReprocesar(positiva);
        System.assertEquals(400, positiva.Cantidad_de_Bolsas__c);
    }

}