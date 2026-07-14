/**
* @author Maximo Martinez
* @date 24/10/2014
* @description Generar Opps a partir de Transacciones:
*               - Si el Item tiene cantidad y esta informado, crea una oppLineItem
*               - Si el Item tiene cantidad 0 y esta informado, duplica el mismo en una nueva transacción con 
*              estado "Respondida Parcialmente", y pone a la transacción nueva como hija.
*               - Si el item NO esta informado, lo agrega a la opp como oppLineItem con estado "No informadas"
*/
public without sharing class CreateOppsFromTransactions{

    /**
    * Atributos
    */
    private List<String> errors;

    /**
    * @author Maximo Martinez
    * @date 05/07/2015
    * @description Contructor
    */
    public CreateOppsFromTransactions(){
        this.errors = new List<String>();
    }

    /**
    * @author Maximo Martinez
    * @date 05/07/2016
    * @description Metodo que retorna la lista de errores que pudieron ocurrir
    */
    public List<String> getErrors(){
        return errors;
    }

    /**
    * @author Maximo Martinez
    * @date 24/10/2014
    * @description Metodo que crea Oportunidades a Transacciones de Tipo DUP
    * @param transaccionIds : id de la Transacciones a partir de la cual se crea una Opportunidad
    */
    public void createDups(Set<ID> transaccionIds){
        
        //Obtenemos el id de la lista de precios vigente
        Id idPriceBook = Utils.getPricebook2Id();  

        //Armamos un SET para coleccionar todos los productos intervinientes en el trigger
        Set<Id> productos =new Set<Id>(); 
       
        List<TransactionWrapper> transactionsWrappers = new List<TransactionWrapper>();
        List<OpportunityWrapper> oppsWrappers = new List<OpportunityWrapper>();

        // Set de transacciones con items en estado no informada
        Set<Id> transaccionesNoInformada = new Set<Id>();
        
        //Consulta los Transactions recolectados obteniendo en una subquery los Item_de_DUP__c
        for(Transaccion__c transaccion : [Select ID, DUP_Original__c ,Saldo_a_Cobrar__c, Factura__c,Subestado__c,RecordType.Name, Nombre_de_la_cuenta__r.Name, Obtentor__c,Obtentor__r.Factura_por_Cuenta_y_Orden__c, Cultivo__c, Campana__c, Name, RecordTypeId, Respondida_via_Minisitio__c, Resultado_Validacion_Analista__c, Obtentor__r.Name, (Select ID, Estado__c, Campana_Agricola__c, Total_a_Facturar__c, Cantidad_de_Facturacion__c, Producto__r.Id, Producto__r.Conversion__c,Producto__r.Precio__c, Tipo_de_Cambio__c, Comision_por_Regalia_Simple__c,Cantidad_Facturacion_En_Bolsas_50__c, Obtentor__c  From Item_de_DUP__r) From Transaccion__c Where ID IN :transaccionIds]){
            
            TransactionWrapper tw = null;
            OpportunityWrapper ow = null;

            // Si la transaccion es Negativa y no tiene DUP Original, Procesamos la Siguiente 
            if(transaccion.Subestado__c == 'Negativa' && transaccion.DUP_Original__c == null)continue;
            
            //Recorremos cada Item_de_DUP__c
            for(Item_de_DUP__c item : transaccion.Item_de_DUP__r){
            
                //Consultamos si el Estado__c del item es "No Informada"
                //en dicho caso creamos una nueva transaccion e introduccimosel item
                

                if(item.Estado__c == 'No Informada'){

                    if(tw == null){
                    
                        //Como tenemos un item que cumple la condicion, instanciamos la clase
                        tw = new TransactionWrapper();
                        tw.transaccion =  transaccion.clone(false,true);
                        tw.items = new List<Item_de_DUP__c>();
                        tw.transaccion.Estado__c = 'Respondida Parcialmente';
                        tw.transaccion.DUP_Original__c = transaccion.Id;
                        //Creamos nombre de la transaccion duplicada tomando los 8 digitos finales
                        //luego del ultimo guion, el resto lo arma un WF
                        String[] name = transaccion.Name.split('-');
                        String transaccionName = (name.get(name.size()-1).length()>=8)?name.get(name.size()-1).substring(name.get(name.size()-1).length()-7,name.get(name.size()-1).length())+'D':name.get(name.size()-1).substring(0,name.get(name.size()-1).length())+'D';
                        tw.transaccion.Name = transaccionName.left(Utils.getFieldLength('Transaccion__c', 'Name'));
                        transactionsWrappers.add(tw);

                        // Coleccionamos el id en el set 
                        transaccionesNoInformada.add(transaccion.Id);
                        
                    }
                    
                    //Creando instancia de item
                    Item_de_DUP__c itemDup = item.clone(false,true);
                    itemDup.Checkear_Duplicado__c = true;

                    // Agregamos el item a la lista
                    tw.items.add(itemDup);

                    

                }else if(item.Estado__c != 'Consumo' && item.Cantidad_de_Facturacion__c != null && item.Cantidad_de_Facturacion__c != 0 && transaccion.Factura__c == null && (transaccion.Saldo_a_Cobrar__c == null ||  transaccion.Saldo_a_Cobrar__c == 0) && (transaccion.Respondida_via_Minisitio__c == false || (transaccion.Respondida_via_Minisitio__c == true && transaccion.Resultado_Validacion_Analista__c == 'Positiva')) ){
                    
                    productos.add(item.Producto__r.Id);
                    
                    if(ow == null){

                        // Creamos el OpportunityWrapper
                        ow = new OpportunityWrapper();
                        
                        // Seteamos la Opportunity
                        ow.opp = getOpportunity(transaccion, idPriceBook);

                        // Si es del criadero Klein hay que crear mas tarde la factura electronica
                        if(transaccion.Obtentor__r.Name.toLowerCase().indexOf('klein')!=-1){
                            ow.opp.Generar_PDF_Factura_Electronica__c = true;
                        }

                        ow.tw = new TransactionWrapper();
                        ow.tw.transaccion = transaccion;
                        ow.tw.items = new List<Item_de_DUP__c>();   
                        oppsWrappers.add(ow);
                    
                    }
                    
                    // Agragamos el item a la lista de items
                    ow.tw.items.add(item);

                }
            }
        }

        // Verificamos si ya se han creado transacciones con items en estado no informada y 
        // que tengan como DUP Original alguna de las DUP del SET
        for(Transaccion__c t : [SELECT Id, DUP_Original__c, (SELECT Id, Estado__c From Item_de_DUP__r WHERE Estado__c = 'No Informada') FROM Transaccion__c WHERE DUP_Original__c IN :transaccionesNoInformada]){

            if(transaccionesNoInformada.contains(t.DUP_Original__c) && !t.Item_de_DUP__r.isEmpty()){
                transaccionesNoInformada.remove(t.DUP_Original__c);
            }

        }

         
        //Obtenemos para los productos de los Item_de_DUP que estan dentro del set su 
        //PriceBookEntry en referencia a la lista de Precios de Pricebook2
        //Con esto armamos un Map donde la KEY sea Product2Id y el value sea PriceBookEntryId 
        Map<Id,PricebookEntry> priceBookEntryXProduct2Id = new Map<Id,PricebookEntry>();
        for(PricebookEntry pbEntry : [SELECT Id, Product2Id,UnitPrice FROM PricebookEntry WHERE Product2Id IN :productos AND Pricebook2Id =:idPriceBook AND IsActive = true]){
            priceBookEntryXProduct2Id.put(pbEntry.Product2Id, pbEntry);
        } 
        
        //Hacemos los insert de las nuevas transacciones (si corresponde)
        if(transactionsWrappers.size() > 0){

            List<Transaccion__c> transactionsToCreate = new List<Transaccion__c>();
            List<Item_de_DUP__c> itemsToCreate = new List<Item_de_DUP__c>();
             
            //recorremos la lista de transactionsWrappers y rellenamos "transactionsToCreate", para luego usarlas en un insert 
            for(TransactionWrapper transactionWrapper: transactionsWrappers){

                // Verificamos si la transaccion no esta repetida
                if(transaccionesNoInformada.contains(transactionWrapper.transaccion.DUP_Original__c)){
                    transactionsToCreate.add(transactionWrapper.transaccion);
                }

            }

            errors.addAll(BatchErrorHelper.getErrors(Utils.insertList((List<SObject>)transactionsToCreate, false), transactionsToCreate));
            
            //Luego del insert, para cada wrapper recorrer sus items y asignarles el FK ID (campo Transaccion__c), además agregarlos al "itemsToCreate" para el insert.    
            //hacer insert de items
            for(TransactionWrapper transactionWrapper: transactionsWrappers){
                if(transaccionesNoInformada.contains(transactionWrapper.transaccion.DUP_Original__c)){
                    for(Item_de_DUP__c itemDeDup : transactionWrapper.items){
                        itemDeDup.Transaccion__c = transactionWrapper.transaccion.Id;
                        //Seteamos el obtentor
                        itemDeDup.Obtentor__c = transactionWrapper.transaccion.Obtentor__c; 
                        itemsToCreate.add(itemDeDup);
                    }
                }    
            }
            if(!itemsToCreate.isEmpty()){
                errors.addAll(BatchErrorHelper.getErrors(Utils.insertList((List<SObject>)itemsToCreate, false), itemsToCreate));
            }

        }
        
        //Creamos las oportunidades para cada transaccion y un OpportunityLineItem por cada Item_de_DUP (si corresponde)
        if(oppsWrappers.size() > 0){
            
            //Set que contendra los ids de las oportunidades FC
            Set<Id> idsOpps = new Set<Id>();   
            
            List<Opportunity> oppsToCreate = new List<Opportunity>();
            List<Transaccion__c> transactionsToUpdate = new List<Transaccion__c>();
            List<OpportunityLineItem> oppItemsToCreate = new List<OpportunityLineItem>();
            
            //misma operatoria que hicimos para transacciones
            for(OpportunityWrapper opportunityWrapper : oppsWrappers){
                oppsToCreate.add(opportunityWrapper.opp);
            }
            
            //Hacemos el insert de las oportunidades
            if(!oppsToCreate.isEmpty()){
                errors.addAll(BatchErrorHelper.getErrors(Utils.insertList((List<SObject>)oppsToCreate, false), oppsToCreate));
            }

            //Asignamos cada Id con su correspondiente FK en OpportunityLineItems
            for(OpportunityWrapper opportunityWrapper : oppsWrappers){
                
                //Agregamos la factura a la transaccion
                opportunityWrapper.tw.transaccion.Factura__c = opportunityWrapper.opp.Id;

                idsOpps.add(opportunityWrapper.opp.Id);

                transactionsToUpdate.add(opportunityWrapper.tw.transaccion);
                
                for(Item_de_DUP__c itemDeDup : opportunityWrapper.tw.items){
                    
                    
                    If(priceBookEntryXProduct2Id.containsKey(itemDeDup.Producto__r.Id)){
                        
                        //Obtenemos un PricebookEntry
                        PricebookEntry pe = priceBookEntryXProduct2Id.get(itemDeDup.Producto__r.Id);
                        
                        //Verificamos que existan los campos requeridos       
                        if(itemDeDup.Cantidad_de_Facturacion__c != null && itemDeDup.Total_a_Facturar__c != null && itemDeDup.Tipo_de_Cambio__c != null){
                            
                            System.Debug(LoggingLevel.INFO,'Crear OpportunityLineItem');
                            //Creamos un OpportunityLineItem y asociamos el mismo a una Oportunidad, tambien
                            //creamos una relacion con una PricebookEntry
                            
                            Double cantidad = itemDeDup.Cantidad_de_Facturacion__c;
                            
                            Double unitPrice = (itemDeDup.Cantidad_de_Facturacion__c == 0 )?0:(itemDeDup.Total_a_Facturar__c/itemDeDup.Cantidad_de_Facturacion__c);
                            
                            if(String.isNotEmpty(opportunityWrapper.opp.Id)){

                                OpportunityLineItem oLItem = new OpportunityLineItem(OpportunityId = opportunityWrapper.opp.Id, PricebookEntryId = pe.Id, Quantity = cantidad,UnitPrice = unitPrice, Tipo_de_Cambio__c = itemDeDup.Tipo_de_Cambio__c, Comision_por_Regalia_Simple__c = itemDeDup.Comision_por_Regalia_Simple__c, Cantidad_Facturacion_En_Bolsas_50__c = itemDeDup.Cantidad_Facturacion_En_Bolsas_50__c, Item_de_DUP__c = itemDeDup.Id);
                                
                                //Agregamos al oportunity line item el ProductEntryId 
                                oppItemsToCreate.add(oLItem);
            
                            }

                        }
                    }
                    
                }
                
               
            }
            
            //Hacemos el update de las transacciones 
            if(transactionsToUpdate.size() > 0){
                errors.addAll(BatchErrorHelper.getErrors(Utils.updateList((List<SObject>)transactionsToUpdate,false),transactionsToUpdate));
            }
            
            //Hacemos el insert de todas las oportunidades
            if(oppItemsToCreate.size() > 0){
                errors.addAll(BatchErrorHelper.getErrors(Utils.insertList((List<SObject>)oppItemsToCreate, false),oppItemsToCreate));
            }
            
            if(idsOpps.size() > 0){
                UtilsOpportunity.asociaNCToFC(idsOpps);
            }
            
            
        }
    }
    
    /**
    * @author Maximo Martinez
    * @date 24/10/2014
    * @description Metodo que crea Oportunidades a Transacciones de Tipo Auditorias
    * @param transaccionIds : id de la Transacciones a partir de la cual se crea una Opportunidad
    */
    public void createAuds(Set<ID> transaccionIds){
        
        //Obtenemos el id de la lista de precios vigente
        Id idPriceBook = Utils.getPricebook2Id();  

        //Armamos un Set para coleccionar todos los productos intervinientes en el trigger
        Set<Id> productos =new Set<Id>(); 
        
        List<OpportunityAuditoriaWrapper> oppsWrappers = new List<OpportunityAuditoriaWrapper>();
        
        for(Transaccion__c transaccion : [Select Id,  Obtentor__r.Name, Auditoria__c, Saldo_a_Cobrar__c,Subestado__c, Factura__c,RecordType.Name,Nombre_de_la_cuenta__r.Name, Obtentor__c,Obtentor__r.Factura_por_Cuenta_y_Orden__c, Cultivo__c, Campana__c, Name, RecordTypeId, (Select Id,Resultado__c,Producto__r.id,Producto__r.Conversion__c,Producto__r.Precio__c, Total_a_Facturar__c,Cantidad_de_Facturacion__c,Unidad_de_Medida_de_Facturacion__c, Kilos_Totales__c, Tipo_de_Cambio__c,Comision_Por_Monto_Fijo__c,Comision_Por_Resarcimiento__c,Comision_por_Regalia_Simple__c, Cantidad_Facturacion_En_Bolsas_50__c From Items_Auditorias__r) From Transaccion__c WHERE Id IN :transaccionIds]){
            
            OpportunityAuditoriaWrapper ow = null;
            
            //Recorremos cada item de auditoria
            for(Item_Auditoria__c itemAuditoria : transaccion.Items_Auditorias__r){

                // Si la transaccion es Negativa y no tiene Auditoria, Procesamos la Siguiente 
                if(transaccion.Subestado__c == 'Negativa' && transaccion.Auditoria__c == null)continue;
                
                //Consultamos si tenemos un Item de Auditoria con Resultado 'Irregular'
                if(itemAuditoria.Resultado__c == 'Irregular'  && itemAuditoria.Cantidad_de_Facturacion__c != null && itemAuditoria.Cantidad_de_Facturacion__c != 0 && transaccion.Factura__c == null && (transaccion.Saldo_a_Cobrar__c == null || transaccion.Saldo_a_Cobrar__c == 0)){
                   
                    //Coleccionamos el producto en el Set      
                    productos.add(itemAuditoria.Producto__r.Id);
                    
                    if(ow == null){
                
                        ow = new OpportunityAuditoriaWrapper();

                        ow.opp = getOpportunity(transaccion, idPriceBook);

                        // Si es del criadero Klein hay que crear mas tarde la factura electronica
                        if(transaccion.Obtentor__r.Name.toLowerCase().indexOf('klein')!=-1){
                            ow.opp.Generar_PDF_Factura_Electronica__c = true;
                        }
                        
                        ow.tw = new TransactionAuditoriaWrapper();
                        ow.tw.items = new List<Item_Auditoria__c>();
                        ow.tw.transaccion = transaccion;
                        
                        oppsWrappers.add(ow);  

                    }
                    
                    ow.tw.items.add(itemAuditoria);
                }
                
            }
            
        }
        
        
        //Obtenemos para los productos de los Item_de_DUP que estan dentro del set su 
        //PriceBookEntry en referencia a la lista de Precios de Pricebook2
        //Con esto armamos un Map donde la KEY sea Product2Id y el value sea PriceBookEntryId 
        Map<Id,PricebookEntry> priceBookEntryXProduct2Id = new Map<Id,PricebookEntry>();

        for(PricebookEntry pbEntry : [SELECT Id, Product2Id,UnitPrice FROM PricebookEntry WHERE Product2Id IN :productos AND Pricebook2Id =:idPriceBook AND IsActive = true]){
            priceBookEntryXProduct2Id.put(pbEntry.Product2Id, pbEntry);
        }
        
        if(oppsWrappers.size() > 0){

            //Set que contendra los ids de las oportunidades
            Set<Id> idsOpps = new Set<Id>();   
            
            List<Opportunity> oppsToCreate = new List<Opportunity>();
            List<Transaccion__c> transactionsToUpdate = new List<Transaccion__c>();
            List<OpportunityLineItem> oppItemsToCreate = new List<OpportunityLineItem>();
            
            //misma operatoria que hicimos para transacciones
            for(OpportunityAuditoriaWrapper opportunityWrapper : oppsWrappers){
                oppsToCreate.add(opportunityWrapper.opp);
            }
            
            //Hacemos el insert de las oportunidades
            if(!oppsToCreate.isEmpty()){
                errors.addAll(BatchErrorHelper.getErrors(Utils.insertList((List<SObject>)oppsToCreate, false), oppsToCreate));
            }
            
            //Asignamos cada Id con su correspondiente FK en OpportunityLineItems
            for(OpportunityAuditoriaWrapper opportunityWrapper : oppsWrappers){
                
                //Agregamos el id de la factura
                opportunityWrapper.tw.transaccion.Factura__c = opportunityWrapper.opp.Id;

                // Coleccionamos el id de la opportunity
                idsOpps.add(opportunityWrapper.opp.Id);
                
                //Coleccionamos la transaccion para luego actualizar todas juntas
                transactionsToUpdate.add(opportunityWrapper.tw.transaccion);
         
                for(Item_Auditoria__c itemAuditoria : opportunityWrapper.tw.items){
                    
                    If(priceBookEntryXProduct2Id.containsKey(itemAuditoria.Producto__r.Id)){
                        
                        //Obtenemos un PricebookEntry
                        PricebookEntry pe = priceBookEntryXProduct2Id.get(itemAuditoria.Producto__r.Id);
                        
                         //Verificamos que existan los campos requeridos                        
                        if(itemAuditoria.Cantidad_de_Facturacion__c != null && itemAuditoria.Total_a_Facturar__c != null && itemAuditoria.Tipo_de_Cambio__c != null){
                            
                            Double unitPrice = (itemAuditoria.Cantidad_de_Facturacion__c == 0 )?0:(itemAuditoria.Total_a_Facturar__c/itemAuditoria.Cantidad_de_Facturacion__c);
                            
                            //Creamos un OpportunityLineItem y asociamos el mismo a una Oportunidad, tambien
                            //creamos una relacion con una PricebookEntry

                            if(String.isNotEmpty(opportunityWrapper.opp.Id)){
                            
                                OpportunityLineItem oLItem = new OpportunityLineItem(OpportunityId = opportunityWrapper.opp.Id, PricebookEntryId = pe.Id, Quantity = itemAuditoria.Cantidad_de_Facturacion__c, UnitPrice = unitPrice, Tipo_de_Cambio__c = itemAuditoria.Tipo_de_Cambio__c, Comision_por_Regalia_Simple__c = itemAuditoria.Comision_por_Regalia_Simple__c, Comision_Por_Monto_Fijo__c = itemAuditoria.Comision_Por_Monto_Fijo__c, Comision_Por_Resarcimiento__c = itemAuditoria.Comision_Por_Resarcimiento__c, Cantidad_Facturacion_En_Bolsas_50__c = itemAuditoria.Cantidad_Facturacion_En_Bolsas_50__c, Item_Auditoria__c = itemAuditoria.Id);
                                
                                //Agregamos al oportunity line item el ProductEntryId 
                                oppItemsToCreate.add(oLItem);

                            }

                        }
                    }
                    
                }
               
            }
            
            //Hacemos el update de las transacciones 
            if(transactionsToUpdate.size() > 0){
                errors.addAll(BatchErrorHelper.getErrors(Utils.updateList((List<SObject>)transactionsToUpdate, false),transactionsToUpdate));
            }
            
            //Hacemos el insert de todas las oportunidades
            if(oppItemsToCreate.size() > 0){
                errors.addAll(BatchErrorHelper.getErrors(Utils.insertList((List<SObject>)oppItemsToCreate, false),oppItemsToCreate));
            }

            if(idsOpps.size() > 0){
                UtilsOpportunity.asociaNCToFC(idsOpps);
            }
            
        }
        
    }

    /**
    * @author Maximo Martinez
    * @date 6/11/2014
    * @description Metodo que crea Oportunidad a partir de una transaccion
    * @param transaccion : Transaccion a partir de la cual se crea una Opportunidad
    */
    public static Opportunity getOpportunity(Transaccion__c transaccion, Id idPriceBook){
        //Creamos una Oportunidad
        Opportunity o = new Opportunity();

        //Seteamos sus atributos
        o.StageName = (transaccion.Obtentor__r.Factura_por_Cuenta_y_Orden__c == true)?'Pendiente Facturacion':'Pendiente Facturacion Obtentor';
        
        String name = transaccion.Nombre_de_la_cuenta__r.Name.left(90) +'-'+transaccion.RecordType.Name+'-'+transaccion.Name;

        o.Name = name.left(Utils.getFieldLength('Opportunity', 'Name'));

        o.Tipo_de_Comprobante__c = (transaccion.Subestado__c == 'Positiva') ? 'FC':'NC';
        o.Pricebook2Id = idPriceBook;
        o.CloseDate = Date.today();
        o.AccountId = transaccion.Nombre_de_la_cuenta__c;
        o.Obtentor__c = transaccion.Obtentor__c;
        o.Transaccion__c = transaccion.Id;
        o.Campana__c = transaccion.Campana__c;
        o.Type = transaccion.RecordType.Name;
        o.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByDeveloperName().get('Regalia_Extendida').getRecordTypeId();

        // Retornamos la oportunidad
        return o;
    }
   
    public class TransactionWrapper{
        public Transaccion__c transaccion {get;set;}
        public List<Item_de_DUP__c> items {get;set;}
    }
    
    public class OpportunityWrapper{
        public Opportunity opp {get;set;}
        public TransactionWrapper tw {get;set;}
    }
    
    public class TransactionAuditoriaWrapper{
        public Transaccion__c transaccion {get;set;}
        public List<Item_Auditoria__c> items {get;set;}
    }
    
    public class OpportunityAuditoriaWrapper{
        public Opportunity opp {get;set;}
        public TransactionAuditoriaWrapper tw {get;set;}
    }
}