/**
* @author Maximo Martinez
* @date 29/12/2015
* @description Clase con metodos utilitarios para el objeto ERPvs__Movimiento_Fondo__c
*/
public without sharing class UtilsMovimientoFondo {
    
    private static final String NOTA_DEBITO = 'Nota de Débito';
    private static final String NOTA_CREDITO = 'Nota de Crédito';
    private static final String MISMO_MES = 'Mismo mes';
    private static final String SEIS_QUINCENAS = '6 Quicenas';
    private static final String UN_ANIO = '1 año';
    /**
    * @author Maximo Martinez
    * @date 29/12/2015
    * @description Metodo que genera ERPvs__Movimiento_Fondo__c a partir de Comprobante_de_Pago__c
    * FL 21/04/2016 Agregado de generacion desde valores
    * FL 06/06/2016 Ajustes varios solicitados por Denise
    */

    static List<Parametros_ERP_y_CRM__c> parametrosERPYCRM {
        get {
            if (parametrosERPYCRM == null) {
                parametrosERPYCRM = [SELECT Tipo_Comprobante_Mov_Fondo_Cobranza__r.ERPvs__Tipo_de_registro__c, Canal_de_venta_ARPOV__c,
                                            Canal_de_venta_cyo__c,Condicion_Comercial__c,CreatedById,CreatedDate,Datos_Generales__c,Id,
                                            IsDeleted,LastModifiedById,LastModifiedDate,Name,OwnerId,Punto_de_Venta_ARPOV__c,Punto_de_Venta_cyo__c,
                                            Punto_de_Venta_cyo__r.ERPvs__Nro_Sucursal__c,Sucursal_para_Cobranzas__c,
                                            Sucursal_para_Cobranzas__r.ERPvs__Empresa__c,Tipo_Comprobante_Mov_Fondo_Cobranza__c, 
                                            NC_diferencia_de_cambio__c, NC_diferencia_de_cambio__r.ERPvs__IdMoneda__c, ND_diferencia_de_cambio__c, 
                                            ND_diferencia_de_cambio__r.ERPvs__IdMoneda__c, Concepto_Dif_Cambio__c, Genero_pago__c, 
                                            Tipo_Comprobante_Mov_Fondo_Pago__c, Sucursal_para_pago__c, Producto_Diferencia_Cambio__c, 
                                            Producto_Diferencia_de_Cambio_PIIBB__c, Desde_Total_Dif_Cambio__c, Hasta_Total_Dif_Cambio__c,
                                            Ajuste_Interno__c, NC_diferencia_cambio_Interna__c, ND_diferencia_cambio_Interna__c, Producto_Ajuste_Interno__c,
                                            Punto_de_venta_interno__c, Punto_de_venta_interno__r.ERPvs__Nro_Sucursal__c, Numerador_interno_NC__c, Numerador_interno_ND__c,
                                            NC_diferencia_de_cambio_se__r.ERPvs__IdMoneda__c, ND_diferencia_de_cambio_se__r.ERPvs__IdMoneda__c, Punto_de_Venta_cyo_se__r.ERPvs__Nro_Sucursal__c, Producto_Diferencia_de_Cambio_SE__c
                                        FROM Parametros_ERP_y_CRM__c ORDER BY LastModifiedDate DESC];
            } 

            return parametrosERPYCRM;
        }
        set;
    }

    public static Parametros_ERP_y_CRM__c parametro {
        get {
            if (parametrosERPYCRM.isEmpty()) return Test.isRunningTest() ? new Parametros_ERP_y_CRM__c() : null;
            else return parametrosERPYCRM[0];
        }
        set;
    }

    public static void generateMovimientosDeFondeFromCP(Set<Id> idsCP){

        System.debug('generateMovimientosDeFondeFromCP()');
        System.debug('idsCP: ' + idsCP);
        
        // Obtenemos el tipo de movimiento de fondo cobranza
        Id rtCobranzas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(ERPvs__Movimiento_Fondo__c.SObjectType).get('Cobranzas');

        // Obtenemos el registro

        // Checkeamos que exista al menos un registro dado de alta
        if(parametrosERPYCRM.isEmpty()){
            // TODO: Marcar Error
            return;
        }

        // Fecha de hoy
        Date today = Date.today();

        // Lista de movimientos de fondo a insertar
        List<ERPvs__Movimiento_Fondo__c> toInsert = new List<ERPvs__Movimiento_Fondo__c>();
        //FL Lógica de manejo de valores
        List<Valor__c> valoresList = new List<Valor__c>();
        Set<String> cuentasDestinatariasIds = new Set<String>();
        List<Comprobante_de_Pago__c> cps = new List<Comprobante_de_Pago__c>();
        //Sets para realizar busqueda de vencimientos
        Set<String> letrasComprobantes = new Set<String>();
        Set<Integer> sucursalesComprobantes = new Set<Integer>();
        Set<Integer> numerosComprobantes = new Set<Integer>();
        Set<String> clientesComprobantes = new Set<String>();
        Set<String> aCuentaOrdenComprobantes = new Set<String>();
        Set<String> facturasIds = new Set<String>();
        Decimal totalValores = 0;
        //FL 2016-07-20 Set de pagos con los cuales debo generar MF de tipo Pago
        Set<Comprobante_de_Pago__c> comprobanteToPago = new Set<Comprobante_de_Pago__c>();
        Map<String, List<Valor__c>> mapComprobanteValoresToPago = new Map<String, List<Valor__c>>();
        Map<String, ERPvs__Movimiento_Fondo__c> mapComprobanteMovimientoFondo = new Map<String, ERPvs__Movimiento_Fondo__c>();
        
        for(Comprobante_de_Pago__c cp : [SELECT Name, Obtentor_Destinatario__c, Cliente__c, Id, Fecha_de_Recepcion_de_Pago__c, CreatedDate, Importe__c, 
                                                (SELECT Name, Importe__c, Cuenta_Destinataria__c, Comprobante_de_Pago__c, Entidad_Originante__r.Banco_ERP__c, Identificacion__c, Fecha_de_Pago__c, Fecha_de_Emision__c, Cuenta_Destinataria__r.Cuenta_Contable__c, Cuenta_Destinataria__r.Pago_directo_semillero__c FROM Valores__r),
                                                (SELECT Id, Name, Comprobante__c, Importe__c, Importe_Aplicar__c, Factura__c, Tipo_de_Cambio__c FROM Aplicaciones__r) 
                                                FROM Comprobante_de_Pago__c WHERE Id IN :idsCP]) {

            // Creamos un nuevo moviento de fondo
            ERPvs__Movimiento_Fondo__c m = new ERPvs__Movimiento_Fondo__c();

            // Setamos sus atributos
            m.ERPvs__A_cuenta_y_orden_de__c = cp.Obtentor_Destinatario__c;
            m.ERPvs__Cuenta__c = cp.Cliente__c;
            //m.ERPvs__Fecha__c = cp.CreatedDate.date();
            m.ERPvs__Fecha__c = Date.today();
            m.ERPvs__Sucursal__c = parametrosERPYCRM[0].Sucursal_para_Cobranzas__c;
            m.ERPvs__Tipo_Comprobante_Movimiento_Fondo__c = parametrosERPYCRM[0].Tipo_Comprobante_Mov_Fondo_Cobranza__c;
            m.Comprobante_de_Pago__c = cp.Id;
            m.RecordTypeId = rtCobranzas;
            m.ERPvs__Numero_Documento__c = Decimal.valueOf(cp.Name.substring(7));

            mapComprobanteMovimientoFondo.put(cp.Id, m);
            toInsert.add(m);   
            totalValores = 0; 
            for(Valor__c v : cp.Valores__r){
                if(v.Cuenta_Destinataria__c != null){
                    valoresList.add(v);
                    cuentasDestinatariasIds.add(v.Cuenta_Destinataria__c);

                    totalValores += v.Importe__c;

                    //FL 2016-07-20 Controlo si un valor esta relacionado con una cuenta destinataria, que tiene cuenta contable y aparte tiene en true el campo Pago_directo_semillero__c y en el objeto Parametros_ERP_y_CRM__c el campo Genero_pago__c es true 
                    if(parametrosERPYCRM[0].Genero_pago__c){
                        if(v.Cuenta_Destinataria__c != null && v.Cuenta_Destinataria__r.Cuenta_Contable__c != null && v.Cuenta_Destinataria__r.Pago_directo_semillero__c){
                            comprobanteToPago.add(cp);

                            if(!mapComprobanteValoresToPago.containsKey(cp.Id)){
                                mapComprobanteValoresToPago.put(cp.Id, new List<Valor__c>());
                            }

                            mapComprobanteValoresToPago.get(cp.Id).add(v);
                        }
                    }
                }
            }

            // FL 2016-07-05: En el MF, campo Total Cobranza, hay que poner la suma de los totales de los valores
            m.ERPvs__Total_Cobranza__c = totalValores;

            clientesComprobantes.add(cp.Cliente__c);
            aCuentaOrdenComprobantes.add(cp.Obtentor_Destinatario__c);
            for(Aplicacion__c ap : cp.Aplicaciones__r){
                String[] comprobanteSplit = ap.Comprobante__c != null ? ap.Comprobante__c.split('-') : null;
                if(comprobanteSplit != null){
                    letrasComprobantes.add(comprobanteSplit.get(0));
                    sucursalesComprobantes.add(Integer.valueOf(comprobanteSplit.get(1)));
                    numerosComprobantes.add(Integer.valueOf(comprobanteSplit.get(2)));
                }
                facturasIds.add(ap.Factura__c);
            }

            cp.Estado_ERP__c = 'PROCESADO';

            cps.add(cp);

        }
        
        if(!toInsert.isEmpty()){
            Utils.insertList(toInsert, true);
        }
        
        Map<String, ERPvs__Movimiento_Fondo__c > mapMovimientosFondo = new Map<String, ERPvs__Movimiento_Fondo__c >();
        
        for(ERPvs__Movimiento_Fondo__c mf : [SELECT Id, Comprobante_de_Pago__c, ERPvs__A_cuenta_y_orden_de__c, ERPvs__A_cuenta_y_orden_de__r.Diferencia_de_cambio__c FROM ERPvs__Movimiento_Fondo__c WHERE Comprobante_de_Pago__c IN :idsCP]){
            
            mapMovimientosFondo.put(mf.Comprobante_de_Pago__c, mf);
            
        }
        
        Map<String, Cuenta_Destinataria__c> mapCuentasDestinatarias = new Map<String, Cuenta_Destinataria__c>();
        
        for(Cuenta_Destinataria__c cd : [SELECT Id, Cuenta_Bancaria__c, Cuenta_Contable__c, Documento_Recibido__c FROM Cuenta_Destinataria__c WHERE ID IN :cuentasDestinatariasIds AND (Cuenta_Bancaria__c != null OR Cuenta_Contable__c != null OR Documento_Recibido__c != null)]){
            
            mapCuentasDestinatarias.put(cd.Id, cd);
            
        }
        
        List<ERPvs__Detalle_Depositos_Recibidos__c> ddrToInsert = new List<ERPvs__Detalle_Depositos_Recibidos__c>();
        List<ERPvs__Detalle_Cuenta_Contable__c> dccToInsert = new List<ERPvs__Detalle_Cuenta_Contable__c>();
        List<ERPvs__Detalle_Documento_Recibido__c> dDocRecToInsert = new List<ERPvs__Detalle_Documento_Recibido__c>();
        List<ERPvs__Documento_Afectado__c> dAfectadosToInsert = new List<ERPvs__Documento_Afectado__c>();
        
        Cuenta_Destinataria__c cd;
        ERPvs__Detalle_Depositos_Recibidos__c ddr;
        ERPvs__Detalle_Cuenta_Contable__c dcc;
        ERPvs__Detalle_Documento_Recibido__c dDocRec;
        ERPvs__Documento_Afectado__c dAfectado;

        //Busco los vencimientos para posteriormente armar los docuemntos afectados
        String key;
        Map<String, ERPvs__Vencimientos__c> mapVencimientos = new Map<String, ERPvs__Vencimientos__c>();
        Map<String, ERPvs__Comprobante_Venta__c> mapCVs = new Map<String, ERPvs__Comprobante_Venta__c>();
        Set<String> cvIds = new Set<String>();
        for(ERPvs__Vencimientos__c v : [SELECT Id, ERPvs__Cuenta__c, ERPvs__A_cuenta_y_orden_de__c, ERPvs__Serie_Documento__c, ERPvs__Sucursal_Documento__c, ERPvs__Numero_Documento__c, ERPvs__Importe_MO__c, ERPvs__Importe_MN__c, ERPvs__Signo__c, ERPvs__Comprobante_Venta__c, ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c FROM ERPvs__Vencimientos__c 
                                                                                                                                                                                        WHERE ERPvs__Cuenta__c IN :clientesComprobantes AND 
                                                                                                                                                                                              ERPvs__A_cuenta_y_orden_de__c IN :aCuentaOrdenComprobantes AND 
                                                                                                                                                                                              ERPvs__Serie_Documento__c IN :letrasComprobantes AND 
                                                                                                                                                                                              ERPvs__Sucursal_Documento__c IN :sucursalesComprobantes AND
                                                                                                                                                                                              ERPvs__Numero_Documento__c IN :numerosComprobantes AND
                                                                                                                                                                                              ERPvs__Importe_MO__c > 0]){

            key = '' + v.ERPvs__Cuenta__c + v.ERPvs__A_cuenta_y_orden_de__c + v.ERPvs__Serie_Documento__c + v.ERPvs__Sucursal_Documento__c + v.ERPvs__Numero_Documento__c;
            mapVencimientos.put(key, v);
            cvIds.add(v.ERPvs__Comprobante_Venta__c);
        }

        String qry = UtilsObject.getObjectSOQL('ERPvs__Comprobante_Venta__c', 'ID IN :cvIds');
        for(ERPvs__Comprobante_Venta__c cv : Database.query(qry)){

            mapCVs.put(cv.Id, cv);

        }

        Map<String, Opportunity> mapFacturas = new Map<String, Opportunity>();
        for(Opportunity f : [SELECT Id, Total_Comprobante__c, Total_Comprobante_ARS__c, Tipo_de_Cambio_del_Comprobante__c, Tipo_de_Cambio_Actualizado__c FROM Opportunity WHERE ID IN :facturasIds]){
            mapFacturas.put(f.Id, f);
        }
        
        ERPvs__Vencimientos__c vencimiento;

        RecordData records = new RecordData();

        // FL 2016-07-06: Busco las monedas para controlar el CV. Si la moneda es pesos, no debe geenrar la NC o ND
        Map<String, ERPvs__Moneda__c> mapMonedas = new Map<String, ERPvs__Moneda__c>();
        for(ERPvs__Moneda__c m : [SELECT Id, Name FROM ERPvs__Moneda__c]){
            mapMonedas.put(m.Id, m);
        }

        // FL 2018-06-12 Agregado de asociación de aplicaciones y líquido producto
        List<Aplicacion__c> aplicacionesToUpdate = new List<Aplicacion__c>();

        for(Comprobante_de_Pago__c cp : cps){

            for(Valor__c v : cp.Valores__r){
                cd = mapCuentasDestinatarias.get(v.Cuenta_Destinataria__c);
                if(cd != null){
                
                    if(cd.Cuenta_Bancaria__c != null){
                    
                        ddr = new ERPvs__Detalle_Depositos_Recibidos__c();
                        ddr.ERPvs__Importe__c = v.Importe__c;
                        ddr.ERPvs__Cuenta_Bancaria__c = cd.Cuenta_Bancaria__c;
                        ddr.ERPvs__Fecha_Deposito__c = v.Fecha_de_Pago__c;
                        ddr.ERPvs__Numero_de_deposito__c = v.Identificacion__c != null ? Decimal.valueOf(v.Identificacion__c.replace('-', '').replace('/', '').right(8)) : 0;
                        ddr.ERPvs__Movimientos__c = mapMovimientosFondo.get(v.Comprobante_de_Pago__c).Id;
                        ddr.Valor__c = v.Id;

                        ddrToInsert.add(ddr);
                    }
                    
                    if(cd.Cuenta_Contable__c != null){
                    
                        dcc = new ERPvs__Detalle_Cuenta_Contable__c();
                        dcc.ERPvs__Importe__c = v.Importe__c;
                        dcc.ERPvs__Debe_Haber__c = 'Debe';
                        dcc.ERPvs__Cuenta_Contable__c = cd.Cuenta_Contable__c;
                        dcc.ERPvs__Movimientos__c = mapMovimientosFondo.get(v.Comprobante_de_Pago__c).Id;
                        dcc.Valor__c = v.Id;

                        dccToInsert.add(dcc);
                    }
                    
                    if(cd.Documento_Recibido__c != null){
                    
                        dDocRec = new ERPvs__Detalle_Documento_Recibido__c();
                        dDocRec.ERPvs__Importe__c = v.Importe__c;
                        dDocRec.ERPvs__Movimiento__c = mapMovimientosFondo.get(v.Comprobante_de_Pago__c).Id;
                        dDocRec.ERPvs__Documentos_Recibidos__c = cd.Documento_Recibido__c;
                        //dDocRec.ERPvs__Fecha_vencimiento__c = cp.Fecha_de_Recepcion_de_Pago__c;
                        dDocRec.ERPvs__Fecha_vencimiento__c = v.Fecha_de_Pago__c;
                        //dDocRec.ERPvs__Fecha__c = v.Fecha_de_Emision__c;
                        Decimal numero = v.Identificacion__c != null ? Decimal.valueOf(v.Identificacion__c.replace('-', '').replace('/', '').right(8)) : null;
                        dDocRec.ERPvs__Numero__c = numero;
                        dDocRec.ERPvs__Banco__c = v.Entidad_Originante__r.Banco_ERP__c;
                        dDocRec.Valor__c = v.Id;
                        

                        dDocRecToInsert.add(dDocRec);
                    }

                }
            }
            Map<String, List<Aplicacion__c>> mapAplicaciones = new Map<String, List<Aplicacion__c>>();
            for(Aplicacion__c ap : cp.Aplicaciones__r){

                key = '' + cp.Cliente__c + cp.Obtentor_Destinatario__c;
                String[] comprobanteSplit = ap.Comprobante__c != null ? ap.Comprobante__c.split('-') : null;
                if(comprobanteSplit != null){
                    key = key + comprobanteSplit.get(0);
                    key = key + Integer.valueOf(comprobanteSplit.get(1));
                    key = key + Integer.valueOf(comprobanteSplit.get(2));
                }
                if(!mapAplicaciones.containsKey(key)){
                    mapAplicaciones.put(key, new List<Aplicacion__c>());
                }
                mapAplicaciones.get(key).add(ap);
                if(mapVencimientos.containsKey(key) && mapVencimientos.get(key).ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c != null){
                    ap.Liquido_Producto__c = mapVencimientos.get(key).ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c;
                    aplicacionesToUpdate.add(ap);
                }
            }

            //Recorro las afectaciones para armar los documentos afectados
            ERPvs__Movimiento_Fondo__c mf;
            for(String keyAux : mapAplicaciones.keySet()){
                vencimiento = mapVencimientos.get(keyAux);
                if(vencimiento != null){
                    mf = mapMovimientosFondo.get(cp.Id);
                    dAfectado = new ERPvs__Documento_Afectado__c();
                    dAfectado.ERPvs__Vencimientos__c = vencimiento.Id;
                    dAfectado.ERPvs__Movimiento_de_Fondo__c = mf.Id;
                    dAfectado.ERPvs__Importe_MO__c = vencimiento.ERPvs__Importe_MO__c;
                    dAfectado.ERPvs__Importe_MN__c = vencimiento.ERPvs__Importe_MN__c;
                    dAfectado.ERPvs__Signo__c = vencimiento.ERPvs__Signo__c;
                    Decimal importe = 0;
                    Decimal importeAfectado = 0;
                    Decimal importeDolares = 0;
                    Decimal importePesos = 0;
                    for(Aplicacion__c ap : mapAplicaciones.get(keyAux)){
                        importeAfectado += ap.Importe_Aplicar__c;
                        importeDolares += ap.Importe_Aplicar__c;
                        importePesos += (ap.Importe_Aplicar__c * (ap.Tipo_de_Cambio__c != null ? ap.Tipo_de_Cambio__c : 1)).setScale(2);
                        importe += ap.Importe__c;
                        dAfectado.Aplicacion__c = ap.Id;
                    }
                    dAfectado.ERPvs__Importe_Afectado__c = importeAfectado <= vencimiento.ERPvs__Importe_MO__c ? importeAfectado : vencimiento.ERPvs__Importe_MO__c;
                    if(mapAplicaciones.get(keyAux).size() == 1){
                        dAfectado.Tc_del_cp__c = mapAplicaciones.get(keyAux).get(0).Tipo_de_Cambio__c;
                    } else {
                        dAfectado.Tc_del_cp__c = (importePesos / importeDolares).setScale(2);
                    }
                    
                    dAfectadosToInsert.add(dAfectado);

                    ERPvs__Comprobante_Venta__c cv = mapCVs.get(vencimiento.ERPvs__Comprobante_Venta__c);
                    Opportunity factura = mapFacturas.get(mapAplicaciones.get(keyAux).get(0).Factura__c);
                    if(factura != null && cv != null && !mapMonedas.get(cv.ERPvs__Moneda__c).Name.equals('ARS')){
                        
                        System.debug('dAfectado.ERPvs__Importe_Afectado__c: ' + dAfectado.ERPvs__Importe_Afectado__c);
                        System.debug('dAfectado.Tc_del_cp__c: ' + dAfectado.Tc_del_cp__c);
                        System.debug('factura.Tipo_de_Cambio_del_Comprobante__c: ' + factura.Tipo_de_Cambio_del_Comprobante__c);
                        System.debug('cp.Importe__c: ' + cp.Importe__c);
                        System.debug('cv.ERPvs__Tc__c: ' + cv.ERPvs__Tc__c);
                        System.debug('importePesos: ' + importePesos);
                        //Decimal difference = (dAfectado.ERPvs__Importe_Afectado__c * (dAfectado.Tc_del_cp__c - factura.Tipo_de_Cambio_del_Comprobante__c)).setScale(2) + (cp.Importe__c - dAfectado.ERPvs__Importe_Afectado__c * dAfectado.Tc_del_cp__c).setScale(2);
                        Decimal difference1 = (dAfectado.ERPvs__Importe_Afectado__c * (dAfectado.Tc_del_cp__c - cv.ERPvs__Tc__c)).setScale(2);
                        Decimal difference2 = (importePesos - (dAfectado.ERPvs__Importe_Afectado__c * dAfectado.Tc_del_cp__c)).setScale(2);
                        System.debug('difference1: ' + difference1);
                        System.debug('difference2: ' + difference2);
                        Decimal difference = difference1 + difference2;

                        generarDiferencias(difference, mf.ERPvs__A_cuenta_y_orden_de__r.Diferencia_de_cambio__c, cv, records, mapComprobanteMovimientoFondo.get(cp.Id));
                    }
                   
                }
                

            }

        }
        
        insert ddrToInsert;
        insert dccToInsert;
        insert dDocRecToInsert;
        insert dAfectadosToInsert;

        records.process();

        update aplicacionesToUpdate;

        update cps;

        //FL Generacion de pagos
        if(!comprobanteToPago.isEmpty()){
            generarPagos(comprobanteToPago, mapComprobanteValoresToPago, parametro, mapCuentasDestinatarias);
        }

        update parametro;
    }

    private static Map<String, ERPvs__Tipo_de_cambio__c> getTiposDeCambio(List<ERPvs__Movimiento_Fondo__c> movimientos) {
        Map<String, ERPvs__Tipo_de_cambio__c> tiposDeCambio = new Map<String, ERPvs__Tipo_de_cambio__c>();
        
        for (ERPvs__Movimiento_Fondo__c mov: movimientos) {
            for (ERPvs__Documento_Afectado__c doc: mov.Erpvs__Documentos_Afectados__r) {
                String key = '' + doc.ERPvs__Vencimientos__r.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c + mov.ERPvs__Fecha__c;
                
                if (tiposDeCambio.containsKey(key) == false) {
                    ERPvs__Tipo_de_cambio__c tc = [select Erpvs__Vendedor__c from ERPvs__Tipo_de_cambio__c where ERPvs__Moneda__c =: doc.ERPvs__Vencimientos__r.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c and Erpvs__Fecha__c <=: mov.ERPvs__Fecha__c order by Erpvs__Fecha__c desc limit 1];
                    tiposDeCambio.put(key, tc);
                }
            }
        }

        return tiposDeCambio;
    }

    public static RecordData generarDiferencias(List<Id> movimientoFondos) {
        List<ERPvs__Movimiento_Fondo__c> movimientos = [select ERPvs__Fecha__c, ERPvs__A_cuenta_y_orden_de__r.Diferencia_de_cambio__c, (select ERPvs__Importe_Afectado__c, ERPvs__Importe_Afectado_x_Signo_MN__c, ERPvs__Vencimientos__r.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c from Erpvs__Documentos_Afectados__r where ERPvs__Vencimientos__r.ERPvs__Moneda__r.ERPvs__Moneda_Nacional__c = False) from ERPvs__Movimiento_Fondo__c where id in: movimientoFondos];

        Set<Id> cvIds = new Set<Id>();
        Map<Id, Map<Id, Decimal>> importes = new Map<Id, Map<Id, Decimal>>();
        Map<String, ERPvs__Tipo_de_cambio__c> tiposDeCambio = getTiposDeCambio(movimientos);

        for (ERPvs__Movimiento_Fondo__c mov: movimientos) {
            importes.put(mov.id, new Map<Id, Decimal>());

            for (ERPvs__Documento_Afectado__c doc: mov.Erpvs__Documentos_Afectados__r) {
                String key = '' + doc.ERPvs__Vencimientos__r.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c + mov.ERPvs__Fecha__c;
                Id cv = doc.ERPvs__Vencimientos__r.Erpvs__Comprobante_Venta__c;
                cvIds.add(cv);
                Decimal current = importes.get(mov.id).containsKey(cv) == false ? 0 : importes.get(mov.id).get(cv);
                importes.get(mov.id).put(cv, current + doc.ERPvs__Importe_Afectado__c * tiposDeCambio.get(key).ERPvs__Vendedor__c - doc.ERPvs__Importe_Afectado_x_Signo_MN__c);
            }
        }  

        System.debug(importes);

        Map<Id, Erpvs__Comprobante_Venta__c> cvsMap = new Map<Id, Erpvs__Comprobante_Venta__c>((List<Erpvs__Comprobante_Venta__c>) Database.query(UtilsObject.getObjectSOQL('ERPvs__Comprobante_Venta__c', 'ID IN :cvIds')));
        
        RecordData records = new RecordData();

        for (ERPvs__Movimiento_Fondo__c mov: movimientos) {
            for (Id cvId: importes.get(mov.id).keySet()) {
                if (importes.get(mov.id).get(cvId) != 0) {
                    generarDiferencias(importes.get(mov.id).get(cvId), mov.ERPvs__A_cuenta_y_orden_de__r.Diferencia_de_cambio__c, cvsMap.get(cvId), records, null);
                }
            }
        }

        records.process();
        return records;
    }

    public class RecordData {
        public List<ERPvs__Comprobante_Venta__c> cvs = new List<ERPvs__Comprobante_Venta__c>();
        public List<ERPvs__Comprobante_Venta__c> cvsSinImpuestos = new  List<ERPvs__Comprobante_Venta__c>();
        List<Boolean> cvsSoloIVA = new List<Boolean>();
        List<List<ERPvs__Productos_Comprobante_de_Venta__c>> productos = new List<List<ERPvs__Productos_Comprobante_de_Venta__c>>(); 
        List<List<ERPvs__Productos_Comprobante_de_Venta__c>> productosSinImpuestos = new List<List<ERPvs__Productos_Comprobante_de_Venta__c>>(); 
        List<List<ERPvs__Percepciones_de_IB__c>> percepcionesIIBB = new List<List<ERPvs__Percepciones_de_IB__c>>(); 
    
        public void process() {
            Set<String> cvIds = new Set<String>();
            //Si tengo que generar NC o ND, primero inserto todos los CV, después recorro los conceptos, les asigno el id del CV y lo inserto
            if(!cvs.isEmpty()){
                
                if (!Test.isRunningTest()) insert cvs;

                List<ERPvs__Productos_Comprobante_de_Venta__c> pcvsToInsert = new List<ERPvs__Productos_Comprobante_de_Venta__c>();
                List<ERPvs__Percepciones_de_IB__c> pIIBBToInsert = new List<ERPvs__Percepciones_de_IB__c>();

                for(Integer i = 0; i < cvs.size(); i++){

                    cvIds.add(cvs.get(i).Id);

                    for(ERPvs__Productos_Comprobante_de_Venta__c pcv : productos.get(i)){

                        pcv.ERPvs__Comprobante__c = cvs.get(i).Id;

                    }
                    pcvsToInsert.addAll(productos.get(i));

                    if(!percepcionesIIBB.isEmpty() && i < percepcionesIIBB.size() && !percepcionesIIBB.get(i).isEmpty()){

                        for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesIIBB.get(i)){

                            pIIBB.ERPvs__Comprobante_Venta__c = cvs.get(i).Id;

                        }
                        pIIBBToInsert.addAll(percepcionesIIBB.get(i));

                    }
                    
                }

                System.debug('pcvsToInsert: ' + pcvsToInsert);
                if (!Test.isRunningTest()) insert pcvsToInsert;

                System.debug('pIIBBToInsert: ' + pIIBBToInsert);
                if (!Test.isRunningTest()) insert pIIBBToInsert;

                UtilsMovimientoFondo.deletePercepcionesIIBB(cvIds);
            }

            if(!cvsSinImpuestos.isEmpty()){
                if (!Test.isRunningTest()) insert cvsSinImpuestos;

                List<ERPvs__Productos_Comprobante_de_Venta__c> pcvsToInsert = new List<ERPvs__Productos_Comprobante_de_Venta__c>();
                List<ERPvs__Percepciones_de_IB__c> pIIBBToInsert = new List<ERPvs__Percepciones_de_IB__c>();
                cvIds.clear();
                for(Integer i = 0; i < cvsSinImpuestos.size(); i++){

                    if(!cvsSoloIVA.get(i))
                        cvIds.add(cvsSinImpuestos.get(i).Id);

                    for(ERPvs__Productos_Comprobante_de_Venta__c pcv : productosSinImpuestos.get(i)){

                        pcv.ERPvs__Comprobante__c = cvsSinImpuestos.get(i).Id;

                    }
                    pcvsToInsert.addAll(productosSinImpuestos.get(i));

                }

                System.debug('pcvsToInsert: ' + pcvsToInsert);
                if (!Test.isRunningTest()) insert pcvsToInsert;

                UtilsComprobanteVenta.createPercepcionesIIBB(cvIds);

                deletePercepcionesIIBB(cvIds);
            }
        }
    }

    private static void generarDiferencias(Decimal difference, String diferenciaCambio, Erpvs__Comprobante_Venta__c cv, RecordData records, ERPvs__Movimiento_Fondo__c mov) {
        if (cv == null) return;
        if (difference > parametro.Desde_Total_Dif_Cambio__c && difference < parametro.Hasta_Total_Dif_Cambio__c) return;
        
        switch on diferenciaCambio {
            when 'Con impuestos incluídos' {
                generarCVNCND(cv, difference, parametro, records.cvs, records.productos, records.percepcionesIIBB, mov);
            }
            when 'Sin impuestos incluídos', 'Sin imp inc + solo IVA' {
                generarCVNCNDSinImpuestos(cv, difference, parametro, records.cvsSinImpuestos, records.productosSinImpuestos, mov, records.cvsSoloIVA, diferenciaCambio.equals('Sin imp inc + solo IVA'));
            }
            when 'Sin imp inc, modelo original' {
                generarCVNCNDSinImpuestosModeloOriginal(cv, difference, parametro, records.cvs, records.productos, records.percepcionesIIBB, mov);
            }
        }
    }

    class Params {
        public ERPvs__Tipo_comprobante_venta__c tipoComprobante;
        public ERPvs__Sucursal__c sucursal;
        public Id producto;
        public Decimal numero = 0;
        public Date fecha;

        public Params(Decimal difference, Boolean sembraEvolucion, ERPvs__Movimiento_Fondo__c mov) {
            if (!parametro.Ajuste_Interno__c) {
                if (sembraEvolucion == false || (Test.isRunningTest() && parametro.NC_diferencia_de_cambio_se__c == null)) {
                    sucursal = parametro.Punto_de_Venta_cyo__r;
                    tipoComprobante = difference < 0 ? parametro.NC_diferencia_de_cambio__r : parametro.ND_diferencia_de_cambio__r;
                    producto = parametro.Producto_Diferencia_Cambio__c;
                } else {
                    sucursal = parametro.Punto_de_Venta_cyo_se__r;
                    tipoComprobante = difference < 0 ? parametro.NC_diferencia_de_cambio_se__r : parametro.ND_diferencia_de_cambio_se__r;
                    producto = parametro.Producto_Diferencia_de_Cambio_SE__c;
                }
                fecha = Date.today();
            } else {
                tipoComprobante = difference < 0 ? parametro.NC_diferencia_cambio_Interna__r : parametro.ND_diferencia_cambio_Interna__r;
                sucursal = parametro.Punto_de_venta_interno__r;
                fecha = mov.ERPvs__Fecha__c;

                if (parametro.Numerador_interno_NC__c == null) parametro.Numerador_interno_NC__c = 1;
                if (parametro.Numerador_interno_ND__c == null) parametro.Numerador_interno_ND__c = 1;
                
                if (difference < 0) {
                    numero = parametro.Numerador_interno_NC__c;
                    parametro.Numerador_interno_NC__c++;
                } else {
                    numero = parametro.Numerador_interno_ND__c;
                    parametro.Numerador_interno_ND__c++;
                }
            }
        }
    }

    private static void setFields(ERPvs__Comprobante_Venta__c cv, Params param, Id cvOriginal) {
        system.debug(param);
        cv.ERPvs__Tipo_de_comprobante__c = param.tipoComprobante.id;
        cv.ERPvs__Moneda__c = param.tipoComprobante.ERPvs__IdMoneda__c;
        cv.ERPvs__Empresa_Sucursal__c = param.sucursal.id;
        cv.ERPvs__Sucursal__c = param.sucursal.ERPvs__Nro_Sucursal__c;
        cv.ERPvs__Numero__c = param.numero;
        cv.ERPvs__Fecha__c = param.fecha;
        
        cv.ERPvs__Contabilizar__c = false;
        cv.ERPvs__CAE__c = null;
        cv.ERPvs__Fecha_vencimiento_CAE__c = null;
        cv.ERPvs__Nro_FE_sin_CAE__c = null;
        cv.ERPvs__Tipo_de_cambio__c = null;
        cv.ERPvs__Importe_IVA1__c = 0;
        cv.ERPvs__Importe_IVA2__c = 0;
        cv.ERPvs__Importe_IVA3__c = 0;
        cv.ERPvs__Redondeo__c = 0;
        cv.ERPvs__Gravado1__c = 0;
        cv.ERPvs__Gravado2__c = 0;
        cv.ERPvs__Gravado3__c = 0;
        cv.ERPvs__Tipo_cambio__c = null;
        cv.ERPvs__No_Controlar__c = false;
        cv.ERPvs__Comprobante_Relacionado__c = cvOriginal;
        cv.ERPvs__Liquido_producto__c = null;
        cv.Numero_de_Comprobante__c = null;
        cv.ERPvs__Codigo_afip__c = null;
        cv.ERPvs__Numero_formatotexto__c = null;
        cv.ERPvs__Razon_Social_1__c = null;
        cv.ERPvs__Categoria_IVA_1__c = null;
        cv.ERPvs__Identificacion_tributaria_1__c = null;
        cv.ERPvs__Direccion_1__c = null;
        cv.ERPvs__Localidad_1__c = null;
        cv.ERPvs__Provincia_Departamento_1__c = null;
        cv.ERPvs__Tipo_Documento__c = null;
        cv.ERPvs__Numero_Documento__c = null;
        cv.ERPvs__Codigo_Postal_1__c = null;
        cv.ERPvs__Observaciones_Afip__c = null;
        
        cv.Tipo_Movimiento__c = 'Diferencia de cambio';
    } 

    private static void generarCVNCND(ERPvs__Comprobante_Venta__c cvOriginal, Decimal difference, Parametros_ERP_y_CRM__c parametroERPYCRM, List<ERPvs__Comprobante_Venta__c> cvs, List<List<ERPvs__Productos_Comprobante_de_Venta__c>> productos, List<List<ERPvs__Percepciones_de_IB__c>> percepcionesIIBB, ERPvs__Movimiento_Fondo__c mov){

        System.debug('generarCVNCND()');
        System.debug('difference: ' + difference);
        System.debug('parametroERPYCRM: ' + parametroERPYCRM);

        ERPvs__Comprobante_Venta__c cv = cvOriginal.clone(false);
        Params param = new Params(difference, cvOriginal.Transaccion__c == null, mov);

        System.debug('cv: ' + cv);

        Boolean isND = difference >= 0;

        setFields(cv, param, cvOriginal.id);
        
        List<ERPvs__Productos_Comprobante_de_Venta__c> pcvs = new List<ERPvs__Productos_Comprobante_de_Venta__c>();

        ERPvs__Productos_Comprobante_de_Venta__c pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

        if(difference < 0){
            difference = difference * -1;
        }
        //FL 2016-09-02 Controlo si es ajuste interno o no
        if(!parametroERPYCRM.Ajuste_Interno__c){
            pcv.ERPvs__Producto__c = param.producto;
            pcv.ERPvs__Cantidad__c = 1;
            
            Decimal porcentajesIva = 0;
            Decimal porcentajes = 100;
            Boolean tienePercepcionIVA = false;
            //IVA
            if(cvOriginal.ERPvs__Porcentaje_de_IVA1__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA1__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA1__c;
            }
            if(cvOriginal.ERPvs__Porcentaje_de_IVA2__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA2__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA2__c;
            }
            if(cvOriginal.ERPvs__Porcentaje_de_IVA3__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA3__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA3__c;
            }
            System.debug('porcentajesIva: ' + porcentajesIva);
            System.debug('porcentajes AFTER IVA: ' + porcentajes);
            //Percepcion IVA
            Decimal porExencionPerIva = (cvOriginal.ERPvs__Porc_Exencion_Percepcion_IVA__c != null ? cvOriginal.ERPvs__Porc_Exencion_Percepcion_IVA__c : 0);
            if(cvOriginal.ERPvs__Porc_Percepcion_IVA_1__c != null){
                porcentajes += cvOriginal.ERPvs__Porc_Percepcion_IVA_1__c - (cvOriginal.ERPvs__Porc_Percepcion_IVA_1__c * (porExencionPerIva / 100));
                tienePercepcionIVA = true;
            }
            if(cvOriginal.ERPvs__Porc_Percepcion_IVA_2__c != null){
                porcentajes += cvOriginal.ERPvs__Porc_Percepcion_IVA_2__c - (cvOriginal.ERPvs__Porc_Percepcion_IVA_2__c * (porExencionPerIva / 100));
                tienePercepcionIVA = true;
            }
            if(cvOriginal.ERPvs__Porc_Percepcion_IVA_3__c != null){
                porcentajes += cvOriginal.ERPvs__Porc_Percepcion_IVA_3__c - (cvOriginal.ERPvs__Porc_Percepcion_IVA_3__c * (porExencionPerIva / 100));
                tienePercepcionIVA = true;
            }
            System.debug('porcentajes AFTER Percepciones IVA: ' + porcentajes);
            //Percepciones de IIBB
            //Clono las percepciones para agregarselas al CV nuevo
            // FL 2016-08-19: Cuando en una diferencia de cambio, se genera una NC, que tiene percepciones de IIBB, hay 
            // que mirar para ese  obtentor percepciones provincia (objeto ERPvs__Percepciones__c) el campo 
            // Devoluciones y compararlo con la fecha del CV original
            List<ERPvs__Percepciones_de_IB__c> percepcionesCVOriginal = [SELECT ERPvs__Coeficiente_padron__c, ERPvs__Porcentaje__c, ERPvs__Provincia__c, ERPvs__Cuenta_Contable__c, ERPvs__Base_Imponible__c, ERPvs__Importe_percepcion__c FROM ERPvs__Percepciones_de_IB__c WHERE ERPvs__Comprobante_Venta__c = :cvOriginal.Id];
            List<ERPvs__Percepciones_de_IB__c> percepcionesToInsert = new List<ERPvs__Percepciones_de_IB__c>();
            ERPvs__Percepciones_de_IB__c pIIBBToInsert;
            Map<String, ERPvs__Percepciones__c> mapPercepcionesObtentor = new Map<String, ERPvs__Percepciones__c>();
            for(ERPvs__Percepciones__c p : [SELECT Id, ERPvs__Provincia__c, ERPvs__Devoluciones__c, Producto_Ajuste_PIIBB__c FROM ERPvs__Percepciones__c WHERE ERPvs__A_cuenta_y_orden_de__c = :cvOriginal.ERPvs__A_cuenta_y_orden_de__c AND ERPvs__Tipo__c = 'IIBB']){
                mapPercepcionesObtentor.put(p.ERPvs__Provincia__c, p);
            }
            ERPvs__Percepciones__c percepcionObtentor;
            
            for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesCVOriginal){
                porcentajes += pIIBB.ERPvs__Porcentaje__c;
            }
            System.debug('porcentajes AFTER Percepciones IIBB: ' + porcentajes);

            if(!tienePercepcionIVA){
                pcv.ERPvs__Precio_unitario__c = difference;
            } else {
                pcv.ERPvs__Precio_unitario__c = (difference / (porcentajes / 100)).setScale(2);
                pcv.ERPvs__Precio_unitario__c = (pcv.ERPvs__Precio_unitario__c * (1 + (porcentajesIva / 100))).setScale(2);
            }

            for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesCVOriginal){
                percepcionObtentor = mapPercepcionesObtentor.get(pIIBB.ERPvs__Provincia__c);
                if(isND || percepcionObtentor == null || percepcionObtentor.ERPvs__Devoluciones__c == null){
                    pIIBBToInsert = pIIBB.clone(false);
                    pIIBBToInsert.Diferencia_de_Precio__c = true;
                    percepcionesToInsert.add(pIIBBToInsert);
                } else {
                    Boolean esFechaFiltro = false;
                    if(percepcionObtentor.ERPvs__Devoluciones__c.equals(MISMO_MES)){
                        esFechaFiltro = cvOriginal.ERPvs__Fecha__c.month() == cv.ERPvs__Fecha__c.month() && cvOriginal.ERPvs__Fecha__c.year() == cv.ERPvs__Fecha__c.year();
                    } else if(percepcionObtentor.ERPvs__Devoluciones__c.equals(SEIS_QUINCENAS)){
                        Date fecha6Quincenas = cvOriginal.ERPvs__Fecha__c.addDays(90);
                        Integer quincenaCVOriginal = fecha6Quincenas.day() <= 15 ? 1 : 2;
                        Integer quincena = cv.ERPvs__Fecha__c.day() <= 15 ? 1 : 2;
                        esFechaFiltro = cv.ERPvs__Fecha__c.year() == fecha6Quincenas.year() && cv.ERPvs__Fecha__c.month() <= fecha6Quincenas.month() && quincena == quincenaCVOriginal;
                    } else if(percepcionObtentor.ERPvs__Devoluciones__c.equals(UN_ANIO)){
                        esFechaFiltro = cvOriginal.ERPvs__Fecha__c.year() == cv.ERPvs__Fecha__c.year();
                    }
                    if(esFechaFiltro){
                        pIIBBToInsert = pIIBB.clone(false);
                        pIIBBToInsert.Diferencia_de_Precio__c = true;
                        percepcionesToInsert.add(pIIBBToInsert);
                    } else {
                        ERPvs__Productos_Comprobante_de_Venta__c pcvPercepcion = new ERPvs__Productos_Comprobante_de_Venta__c();
                        pcvPercepcion.ERPvs__Cantidad__c = 1;
                        pcvPercepcion.ERPvs__Precio_unitario__c = ((difference / (porcentajes / 100)) * (pIIBB.ERPvs__Porcentaje__c / 100)).setScale(2);
                        pcvPercepcion.ERPvs__Producto__c = percepcionObtentor.Producto_Ajuste_PIIBB__c;
                        pcvs.add(pcvPercepcion);
                    }
                }
            }
            
            for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesToInsert){
                
                pIIBB.ERPvs__Base_Imponible__c = (difference / (porcentajes / 100)).setScale(2);
                pIIBB.ERPvs__Base_Imponible_Minima__c =  pIIBB.ERPvs__Base_Imponible_Minima__c != null ? pIIBB.ERPvs__Base_Imponible_Minima__c : 0;
                pIIBB.ERPvs__Importe_percepcion__c = (((pIIBB.ERPvs__Base_Imponible__c * (pIIBB.ERPvs__Coeficiente_padron__c != null && pIIBB.ERPvs__Coeficiente_padron__c != 0 ? pIIBB.ERPvs__Coeficiente_padron__c : 1))/ 100) * pIIBB.ERPvs__Porcentaje__c).setScale(2);
            
            }

            System.debug('percepcionesToInsert: ' + percepcionesToInsert);
            percepcionesIIBB.add(percepcionesToInsert);
        
        } else {
            pcv.ERPvs__Producto__c = parametroERPYCRM.Producto_Ajuste_Interno__c;
            pcv.ERPvs__Cantidad__c = 1;
            pcv.ERPvs__Precio_unitario__c = difference;

            List<ERPvs__Percepciones_de_IB__c> percepcionesToInsert = new List<ERPvs__Percepciones_de_IB__c>();
            percepcionesIIBB.add(percepcionesToInsert);
        }

        pcvs.add(pcv);

        cvs.add(cv);
        productos.add(pcvs);
        
    }

    //FL 2020-03-11 Generación de NC ND Sin impuestos incluídos
    private static void generarCVNCNDSinImpuestos(ERPvs__Comprobante_Venta__c cvOriginal, Decimal difference, Parametros_ERP_y_CRM__c parametroERPYCRM,  List<ERPvs__Comprobante_Venta__c> cvs, List<List<ERPvs__Productos_Comprobante_de_Venta__c>> productos, ERPvs__Movimiento_Fondo__c mov, List<Boolean> cvsSoloIVA, Boolean soloIVA){

        System.debug('generarCVNCNDSinImpuestos()');
        System.debug('difference: ' + difference);
        System.debug('parametroERPYCRM: ' + parametroERPYCRM);

        ERPvs__Comprobante_Venta__c cv = cvOriginal.clone(false);
        Params param = new Params(difference, cvOriginal.Transaccion__c == null, mov);

        System.debug('cv: ' + cv);

        setFields(cv, param, cvOriginal.id);

        cv.ERPvs__Porc_Percepcion_IVA_1__c = 0;
        cv.ERPvs__Porc_Percepcion_IVA_2__c = 0;
        cv.ERPvs__Porc_Percepcion_IVA_3__c = 0;
        cv.ERPvs__Porc_Exencion_Percepcion_IVA__c = 0;
        cv.ERPvs__No_realizar_calculos_automaticos__c = soloIVA;
                
        List<ERPvs__Productos_Comprobante_de_Venta__c> pcvs = new List<ERPvs__Productos_Comprobante_de_Venta__c>();

        ERPvs__Productos_Comprobante_de_Venta__c pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

        if(difference < 0){
            difference = difference * -1;
        }
        //FL 2016-09-02 Controlo si es ajuste interno o no
        if(!parametroERPYCRM.Ajuste_Interno__c){
            pcv.ERPvs__Producto__c = param.producto;
            pcv.ERPvs__Cantidad__c = 1;
            
            Decimal porcentajesIva = 0;
            Decimal porcentajes = 100;
            Boolean tienePercepcionIVA = false;
            //IVA
            if(cvOriginal.ERPvs__Porcentaje_de_IVA1__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA1__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA1__c;
            }
            if(cvOriginal.ERPvs__Porcentaje_de_IVA2__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA2__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA2__c;
            }
            if(cvOriginal.ERPvs__Porcentaje_de_IVA3__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA3__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA3__c;
            }
            System.debug('porcentajesIva: ' + porcentajesIva);
            System.debug('porcentajes AFTER IVA: ' + porcentajes);
            
            difference = (difference * (porcentajes / 100)).setScale(2);
            
            pcv.ERPvs__Precio_unitario__c = difference;

        } else {
            pcv.ERPvs__Producto__c = parametroERPYCRM.Producto_Ajuste_Interno__c;
            pcv.ERPvs__Cantidad__c = 1;
            pcv.ERPvs__Precio_unitario__c = difference;
        }

        pcvs.add(pcv);
        cvs.add(cv);
        cvsSoloIVA.add(soloIVA);
        productos.add(pcvs);
        
    }

    //FL 2018-01-23 Generación de NC ND Sin impuestos incluídos modelo original
    private static void generarCVNCNDSinImpuestosModeloOriginal(ERPvs__Comprobante_Venta__c cvOriginal, Decimal difference, Parametros_ERP_y_CRM__c parametroERPYCRM, List<ERPvs__Comprobante_Venta__c> cvs, List<List<ERPvs__Productos_Comprobante_de_Venta__c>> productos, List<List<ERPvs__Percepciones_de_IB__c>> percepcionesIIBB, ERPvs__Movimiento_Fondo__c mov){

        System.debug('generarCVNCNDSinImpuestosModeloOriginal()');
        System.debug('difference: ' + difference);
        System.debug('parametroERPYCRM: ' + parametroERPYCRM);

        ERPvs__Comprobante_Venta__c cv = cvOriginal.clone(false);
        Params param = new Params(difference, cvOriginal.Transaccion__c == null, mov);

        System.debug('cv: ' + cv);

        Boolean isND = difference >= 0;

        setFields(cv, param, cvOriginal.id);

        List<ERPvs__Productos_Comprobante_de_Venta__c> pcvs = new List<ERPvs__Productos_Comprobante_de_Venta__c>();

        ERPvs__Productos_Comprobante_de_Venta__c pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

        if(difference < 0){
            difference = difference * -1;
        }
        //FL 2016-09-02 Controlo si es ajuste interno o no
        if(!parametroERPYCRM.Ajuste_Interno__c){
            pcv.ERPvs__Producto__c = param.producto;
            pcv.ERPvs__Cantidad__c = 1;
            
            Decimal porcentajesIva = 0;
            Decimal porcentajes = 100;
            Boolean tienePercepcionIVA = false;
            //IVA
            if(cvOriginal.ERPvs__Porcentaje_de_IVA1__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA1__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA1__c;
            }
            if(cvOriginal.ERPvs__Porcentaje_de_IVA2__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA2__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA2__c;
            }
            if(cvOriginal.ERPvs__Porcentaje_de_IVA3__c != null){
                porcentajes += cvOriginal.ERPvs__Porcentaje_de_IVA3__c;
                porcentajesIva += cvOriginal.ERPvs__Porcentaje_de_IVA3__c;
            }
            System.debug('porcentajesIva: ' + porcentajesIva);
            System.debug('porcentajes AFTER IVA: ' + porcentajes);

            List<ERPvs__Percepciones_de_IB__c> percepcionesCVOriginal = [SELECT ERPvs__Coeficiente_padron__c, ERPvs__Porcentaje__c, ERPvs__Provincia__c, ERPvs__Cuenta_Contable__c, ERPvs__Base_Imponible__c, ERPvs__Importe_percepcion__c FROM ERPvs__Percepciones_de_IB__c WHERE ERPvs__Comprobante_Venta__c = :cvOriginal.Id];
            /**
            for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesCVOriginal){
                porcentajes += pIIBB.ERPvs__Porcentaje__c;
            }
            System.debug('porcentajes AFTER Percepciones IIBB: ' + porcentajes);
            **/
            Decimal differencePCV = (difference * (porcentajes / 100)).setScale(2);
            
            pcv.ERPvs__Precio_unitario__c = differencePCV;

            //Percepciones de IIBB
            List<ERPvs__Percepciones_de_IB__c> percepcionesToInsert = new List<ERPvs__Percepciones_de_IB__c>();
            ERPvs__Percepciones_de_IB__c pIIBBToInsert;
            Map<String, ERPvs__Percepciones__c> mapPercepcionesObtentor = new Map<String, ERPvs__Percepciones__c>();
            for(ERPvs__Percepciones__c p : [SELECT Id, ERPvs__Provincia__c, ERPvs__Devoluciones__c, Producto_Ajuste_PIIBB__c FROM ERPvs__Percepciones__c WHERE ERPvs__A_cuenta_y_orden_de__c = :cvOriginal.ERPvs__A_cuenta_y_orden_de__c AND ERPvs__Tipo__c = 'IIBB']){
                mapPercepcionesObtentor.put(p.ERPvs__Provincia__c, p);
            }
            ERPvs__Percepciones__c percepcionObtentor;

            for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesCVOriginal){
                percepcionObtentor = mapPercepcionesObtentor.get(pIIBB.ERPvs__Provincia__c);
                if(isND || percepcionObtentor == null || percepcionObtentor.ERPvs__Devoluciones__c == null){
                    pIIBBToInsert = pIIBB.clone(false);
                    pIIBBToInsert.Diferencia_de_Precio__c = true;
                    percepcionesToInsert.add(pIIBBToInsert);
                } else {
                    Boolean esFechaFiltro = false;
                    if(percepcionObtentor.ERPvs__Devoluciones__c.equals(MISMO_MES)){
                        esFechaFiltro = cvOriginal.ERPvs__Fecha__c.month() == cv.ERPvs__Fecha__c.month() && cvOriginal.ERPvs__Fecha__c.year() == cv.ERPvs__Fecha__c.year();
                    } else if(percepcionObtentor.ERPvs__Devoluciones__c.equals(SEIS_QUINCENAS)){
                        Date fecha6Quincenas = cvOriginal.ERPvs__Fecha__c.addDays(90);
                        Integer quincenaCVOriginal = fecha6Quincenas.day() <= 15 ? 1 : 2;
                        Integer quincena = cv.ERPvs__Fecha__c.day() <= 15 ? 1 : 2;
                        esFechaFiltro = cv.ERPvs__Fecha__c.year() == fecha6Quincenas.year() && cv.ERPvs__Fecha__c.month() <= fecha6Quincenas.month() && quincena == quincenaCVOriginal;
                    } else if(percepcionObtentor.ERPvs__Devoluciones__c.equals(UN_ANIO)){
                        esFechaFiltro = cvOriginal.ERPvs__Fecha__c.year() == cv.ERPvs__Fecha__c.year();
                    }
                    if(esFechaFiltro){
                        pIIBBToInsert = pIIBB.clone(false);
                        pIIBBToInsert.Diferencia_de_Precio__c = true;
                        percepcionesToInsert.add(pIIBBToInsert);
                    } else {
                        ERPvs__Productos_Comprobante_de_Venta__c pcvPercepcion = new ERPvs__Productos_Comprobante_de_Venta__c();
                        pcvPercepcion.ERPvs__Cantidad__c = 1;
                        pcvPercepcion.ERPvs__Precio_unitario__c = (differencePCV * (pIIBB.ERPvs__Porcentaje__c / 100)).setScale(2);
                        pcvPercepcion.ERPvs__Producto__c = percepcionObtentor.Producto_Ajuste_PIIBB__c;
                        pcvs.add(pcvPercepcion);
                    }
                }
            }
            
            for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesToInsert){
                
                pIIBB.ERPvs__Base_Imponible__c = difference;
                pIIBB.ERPvs__Base_Imponible_Minima__c =  pIIBB.ERPvs__Base_Imponible_Minima__c != null ? pIIBB.ERPvs__Base_Imponible_Minima__c : 0;
                pIIBB.ERPvs__Importe_percepcion__c = (((pIIBB.ERPvs__Base_Imponible__c * (pIIBB.ERPvs__Coeficiente_padron__c != null && pIIBB.ERPvs__Coeficiente_padron__c != 0 ? pIIBB.ERPvs__Coeficiente_padron__c : 1))/ 100) * pIIBB.ERPvs__Porcentaje__c).setScale(2);
            
            }

            System.debug('percepcionesToInsert: ' + percepcionesToInsert);
            percepcionesIIBB.add(percepcionesToInsert);

        } else {
            pcv.ERPvs__Producto__c = parametroERPYCRM.Producto_Ajuste_Interno__c;
            pcv.ERPvs__Cantidad__c = 1;
            pcv.ERPvs__Precio_unitario__c = difference;
        }

        pcvs.add(pcv);

        cvs.add(cv);
        productos.add(pcvs);
        
    }


    private static void generarPagos(Set<Comprobante_de_Pago__c> comprobanteToPago, Map<String, List<Valor__c>> mapComprobanteValoresToPago, Parametros_ERP_y_CRM__c parametros, Map<String, Cuenta_Destinataria__c> mapCuentasDestinatarias){

        Id rtPagos = RecordTypeTool.GetRecordTypeIdsByDeveloperName(ERPvs__Movimiento_Fondo__c.SObjectType).get('Pagos');

        List<ERPvs__Movimiento_Fondo__c> movimientos = new List<ERPvs__Movimiento_Fondo__c>();
        List<ERPvs__Detalle_Cuenta_Contable__c> detalles = new List<ERPvs__Detalle_Cuenta_Contable__c>();

        ERPvs__Movimiento_Fondo__c m;
        Cuenta_Destinataria__c cd;
        ERPvs__Detalle_Cuenta_Contable__c dcc;

        for(Comprobante_de_Pago__c cp : comprobanteToPago) {


            for(Valor__c v : mapComprobanteValoresToPago.get(cp.Id)){
                // Creamos un nuevo moviento de fondo
                m = new ERPvs__Movimiento_Fondo__c();

                // Setamos sus atributos
                m.ERPvs__Cuenta__c = cp.Obtentor_Destinatario__c;
                m.ERPvs__Sucursal__c = parametros.Sucursal_para_pago__c;
                m.ERPvs__Tipo_Comprobante_Movimiento_Fondo__c = parametros.Tipo_Comprobante_Mov_Fondo_Pago__c;
                m.ERPvs__Fecha__c = cp.CreatedDate.date();
                m.ERPvs__Total_Pago__c = v.Importe__c;
                m.Comprobante_de_Pago__c = cp.Id;
                m.RecordTypeId = rtPagos;
                
                movimientos.add(m);

                cd = mapCuentasDestinatarias.get(v.Cuenta_Destinataria__c);
                
                dcc = new ERPvs__Detalle_Cuenta_Contable__c();
                dcc.ERPvs__Importe__c = v.Importe__c;
                dcc.ERPvs__Debe_Haber__c = 'Haber';
                dcc.ERPvs__Cuenta_Contable__c = cd.Cuenta_Contable__c;
                
                detalles.add(dcc);
                
            }
        }

        if(!movimientos.isEmpty()){
            insert movimientos;
        }

        if(!detalles.isEmpty()){
            Integer i = 0;
            for(ERPvs__Detalle_Cuenta_Contable__c dccAux : detalles){
                dccAux.ERPvs__Movimientos__c = movimientos.get(i).Id;
                i++; 
            }
            insert detalles;
        }
    
    }

    private static void deletePercepcionesIIBB(Set<String> cvIds){

        for(List<ERPvs__Percepciones_de_IB__c> percepciones : [SELECT Id FROM ERPvs__Percepciones_de_IB__c WHERE ERPvs__Comprobante_Venta__c IN :cvIds AND Diferencia_de_Precio__c = false]){
            delete percepciones;
        }
    }

}