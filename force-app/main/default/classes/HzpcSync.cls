public with sharing class HzpcSync {

    @future(callout=true)
    public static void doSyncDeleteTransacciones(String dataString){
        System.debug('dataString: ' + dataString);
        HzpcSyncRestClient.SyncRequest request = new HzpcSyncRestClient.SyncRequest();
        request.allOrNone = false;
        List<Map<String, Object>> records = new List<Map<String, Object>>();

        Set<String> transaccionesIds = (Set<String>) JSON.deserialize(dataString, Set<String>.class);
        System.debug('transaccionesIds: ' + transaccionesIds);
        for(String transaccionId : transaccionesIds){
            Map<String, Object> record = new Map<String, Object>{'attributes' => new Map<String, Object>{'type' => 'Declaracion_de_Uso_Propio__c'}};
            record.put('id', transaccionId);
            record.put('Borrado__c', true);
            records.add(record);
        }

        request.records = records;

        HzpcSyncRestClient.doSyncUpdate(request);
    }

    @future(callout=true)
    public static void doSyncDeleteItemsDup(String dataString){
        HzpcSyncRestClient.SyncRequest request = new HzpcSyncRestClient.SyncRequest();
        request.allOrNone = false;
        List<Map<String, Object>> records = new List<Map<String, Object>>();

        Set<String> itemsDupIds = (Set<String>) JSON.deserialize(dataString, Set<String>.class);

        for(String itemId : itemsDupIds){
            Map<String, Object> record = new Map<String, Object>{'attributes' => new Map<String, Object>{'type' => 'Linea_de_DUP__c'}};
            record.put('id', itemId);
            record.put('Borrado__c', true);
            records.add(record);
        }

        request.records = records;

        HzpcSyncRestClient.doSyncUpdate(request);
    }

    public static void doSyncItemsDup(List<Item_de_DUP__c> itemsDup, TriggerOperation context){
        HzpcSyncRestClient.SyncRequest request = new HzpcSyncRestClient.SyncRequest();
        request.allOrNone = false;
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        for(Item_de_DUP__c itemDup : itemsDup){
            records.add(convertToMap(itemDup.Id, itemDup, context));
        }

        request.records = records;

        List<HzpcSyncRestClient.RecordSyncResponse> results;
        List<Item_de_DUP__c> toUpdate = new List<Item_de_DUP__c>();
        if(context == TriggerOperation.AFTER_INSERT){
            results = HzpcSyncRestClient.doSyncInsert(request);
            for(Integer i = 0; i < results.size(); i++){
                HzpcSyncRestClient.RecordSyncResponse insertResult = results[i];
                Item_de_DUP__c recToUpdate = new Item_de_DUP__c(Id = itemsDup[i].Id);
                if(insertResult.success){
                    recToUpdate.HZPCId__c = insertResult.id;
                }else{
                    recToUpdate.Hzpc_Sync_Error__c = formatErrors(insertResult.errors);
                }
                toUpdate.add(recToUpdate);
            }
        }else if(context == TriggerOperation.AFTER_UPDATE){
            results = HzpcSyncRestClient.doSyncUpdate(request);
            for(Integer i = 0; i < results.size(); i++){
                HzpcSyncRestClient.RecordSyncResponse insertResult = results[i];
                if(insertResult.success == false){
                    toUpdate.add(new Item_de_DUP__c(Id = itemsDup[i].Id, Hzpc_Sync_Error__c = formatErrors(insertResult.errors)));
                }
            }
        }

        if(toUpdate.isEmpty() == false){
            update toUpdate;
        }
    }

    public static void doSyncTransacciones(List<Transaccion__c> transacciones, TriggerOperation context){
        HzpcSyncRestClient.SyncRequest request = new HzpcSyncRestClient.SyncRequest();
        request.allOrNone = false;
        List<Map<String, Object>> records = new List<Map<String, Object>>();
        for(Transaccion__c transaccion : transacciones){
            records.add(convertToMap(transaccion.Id, transaccion, context));
        }

        request.records = records;

        List<HzpcSyncRestClient.RecordSyncResponse> results;
        List<Transaccion__c> toUpdate = new List<Transaccion__c>();
        if(context == TriggerOperation.AFTER_INSERT){
            results = HzpcSyncRestClient.doSyncInsert(request);
            for(Integer i = 0; i < results.size(); i++){
                HzpcSyncRestClient.RecordSyncResponse insertResult = results[i];
                Transaccion__c recToUpdate = new Transaccion__c(Id = transacciones[i].Id);
                if(insertResult.success){
                    recToUpdate.HZPCId__c = insertResult.id;
                }else{
                    recToUpdate.Hzpc_Sync_Error__c = formatErrors(insertResult.errors);
                }
                toUpdate.add(recToUpdate);
            }
        }else if(context == TriggerOperation.AFTER_UPDATE){
            results = HzpcSyncRestClient.doSyncUpdate(request);
            for(Integer i = 0; i < results.size(); i++){
                HzpcSyncRestClient.RecordSyncResponse insertResult = results[i];
                if(insertResult.success == false){
                    toUpdate.add(new Transaccion__c(Id = transacciones[i].Id, Hzpc_Sync_Error__c = formatErrors(insertResult.errors)));
                }
            }
        }

        if(toUpdate.isEmpty() == false){
            update toUpdate;
        }
    }

    private static Map<String, Object> convertToMap(String id, SObject sObj, TriggerOperation context) {
        String type = sObj.getSObjectType().getDescribe().getName() == 'Transaccion__c' ? 'Declaracion_De_Uso_Propio__c' : 'Linea_de_DUP__c';
        Map<String, Object> record = new Map<String, Object>{'attributes' => new Map<String, Object>{'type' => type}};

        for (String fieldName : sObj.getPopulatedFieldsAsMap().keySet()) {
            if(isLookupField(fieldName)){
                continue;
            }
            if(fieldName.contains('__r')){
                SObject relatedObject = sObj.getSObject(fieldName);
                if(fieldName.contains('Transaccion__r')){
                    if(context == TriggerOperation.AFTER_INSERT){
                        record.put('Declaracion_de_Uso_Propio__c', relatedObject.get('HZPCId__c'));    
                    }
                }else if(fieldName.contains('Factura__r')){
                    addFacturaFields(relatedObject, record);
                }else{
                    record.put(fieldName.replace('__r', '__c'), relatedObject.get('Name'));
                }
            }else{
                Object fieldValue = sObj.get(fieldName);
                record.put(toHzpcField(fieldName), fieldValue);
            }
        }

        return record;
    }

    private static void addFacturaFields(SObject relatedObject, Map<String, Object> record){
        if(relatedObject.get('Name') != null) record.put('Factura__c', relatedObject.get('Name'));
        if(relatedObject.get('Neto_Comprobante_ARS__c') != null) record.put('Neto_Comprobante_ARS__c', relatedObject.get('Neto_Comprobante_ARS__c'));
        if(relatedObject.get('Total_Comprobante_ARS__c') != null ) record.put('Total_Comprobante_ARS__c', relatedObject.get('Total_Comprobante_ARS__c'));
        if(relatedObject.get('Saldo_a_Gestionar__c') != null) record.put('Saldo_a_Gestionar__c', relatedObject.get('Saldo_a_Gestionar__c'));
        if(relatedObject.get('Saldo_a_Gestionar_ARS__c') != null) record.put('Saldo_a_Gestionar_ARS__c', relatedObject.get('Saldo_a_Gestionar_ARS__c'));
        if(relatedObject.get('Total_Pagos_Recibidos__c') != null) record.put('Total_Pagos_Recibidos__c', relatedObject.get('Total_Pagos_Recibidos__c'));
        if(relatedObject.get('Pagos_Recibidos__c') != null) record.put('Pagos_Recibidos__c', relatedObject.get('Pagos_Recibidos__c'));
        if(relatedObject.get('Percepciones__c') != null) record.put('Percepciones__c', relatedObject.get('Percepciones__c'));
        if(relatedObject.get('Saldo_a_Cobrar_ARS__c') != null) record.put('Saldo_a_Cobrar_ARS__c', relatedObject.get('Saldo_a_Cobrar_ARS__c'));
        if(relatedObject.get('Saldo_a_Cobrar_Comprobante__c') != null) record.put('Saldo_a_Cobrar__c', relatedObject.get('Saldo_a_Cobrar_Comprobante__c'));
    }

    private static String toHzpcField(String fieldName){
        String hzpcField;
        switch on fieldName {
            when 'HZPCId__c' {
                hzpcField = 'id';
            }
            when 'Z9_Unidad_de_Medida_de_Facturacion__c'{
                hzpcField = 'Unidad_de_Medida_de_Facturacion__c';
            }
            when 'Id'{
                hzpcField = 'ArPOVId__c';
            }
            when 'Saldo_Actualizado__c'{
                hzpcField = 'Saldo_Actualizado_ARS__c';
            }
            when 'Transaccion__c'{
                hzpcField = 'Declaracion_de_Uso_Propio__c';
            }
            when 'Total_Bruto__c'{
                hzpcField = 'Total_Bruto_ARS__c';
            }
            when 'Total_a_Facturar__c'{
                hzpcField = 'Total_a_Facturar_ARS__c';
            }
            when 'Unidades_a_Cobrar__c'{
                hzpcfield = 'Precio_Total__c';
            }
            when 'Cantidad_Facturacion_En_Bolsas_50__c'{
                hzpcField = 'Cantidad_Bolsas_50__c';
            }
            when 'Nro_Comprobante_Opp__c'{
                hzpcField = 'Numero_de_Comprobante__c';
            }
            when else{
                hzpcField = fieldName;
            }
        }

        return hzpcField;
    }

    private static Boolean isLookupField(String fieldName){
        Set<String> lookupFields = new Set<String>{'DUP_Original__c', 'Remesa__c', 'Provincia__c', 'Factura__c', 'Lote__c', 'Localidad__c', 'Cultivo__c', 'Contacto__c', 'Producto__c', 'Lugar_de_Siembra__c', 'Transaccion__c'};
        return lookupFields.contains(fieldName);
    }

    private static String formatErrors(List<HzpcSyncRestClient.ResponseError> errors){
        String errorMessage = '';
        for(HzpcSyncRestClient.ResponseError err : errors){
            errorMessage += err.statusCode + ': ' + err.message + '\n';
        }
        return errorMessage;
    }
}