/**
* @author Maximo Martinez
* @date 2/06/2014
* @description Clase encargada de setear el tipo de cambio
*/
public without sharing  class AgregaTipoCambio{
    
    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Metodo encargado de setear el tipo de cambio para los items dups cuando el campo Cantidad Declarada paso a tener valor
    */ 
    public static void setTipoDeCambio(List<Item_de_DUP__c> items){

        Map<Id, Item_de_DUP__c> groupedItems = new Map<Id, Item_de_DUP__c>(items); 

        // Obtenemos la fecha actual
        Date today = Date.today();

        // Ontenemos las conversiones para la fecha actual
        Map<String, Tipo_de_Cambio__c> cambios = new Map<String, Tipo_de_Cambio__c>();

        for(Tipo_de_Cambio__c t : [SELECT Cotizacion__c, Moneda__r.Codigo_Univoco__c FROM Tipo_de_Cambio__c WHERE Fecha__c = :today]){
            cambios.put(t.Moneda__r.Codigo_Univoco__c, t);
        }

        // Obtenemos los items dup cuyas transacciones son != 'Negativa'
        for(Item_de_DUP__c item : [SELECT Id, Conversion__c, Transaccion__r.Name FROM Item_de_DUP__c WHERE Subestado_de_la_Transaccion__c != 'Negativa' AND Id IN :groupedItems.keySet()]){

            if(!groupedItems.containsKey(item.Id)){
                continue;
            }

            Item_de_DUP__c i = groupedItems.get(item.Id);

            if(cambios.containsKey(item.Conversion__c)){

                Tipo_de_Cambio__c t = cambios.get(item.Conversion__c);

                i.Tipo_de_Cambio__c = t.Cotizacion__c;

            }else{
                // No se encontro el tipo de cambio para la fecha actual
                // Marco el campo Cantidad_Declarada__c
                i.Cantidad_Declarada__c.addError(Label.Error_No_Esta_Cargado_el_Tipo_de_Cambio);
                
            }

        }

    }

    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Metodo encargado de retornar el tipo de cambio de las monedas, cargadas en el sistema
    */ 
    public static List<AggregateResult> getCotizacionesDelDia(){
        
        // Debo asignar el valor de la cotización actual de la moneda
        Date fechaActual = Date.today();
        
        // Obtengo las conversiones de las monedas del sistema
        List<AggregateResult> tiposCambio;
        
        //Obtengo la fecha de hoy
        Datetime today = Datetime.now();
        
        //Obtengo el día
        String dia = today.format('E');
        
        if(dia == 'Mon' || dia == 'Tue' || dia == 'Wed' || dia == 'Thu' || dia == 'Fri')
            tiposCambio = [Select moneda__r.Moneda_de_la_compania__c monedaDefault, moneda__r.Name moneda, Max(Fecha__c) fecha, Max(Cotizacion__c) cotizacion from Tipo_de_Cambio__c where Fecha__c = :fechaActual group by moneda__r.Moneda_de_la_compania__c, moneda__r.Name];
        else
            tiposCambio = [Select moneda__r.Moneda_de_la_compania__c monedaDefault, moneda__r.Name moneda, Max(Fecha__c) fecha, Max(Cotizacion__c) cotizacion from Tipo_de_Cambio__c where Fecha__c <= :fechaActual group by moneda__r.Moneda_de_la_compania__c, moneda__r.Name];
        
        
        return tiposCambio;
    }
    
    
    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Metodo encargado de retornar la moneda default de la compania
    */ 
    public static Moneda__c getMonedaDeafult(){
        
        // Obtengo la monedaDefault
        
        List<Moneda__c> monedas = [Select Name from Moneda__c where Moneda_de_la_compania__c = true LIMIT 1];
        
        Moneda__c moneda = null;
        
        if(monedas.size() > 0){
            
            moneda = monedas.get(0);
            
        }
        
        return moneda;
        
    }
    
     
    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Metodo encargado de setear el tipo de cambio a los items auditorias
    */ 
     public static void agregarTipoCambio(List<Item_Auditoria__c> items){
         
         //Obtengo los tipos de cambios del día de las monedas
         List<AggregateResult> tiposCambio = getCotizacionesDelDia();
         
         //Obtengo la moneda default de la compania
         Moneda__c monedaDefault = getMonedaDeafult();
         
         //Obtengo las transacciones de estos items
         
         //Set que coleccionara los ids de las transacciones
         Set<Id> idsTransacciones = new Set<Id>();
         
         //Set para coleccionar los ids de los productos
         Set<Id> idsProductos = new Set<Id>();
         
         
         //Recorro los items y colecciono los ids de las transacciones
         for(Item_Auditoria__c item : items){
             
             //Si el campo Z9_Carga_Inicial__c esta en true no realizamos la carga
             if(item.Z9_Carga_Inicial__c != true){
             
                 //Colecciono el Id de la Transaccion en el Set
                 idsTransacciones.add(item.Auditoria__c);
                 
                 //Colecciono el id de los productos
                 idsProductos.add(item.Producto__c);
             
             }
         
         }

         System.debug(LoggingLevel.INFO, idsTransacciones);
         System.debug(LoggingLevel.INFO, idsProductos);
         
         
         //Obtengo las cotizaciones que se agregaron a items previamente agregados a las transacciones
         //a fin de si ya tengo definidad una linea con la misma cotizacion que una que voy a agregar,
         //uso la misma cotizacion, si no esta la saco de las cotizaciones que calcule al principio
         
         //Map que me permitira agrupar por cada transaccion cada tipo de conversion que ya ha sido cargado
         Map<Id,Map<String,Double>> conversionesByTransacciones = new Map<Id,Map<String,Double>>();
         
         //Map que agrupa las conversiones y cotizaciones
         Map<String,Double> tipoCambioByConverion;
         
         for(Transaccion__c transaccion : [SELECT Id, Subestado__c,(SELECT Id, Tipo_de_Cambio__c, Conversion__c,Producto__r.Conversion__c FROM Items_Auditorias__r ) FROM Transaccion__c WHERE Id IN :idsTransacciones AND Subestado__c != 'Negativa']){

            //Si no existe una entrada para la transaccion, la creamos
            if(!conversionesByTransacciones.containsKey(transaccion.Id)){
                conversionesByTransacciones.put(transaccion.Id,new Map<String,Double>());
            }
             
             //Obtenemos el map que agrupa las conversiones y cotizaciones
             tipoCambioByConverion = conversionesByTransacciones.get(transaccion.Id);
             
             System.debug(LoggingLevel.INFO, 'TEst');

             //Recorremos los items auditorias
             for(Item_Auditoria__c item : transaccion.Items_Auditorias__r){

                System.debug(LoggingLevel.INFO, item.Producto__r.Conversion__c);
                 
                 //Si no existe una entrada para la conversion, la creamos
                 if(!tipoCambioByConverion.containsKey(item.Producto__r.Conversion__c)){
                     tipoCambioByConverion.put(item.Producto__r.Conversion__c,item.Tipo_de_Cambio__c);
                 }
                 
             }
             
         }

         System.debug(LoggingLevel.INFO, tipoCambioByConverion);
         
         //Map que contendra los productos 
         Map<Id,Product2> productById = new Map<Id,Product2>();
         
         for(Product2 p : [SELECT Id, Conversion__c FROM Product2 WHERE Id IN :idsProductos]){
             productById.put(p.Id,p);
         }
         
         //Por ultimo recorro los items que se pasaron como parametro a este metodo y seteo su tipo de cambio, 
         //primero verifico si el cambio lo puedo obtener de otra linea de la transaccion, sino lo saco de los
         //tipos de cambio que se cargaron para esta fecha
         for(Item_Auditoria__c item : items){
            
            //Si el campo Z9_Carga_Inicial__c esta en true ó el item es resultado no es regular no realizamos la carga 
            if(item.Z9_Carga_Inicial__c == true)
                continue;
            
            // Si no esta en el Map la transaccion cargada, continuamos con el siguiente item
            if(!conversionesByTransacciones.containsKey(item.Auditoria__c)) 
                continue;

            //Seteo el tipo de cambio en null
            item.Tipo_de_Cambio__c = null;

            //Obtengo el Map que contiene las conversiones de las lineas de la transaccion
            tipoCambioByConverion = conversionesByTransacciones.get(item.Auditoria__c); 

            Double tipoCambio;

            //Revisamos si la conversion que tiene el item esta en el map
            if(tipoCambioByConverion.containsKey(item.Producto__r.Conversion__c)){
             
             //Obtenemos el tipo de cambio
             item.Tipo_de_Cambio__c =  tipoCambioByConverion.get(item.Producto__r.Conversion__c);
             
            }else{
             
             Product2 p = null;
             
             //Obtengo el producto de la auditoria
             if(productById.containsKey(item.Producto__c)){
                 p = productById.get(item.Producto__c);
             
                 //Obtenemos el tipo de cambio de las cotizaciones seteadas en el día
                 for (AggregateResult tp: tiposCambio){
                    
                    //Verificamos si tenemos una moneda default cargada
                    if( monedaDefault != null ){
                        //Sino seteo el tipo de cambio
                        if((Boolean)tp.get('monedaDefault') || monedaDefault.Name == p.Conversion__c){
                            //Seteo el Tipo de Cambio al Item
                            item.Tipo_de_Cambio__c = 1;
                            break;
                        }
                    }
                    // Asigno el tipo de cambio que le corresponde a la moneda del producto.
                    if((String)tp.get('moneda') == p.Conversion__c){
                        //Seteo el Tipo de Cambio al Item
                        item.Tipo_de_Cambio__c = (Decimal)tp.get('cotizacion');
                        break;
                    }
                }
                
                
                
                //Si se seteo el tipo de cambio, lo agrego al map
                //a fin de si se cargo mas de una linea y esta en este lote que estamos procesando,
                //se utilice la misma conversion que hemos usado
                if(item.Tipo_de_Cambio__c != null){
                    tipoCambioByConverion.put(item.Producto__r.Conversion__c,item.Tipo_de_Cambio__c);
                }

            }
             
            }

            // Si no se asignó ningún tipo de cambio, lanzo un error
            // Pero si es Resultado es Regular no salta el error
            if(item.Tipo_de_Cambio__c == null && item.Resultado__c != 'Regular'){
                item.addError('No se cargó el tipo de cambio para la fecha actual. Póngase en contacto con administración');
            } 
            
         }
         
     }
     
     
     /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Metodo encargado de setear el tipo de cambio a los items dup
    */ 
     public static void agregarTipoCambio(List<Item_de_DUP__c> items){
         
         //Obtengo los tipos de cambios del día de las monedas
         List<AggregateResult> tiposCambio = getCotizacionesDelDia();
         
         //Obtengo la moneda default de la compania
         Moneda__c monedaDefault = getMonedaDeafult();
         
         //Obtengo las transacciones de estos items
         
         //Set que coleccionara los ids de las transacciones
         Set<Id> idsTransacciones = new Set<Id>();
         
         //Recorro los items y colecciono los ids de las transacciones
         for(Item_de_DUP__c item : items){
             //Si el campo Z9_Carga_Inicial__c esta en true no realizamos la carga
             if(item.Z9_Carga_Inicial__c  != true){
                 //Colecciono el Id de la Transaccion en el Set
                 idsTransacciones.add(item.Transaccion__c);
             }
         }
         
         
         //Obtengo las cotizaciones que se agregaron a items previamente agregados a las transacciones
         //a fin de si ya tengo definidad una linea con la misma cotizacion que una que voy a agregar,
         //uso la misma cotizacion, si no esta la saco de las cotizaciones que calcule al principio
         
         //Map que me permitira agrupar por cada transaccion cada tipo de conversion que ya ha sido cargado
         Map<Id,Map<String,Double>> conversionesByTransacciones = new Map<Id,Map<String,Double>>();
         
         //Map que agrupa las conversiones y cotizaciones
         Map<String,Double> tipoCambioByConverion;
         
         for(Transaccion__c transaccion : [SELECT Id, (SELECT Id, Tipo_de_Cambio__c, Conversion__c FROM Item_de_DUP__r ) FROM Transaccion__c WHERE Id IN :idsTransacciones AND Subestado__c != 'Negativa']){
             
             //Si no existe una entrada para la transaccion, la creamos
             if(!conversionesByTransacciones.containsKey(transaccion.Id)){
                 conversionesByTransacciones.put(transaccion.Id,new Map<String,Double>());
             }
             
             //Obtenemos el map que agrupa las conversiones y cotizaciones
             tipoCambioByConverion = conversionesByTransacciones.get(transaccion.Id);
             
             //Recorremos los items auditorias
             for(Item_de_DUP__c item : transaccion.Item_de_DUP__r){
                 
                 //Si no existe una entrada para la conversion, la creamos
                 if(!tipoCambioByConverion.containsKey(item.Conversion__c)){
                     tipoCambioByConverion.put(item.Conversion__c,item.Tipo_de_Cambio__c);
                 }
                 
             }
             
         }
         
         System.Debug(LoggingLevel.INFO,conversionesByTransacciones);
         
         //Por ultimo recorro los items que se pasaron como parametro a este metodo y seteo su tipo de cambio, 
         //primero verifico si el cambio lo puedo obtener de otra linea de la transaccion, sino lo saco de los
         //tipos de cambio que se cargaron para esta fecha
         for(Item_de_DUP__c item : items){
         
             //Si el campo Z9_Carga_Inicial__c esta en true no realizamos la carga
             if(item.Z9_Carga_Inicial__c  != true){
                 
                 //Si no tenemos seteada la conversion, no aplicamos la logica
                 if(item.Conversion__c != null){

                     // Si la transaccion no esta en el map, no proceso ese item
                     if(!conversionesByTransacciones.containsKey(item.Transaccion__c))
                        continue;
                 
                     //Seteo el tipo de cambio en null
                     item.Tipo_de_Cambio__c = null;
                     
                     //Obtengo el Map que contiene las conversiones de las lineas de la transaccion
                     tipoCambioByConverion = conversionesByTransacciones.get(item.Transaccion__c); 
                     
                     Double tipoCambio;
                     
                     //Revisamos si la conversion que tiene el item esta en el map
                     if(tipoCambioByConverion.containsKey(item.Conversion__c)){
                         
                         //Obtenemos el tipo de cambio
                         item.Tipo_de_Cambio__c = tipoCambioByConverion.get(item.Conversion__c);
                         
                     }else{
                         
                         
                         //Obtenemos el tipo de cambio de las cotizaciones seteadas en el día
                         for (AggregateResult tp: tiposCambio){
                            
                            //Verificamos si tenemos una moneda default cargada
                            if( monedaDefault != null ){
                                //Sino seteo el tipo de cambio
                                if((Boolean)tp.get('monedaDefault') || monedaDefault.Name == item.Conversion__c){
                                    //Seteo el Tipo de Cambio al Item
                                    item.Tipo_de_Cambio__c = 1;
                                    break;
                                }
                            }
                            
                            // Asigno el tipo de cambio que le corresponde a la moneda del producto.
                            if((String)tp.get('moneda') == item.Conversion__c){
                                //Seteo el Tipo de Cambio al Item
                                item.Tipo_de_Cambio__c = (Decimal)tp.get('cotizacion');
                                break;
                            }
                        }
                        
                        //Si se seteo el tipo de cambio, lo agrego al map
                        //a fin de si se cargo mas de una linea y esta en este lote que estamos procesando,
                        //se utilice la misma conversion que hemos usado
                        if(item.Tipo_de_Cambio__c != null){
                            tipoCambioByConverion.put(item.Conversion__c,item.Tipo_de_Cambio__c);
                        }
                         
                     }
                     
                    // Si no se asignó ningún tipo de cambio, lanzo un error
                    if(item.Tipo_de_Cambio__c == null){
                        item.addError('No se cargó el tipo de cambio para la fecha actual. Póngase en contacto con administración');
                    } 
                
                }
            
            }
         }
         
     }
     
}