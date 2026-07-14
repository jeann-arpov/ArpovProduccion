trigger tg_Item_Auditoria on Item_Auditoria__c (before insert) {
    
    if(Trigger.isBefore){
    
        /** 2014-07-16: Desactivado a pedido de Sebastián Iglesias
        
        List<Item_Auditoria__c> items = Trigger.new;
        // Verificación de unicidad de producto
        Map<String, Transaccion__c> mapTransacciones = new Map<String, Transaccion__c>();
        for(Item_Auditoria__c i : items){
            if(i.Z9_Carga_Inicial__c  != true){
                mapTransacciones.put(i.Auditoria__c, null);
            }
        }
        for(Transaccion__c t : [SELECT ID, Nombre_de_la_cuenta__c, Obtentor__c, Campana__c, Cultivo__c, Subestado__c FROM Transaccion__c WHERE Subestado__c = 'Positiva' AND Id IN :mapTransacciones.keySet()]){
            mapTransacciones.put(t.ID, t);
        }
        Map<String, Item_Auditoria__c> mapItemsExistentes = new Map<String, Item_Auditoria__c>();
        //Traigo items existentes
        for(Item_Auditoria__c i : [SELECT ID,Z9_Carga_Inicial__c, Producto__c, Auditoria__r.Nombre_de_la_cuenta__c, Auditoria__r.Obtentor__c, Auditoria__r.Campana__c, Auditoria__r.Cultivo__c, Auditoria__r.Subestado__c  FROM Item_Auditoria__c WHERE Auditoria__c IN :mapTransacciones.keySet()]){
            if(i.Z9_Carga_Inicial__c  != true){
                String key = '' + i.Auditoria__r.Nombre_de_la_cuenta__c + i.Auditoria__r.Cultivo__c + i.Auditoria__r.Campana__c + i.Auditoria__r.Obtentor__c + i.Auditoria__r.Subestado__c + i.Producto__c;
                mapItemsExistentes.put(key, i);
            }
        }
        //Recorro los item comparando los que ya fueron cargados
        // 29-05-2014: ***** MODIFICADO POR JLI PARA CARGA INICIAL *****
        
        for(Item_Auditoria__c i : items){
            if(i.Z9_Carga_Inicial__c  != true){
                Transaccion__c t = mapTransacciones.get(i.Auditoria__c);
                if(t != null){
                    String key = '' + t.Nombre_de_la_cuenta__c + t.Cultivo__c + t.Campana__c + t.Obtentor__c + t.Subestado__c + i.Producto__c;
                    if(mapItemsExistentes.containsKey(key)){
                        if(Trigger.isInsert){
                            mapItemsExistentes.put(key, i);
                            i.addError(Label.Error_Item_DUP_Duplicado);
                        } else if(Trigger.isUpdate){
                            if(mapItemsExistentes.get(key).ID != i.ID){
                                i.addError(Label.Error_Item_DUP_Duplicado);
                            }
                        }
                    } 
                }
            }
        } 
        **/
        
        //Tipo de Cambio
        if(Trigger.isInsert){
           AgregaTipoCambio.agregarTipoCambio(Trigger.new);
        }
        
    }
    
    
}