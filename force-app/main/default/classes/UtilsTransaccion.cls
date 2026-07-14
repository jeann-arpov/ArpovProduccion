/**
* @author Maximo Martinez
* @date 06/06/2014
* @description Clase Auxiliar del Objecto Transaccion__c
*/
public without sharing class UtilsTransaccion{

     /**
    * @author Maximo Martinez
    * @date 07/01/2015
    * @description Metodo que dependiendo de si una transaccion tiene comprobantes de venta o no setea Tiene CAE 
    */ 
    public static void setTieneCAE(Set<Id> idsTransacciones) {
        
        for(List<Transaccion__c> ts : [SELECT Id FROM Transaccion__c WHERE Id IN :idsTransacciones]) {
            
            for(Transaccion__c t : ts) {
                
                t.Tiene_CAE__c = true;

            } 

            update ts;

        }

    }

    /**
    * @author Maximo Martinez
    * @date 24/10/2014
    * @description Metodo que Crea una NC por cada Transaccion Dup que se le pasa
    * @param lista : lista de transacciones Auditorias
    */
    public static void generarNCAuditorias(List<Transaccion__c> lista){

        // Map de Errores por Transaccion
        Map<Id, List<String>> errorsByTransaction = new Map<Id, List<String>>();

        //Map que contiene las auditorias
        Map<Id, Transaccion__c> auditorias = new Map<Id, Transaccion__c>();

        //Recorro las auditorias, solo me quedo con aquellas que tienen una factura
        for(Transaccion__c auditoria : lista){

            // Agrego la entrada al map
            errorsByTransaction.put(auditoria.Id, new List<String>());

            if(auditoria.Factura__c != null){

                //Agrego la auditoria al map
                auditorias.put(auditoria.Id, auditoria);

            }else{    

                //Indico error
                errorsByTransaction.get(auditoria.Id).add(Label.Error_Crear_Nota_de_Credito+' '+Label.Error_Transaccion_Sin_Factura);
            
            }

        }

        //Checkeo que las facturas de las auditorias tengan numero de comprobante
        for(Transaccion__c auditoria : [SELECT Id,Factura__r.N_de_Comprobante__c, Auditoria__c, Subestado__c FROM Transaccion__c WHERE Id IN :auditorias.keySet()]){

            if(auditoria.Factura__r.N_de_Comprobante__c == null){

                if(auditorias.containsKey(auditoria.Id)){

                    //La elimino del map
                    Transaccion__c aud = auditorias.remove(auditoria.Id);

                    //Agrego el error
                    errorsByTransaction.get(aud.Id).add(Label.Error_Crear_Nota_de_Credito+' '+Label.Error_Factura_Sin_Comprobante);
                }

            }

        }

        //Checkeamos si las transacciones no tenian ya una Auditoria Negativa Generada
        for(Transaccion__c auditoria : [SELECT Id, Auditoria__c FROM Transaccion__c WHERE Auditoria__c IN :auditorias.keySet() AND Subestado__c = 'Negativa']){

            if(auditorias.containsKey(auditoria.Auditoria__c)){

                //La elimino del map
                Transaccion__c aud = auditorias.remove(auditoria.Auditoria__c);

            }

        }


        //Set con las auditorias
        Set<Id> idsAUDS = new Set<Id>(auditorias.keySet());


        //Clonamos las transacciones
        
        //Para clonarlas usamos un metodo que trae todos los campos de la transaccion
        String queryTransaccion = Utils.selectByName('Transaccion__c','WHERE Id IN :idsAUDS');

        //Para clonar los item de dup hacemos lo mismo
        String queryItemAuditoria = Utils.selectByName('Item_Auditoria__c','WHERE Auditoria__c IN :idsAUDS');
        
        //Clonamos los item de DUP

        //Map para ordenar los item de auditoria por transaccion
        Map<Id,List<Item_Auditoria__c>> items = new Map<Id,List<Item_Auditoria__c>>();

        for(Item_Auditoria__c item : Database.query(queryItemAuditoria)){

            if(!items.containsKey(item.Auditoria__c)){

                items.put(item.Auditoria__c, new List<Item_Auditoria__c>());

            }

            //Clonamos el Objeto
            Item_Auditoria__c itemCloned = item.clone(false, true);

            //Seteamos en negativo algunos valores
            if(itemCloned.Comision_por_Regalia_Simple__c != null)
                itemCloned.Comision_por_Regalia_Simple__c *=(-1);
            if(itemCloned.Cantidad_Relevada__c != null)
                itemCloned.Cantidad_Relevada__c *=(-1);

            //Agregamos al Map
            items.get(item.Auditoria__c).add(itemCloned);

        }


        //Lista de las transacciones a insertar
        List<Transaccion__c> transToInsert = new List<Transaccion__c>();


        //Clonamos las transacciones
        for(Transaccion__c transaccion : Database.query(queryTransaccion)){

                //Clonamos la transacciones
                Transaccion__c transaccionCloned = transaccion.clone(false, true);

                //Borramos el id externo
                transaccionCloned.Id_Externo__c = null;
                transaccionCloned.Id_Externo_SG__c = null;

                transaccionCloned.Auditoria__c = transaccion.Id;

                transaccionCloned.Cancela_DUP_Original__c = false;
                //transaccionCloned.DUP_Original__c = null;

                transaccionCloned.Estado__c = 'Completa';

                transaccionCloned.Subestado__c = 'Negativa';

                transaccionCloned.Name = null;

                transaccionCloned.Z9_Tipo__c = null;

                transaccionCloned.Factura__c = null;

                transaccionCloned.Saldo_a_Cobrar__c = null;

                transaccionCloned.Fecha_de_Respuesta__c = Date.today();

                //Agregamos a la lista
                transToInsert.add(transaccionCloned);

        }

        List<Item_Auditoria__c> itemsToInsert = new List<Item_Auditoria__c>();

        // Map que contiene la transaccion insertado y su id 
        Map<Id,Transaccion__c> insertedAudById = new Map<Id,Transaccion__c>();

        //Insertamos las transacciones
        if(transToInsert.size() > 0){

            List<Database.SaveResult> svrs = Utils.insertList(transToInsert, false);
            
            // Recorremos los registros en busca de Errores
            for(Integer i = 0 ; i < transToInsert.size() ; i++){

                // Obtenemos la transaccion
                Transaccion__c t = transToInsert.get(i);

                // Obtenemos el SaveResult
                Database.SaveResult svr = svrs.get(i);


                // Verificmamos si ocurrio un error al insertar la transaccion
                if(!svr.isSuccess()){

                    for(Database.Error err : svr.getErrors()) {

                        // Agregamos el error en la Auditoria Positiva
                        errorsByTransaction.get(t.Auditoria__c).add(Label.Error_Generar_NC_Aud_Unable_To_Insert_Aud.replace('{error_message}',err.getMessage()));

                    }

                }else{

                    // La transaccion se creo con exito, procesamos sus items
                    //Agregamos el id al set

                    insertedAudById.put(t.Id, t);

                    if(items.containsKey(t.Auditoria__c)){

                        for(Item_Auditoria__c item : items.get(t.Auditoria__c)){

                            //Seteamos la transaccion
                            item.Auditoria__c = t.Id;

                            //Agregamos a la lista
                            itemsToInsert.add(item);

                        }

                    }

                }

            }

        }

        // Map que contendra las Auditorias negativas que se crearon, pero que deben eliminarse
        // porque ocurrio un error al insertar alguno de sus items
        Map<Id, Transaccion__c> negativeAudsToDelete = new Map<Id, Transaccion__c>();

        if(itemsToInsert.size() > 0){

            List<Database.SaveResult> svrs = Utils.insertList(itemsToInsert, false);
        
            // Revisamos los resultados en busca de errores
            for(Integer i = 0 ; i < itemsToInsert.size() ; i++){

                // Obtenemos el item
                Item_Auditoria__c item = itemsToInsert.get(i);

                // Obtengo el SaveResult
                Database.SaveResult svr = svrs.get(i);

                // Revisamos si ocurrio un error
                if(!svr.isSuccess()){

                    // Obtenemos la transaccion
                    Transaccion__c t = insertedAudById.get(item.Auditoria__c);

                    // Agregamos la auditoria al set
                    negativeAudsToDelete.put(t.Id, t);

                    for(Database.Error err : svr.getErrors()) {

                        // Agregamos el error en la Auditoria Positiva
                        errorsByTransaction.get(t.Auditoria__c).add(Label.Error_Generar_NC_Aud_Unable_To_Insert_Aud_Item.replace('{error_message}',err.getMessage()));

                    }

                }

            }


        }

        // Revisamos si hay Aud a eliminar, y las eliminamos
        if(!negativeAudsToDelete.isEmpty()){

            List<Database.DeleteResult> dlrs = Utils.deleteList(negativeAudsToDelete.values(), false);

        }

        // Agregamos los errores a las transacciones que correspondan
        for(Transaccion__c t: lista){

            // Verificamos si tiene errores
            if(!errorsByTransaction.get(t.Id).isEmpty()){

                // Agregamos el error
                t.addError(String.join(errorsByTransaction.get(t.Id),'\n'));

            }

        }

    }


    /**
    * @author Maximo Martinez
    * @date 25/04/2018
    * @description Metodo que Crea una NC por cada Transaccion que se le pasa
    * @param idsTransacciones : set de ids de transacciones
    */
    public static Map<Id, List<String>> generarNCDUPS(Set<Id> idsTransacciones){
        return generarNCDUPS(idsTransacciones,false);
    }


    /**
    * @author Maximo Martinez
    * @date 24/10/2014
    * @description Metodo que Crea una NC por cada Transaccion que se le pasa
    * @param idsTransacciones : set de ids de transacciones
    */
    public static Map<Id, List<String>> generarNCDUPS(Set<Id> idsTransacciones, Boolean deleteMinisiteData){

        Id rtDup = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        Id rtAud = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('Auditorias');
            
        // Map con los resultados de la operacion
        Map<Id, List<String>> errorsByTransaction = new Map<Id, List<String>>();

        //Clonamos las transacciones
        
        //Para clonarlas usamos un metodo que trae todos los campos de la transaccion
        String queryTransaccion = Utils.selectByName('Transaccion__c','WHERE Id IN :idsTransacciones');

        //Para clonar los item de dup hacemos lo mismo
        String queryItemDeDUP = Utils.selectByName('Item_de_DUP__c','WHERE Transaccion__c IN :idsTransacciones');

        String queryItemDeAUD = Utils.selectByName('Item_Auditoria__c','WHERE Auditoria__c IN :idsTransacciones');
        
        //Clonamos los item de DUP

        //Map para ordenar los item de dup por transaccion
        Map<Id,List<SObject>> items = new Map<Id,List<SObject>>();

        for(Item_de_DUP__c item : (List<Item_de_DUP__c>)Database.query(queryItemDeDUP)){

            if(!items.containsKey(item.Transaccion__c)){

                items.put(item.Transaccion__c, new List<Item_de_DUP__c>());

            }

            //Clonamos el Objeto
            Item_de_DUP__c itemCloned = item.clone(false, true);

            //Seteamos en negativo algunos valores
            if(itemCloned.Comision_por_Regalia_Simple__c != null){
                itemCloned.Comision_por_Regalia_Simple__c *=(-1);
            }
            
            if(itemCloned.Cantidad_Declarada__c != null){
                itemCloned.Cantidad_Declarada__c *=(-1);
            }

            if(deleteMinisiteData){
                itemCloned.Cantidad_Declarada__c = null;
                itemCloned.Hectareas_Declaradas__c = null;
                itemCloned.Variedad_Agregada_Manualmente__c = false;
            }

            itemCloned.Z9_DUP_Origen__c = null;

            //Agregamos al Map
            items.get(item.Transaccion__c).add(itemCloned);

        }


        for(Item_Auditoria__c item : (List<Item_Auditoria__c>)Database.query(queryItemDeAUD)){

            if(!items.containsKey(item.Auditoria__c)){

                items.put(item.Auditoria__c, new List<SObject>());

            }

            //Clonamos el Objeto
            Item_Auditoria__c itemCloned = item.clone(false, true);

            //Seteamos en negativo algunos valores
            if(itemCloned.Comision_por_Regalia_Simple__c != null){
                itemCloned.Comision_por_Regalia_Simple__c *=(-1);
            }
            
            if(itemCloned.Cantidad_Relevada__c != null){
                itemCloned.Cantidad_Relevada__c *=(-1);
            }

            //itemCloned.Z9_DUP_Origen__c = null;

            //Agregamos al Map
            items.get(item.Auditoria__c).add(itemCloned);

        }


        //Clonamos las transacciones

        //Lista de las transacciones a insertar
        List<Transaccion__c> transToInsert = new List<Transaccion__c>();

        for(Transaccion__c transaccion : Database.query(queryTransaccion)){

            if(transaccion.RecordTypeId != rtAud && transaccion.RecordTypeId != rtDup){
                continue;
            }   

            // Instanciamos el Map
            errorsByTransaction.put(transaccion.Id, new List<String>());

            //Clonamos la transacciones
            Transaccion__c transaccionCloned = transaccion.clone(false, true);

            if(transaccion.RecordTypeId == rtAud){
                
                transaccionCloned.Auditoria__c = transaccion.Id;

            }else{

                //Seteamos la Transacciones Original
                transaccionCloned.DUP_Original__c = transaccion.Id;
            
            }

            //Seteamos su estado como negativo
            transaccionCloned.Subestado__c = 'Negativa';

            //Borramos el los ids externos
            transaccionCloned.Id_Externo__c = null;

            transaccionCloned.Id_Externo_SG__c = null;

            

            //Borramos el Name
            transaccionCloned.Name = null;

            transaccionCloned.Z9_Tipo__c = null;

            transaccionCloned.Factura__c = null;

            transaccionCloned.Nro_Comprobante__c = null;

            transaccionCloned.Saldo_a_Cobrar__c = null;

            if(deleteMinisiteData){
                transaccionCloned.Respondida_via_Minisitio__c = false;
                transaccionCloned.Resultado_Validacion_Analista__c = null;
                transaccionCloned.Cargada_via_Minisitio__c = false;
                transaccionCloned.Apellido_y_Nombre__c = null;
                transaccionCloned.Tipo_de_Documento__c = null;
                transaccionCloned.Numero_de_Documento__c = null;
            }

            transaccionCloned.Fecha_de_Respuesta__c = Date.today();

            //Agregamos a la lista
            transToInsert.add(transaccionCloned);

        }

        //Lista de items a insertar
        List<SObject> itemsToInsert = new List<SObject>();

        // Map que contiene la transaccion insertado y su id 
        Map<Id,Transaccion__c> insertedAudById = new Map<Id,Transaccion__c>();

        //Insertamos las transacciones
        if(transToInsert.size() > 0){

            List<Database.SaveResult> svrs = Utils.insertList(transToInsert, false);

            // Recorremos los registros en busca de Errores
            for(Integer i = 0 ; i < transToInsert.size() ; i++){

                // Obtenemos la transaccion
                Transaccion__c t = transToInsert.get(i);

                // Obtenemos el SaveResult
                Database.SaveResult svr = svrs.get(i);

                Id idTransaccionCloned = (String.isNotEmpty(t.DUP_Original__c))?t.DUP_Original__c:t.Auditoria__c;

                // Verificmamos si ocurrio un error al insertar la transaccion
                if(!svr.isSuccess()){

                    for(Database.Error err : svr.getErrors()) {

                        // Agregamos el error en la Auditoria Positiva
                        errorsByTransaction.get(idTransaccionCloned).add(err.getMessage());

                    }

                }else{

                    // La transaccion se creo con exito, procesamos sus items
                    //Agregamos el id al set

                    insertedAudById.put(t.Id, t);

                    if(items.containsKey(idTransaccionCloned)){

                        for(SObject item : items.get(idTransaccionCloned)){

                            if(item instanceof Item_de_DUP__c){
                                //Seteamos la transaccion
                                item.put('Transaccion__c',t.Id);
                            }else{
                                item.put('Auditoria__c',t.Id);
                            }

                            //Agregamos a la lista
                            itemsToInsert.add(item);

                        }

                    }

                }

            }


        }


        // Map que contendra las Auditorias negativas que se crearon, pero que deben eliminarse
        // porque ocurrio un error al insertar alguno de sus items
        Map<Id, Transaccion__c> negativeNCToDelete = new Map<Id, Transaccion__c>();

        if(itemsToInsert.size() > 0){

            List<Database.SaveResult> svrs = Utils.insertList(itemsToInsert, false);
        
            // Revisamos los resultados en busca de errores
            for(Integer i = 0 ; i < itemsToInsert.size() ; i++){

                // Obtenemos el item
                SObject item = itemsToInsert.get(i);

                // Obtengo el SaveResult
                Database.SaveResult svr = svrs.get(i);

                // Revisamos si ocurrio un error
                if(!svr.isSuccess()){

                    Id idTransaccion = String.valueOf((item instanceof Item_de_DUP__c)?item.get('Transaccion__c'):item.get('Auditoria__c'));

                    // Obtenemos la transaccion
                    Transaccion__c t = insertedAudById.get(idTransaccion);

                    Id idTransaccionCloned = (String.isNotEmpty(t.DUP_Original__c))?t.DUP_Original__c:t.Auditoria__c;

                    // Agregamos la auditoria al set
                    negativeNCToDelete.put(t.Id, t);

                    for(Database.Error err : svr.getErrors()) {

                        // Agregamos el error en la Auditoria Positiva
                        errorsByTransaction.get(idTransaccionCloned).add(err.getMessage());

                    }

                }

            }


        }

        // Revisamos si hay NC a eliminar, y las eliminamos
        if(!negativeNCToDelete.isEmpty()){

            List<Database.DeleteResult> dlrs = Utils.deleteList(negativeNCToDelete.values(), false);

        }

        return errorsByTransaction;

    }

    /**
    * @author Maximo Martinez
    * @date 12/09/2014
    * @description Clase Auxiliar del Objecto Transaccion__c
    */
    public static void cancelarDups(List<Transaccion__c> lista){


        //Map que vinculara la transaccion a cancelar con la Auditoria que la cancela
        Map<Id, Id> transacciones = new Map<Id, Id>();

        //Recorremos las Auditorias
        for(Transaccion__c auditoria : lista){

            transacciones.put(auditoria.DUP_Original__c, auditoria.Id);

        }

        //Lista que contendra las transacciones a actualizar
        List<Transaccion__c> transaccionesToUpdate = new List<Transaccion__c>();

        //Lista que contendra los item de las transacciones a actualizar
        List<Item_de_DUP__c> itemsToUpdate = new List<Item_de_DUP__c>();

        //Consultamos por las DUPS y sus item de DUPS
        for(Transaccion__c transaccion : [SELECT Id, (SELECT Id From Item_de_DUP__r) FROM Transaccion__c WHERE Id IN :transacciones.keySet()]){

            //Verificamos si la entrada esta en el map
            if(transacciones.containsKey(transaccion.Id)){

                //Obtenemos el id de la auditoria
                Id idAuditoria = transacciones.get(transaccion.Id);

                //Pasamos el estado de la DUP "Cancelada por Auditoría"
                transaccion.Estado__c = 'Cancelada por Auditoría';

                //Seteamos la auditoria que la cancela
                transaccion.Auditoria__c = idAuditoria;

                //Recorremos sus items
                for(Item_de_DUP__c item : transaccion.Item_de_DUP__r){

                    item.Estado__c = 'Cancelada por Auditoría';
                    item.Cantidad_Declarada__c = 0;

                    //Agregamos a la lista de items a actualizar
                    itemsToUpdate.add(item);

                }

                //Agregamos a la lista de transacciones a actualizar
                transaccionesToUpdate.add(transaccion);

            }

        }  

        if(transaccionesToUpdate.size() > 0)
            Utils.updateList(transaccionesToUpdate);

        if(itemsToUpdate.size() > 0)
            Utils.updateList(itemsToUpdate);      

    }

    //Metodo que a partir de un set de Transacciones cambia el Estado de las mismas
    public static void cambiarEstado(Set<Id> idsTransacciones, String nuevoEstado){
        
        //Instanciamos una lista para las Transacciones que vamos a actualizar
        List<Transaccion__c> transaccionesToUpdate = new List<Transaccion__c>();
        for(Transaccion__c transaccion : [SELECT Id, Estado__c FROM Transaccion__c WHERE Id IN :idsTransacciones]){
            
            //Cambiamos el Estado de la Transaccion
            transaccion.Estado__c = nuevoEstado;
            
            //Agregamos la transacciones a la lista de Transacciones a Actualizar
            transaccionesToUpdate.add(transaccion);
        }
        
        if(transaccionesToUpdate.size() > 0 ){
            Utils.updateList(transaccionesToUpdate);
        }
    }

    /**
     * Replica la rama "Facturada" / Actualiza Transacción del proceso Sincroniza_Estado_Opp_y_TRX_V5:
     * al pasar la oportunidad a Facturada (o crearla ya en Facturada), sincroniza la TRX vinculada.
     * Se usa en el trigger para cubrir casos donde el PB no vuelve a ejecutar la acción (Previously Met u otro orden).
     */
    public static void sincronizarTransaccionDesdeOppFacturada(List<Opportunity> nuevas, Map<Id, Opportunity> viejasPorId) {
        List<Transaccion__c> transaccionesToUpdate = new List<Transaccion__c>();
        for (Opportunity opp : nuevas) {
            if (opp.Transaccion__c == null || opp.StageName != 'Facturada') {
                continue;
            }
            if (viejasPorId != null) {
                Opportunity oldOpp = viejasPorId.get(opp.Id);
                if (oldOpp != null && oldOpp.StageName == 'Facturada') {
                    continue;
                }
            }
            Transaccion__c trx = new Transaccion__c(
                Id = opp.Transaccion__c,
                Estado_ERP__c = 'SENT',
                Estado__c = opp.StageName,
                Z9_Cambio__c = false
            );
            transaccionesToUpdate.add(trx);
        }
        if (!transaccionesToUpdate.isEmpty()) {
            Utils.updateList(transaccionesToUpdate);
        }
    }
    
    //Metodo que asigna el tipo de cambio a una transaccion negativa a partir del tipo de cambio de su transaccion asociada
    public static void asignaTipoCambioTransaccionNegativa(Set<Id> idsTransacciones){
        
        //Set que contendra los ids de las transacciones positivas 
        Set<Id> idsPositivas = new Set<Id>();
        
        //Recorremos las transacciones negativas y obtenemos sus transacciones asociadas
        for(Transaccion__c transaccion : [SELECT Id ,DUP_Original__c FROM Transaccion__c WHERE Id IN :idsTransacciones]){
            idsPositivas.add(transaccion.DUP_Original__c);
        }
        
        //Map que contendra el id de la transaccion y el tipo de cambio
        Map<Id,Double> tipoCambioById = new Map<Id,Double>();
        
        //Recorremos las transacciones (positivas) y completamos el map
        for(Transaccion__c transaccion : [SELECT Id, Tipo_de_Cambio__c FROM Transaccion__c WHERE Id IN :idsPositivas]){
            tipoCambioById.put(transaccion.Id, transaccion.Tipo_de_Cambio__c);
        }
        
        //Lista que contendra las transacciones a actualizar
        List<Transaccion__c> transaccionesToUpdate = new List<Transaccion__c>();
        
        //Recorremos nuevamente las transacciones negativas y asociamos el tipo de cambio
        for(Transaccion__c transaccion : [SELECT Id ,DUP_Original__c FROM Transaccion__c WHERE Id IN :idsTransacciones]){
            if(tipoCambioById.containsKey(transaccion.DUP_Original__c)){
                Double tipoCambio = tipoCambioById.get(transaccion.DUP_Original__c);
                transaccion.Tipo_de_Cambio__c = tipoCambio;
                transaccionesToUpdate.add(transaccion);
            }
        }
        
        //Si hay transacciones para actualizar, llamamos al metodo de insercion por lotes
        if(transaccionesToUpdate.size() > 0){
            Utils.updateList(transaccionesToUpdate);
        }
    }

    /**
    * @author Maximo Martinez
    * @date 19/12/2017
    * @description Metodo que envia un email con el pdf de la dup adjunto
    */ 
    public static void envioDeDUPPorMail(List<Transaccion__c> transacciones, Map<Id,Transaccion__c> oldMap){
        if (System.isBatch() || System.isFuture()) return;

        Set<Id> idsTransacciones = new Set<Id>();
        Set<Id> idsAccounts = new Set<Id>();

        for(Transaccion__c t : transacciones){

            if( (oldMap == null && t.Resultado_Validacion_Analista__c == 'Positiva') || (oldMap!=null && t.Resultado_Validacion_Analista__c == 'Positiva' && t.Resultado_Validacion_Analista__c != oldMap.get(t.Id).Resultado_Validacion_Analista__c) ){

                idsTransacciones.add(t.Id);
                idsAccounts.add(t.Nombre_de_la_cuenta__c);
            
            }

        }

        // Llamamos al future method, ya que la llamada que renderiza el PDF no puede hacerse sincronicamente
        if(!idsTransacciones.isEmpty()){
            envioDeDUPPorMail(idsTransacciones,idsAccounts);
        }

    }

    /**
    * @author Maximo Martinez
    * @date 19/12/2017
    * @description Metodo que envia un email con el pdf de la dup adjunto
    */ 
    @future(callout=true)
    public static void envioDeDUPPorMail(Set<Id> idsDups, Set<Id> idsAccounts){

        // Lista con los emails a enviar en este lote
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        // Map de Errores, por Transaccion
        List<String> errors = new List<String>();

        List<Transaccion__c> transaccionesToSend = new List<Transaccion__c>();

        Map<String, OrgWideEmailAddress> orgWideEmails = new Map<String,OrgWideEmailAddress>(); 

        for(OrgWideEmailAddress orgWideEmail : [SELECT Id,Address FROM OrgWideEmailAddress]){

            orgWideEmails.put(orgWideEmail.Address, orgWideEmail);

        }

        for(Account a : [SELECT Id, Operador__r.Email, (SELECT Id, Name, Campana__r.Template_Envio_de_DUP__c FROM Transacciones__r WHERE Id IN :idsDups), (SELECT Id FROM Contacts WHERE Contacto_Remesa__c = true LIMIT 1) FROM Account WHERE Id IN :idsAccounts]){

            if(a.Contacts.size() == 0){
                continue;
            }

            for(Transaccion__c t : a.Transacciones__r){

                // Generamos la URL
                PageReference pdfPage = Page.dupPDF;
                
                // Seteamos el Id
                pdfPage.getParameters().put('transaccionId',t.Id);
                pdfPage.getParameters().put('validacionAnalista','true');

                Blob pdfBody;

                // Intentamos obtener el contenido, puede dar error
                try{
                
                    pdfBody = (Test.isRunningTest())?Blob.valueOf('test'):pdfPage.getContentAsPDF();
                
                }catch(Exception e){
                    
                    System.debug(LoggingLevel.WARN,e.getMessage());

                }  

                Messaging.Emailfileattachment efa = new Messaging.Emailfileattachment();
                efa.setFileName(t.Name+'.pdf');
                efa.setBody(pdfBody);

                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setTargetObjectId(a.Contacts[0].Id);
                msg.setTemplateId(t.Campana__r.Template_Envio_de_DUP__c);
                msg.setFileAttachments(new List<Messaging.Emailfileattachment>{efa});
                msg.setUseSignature(false);
                msg.setSaveAsActivity(true);
                msg.setWhatId(t.Id);  
                
                if(orgWideEmails.containsKey(a.Operador__r.Email)){
                    msg.setOrgWideEmailAddressId(orgWideEmails.get(a.Operador__r.Email).Id);
                }

                emailsToSend.add(msg);

                transaccionesToSend.add(t);

            }

        }

        System.debug(LoggingLevel.WARN, emailsToSend);

        if (!emailsToSend.isEmpty()) {
        
            // Enviamos los emails
            List<Messaging.SendEmailResult> emailsResult = (Test.isRunningTest()) ? new List<Messaging.SendEmailResult>{null} : Messaging.sendEmail(emailsToSend, false);
            
            Integer i = 0;



            // Verificamos si ocurrio un error
            for (Messaging.SendEmailResult ser: emailsResult) {

                //Verificamos si ocurrio un error
                if (!ser.isSuccess()) {

                    Transaccion__c t = transaccionesToSend[i];

                    errors.add(String.format('Error al enviar Email DUP Transaccion {0}. Error {1}',new List<String>{t.Name,ser.getErrors()[0].getMessage()}));
                    
                }

                i++;

            }
        }

        if(!errors.isEmpty() || Test.isRunningTest()){

            String msg = String.join(errors,'\n');

            System.debug(LoggingLevel.WARN,msg);

            // Enviamos email al usuario con los errores
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTargetObjectId(UserInfo.getUserID());
            mail.setSubject('Errores Enviando Email DUPs');
            mail.setPlainTextBody(msg);
            mail.setSaveAsActivity(false);
            if(!Test.isRunningTest()){
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }


        }

    }

}