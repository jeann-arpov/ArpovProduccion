global with sharing class BatchApexGenerarCVComisiones implements Database.Batchable<sObject>, Database.Stateful{
    
    public static Integer BATCH_SIZE = 200;

    public Set<Id> idsAplicaciones = new Set<Id>();

    private Parametros_ERP_y_CRM__c parametrosERPYCRM;

    private Map<String, ERPvs__Comprobante_Venta__c> mapCVs;
    private Map<String, Map<String, ERPvs__Productos_Comprobante_de_Venta__c>> mapPCVs;
    private Map<String, List<Aplicacion__c>> mapCVsAplicaciones;
    private Boolean isNC;
    public List<String> errors;

    global BatchApexGenerarCVComisiones(Set<Id> ids) {
        idsAplicaciones = ids;
        this.errors = new List<String>();
        isNC = false;
    }    

    global BatchApexGenerarCVComisiones(Set<Id> ids, Boolean isNC) {
        idsAplicaciones = ids;
        this.errors = new List<String>();
        this.isNC = isNC;
    }  
    
    global Database.QueryLocator start(Database.BatchableContext BC) {

        parametrosERPYCRM = new Parametros_ERP_y_CRM__c();
        try{
            parametrosERPYCRM = [SELECT Comision_Regalia_Simple_AUD__c, Comision_Regalia_Simple_AUD__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c, Comision_Regalia_Simple_DUP__c, Comision_Regalia_Simple_DUP__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c, Comision_Resarcimiento_AUD__c, Comision_Resarcimiento_AUD__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c, Condicion_Comercial_comisiones__c, Tipo_cv_comisiones_FC__c, Tipo_cv_comisiones_NC__c,
                                       Punto_de_Venta_ARPOV__c, Punto_de_Venta_ARPOV__r.ERPvs__Nro_Sucursal__c, Canal_de_venta_ARPOV__c, Canal_de_venta_cyo__c
                                FROM Parametros_ERP_y_CRM__c 
                                ORDER BY LastModifiedDate DESC LIMIT 1];
        } catch(Exception e){ }
        
        String query = 'SELECT ';

        query += 'CreatedDate, Factura__r.Type, Factura__r.Transaccion__c, Factura__r.Campania_Transaccion__c, Factura__r.Obtentor__c, Factura__r.Obtentor__r.Direccion_de_Correo_electronico_del_CUIT__c, Obtentor_Nombre__c, Cuenta_Originante__c, Cuenta_Originante__r.Direccion_de_Correo_electronico_del_CUIT__c, Tipo_de_Comprobante__c, Importe__c, ';

        query += '(SELECT Id, Name, Comision_por_Regalia_Simple__c, Comision_por_Resarcimiento__c, Comision_por_Monto_Fijo__c, Item_de_Auditoria__c, Item_de_Auditoria__r.Campana__c, Item_de_Auditoria__r.Campana_Ano__c, Pagos_Recibidos__c, Coeficiente_RS_a_Aplicar__c, Coeficiente_RES_a_Aplicar__c, Bolsas_Cobradas_50Kg__c, Item_de_Auditoria__r.Auditoria__r.Estado__c, Item_de_Auditoria__r.Auditoria__r.Factura__r.Percepciones__c, Item_de_Auditoria__r.Porcentaje_sobre_Total_ARS__c, Cobrado_por_Resarcimiento__c, Cobrado_por_Regalia_Simple__c FROM Apliciones_Item_de_AUD__r),';

        query += '(SELECT Id, Name, Comision_Regalia_Simple__c, Item_de_DUP__c, Item_de_DUP__r.Campana_Agricola__c, Item_de_DUP__r.Campana_Ano__c, Pagos_Recibidos__c, Coeficiente_RS_a_Aplicar__c, IVA_sobre_la_Comision__c, Bolsas_Cobradas_50Kg__c, Item_de_DUP__r.Transaccion__r.Total_a_Facturar__c, Item_de_DUP__r.Total_a_Facturar__c, Porcentaje_sobre_el_Total__c FROM Aplicaciones__r),';

        query += 'Id, Name, Cuenta_Originante__r.ERPvs__Activa__c FROM Aplicacion__c WHERE CreatedDate >= 2018-01-01T00:00:00Z AND Cuenta_Originante__r.Estado__c = \'Activo\' AND Factura__c != null AND Comisionable__c = true AND (Cuenta_y_Orden__c = false OR (Cuenta_y_Orden__c = true AND Estado_ERP__c = \'PROCESADO\'))';     

        if(idsAplicaciones != null && !idsAplicaciones.isEmpty())
            query += ' AND Id IN :idsAplicaciones';

        mapCVs = new Map<String, ERPvs__Comprobante_Venta__c>();

        mapPCVs = new Map<String, Map<String, ERPvs__Productos_Comprobante_de_Venta__c>>();

        mapCVsAplicaciones = new Map<String, List<Aplicacion__c>>();

        return Database.getQueryLocator(query);
    }

    global void execute(Database.BatchableContext BC, List<Aplicacion__c> scope){

        String keyCV;
        String keyPCV;
        ERPvs__Comprobante_Venta__c cv;
        ERPvs__Productos_Comprobante_de_Venta__c pcv;
        String campaniaAnio;
        String campaniaId;

        try{
            for(Aplicacion__c ap : scope){

                campaniaAnio = null;
                campaniaId = null;

                for(Aplicacion_Item_DUP__c aidup : ap.Aplicaciones__r){
                    if(campaniaAnio == null){
                        campaniaAnio = aidup.Item_de_DUP__r.Campana_Ano__c;
                        campaniaId = aidup.Item_de_DUP__r.Campana_Agricola__c;
                    } else {
                        if(Integer.valueOf(aidup.Item_de_DUP__r.Campana_Ano__c) > Integer.valueOf(campaniaAnio)){
                            campaniaAnio = aidup.Item_de_DUP__r.Campana_Ano__c;
                            campaniaId = aidup.Item_de_DUP__r.Campana_Agricola__c;
                        }
                    }
                }

                for(Aplicacion_Item_de_AUD__c aiaud : ap.Apliciones_Item_de_AUD__r){
                    if(campaniaAnio == null){
                        campaniaAnio = aiaud.Item_de_Auditoria__r.Campana_Ano__c;
                        campaniaId = aiaud.Item_de_Auditoria__r.Campana__c;
                    } else {
                        if(Integer.valueOf(aiaud.Item_de_Auditoria__r.Campana_Ano__c) > Integer.valueOf(campaniaAnio)){
                            campaniaAnio = aiaud.Item_de_Auditoria__r.Campana_Ano__c;
                            campaniaId = aiaud.Item_de_Auditoria__r.Campana__c;
                        }
                    }
                }

                for(Aplicacion_Item_DUP__c aidup : ap.Aplicaciones__r){

                    keyCV = '' + ap.Obtentor_Nombre__c;

                    System.debug('aidup.Pagos_Recibidos__c: ' + aidup.Pagos_Recibidos__c);
                    System.debug('ap.Importe__c : ' + ap.Importe__c );
                    // System.debug('aidup.Item_de_DUP__r.Transaccion__r.Factura__r.Percepciones__c: ' + aidup.Item_de_DUP__r.Transaccion__r.Factura__r.Percepciones__c);
                    // System.debug('aidup.Item_de_DUP__r.Transaccion__r.Factura__r.Neto_Comprobante__c: ' + aidup.Item_de_DUP__r.Transaccion__r.Factura__r.Neto_Comprobante__c);
                    // System.debug('aidup.Item_de_DUP__r.Transaccion__r.Factura__r.Total_Comprobante__c: ' + aidup.Item_de_DUP__r.Transaccion__r.Factura__r.Total_Comprobante__c);
                    // System.debug('aidup.Porcentaje_sobre_el_Total__c : ' + aidup.Porcentaje_sobre_el_Total__c );
                    // System.debug('aidup.Item_de_DUP__r.Transaccion__r.Total_a_Facturar__c: ' + aidup.Item_de_DUP__r.Transaccion__r.Total_a_Facturar__c);
                    // System.debug('aidup.Item_de_DUP__r.Total_a_Facturar__c: ' + aidup.Item_de_DUP__r.Total_a_Facturar__c);
                    // System.debug('aidup.Porcentaje_sobre_el_Total__c : ' + aidup.Porcentaje_sobre_el_Total__c);

                    if(!mapCVs.containsKey(keyCV)){
                        cv = new ERPvs__Comprobante_Venta__c();

                        cv.ERPvs__Cliente__c = ap.Factura__r.Obtentor__c;
                        cv.ERPvs__Empresa_Sucursal__c = parametrosERPYCRM.Punto_de_Venta_ARPOV__c;
                        cv.ERPvs__Canal_de_venta__c = parametrosERPYCRM.Canal_de_venta_ARPOV__c;
                        cv.ERPvs__Forma_de_Pago__c = parametrosERPYCRM.Condicion_Comercial_comisiones__c;
                        cv.ERPvs__Sucursal__c = parametrosERPYCRM.Punto_de_Venta_ARPOV__r.ERPvs__Nro_Sucursal__c;
                        cv.ERPvs__Correo_Electronico_Contacto__c = ap.Factura__r.Obtentor__r.Direccion_de_Correo_electronico_del_CUIT__c;
                        cv.ERPvs__Tipo_de_comprobante__c = !isNC ? parametrosERPYCRM.Tipo_cv_comisiones_FC__c : parametrosERPYCRM.Tipo_cv_comisiones_NC__c;

                        mapCVs.put(keyCV, cv);
                        mapCVsAplicaciones.put(keyCV, new List<Aplicacion__c>());
                        
                        mapPCVs.put(keyCV, new  Map<String, ERPvs__Productos_Comprobante_de_Venta__c>());

                        pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

                        pcv.ERPvs__Cantidad__c = aidup.Pagos_Recibidos__c;
                        pcv.ERPvs__Precio_unitario__c = aidup.Coeficiente_RS_a_Aplicar__c * (1 + (parametrosERPYCRM.Comision_Regalia_Simple_DUP__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c / 100));
                        pcv.ERPvs__Producto__c = parametrosERPYCRM.Comision_Regalia_Simple_DUP__c;
                        pcv.ERPvs__Canal_de_Venta__c = parametrosERPYCRM.Canal_de_venta_ARPOV__c;
                        pcv.Cantidad_Bolsas_Presupuesto__c = aidup.Bolsas_Cobradas_50Kg__c;
                        pcv.Campana_Agricola__c = campaniaId;
                        
                        keyPCV = '' + pcv.ERPvs__Producto__c + campaniaId + String.valueOf(aidup.Coeficiente_RS_a_Aplicar__c);

                        mapPCVs.get(keyCV).put(keyPCV, pcv);

                    } else {

                        keyPCV = '' + parametrosERPYCRM.Comision_Regalia_Simple_DUP__c + campaniaId + String.valueOf(aidup.Coeficiente_RS_a_Aplicar__c);

                        if(mapPCVs.get(keyCV).get(keyPCV) == null){
                            pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

                            pcv.ERPvs__Cantidad__c = aidup.Pagos_Recibidos__c;
                            pcv.ERPvs__Precio_unitario__c = aidup.Coeficiente_RS_a_Aplicar__c * (1 + (parametrosERPYCRM.Comision_Regalia_Simple_DUP__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c / 100));
                            pcv.ERPvs__Producto__c = parametrosERPYCRM.Comision_Regalia_Simple_DUP__c;
                            pcv.ERPvs__Canal_de_Venta__c = parametrosERPYCRM.Canal_de_venta_ARPOV__c;
                            pcv.Cantidad_Bolsas_Presupuesto__c = aidup.Bolsas_Cobradas_50Kg__c;
                            pcv.Campana_Agricola__c = campaniaId;
                            
                            mapPCVs.get(keyCV).put(keyPCV, pcv);
                        } else {
                            pcv = mapPCVs.get(keyCV).get(keyPCV);
                            pcv.ERPvs__Cantidad__c += aidup.Pagos_Recibidos__c;
                            pcv.Cantidad_Bolsas_Presupuesto__c += aidup.Bolsas_Cobradas_50Kg__c;
                        }
                    }

                    System.debug('pcv dup: ' + pcv);
                }   

                for(Aplicacion_Item_de_AUD__c aiaud : ap.Apliciones_Item_de_AUD__r){

                    System.debug('aiaud.Pagos_Recibidos__c: ' + aiaud.Pagos_Recibidos__c);
                    System.debug('aiaud.Cobrado_por_Regalia_Simple__c: ' + aiaud.Cobrado_por_Regalia_Simple__c); 
                    System.debug('aiaud.Comision_por_Regalia_Simple__c: ' + aiaud.Comision_por_Regalia_Simple__c);
                    System.debug('aiaud.Cobrado_por_Resarcimiento__c: ' + aiaud.Cobrado_por_Resarcimiento__c);
                    System.debug('aiaud.Comision_por_Resarcimiento__c: ' + aiaud.Comision_por_Resarcimiento__c);
                    System.debug('aiaud.Item_de_Auditoria__r.Auditoria__r.Estado__c: ' + aiaud.Item_de_Auditoria__r.Auditoria__r.Estado__c);
                    System.debug('aiaud.Item_de_Auditoria__r.Auditoria__r.Factura__r.Percepciones__c: ' + aiaud.Item_de_Auditoria__r.Auditoria__r.Factura__r.Percepciones__c);
                    System.debug('aiaud.Item_de_Auditoria__r.Porcentaje_sobre_Total_ARS__c: ' + aiaud.Item_de_Auditoria__r.Porcentaje_sobre_Total_ARS__c);

                    keyCV = '' + ap.Obtentor_Nombre__c;

                    if(!mapCVs.containsKey(keyCV)){
                        cv = new ERPvs__Comprobante_Venta__c();

                        cv.ERPvs__Cliente__c = ap.Factura__r.Obtentor__c;
                        cv.ERPvs__Empresa_Sucursal__c = parametrosERPYCRM.Punto_de_Venta_ARPOV__c;
                        cv.ERPvs__Canal_de_venta__c = parametrosERPYCRM.Canal_de_venta_ARPOV__c;
                        cv.ERPvs__Forma_de_Pago__c = parametrosERPYCRM.Condicion_Comercial_comisiones__c;
                        cv.ERPvs__Sucursal__c = parametrosERPYCRM.Punto_de_Venta_ARPOV__r.ERPvs__Nro_Sucursal__c;
                        cv.ERPvs__Correo_Electronico_Contacto__c = ap.Factura__r.Obtentor__r.Direccion_de_Correo_electronico_del_CUIT__c;
                        cv.ERPvs__Tipo_de_comprobante__c = !isNC ? parametrosERPYCRM.Tipo_cv_comisiones_FC__c : parametrosERPYCRM.Tipo_cv_comisiones_NC__c;

                        mapCVs.put(keyCV, cv);
                        mapCVsAplicaciones.put(keyCV, new List<Aplicacion__c>());
                        
                        mapPCVs.put(keyCV, new  Map<String, ERPvs__Productos_Comprobante_de_Venta__c>());
                    }

                    if(aiaud.Comision_por_Regalia_Simple__c > 0 ){

                        keyPCV = '' + parametrosERPYCRM.Comision_Regalia_Simple_AUD__c + campaniaId + String.valueOf(aiaud.Coeficiente_RS_a_Aplicar__c);

                        if(mapPCVs.get(keyCV).get(keyPCV) == null){
                            pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

                            pcv.ERPvs__Cantidad__c = aiaud.Cobrado_por_Regalia_Simple__c;
                            pcv.ERPvs__Precio_unitario__c = aiaud.Coeficiente_RS_a_Aplicar__c * (1 + (parametrosERPYCRM.Comision_Regalia_Simple_AUD__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c / 100));
                            pcv.ERPvs__Producto__c = parametrosERPYCRM.Comision_Regalia_Simple_AUD__c;
                            pcv.ERPvs__Canal_de_Venta__c = parametrosERPYCRM.Canal_de_venta_ARPOV__c;
                            pcv.Cantidad_Bolsas_Presupuesto__c = aiaud.Bolsas_Cobradas_50Kg__c;
                            pcv.Campana_Agricola__c = campaniaId;
                            
                            mapPCVs.get(keyCV).put(keyPCV, pcv);
                        } else {
                            pcv = mapPCVs.get(keyCV).get(keyPCV);
                            pcv.ERPvs__Cantidad__c += aiaud.Cobrado_por_Regalia_Simple__c;
                            pcv.Cantidad_Bolsas_Presupuesto__c += aiaud.Bolsas_Cobradas_50Kg__c;
                        }
                        
                    }

                    if(aiaud.Comision_por_Resarcimiento__c > 0 ){

                        keyPCV = '' + parametrosERPYCRM.Comision_Resarcimiento_AUD__c + campaniaId + String.valueOf(aiaud.Coeficiente_RS_a_Aplicar__c);

                        if(mapPCVs.get(keyCV).get(keyPCV) == null){
                            pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

                            pcv.ERPvs__Cantidad__c = aiaud.Cobrado_por_Resarcimiento__c;
                            pcv.ERPvs__Precio_unitario__c = aiaud.Coeficiente_RES_a_Aplicar__c * (1 + (parametrosERPYCRM.Comision_Resarcimiento_AUD__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c / 100));
                            pcv.ERPvs__Producto__c = parametrosERPYCRM.Comision_Resarcimiento_AUD__c;
                            pcv.ERPvs__Canal_de_Venta__c = parametrosERPYCRM.Canal_de_venta_cyo__c;
                            pcv.Cantidad_Bolsas_Presupuesto__c = aiaud.Bolsas_Cobradas_50Kg__c;
                            pcv.Campana_Agricola__c = campaniaId;
                        
                            mapPCVs.get(keyCV).put(keyPCV, pcv);
                        } else {
                            pcv = mapPCVs.get(keyCV).get(keyPCV);
                            pcv.ERPvs__Cantidad__c += aiaud.Cobrado_por_Resarcimiento__c;
                            pcv.Cantidad_Bolsas_Presupuesto__c += aiaud.Bolsas_Cobradas_50Kg__c;
                        }
                        
                    }

                    System.debug('pcv aud: ' + pcv);

                }   

                mapCVsAplicaciones.get(keyCV).add(ap);
            }    

        } catch(Exception e) {
            errors.add(e.getLineNumber() +  ' - ' + e.getMessage());
        }
        
    }
    
    global void finish(Database.BatchableContext BC) {

        String systemErrors = BatchErrorHelper.getBatchClassErrors(BC);
        
        if(systemErrors != ''){
            errors.add(systemErrors);
        }

        if(!errors.isEmpty()){ // Si ocurrio un error se notifica via email
        
            String message = String.join(errors, '\n');

            System.debug(LoggingLevel.WARN, message);

            try{

                List<String> destinatariosErroresBatchs = BatchErrorHelper.getDestinatariosErroresBatchs();

                if(destinatariosErroresBatchs.isEmpty()){
                    return;
                }

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(destinatariosErroresBatchs);
                mail.setSubject('Arpov: Errores en BatchApexGenerarCVComisiones');
                mail.setPlainTextBody(message);
                mail.setSaveAsActivity(false);
                if(!Test.isRunningTest()){
                    Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                }
                  
            }catch(Exception e){}  

        } else {

            Savepoint sp = Database.setSavepoint();

            try{

                insert mapCVs.values();
                ERPvs__Comprobante_Venta__c cv;
                List<ERPvs__Productos_Comprobante_de_Venta__c> pcvsToInsert = new List<ERPvs__Productos_Comprobante_de_Venta__c>();
                for(String key : mapCVs.keySet()){
                    cv = mapCVs.get(key);
                    for(ERPvs__Productos_Comprobante_de_Venta__c pcv : mapPCVs.get(key).values()){
                        pcv.ERPvs__Comprobante__c = cv.Id;
                        //2020-07-30 FL Denise: Si, siempre que sea negativo pasalo a positivo.
                        pcv.ERPvs__Cantidad__c = Math.abs(pcv.ERPvs__Cantidad__c);
                        pcv.Cantidad_Bolsas_Presupuesto__c = Math.abs(pcv.Cantidad_Bolsas_Presupuesto__c);
                        pcv.ERPvs__Precio_unitario__c = Math.abs(pcv.ERPvs__Precio_unitario__c);
                        
                        pcvsToInsert.add(pcv);
                    }
                }

                insert pcvsToInsert;
                
                List<Aplicacion__c> aplicacionesToUpdate = new List<Aplicacion__c>();
                for(String key : mapCVs.keySet()){
                    for(Aplicacion__c ap : mapCVsAplicaciones.get(key)){
                        ap.CV_Comisiones__c = mapCVs.get(key).Id;
                        aplicacionesToUpdate.add(ap);
                    }
                }

                update aplicacionesToUpdate;
                
            } catch(Exception e){

                Database.rollback(sp);

                try{

                    List<String> destinatariosErroresBatchs = BatchErrorHelper.getDestinatariosErroresBatchs();

                    if(destinatariosErroresBatchs.isEmpty()){
                        return;
                    }

                    Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                    mail.setToAddresses(destinatariosErroresBatchs);
                    mail.setSubject('Arpov: Errores en BatchApexGenerarCVComisiones');
                    mail.setPlainTextBody(e.getLineNumber() + ' - ' + e.getMessage());
                    mail.setSaveAsActivity(false);
                    if(!Test.isRunningTest()){
                        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                    }
                        
                }catch(Exception eAux){}  
            }
        }

        
        
    }
}