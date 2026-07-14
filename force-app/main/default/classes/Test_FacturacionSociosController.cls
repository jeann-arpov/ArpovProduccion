@isTest
public with sharing class Test_FacturacionSociosController{

    @isTest static void testFacturacionSociosController(){
        
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
        insert param;
        
        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;
        
        ERPvs__Parametro_Facturacion__c pf = new ERPvs__Parametro_Facturacion__c ();
        pf.ERPvs__Fecha_de_Cierre__c = date.today() - 10;
        pf.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        insert pf;
        
        ERPvs__Condicion_Comercial__c condC = new ERPvs__Condicion_Comercial__c ();
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
        
        ERPvs__Tipo_de_cambio__c tc = new ERPvs__Tipo_de_cambio__c ();
        tc.ERPvs__Moneda__c = [SELECT Id FROM ERPvs__Moneda__c WHERE ERPvs__Moneda_Traducida__c = true].id;
        tc.ERPvs__Fecha__c = date.today(); 
        tc.ERPvs__Comprador__c = 1;
        tc.ERPvs__Vendedor__c = 1;
        tc.ERPvs__Comprador_pizarra__c = 1;
        tc.ERPvs__Vendedor_pizarra__c = 1;
        insert tc;
        
        ERPvs__Letra_Comprobante_Venta__c letra = new ERPvs__Letra_Comprobante_Venta__c();
        letra.ERPvs__Categoria_IVA__c = categoria.id;
        letra.ERPvs__Categoria_IVA_Facturada__c = categoria.id;
        letra.ERPvs__Letra__c = 'A';
        insert letra;
        
        Test.startTest();
        
        List<Account> socios = new List<Account>();
        Account s;
        s = new Account();
        s.Name = 'Socio';
        s.Es_Socio__c = true;
        s.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
        s.Clave_Unica__c = 'socio';
        s.N_CUIT__c = '33693450239';
        s.Condicion_Impositiva__c = 'No Aplica';
        s.Localidad_Envio__c = localidad.Id;
        s.Type = 'Obtentor';
        s.Id_Obtentor__c = '1';
        s.Nombre_Obtentor__c = 'Obtentor';
        s.Cuenta_Activa__c = true;
        s.ERPvs__Categoria_IVA__c = categoria.Id;
        
        socios.add(s);
        
        s = new Account();
        s.Name = 'Socio2';
        s.Es_Socio__c = true;
        s.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
        s.Clave_Unica__c = 'socio2';
        s.N_CUIT__c = '30661943145';
        s.Condicion_Impositiva__c = 'No Aplica';
        s.Localidad_Envio__c = localidad.Id;
        s.Type = 'Obtentor';
        s.Id_Obtentor__c = '2';
        s.Nombre_Obtentor__c = 'Obtentor2';
        s.Cuenta_Activa__c = true;
        s.ERPvs__Categoria_IVA__c = categoria.Id;
        
        socios.add(s);
        
        insert socios;
        
        socios.get(0).ERPvs__Activa__c = true;
        socios.get(1).ERPvs__Activa__c = true;
        
        update socios;
        
        System.Debug(LoggingLevel.WARN,'socios: ' + socios);
        
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
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        List<Product2> productos = new List<Product2>();

        productos.add(Test_TestUtils.crearProducto(true,'Producto Test1',moneda1.Codigo_Univoco__c, 'Variedad Test 1', cultivo,  'Regalía Extendida', 2, socios[0], false));
        
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
        
        List<Socio__c> socs = new List<Socio__c>();
        Socio__c soc = new Socio__c();
        soc.Empresa__c = emp.Id;
        soc.Cuenta__c = socios.get(0).Id;
        soc.Categoria_Socio__c = 'Standard';
        socs.add(soc);
        
        soc = new Socio__c();
        soc.Empresa__c = emp.Id;
        soc.Cuenta__c = socios.get(1).Id;
        soc.Categoria_Socio__c = 'Standard';
        socs.add(soc);
        
        insert socs;
        
        FacturacionSociosController ctrl = new FacturacionSociosController();
        ctrl.getEmpresas();
        ctrl.empresaId = emp.Id;
        ctrl.doSelectEmpresa();
        //ctrl.doSearch();
        ctrl.doCancel();
        ctrl.getHasNext();
        ctrl.next();
        ctrl.getHasPrevious();
        ctrl.previous();
        ctrl.getHasResults();
        ctrl.getPageNumber();
        ctrl.doLast();
        ctrl.doFirst();
        ctrl.goToPage();
        ctrl.goToPage2();
        ctrl.getRecordViewFrom();
        ctrl.getRecordViewTo();
        ctrl.doSearch();
        ctrl.getCategoriasSocios();
        ctrl.doSecondPage();
        ctrl.pcvs[0].pcv.ERPvs__Producto__c = prod.Id;
        ctrl.getProductos();
        ctrl.getCondicionesComerciales();
        ctrl.getTiposComprobante();
        ctrl.getSucursales();
        ctrl.getCanalesVenta();
        ctrl.cv.ERPvs__Empresa_Sucursal__c = suc.Id;
        ctrl.cv.ERPvs__Canal_de_venta__c= canal.Id;
        ctrl.doGenerateInvoices();
        ctrl.doSecondPageCancel();
        ctrl.doSecondPageAllSelected();
        ctrl.doSecondPage();
        ctrl.doGenerateInvoices();
                
        FacturacionSociosController.calcularCuotas(100, 3);
        FacturacionSociosController.Wrapper w = new FacturacionSociosController.Wrapper(true, socios[0]);
        w.isChecked = false;
        w.socio = null;
        
        Test.stopTest();
    }
    
}