/**
* @author Maximo Martinez
* @date 06/06/2014
* @description Metodo que contiene metodos auxiliares de la clase Item de DUP
*/
public with sharing class UtilsItemDeDUP {

    /**
    * @author Maximo Martinez
    * @date 10/02/2015
    * @description Valida que no existan items duplicados
    */
    public static void checkDuplicados(List<Item_de_DUP__c> lista){

        // Lista de Items de DUP a checkear
        List<Item_de_DUP__c> toCheck = new List<Item_de_DUP__c>();

        // Solo voy a considerar items que tengan seteado el flag Checkear_Duplicado__c en true
        for(Item_de_DUP__c item : lista){

            if(item.Checkear_Duplicado__c)
                toCheck.add(item);

        }

        // Set de tipos de lotes cuyas transacciones no entran en la validacion de duplicado
        Set<String> lotesToSkipValidation = new Set<String>{'Especial'};

        // Set de lotes que son validos en el proceso
        Set<String> lotesValidos = new Set<String>{'Basico', 'Complementario'};

        List<Item_de_DUP__c > items = toCheck;
        
        // Verificación de unicidad de producto
        // Recorro los items que trigger y obtengo los ids de las transacciones
        Map<String, Transaccion__c> mapTransacciones = new Map<String, Transaccion__c>();
        for(Item_de_DUP__c i : items){
            mapTransacciones.put(i.Transaccion__c, null);
        }
        
        Set<String> nombresCuenta = new Set<String>();
        Set<String> cultivos = new Set<String>();
        Set<String> campanas = new Set<String>();
        Set<String> obtentores = new Set<String>();

        // Obtengo las transacciones, las guardo en un map y armos sets para filtado de items de dups existentes
        for(Transaccion__c t : [SELECT ID, Nombre_de_la_cuenta__c, Obtentor__c, Campana__c, Cultivo__c, Subestado__c FROM Transaccion__c WHERE Subestado__c != null AND Subestado__c = 'Positiva' AND ID IN :mapTransacciones.keySet() AND DUP_Original__c = null AND Lote__r.Tipo__c NOT IN :lotesToSkipValidation AND Lote__r.Tipo__c IN :lotesValidos]){
            nombresCuenta.add(t.Nombre_de_la_cuenta__c);
            cultivos.add(t.Cultivo__c);
            campanas.add(t.Campana__c);
            obtentores.add(t.Obtentor__c);
            mapTransacciones.put(t.ID, t);
        }

        Map<String, Map<String, Item_de_DUP__c>> mapItemsExistentes = new Map<String, Map<String, Item_de_DUP__c>>();
        Map<String, Decimal> mapItemsExistentesCantidad = new Map<String, Decimal>();

        //Traigo items existentes

        if(!Test.isRunningTest()){

            for(AggregateResult i : [SELECT COUNT(ID) Cantidad, Producto__c Producto, Transaccion__r.Nombre_de_la_cuenta__c Nombre_de_la_cuenta, Transaccion__r.Obtentor__c Obtentor, Transaccion__r.Campana__c Campana, Transaccion__r.Cultivo__c Cultivo, Transaccion__r.Subestado__c Subestado FROM Item_de_DUP__c 
                                    WHERE Transaccion__r.Nombre_de_la_cuenta__c IN :nombresCuenta AND Transaccion__r.Obtentor__c IN :obtentores AND Transaccion__r.Campana__c IN :campanas AND Transaccion__r.Cultivo__c IN :cultivos AND Transaccion__r.Lote__r.Tipo__c NOT IN :lotesToSkipValidation AND Transaccion__r.Lote__r.Tipo__c IN :lotesValidos
                                    GROUP BY Producto__c, Transaccion__r.Nombre_de_la_cuenta__c, Transaccion__r.Obtentor__c, Transaccion__r.Campana__c, Transaccion__r.Cultivo__c, Transaccion__r.Subestado__c]){
                String key = '' + i.get('Nombre_de_la_cuenta') + i.get('Cultivo') + i.get('Campana') + i.get('Obtentor') + i.get('Subestado') + i.get('Producto');
                mapItemsExistentesCantidad.put(key, (Decimal)i.get('Cantidad'));
            }
            
            if(Trigger.isUpdate){
                for(Item_de_DUP__c i : [SELECT ID, Producto__c, Transaccion__r.Nombre_de_la_cuenta__c, Transaccion__r.Obtentor__c, Transaccion__r.Campana__c, Transaccion__r.Cultivo__c, Transaccion__r.Subestado__c  FROM Item_de_DUP__c 
                                    WHERE Transaccion__r.Nombre_de_la_cuenta__c IN :nombresCuenta AND Transaccion__r.Obtentor__c IN :obtentores AND Transaccion__r.Campana__c IN :campanas AND Transaccion__r.Cultivo__c IN :cultivos AND Transaccion__r.Lote__r.Tipo__c NOT IN :lotesToSkipValidation AND Transaccion__r.Lote__r.Tipo__c IN :lotesValidos]){
                    String key = '' + i.Transaccion__r.Nombre_de_la_cuenta__c + i.Transaccion__r.Cultivo__c + i.Transaccion__r.Campana__c + i.Transaccion__r.Obtentor__c + i.Transaccion__r.Subestado__c + i.Producto__c;
                    if(!mapItemsExistentes.containsKey(key)){
                        mapItemsExistentes.put(key, new Map<String, Item_de_DUP__c>());
                    }
                    mapItemsExistentes.get(key).put(i.Id, i);
                }
            
            }
            
        }

        //Recorro los item comparando los que ya fueron cargados
        // 29-05-2014: ***** MODIFICADO POR JLI PARA CARGA INICIAL *****
        // 28-10-2014: ***** MODIFICADO POR FL PARA QUE PERMITA CARGA DE POSITIVOS SI YA TIENE CARGADOS NEGATIVOS *****
        
        for(Item_de_DUP__c i : items){
            if(i.Z9_Carga_Inicial__c  != true){
                Transaccion__c t = mapTransacciones.get(i.Transaccion__c);
                if(t != null){
                    String key = '' + t.Nombre_de_la_cuenta__c + t.Cultivo__c + t.Campana__c + t.Obtentor__c + t.Subestado__c + i.Producto__c;
                    //Controlo la cantidad de positivas y negativas, para ver si dejo insertar o no
                    String keyAux = '' + t.Nombre_de_la_cuenta__c + t.Cultivo__c + t.Campana__c + t.Obtentor__c + 'Positiva' + i.Producto__c; 
                    Decimal cantidadPositiva = mapItemsExistentesCantidad.get(keyAux)!=null?mapItemsExistentesCantidad.get(keyAux):0;
                    keyAux = '' + t.Nombre_de_la_cuenta__c + t.Cultivo__c + t.Campana__c + t.Obtentor__c + 'Negativa' + i.Producto__c; 
                    Decimal cantidadNegativa = mapItemsExistentesCantidad.get(keyAux)!=null?mapItemsExistentesCantidad.get(keyAux):0;
                    Boolean permitePositiva = (cantidadPositiva == 0 || (cantidadPositiva <= cantidadNegativa))?true:false;
 
                    if(Trigger.isInsert){
                        
                        if(key.contains('Positiva') && !permitePositiva){
                            i.addError(Label.Error_Item_DUP_Duplicado);
                        } else {
                            if(mapItemsExistentesCantidad.containsKey(key)){
                                mapItemsExistentesCantidad.put(key, mapItemsExistentesCantidad.get(key) + 1);
                            } else {
                                mapItemsExistentesCantidad.put(key, 1);
                            }
                        }
                    
                    } else if(Trigger.isUpdate){
                        //Controlo si ya existe el item para esa combinacion, y si existe controlo que no haya 2 o mas iguales, por si hubo carga de datos previa sin control.
                        if(key.contains('Positiva') && mapItemsExistentes.containsKey(key) && !permitePositiva && (!mapItemsExistentes.get(key).containsKey(i.Id) || (cantidadPositiva-cantidadNegativa >= 2))){
                            i.addError(Label.Error_Item_DUP_Duplicado);
                        } else {
                            if(mapItemsExistentesCantidad.containsKey(key)){
                                mapItemsExistentesCantidad.put(key, mapItemsExistentesCantidad.get(key) + 1);
                            } else {
                                mapItemsExistentesCantidad.put(key, 1);
                            }
                            
                            if(!mapItemsExistentes.containsKey(key)){
                                mapItemsExistentes.put(key, new Map<String, Item_de_DUP__c>());
                            } 
                            mapItemsExistentes.get(key).put(i.Id, i);
                            
                        }
                    }
                    
                }
            }
        } 


    }


}