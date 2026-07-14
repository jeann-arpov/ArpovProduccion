@isTest
private class Test_UtilsMovimientoFondo {
    
    @testSetup static void setDatosGenerales() {
        ERPvs.TestUtils.insertDatosGenerales();
    }

    @isTest static void test() {
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

        ERPvs__Cuenta_Contable__c cc = new ERPvs__Cuenta_Contable__c();
        cc.Name = '1';
        cc.ERPvs__Pertenece_A__c = list_dg.get(2).id;
        cc.ERPvs__Empresa__c = emp.id; 
        cc.ERPvs__Denominacion__c = 'deno';
        cc.ERPvs__Auxiliares__c = aux.id;
        cc.ERPvs__Moneda__c = monN.id; 
        cc.ERPvs__Rubros_Contables__c = rc.id;
        //cc.ERPvs__ERPvs__Cuenta_Contable_en_Fondos__c = true;
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
        insert obtentor;
        
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

        ERPvs__Canal_de_venta__c canal = new ERPvs__Canal_de_venta__c ();
        canal.name = 'canal de venta';
        canal.ERPvs__Pertenece_A__c = list_dg.get(3).id;
        insert canal;
        
        Parametros_ERP_y_CRM__c param = new Parametros_ERP_y_CRM__c();
        param.Punto_de_Venta_ARPOV__c = suc.Id;
        param.Canal_de_venta_ARPOV__c = canal.Id;
        param.Punto_de_Venta_cyo__c = suc.Id;
        param.Sucursal_para_Cobranzas__c = suc.Id;
        param.Tipo_Comprobante_Mov_Fondo_Cobranza__c = tcmfC.id;
        insert param;

        UtilsMovimientoFondo.generateMovimientosDeFondeFromCP(new Set<Id>{cp.Id});
    }
    
}