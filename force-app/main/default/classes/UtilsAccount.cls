/**
* @author Maximo Martinez
* @date 05/06/2014
* @description Clase con diferentes metodos auxiliares para el objeto Account
*/ 
public with sharing class UtilsAccount{
    
    /**
    * @author Maximo Martinez
    * @date 5/06/2014
    * @description Metodo encargado de mantener actualizado el Contacto Remesa
    */ 
    public static void gestionarContactoRemesa(List<WrapperAccountEmail> lista){
        /*
        Map<Id, List<String>> errores = new Map<Id, List<String>>();

        //Obtengo los ids de las cuentas
        Map<Id, WrapperAccountEmail> groupedAccounts = new Map<Id, WrapperAccountEmail>();
       
        for(WrapperAccountEmail wae: lista){
           
          groupedAccounts.put(wae.account.Id, wae);

          errores.put(wae.account.Id, new List<String>());
           
        }

        System.debug(LoggingLevel.WARN, groupedAccounts.size());
       
       //Recorremos los contactos
       
       //Lista de contactos a crear
       List<Contact> toUpdate = new List<Contact>();
       
       //Lista de contactos a insertar
       List<Contact> toInsert = new List<Contact>();
        
       //Lista de contactos a eliminar
       List<Contact> toDelete = new List<Contact>();
       
       for(Account cuenta : [SELECT Id, Direccion_de_Correo_electronico_del_CUIT__c, (SELECT Id,AccountId,Email,Contacto_Remesa__c,Name FROM Contacts WHERE Contacto_Remesa__c = true) FROM Account WHERE Id IN :groupedAccounts.keySet()]){
            
            System.debug(LoggingLevel.ERROR, cuenta.Contacts);

            // Si la cuenta no esta en el map proceso la siguiente
            if(!groupedAccounts.containsKey(cuenta.Id)){
                continue;
            }

            // Obtengo el Wrapper
            WrapperAccountEmail wae = groupedAccounts.get(cuenta.Id);

            // Recorrer los contactos y almacenar los de igual email
            List<Contact> equalOldEmail = new List<Contact>();

            List<Contact> equalNewEmail = new List<Contact>();

            for(Contact c : cuenta.Contacts){

                // Recorro los contactos y los clasifico segun su email 
                if(wae.oldEmail == c.Email){

                    // Si el email cambio seteo el nuevo email
                    c.Email = cuenta.Direccion_de_Correo_electronico_del_CUIT__c;

                    equalOldEmail.add(c);

                }else if(cuenta.Direccion_de_Correo_electronico_del_CUIT__c == c.Email){ 

                    // Coleccionamos los contactos que tienen el mismo email
                    equalNewEmail.add(c);

                }

            }

            if(!equalOldEmail.isEmpty()){
                
                // Si el email se borro, entonces los contactos los elimino
                if(String.isEmpty(cuenta.Direccion_de_Correo_electronico_del_CUIT__c)){
                    toDelete.addAll(equalOldEmail);
                }else{
                    toUpdate.addAll(equalOldEmail);
                }

            }else if(equalNewEmail.isEmpty()){ // Si no hay contactos con el email en la cuenta creo un contacto

                System.debug(LoggingLevel.ERROR, cuenta.Direccion_de_Correo_electronico_del_CUIT__c);
                System.debug(LoggingLevel.ERROR, wae.oldEmail);

                if(String.isNotEmpty(cuenta.Direccion_de_Correo_electronico_del_CUIT__c)){
                    
                    //No tiene un contacto de remesa lo creo
                    Contact contacto = new Contact();
                   
                    //Seteamos algunos datos
                    contacto.Email = cuenta.Direccion_de_Correo_electronico_del_CUIT__c;
                    contacto.FirstName = 'Contacto';
                    contacto.LastName = 'Remesa';
                    contacto.Contacto_Remesa__c = true;
                    contacto.AccountId = cuenta.Id;
                   
                    //Agregamos a la lista de contactos
                    toInsert.add(contacto);
                }

            }
           
        }
       
        //Llamamos al metodo de insercion por lotes
        if(toInsert.size() > 0){
            
            List<Database.SaveResult> svr = Utils.insertList(toInsert,false);

            for(Integer i = 0 ; i < svr.size() ; i++ ){

                Database.SaveResult sv = svr[i];

                if(!sv.isSuccess()){

                    Contact c = toInsert[i];

                    for(Database.Error er : sv.getErrors()) {
                        
                        if(errores.containsKey(c.AccountId)){

                            errores.get(c.AccountId).add(er.getMessage());

                        }

                    }

                }

            }   

        }

        //Llamamos al metodo de actualizacion por lotes
        if(toUpdate.size() > 0){

            List<Database.SaveResult> svr = Utils.updateList(toUpdate,false);

            for(Integer i = 0 ; i < svr.size() ; i++ ){

                Database.SaveResult sv = svr[i];

                if(!sv.isSuccess()){

                    Contact c = toUpdate[i];

                    for(Database.Error er : sv.getErrors()) {
                        
                        if(errores.containsKey(c.AccountId)){

                            errores.get(c.AccountId).add(er.getMessage());

                        }

                    }

                }

            }

        }

        if(!toDelete.isEmpty()){

            List<Database.DeleteResult> svr = Utils.deleteList(toDelete,false);

            for(Integer i = 0 ; i < svr.size() ; i++ ){

                Database.DeleteResult sv = svr[i];

                if(!sv.isSuccess()){

                    Contact c = toDelete[i];

                    for(Database.Error er : sv.getErrors()) {
                        
                        if(errores.containsKey(c.AccountId)){

                            errores.get(c.AccountId).add(er.getMessage());

                        }

                    }

                }

            }    
        }

        // Recorremos los errores
        for(Id accountId : errores.keySet()){

            // Si hay errores continuo
            if(errores.get(accountId).isEmpty()){
                continue;
            }

            String message = String.join(errores.get(accountId), '\n');

            if(groupedAccounts.containsKey(accountId)){

                WrapperAccountEmail wp = groupedAccounts.get(accountId);

                wp.account.Direccion_de_Correo_electronico_del_CUIT__c.addError(message);

            }

        }
        */
    }
    
    /**
    * @author Maximo Martinez
    * @date 8/07/2014
    * @description Metodo encargado de setear las prioridades de las cuentas a partir de las interacciones
    */ 
    public static void setearPrioridades(List<Interaccion__c> lista){
        
        /**Obtenemos los tipos de registro de los casos Gestion de Venta y Gestion de CUIT**/
        Id rtGCId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');
        
        Id rtGVId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_Venta');
        
        /**Recorremos las interacciones y vamos armando los wrappers**/
        
        //Set para coleccionar los ids de los casos
        Set<Id> idsCasos = new Set<Id>();
        
        for(Interaccion__c i : lista){
          
          idsCasos.add(i.Caso__c);
            
        }
        
        
        /**Obtengo los casos, y de esta manera obtengo la cuenta asociada a los mismos**/
        
        //Map para agruparpor cuenta los tipos de casos
        Map<Id,Set<Id>> cuentas = new Map<Id,Set<Id>>();
        
        for(Case c : [SELECT Id, AccountId, RecordTypeId FROM Case WHERE Id IN :idsCasos AND (RecordTypeId = :rtGCId OR RecordTypeId = :rtGVId)]){
            
            //Si no esta creada la entrada al ma, la creamos
            if(!cuentas.containsKey(c.AccountId)){
                
                //Creamos la entrada
                cuentas.put(c.AccountId,new Set<Id>());
                
            }
            
            //Obtenemos el set de tipos de casos
            Set<Id> tipos = cuentas.get(c.AccountId);
            
            //Agrego el tipo de casos al set de tipos
            tipos.add(c.RecordTypeId);
            
        }
        
        
        /**Obtengo las cuentas segun los casos que recorri**/
        
        //Lista de cuentas a actualizar
        List<Account> toUpdate = new List<Account>();
        
        for(Account a : [SELECT Id, Prioridad_Cobranzas_Original__c,Prioridad_Cobranzas_Recalculada__c,Prioridad_DUP_Invierno_Original__c,Prioridad_DUP_Invierno_Recalculada__c,Prioridad_DUP_Verano_Original__c,Prioridad_DUP_Verano_Recalculada__c, Prioridad_Venta_Invierno_Original__c, Prioridad_Venta_Invierno_Recalculada__c, Prioridad_Venta_Verano_Original__c,Prioridad_Venta_Verano_Recalculada__c FROM Account WHERE Id IN : cuentas.keySet()]){
            
            //Si la entrada esta en el map
            if(cuentas.containsKey(a.id)){
                
                //Obtenemos los tipos de caso, que se registraron para esa cuenta, segun las interaccion que dispararon,
                //el procesamiento
                Set<Id> tipos = cuentas.get(a.Id);
                
                if(tipos.contains(rtGCId) || tipos.contains(rtGVId)){
                
                    //Si se registro que hay casos de tipo gestion de cuit
                    if(tipos.contains(rtGCId)){
                        
                        //Actualizamos los campos correspondientes
                        a.Prioridad_Cobranzas_Original__c = 999999;
                        a.Prioridad_Cobranzas_Recalculada__c = 999999;
                        a.Prioridad_DUP_Invierno_Original__c = 999999;
                        a.Prioridad_DUP_Invierno_Recalculada__c = 999999;
                        a.Prioridad_DUP_Verano_Original__c = 999999;
                        a.Prioridad_DUP_Verano_Recalculada__c = 999999;
                        
                    }
                    
                    //Si se registro que hay casos de tipo gestion de venta
                    if(tipos.contains(rtGVId)){
                        
                        a.Prioridad_Venta_Invierno_Original__c = 999999;
                        a.Prioridad_Venta_Invierno_Recalculada__c = 999999;
                        a.Prioridad_Venta_Verano_Original__c = 999999;
                        a.Prioridad_Venta_Verano_Recalculada__c = 999999;
                        
                    }
                
                    //Agregamos la cuenta a la lista de cuentas a actualizar
                    toUpdate.add(a);
                    
                }
            }
            
        }
        
        
        //Actualizamos las cuentas
        if(toUpdate.size() > 0){
            
            Utils.updateList(toUpdate);
            
        }
                
        
    }

    /**
    * @author Maximo Martinez
    * @date 06/08/2014
    * @description Metodo de Insercion por lotes Parciales, es decir si un registro falla, intenta con el que le sigue
    */ 
    public static List<Database.SaveResult> insertPartialList(List<Account> lista){
        return Database.insert(lista,false);
    }

    public static String getExclusionDay(Date d, SobjectField field) {
        //Obtenemos el Descriptor del Campo
        Schema.DescribeFieldResult fieldResult = field.getDescribe();

        //Obtenemos los valores de la pick list
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();

        Integer i = 0;

        //Recorremos los valores del picklist y armamos las opciones
        while( i<ple.size() && !(ple[i].isActive() && Integer.valueOf(ple[i].getValue()) == d.day())){
            i++;
        }       

        if(i<ple.size() && ple[i].isActive() && Integer.valueOf(ple[i].getValue()) == d.day()){
            return ple[i].getValue();
        }else{
            return '';
        }
    }

    /**
    * @author Maximo Martinez
    * @date 26/11/2015
    * @description Metodo auxiliar que retorna el dia de exclusion en un formato valido
    */
    public static String getExclusionDay(Date d){
        return getExclusionDay(d, Account.Dias_de_Exclusion_de_Facturacion__c);
    }
    
    public static String getCuitCorteva(){
        return Sembra_Evolucion__c.getOrgDefaults().Corteva_30_Cuit__c;
    }

    /**
    * @author Maximo Martinez
    * @date 18/11/2015
    * @description Clase Auxiliar para Almacenar una Cuenta y sus correspondientes emails
    */
    public class WrapperAccountEmail {
        
        public Account account {get; set;}
        public String oldEmail {get; set;}

        public WrapperAccountEmail(Account account, String oldEmail){
            this.account = account;
            this.oldEmail = oldEmail;
        }

    }
    
}