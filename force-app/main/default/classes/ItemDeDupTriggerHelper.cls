public with sharing class ItemDeDupTriggerHelper {

    public static void syncWithHzpc(List<Item_de_DUP__c> items, TriggerOperation context){
        Map<Id, Item_de_DUP__c> mapItems = new Map<Id, Item_de_DUP__c>(items);
        if(mapItems.isEmpty() == false){
            if(context == TriggerOperation.BEFORE_DELETE){
                HzpcSync.doSyncDeleteItemsDup(JSON.serialize(getHzpcIds(mapItems.values())));
            }else{
                Database.executeBatch(new BatchApexSyncItemsDupHzpc(mapItems.keySet(), context), BatchApexSyncItemsDupHzpc.BATCH_SIZE);
            }
        }
    }

    public static Set<String> getHzpcIds(List<Item_de_DUP__c> items){
        Set<String> hzpcIds = new Set<String>();
        for(Item_de_DUP__c item : items){
            hzpcIds.add(item.HZPCId__c);
        }
        return hzpcIds;
    }

    //logica en trigger que estaba antes en el trigger 
    public static void processItemsDupBeforeInsertOld(List<Item_de_DUP__c> itemsDup){
        if(System.isBatch()){
            UtilsItemDeDUP.checkDuplicados(itemsDup);
        }

        AgregaTipoCambio.agregarTipoCambio(itemsDup);
    }

    //logica en trigger que estaba antes en el trigger 
    public static void processItemsDupBeforeUpdateOld(List<Item_de_DUP__c> itemsDupOld, List<Item_de_DUP__c> itemsDupNew){
        List<Item_de_DUP__c> toSetTipoCambio = new List<Item_de_DUP__c>();
        Map<Id, Item_de_DUP__c> oldMap = new Map<Id, Item_de_DUP__c>(itemsDupOld);
        for(Item_de_DUP__c item : itemsDupNew){
            if((!item.No_Facturar__c && oldMap.get(item.Id).No_Facturar__c)  || (oldMap.get(item.Id).Cantidad_Declarada__c == null || oldMap.get(item.Id).Cantidad_Declarada__c == 0) ){
                if(item.Cantidad_Declarada__c > 0){
                    toSetTipoCambio.add(item);
                }
            }
        }

        if(!toSetTipoCambio.isEmpty()){
            AgregaTipoCambio.setTipoDeCambio(toSetTipoCambio);
        }
    }

    //logica en trigger que estaba antes en el trigger 
    public static void processItemsDupAfterInsertOld(List<Item_de_DUP__c> itemsDup){
        UtilsCasos.crearCasosDups(itemsDup);
        Map<String, Set<String>> mapTransaccionVariedades = new Map<String, Set<String>>();

        Set<ID> transaccionesIds = new Set<ID>();
        Set<ID> productosIds = new Set<ID>();
        for(Item_de_DUP__c i : itemsDup){
            transaccionesIds.add(i.Transaccion__c);
            productosIds.add(i.Producto__c);
            if(!mapTransaccionVariedades.containsKey(i.Transaccion__c)){
                mapTransaccionVariedades.put(i.Transaccion__c, new Set<String>());
            }
        }

        Map<String, Product2> mapProductos = new Map<String, Product2>();
        for(Product2 p : [SELECT ID, Variedad__c FROM Product2 WHERE ID IN :productosIds]){
            mapProductos.put(p.ID, p);
        }
        for(Item_de_DUP__c i : itemsDup){
            mapTransaccionVariedades.get(i.Transaccion__c).add(mapProductos.get(i.Producto__c).Variedad__c);
        }

        List<Transaccion__c> transacciones = getTransaccionesActualizar(transaccionesIds, mapTransaccionVariedades);

        update transacciones;
    }
        
    //logica en trigger que estaba antes en el trigger 
    public static void processItemsDupAfterUpdateOld(List<Item_de_DUP__c> itemsDupOld, List<Item_de_DUP__c> itemsDupNew){
        Map<String, Set<String>> mapTransaccionVariedades = new Map<String, Set<String>>();
        Set<ID> transaccionesIds = new Set<ID>();
        for(Item_de_DUP__c i : itemsDupNew){
            transaccionesIds.add(i.Transaccion__c);
            if(!mapTransaccionVariedades.containsKey(i.Transaccion__c)){
                mapTransaccionVariedades.put(i.Transaccion__c, new Set<String>());
            }
        }

        List<Transaccion__c> transacciones = getTransaccionesActualizar(transaccionesIds, mapTransaccionVariedades);

        update transacciones;
    }

    public static void processItemsDupAfterDelete(List<Item_de_DUP__c> itemsDupOld){
        UtilsCasos.eliminarCasosDUPS(itemsDupOld);

        Map<String, Set<String>> mapTransaccionVariedades = new Map<String, Set<String>>();
        Set<ID> transaccionesIds = new Set<ID>();
        for(Item_de_DUP__c i : itemsDupOld){
            transaccionesIds.add(i.Transaccion__c);
            if(!mapTransaccionVariedades.containsKey(i.Transaccion__c)){
                mapTransaccionVariedades.put(i.Transaccion__c, new Set<String>());
            }
        }

        List<Transaccion__c> transacciones = getTransaccionesActualizar(transaccionesIds, mapTransaccionVariedades);

        update transacciones;
    }

    private static List<Transaccion__c> getTransaccionesActualizar(Set<Id> transaccionesIds, Map<String, Set<String>> mapTransaccionVariedades){
        //Traigo las transaccioens a actualizar
        List<Transaccion__c> transacciones = [SELECT ID, (SELECT Producto__r.Variedad__c FROM Item_de_DUP__r) FROM Transaccion__c WHERE ID IN :transaccionesIds];
        for(Transaccion__c t : transacciones){
            Set<String> variedades = mapTransaccionVariedades.get(t.ID);
            //Obtengo las variedades
            for(Item_de_DUP__c i : t.Item_de_DUP__r){
                variedades.add(i.Producto__r.Variedad__c);
            }
            t.Variedades__c = '';
            Integer i = 0;
            for(String v : variedades){
                if(i != 0){
                    t.Variedades__c += '; ';
                }
                t.Variedades__c += v;
                i++;
            }
        }

        return transacciones;
    }
}