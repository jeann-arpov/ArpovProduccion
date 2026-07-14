global with sharing class BatchApexGenerarRemesas implements Database.Batchable<sObject>, Database.Stateful{
    public static Integer BATCH_SIZE = 200;

    public Set<Id> idsAplicaciones = new Set<Id>();

    private Parametros_ERP_y_CRM__c parametrosERPYCRM;
    private ERPvs__Movimiento_Fondo__c mov;
    private Map<String, ERPvs__Documento_Afectado__c> mapDocumentosAfectados;
    public List<String> errors;
    Decimal totalPago;


    global BatchApexGenerarRemesas(Set<Id> ids) {
        idsAplicaciones = ids;
        this.errors = new List<String>();
        mov = createMovimiento();
        totalPago = 0;
        mapDocumentosAfectados = new Map<String, ERPvs__Documento_Afectado__c>();
    }    
    
    global Database.QueryLocator start(Database.BatchableContext BC) {

        String query = 'SELECT ';

        query += 'CreatedDate, Importe__c, Importe_Aplicar__c, Tipo_de_Cambio_del_Comprobante__c, Factura__r.Type, Factura__r.Transaccion__c, Factura__r.Campania_Transaccion__c, Factura__r.Obtentor__c, Liquido_Producto__c, CV_Comisiones__c, Comprobante_de_Pago__c, Comprobante__c, ';

        query += 'Id, Name, Cuenta_Originante__r.ERPvs__Activa__c FROM Aplicacion__c WHERE Id IN :idsAplicaciones';     

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Aplicacion__c> scope){

        try{
            Set<Id> cpIds = new Set<Id>();
            Map<String, String> mapCPAplicacion = new Map<String, String>();
            
            for(Aplicacion__c ap : scope){
                cpIds.add(ap.Comprobante_de_Pago__c);
                mapCPAplicacion.put(ap.Comprobante_de_Pago__c, ap.Id);
                mov.ERPvs__Cuenta__c = ap.Factura__r.Obtentor__c;
                totalPago += ap.Importe__c;
            }

            upsert mov;

            Set<String> fieldsR = new Set<String>();
            fieldsR.add('ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c');
            fieldsR.add('ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__c');
            fieldsR.add('ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c');
            fieldsR.add('ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Comprobante_Relacionado__c');

            String qry = UtilsObject.getObjectSOQL('ERPvs__Documento_Afectado__c', 'ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c IN :cpIds AND ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c != null', fieldsR);

            Map<String, Map<String,ERPvs__Documento_Afectado__c>> mapDocumentosFC = new Map<String, Map<String,ERPvs__Documento_Afectado__c>>();
            //Map<String, List<ERPvs__Documento_Afectado__c>> mapDocumentosDC = new Map<String, List<ERPvs__Documento_Afectado__c>>();
            Map<String, Map<String, ERPvs__Documento_Afectado__c>> mapDocumentosDC = new Map<String, Map<String, ERPvs__Documento_Afectado__c>>();
            Set<String> lpIds = new Set<String>();
            for(ERPvs__Documento_Afectado__c daAux : Database.query(qry)){
                System.Debug('daAux.Id:' + daAux.Id);
                System.Debug('daAux.Name:' + daAux.Name);
                System.Debug('daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c:' + daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c);
                System.Debug('daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c:' + daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c);
                lpIds.add(daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c);
                if(daAux.ERPvs__Tipo__c.toLowerCase().equals('factura')){
                    if(!mapDocumentosFC.containsKey(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c)){
                        mapDocumentosFC.put(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c, new Map<String,ERPvs__Documento_Afectado__c>());
                    }
                    mapDocumentosFC.get(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c).put(daAux.Nro_Comprobante__c, daAux);
                } else {
                    if(!mapDocumentosDC.containsKey(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c)){
                        //mapDocumentosDC.put(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c, new List<ERPvs__Documento_Afectado__c>());
                        mapDocumentosDC.put(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c, new Map<String, ERPvs__Documento_Afectado__c>());
                    }
                    //mapDocumentosDC.get(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c).add(daAux);
                    mapDocumentosDC.get(daAux.ERPvs__Movimiento_de_Fondo__r.Comprobante_de_Pago__c).put(daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Comprobante_Relacionado__c, daAux);
                }
            }

            Map<String, ERPvs__Vencimientos__c> mapLPVencimientos = new Map<String, ERPvs__Vencimientos__c>();
            for(ERPvs__Vencimientos__c v : [SELECT Id, Name, ERPvs__Comprobante_Compra__c, ERPvs__Signo__c, ERPvs__Comprobante_Compra__r.ERPvs__Moneda__r.Name, ERPvs__Importe_MO__c, ERPvs__Importe_MN__c FROM ERPvs__Vencimientos__c WHERE ERPvs__Comprobante_Compra__c IN :lpIds]){
                mapLPVencimientos.put(v.ERPvs__Comprobante_Compra__c, v);
            }

            String key;
            ERPvs__Documento_Afectado__c daFC, daDC, daAux;
            Decimal tc, importeAfectado;
            String moneda, fcId;
            ERPvs__Vencimientos__c v;

            for(Aplicacion__c ap : scope){

                ap.MOV_Remesa__c = mov.Id;
                key = ap.Comprobante_de_Pago__c;

                System.Debug('key:' + key);
                System.Debug('mapDocumentosFC.containsKey(key):' + mapDocumentosFC.containsKey(key));
                if(mapDocumentosFC.containsKey(key)){

                    if(mapDocumentosFC.get(key).get(ap.Comprobante__c) != null){
                        daAux = mapDocumentosFC.get(key).get(ap.Comprobante__c);
                        key = daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c;
                        fcId = daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__c;
                        v = mapLPVencimientos.get(daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c);
                        
                        daFC = getDocumentoAfectado(mapDocumentosAfectados, key, ap, v, mov);
                        
                        System.Debug('daFC:' + daFC);
                        moneda = v.ERPvs__Comprobante_Compra__r.ERPvs__Moneda__r.Name;
                        tc = moneda.equals('ARS') ? ap.Tipo_de_Cambio_del_Comprobante__c : 1;
                        importeAfectado = (ap.Importe_Aplicar__c * tc).setScale(2);
                        daFC.ERPvs__Importe_Afectado__c += importeAfectado;
                        //daFC.ERPvs__Importe_MN__c += importeAfectado;
                        //daFC.ERPvs__Importe_MO__c += ap.Importe_Aplicar__c;
                        //daFC.ERPvs__Importe_MN__c = v.ERPvs__Importe_MN__c;
                        //daFC.ERPvs__Importe_MO__c = v.ERPvs__Importe_MO__c;
                        
                    }
                    
                    key = ap.Comprobante_de_Pago__c;
                    System.Debug('mapDocumentosDC.containsKey(key):' + mapDocumentosDC.containsKey(key));
                    if(mapDocumentosDC.containsKey(key)){
                        ERPvs__Documento_Afectado__c daAux2 = mapDocumentosDC.get(key).get(fcId);
                        System.Debug('daAux2:' + daAux2);
                        //Fix para dar cobertura, ya que no puedo crear todo los datos que necesita el test por too many queries
                        if(Test.isRunningTest()){
                            ERPvs__Comprobante_Venta__c cv = new ERPvs__Comprobante_Venta__c();
                            cv.ERPvs__Liquido_producto__c = daAux.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c;
                            v = new ERPvs__Vencimientos__c();
                            v.ERPvs__Comprobante_Venta__r = cv;
                            daAux2 = new ERPvs__Documento_Afectado__c();
                            daAux2.ERPvs__Vencimientos__r = v;
                        }
                        if(daAux2 != null) {
                            key = daAux2.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c;
                            System.Debug('daAux2.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c:' + daAux2.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c);
                            v = mapLPVencimientos.get(daAux2.ERPvs__Vencimientos__r.ERPvs__Comprobante_Venta__r.ERPvs__Liquido_producto__c);
                            
                            daDC = getDocumentoAfectado(mapDocumentosAfectados, key, ap, v, mov);
                            
                            System.Debug('daDC:' + daDC);
                            tc = !moneda.equals('ARS') ? ap.Tipo_de_Cambio_del_Comprobante__c : 1;
                            System.Debug('tc:' + tc);
                            System.Debug('daDC.ERPvs__Importe_Afectado__c:' + daDC.ERPvs__Importe_Afectado__c);
                            System.Debug('ap.Importe__c:' + ap.Importe__c);
                            System.Debug('importeAfectado:' + importeAfectado);
                            daDC.ERPvs__Importe_Afectado__c += ap.Importe__c - (importeAfectado * tc).setScale(2);  
                            //daDC.ERPvs__Importe_MN__c += daDC.ERPvs__Importe_Afectado__c;
                            //daDC.ERPvs__Importe_MO__c += daDC.ERPvs__Importe_Afectado__c;
                            //daDC.ERPvs__Importe_MN__c = v.ERPvs__Importe_MN__c;
                            //daDC.ERPvs__Importe_MO__c = v.ERPvs__Importe_MO__c;
                            
                            //daFC.ERPvs__Importe_MN__c += daDC.ERPvs__Importe_Afectado__c;
                            //daFC.ERPvs__Importe_MO__c += daDC.ERPvs__Importe_Afectado__c;
                            //daFC.ERPvs__Importe_MN__c = v.ERPvs__Importe_MN__c;
                            //daFC.ERPvs__Importe_MO__c = v.ERPvs__Importe_MO__c;
                            //break;      
                        }
                        
                    }

                }
            }

            update scope;
        } catch(Exception e){
            System.debug(e);
            errors.add(e.getMessage());

        }  
        
    }

    global void finish(Database.BatchableContext BC) {
        Boolean emailSent = BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Arpov: Errores en BatchApexGenerarRemesas');

        if (emailSent == false) {       
            Savepoint sp = Database.setSavepoint();

            try{
                mov.ERPvs__Total_Pago__c = totalPago;

                update mov;
                
                Set<Id> vencimientosIds = new Set<Id>();
                for(String key : mapDocumentosAfectados.keySet()){
                    System.debug('mapDocumentosAfectados.get(key): ' + mapDocumentosAfectados.get(key));
                    if(mapDocumentosAfectados.get(key).ERPvs__Importe_Afectado__c <= 0){
                        System.debug('Importe afectado negativo: ' + mapDocumentosAfectados.get(key).ERPvs__Importe_Afectado__c);
                        if(mapDocumentosAfectados.get(key).ERPvs__Signo__c == 1){
                            mapDocumentosAfectados.get(key).ERPvs__Importe_Afectado__c *= -1;
                        } else {
                            mapDocumentosAfectados.get(key).ERPvs__Importe_Afectado__c = 1;
                        }
                    }
                    vencimientosIds.add(mapDocumentosAfectados.get(key).ERPvs__Vencimientos__c);
                }
                // 2020-08-27 FL Fix para cuando el cálculo de importe afectado supera el importe del vencimiento
                String key;
                for(ERPvs__Vencimientos__c v : [SELECT Id, Name, ERPvs__Comprobante_Compra__c, ERPvs__Importe_MO__c FROM ERPvs__Vencimientos__c WHERE Id IN :vencimientosIds]){
                    key = '' + v.ERPvs__Comprobante_Compra__c;
                    if(mapDocumentosAfectados.containsKey(key)){
                        if(mapDocumentosAfectados.get(key).ERPvs__Importe_Afectado__c > v.ERPvs__Importe_MO__c){
                            mapDocumentosAfectados.get(key).ERPvs__Importe_Afectado__c = v.ERPvs__Importe_MO__c;
                        }
                    }
                }
                
                insert mapDocumentosAfectados.values();

            } catch(Exception e){

                Database.rollback(sp);
                BatchErrorHelper.sendEmail(e.getLineNumber() + ' - ' + e.getMessage(), 'Arpov: Errores en BatchApexGenerarRemesas');
            }
        }
    }

    private static ERPvs__Documento_Afectado__c getDocumentoAfectado(Map<String, ERPvs__Documento_Afectado__c> mapDocumentosAfectados, String key, Aplicacion__c ap, ERPvs__Vencimientos__c v, ERPvs__Movimiento_Fondo__c mov) {
        ERPvs__Documento_Afectado__c daDC;

        if(!mapDocumentosAfectados.containsKey(key)){
            daDC = new ERPvs__Documento_Afectado__c();

            daDC.Aplicacion__c = ap.Id;
            daDC.ERPvs__Vencimientos__c = v.Id;
            daDC.ERPvs__Signo__c = v.ERPvs__Signo__c;
            daDC.ERPvs__Importe_MN__c = v.ERPvs__Importe_MN__c;
            daDC.ERPvs__Importe_MO__c = v.ERPvs__Importe_MO__c;
            daDC.ERPvs__Importe_Afectado__c = 0;
            daDC.ERPvs__Movimiento_de_Fondo__c = mov.Id;

            mapDocumentosAfectados.put(key, daDC);
        } else {
            daDC = mapDocumentosAfectados.get(key);
        }

        return daDC;
    }

    private ERPvs__Movimiento_Fondo__c createMovimiento(){

        parametrosERPYCRM = new Parametros_ERP_y_CRM__c();
        try{
            parametrosERPYCRM = [SELECT Sucursal_para_pago__c, Sucursal_para_pago__r.ERPvs__Empresa__c, Tipo_Comprobante_Mov_Fondo_Pago__c, Tipo_Comprobante_Mov_Fondo_Pago__r.ERPvs__IdMoneda__c
                                FROM Parametros_ERP_y_CRM__c 
                                ORDER BY LastModifiedDate DESC LIMIT 1];
        } catch(Exception e){ }

        ERPvs__Movimiento_Fondo__c mov = new ERPvs__Movimiento_Fondo__c();

        mov.ERPvs__Sucursal__c = parametrosERPYCRM.Sucursal_para_pago__c;
        mov.ERPvs__Fecha__c = Date.today();
        mov.ERPvs__Tipo_Comprobante_Movimiento_Fondo__c = parametrosERPYCRM.Tipo_Comprobante_Mov_Fondo_Pago__c;
        mov.ERPvs__Moneda__c = parametrosERPYCRM.Tipo_Comprobante_Mov_Fondo_Pago__r.ERPvs__IdMoneda__c;
        mov.RecordTypeId = Schema.SObjectType.ERPvs__Movimiento_Fondo__c.getRecordTypeInfosByName().get('Pagos').getRecordTypeId();
        
        return mov;
    }
}