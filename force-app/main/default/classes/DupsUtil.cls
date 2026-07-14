public without sharing class DupsUtil{

    private Map<String, Transaccion__c> mapTransaciones;
    private Map<String, Remesa__c> mapRemesas;
    private Map<String, Set<ID>> mapObtentorProductos;
    private Map<String, List<Contact>> mapContactos;
    private Set<String> destinatarios;
    private Set<String> cultivos;
    private Set<String> obtentores;
    private String rtTransaccionDUP;
    
    public DupsUtil(){
        mapTransaciones = new Map<String, Transaccion__c>();
        mapRemesas = new Map<String, Remesa__c>();
        mapObtentorProductos= new Map<String, Set<ID>>();
        mapContactos= new Map<String, List<Contact>>();
        destinatarios = new Set<String>();
        cultivos = new Set<String>();
        obtentores = new Set<String>();
        rtTransaccionDUP = RecordTypeTool.getRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        System.debug(LoggingLevel.INFO, 'rtTransaccionDUP: ' + rtTransaccionDUP); 
    }
    /**
    public void inicializarDatos(Lote__c lote){
        List<Transaccion__c> transacciones = [SELECT Nombre_de_la_cuenta__c, Cultivo__c, Campana__c, Obtentor__c, (SELECT Producto__c FROM Item_de_DUP__r) FROM Transaccion__c WHERE Lote__c = :lote.ID];
        Set<String> cuentasIds = new Set<String>();
        String keyObtentor;
        for(Transaccion__c t : transacciones){
            String key = String.valueOf(t.Nombre_de_la_cuenta__c) + String.valueOf(t.Cultivo__c) + String.valueOf(t.Campana__c) + String.valueOf(t.Obtentor__c);
            mapTransaciones.put(key, t);
            keyObtentor = ''+t.Nombre_de_la_cuenta__c+t.Obtentor__c;
            if(!mapObtentorProductos.containsKey(keyObtentor)){
                mapObtentorProductos.put(keyObtentor, new Set<ID>());
            }
            for(Item_de_DUP__c i : t.Item_de_DUP__r){
                mapObtentorProductos.get(keyObtentor).add(i.Producto__c);
            }
            cuentasIds.add(t.Nombre_de_la_cuenta__c);
        }
        if(!cuentasIds.isEmpty()){
            for(Contact c : [SELECT ID, AccountID FROM Contact WHERE AccountID IN :cuentasIds AND Contacto_Remesa__c = true]){
                mapContactos.put(c.AccountID, c);
            }
        }
        List<Remesa__c> remesas = [SELECT Productor__c FROM Remesa__c WHERE Lote__c = :lote.ID];
        for(Remesa__c r : remesas){
            String key = String.valueOf(r.Productor__c);
            mapRemesas.put(key, r);
        }
    }
    **/
    public void dupsVentas(List<Venta__c> ventas, Lote__c lote) {
        armaSetsVentas(ventas);
        
        armaMaps(lote);
    
        List<Remesa__c> remesasNuevas = new List<Remesa__c>();

        List<WrapperContactoRemesa> wrappers = new List<WrapperContactoRemesa>();

        Map<String, ID> mapVariedadesRegalias = new Map<String, ID>();
        List<String> origenIds = new List<String>();
        List<Transaccion__c> transaccionesNuevas = new List<Transaccion__c>();
        Database.SaveResult[] lins;
        
        for(Product2 p : [SELECT ID, Variedad__c FROM Product2 WHERE Family = 'Regalía Extendida' AND IsActive = true]){
            mapVariedadesRegalias.put(p.Variedad__c, p.ID);
        }
        Set<String> cuentasIds = new Set<String>();
        Integer idExterno = 0;
        //String keyObtentor;
        for(Venta__c v : ventas){
            String key = String.valueOf(v.Destinatario__c) + String.valueOf(v.Cultivo__c) + String.valueOf(lote.Campana__c) + String.valueOf(v.Producto__r.Obtentor_Comercializa__c);
            if(!mapTransaciones.containsKey(key)){

                // Si corremos en contexto de Batch
                if(System.isBatch() && v.Destinatario__r.No_Generar_DUP__c)
                    continue;

                Transaccion__c t = new Transaccion__c ();
                t.Nombre_de_la_cuenta__c = v.Destinatario__c;
                t.Cultivo__c = v.Cultivo__c;
                t.Campana__c = lote.Campana__c;
                t.Obtentor__c = v.Producto__r.Obtentor_Comercializa__c;
                t.Lote__c = lote.ID;
                t.RecordTypeID = rtTransaccionDUP ;
                t.Id_Externo__c = '' + idExterno;
                t.Name = '' + idExterno;
                mapTransaciones.put(key, t);
                transaccionesNuevas.add(t);
                origenIds.add(v.ID);
                cuentasIds.add(v.Destinatario__c);
                idExterno++;


            }
        }
        if(!cuentasIds.isEmpty()){

            // Recorremos las cuentas y sus contactos
            for(Account a : [SELECT Id, (SELECT Id, Name FROM Contacts WHERE Contacto_Remesa__c = true) FROM Account WHERE Id IN :cuentasIds]){

                if(!mapContactos.containsKey(a.Id)){
                    mapContactos.put(a.Id, a.Contacts);    
                }

            }

        }

        List<Log__c> logs = new List<Log__c>();
        Set<String> transaccionesIdsUpdate = new Set<String>();
        if(!transaccionesNuevas.isEmpty()){
            lins = Database.insert(transaccionesNuevas, false);
            for(Integer i = 0; i < lins.size(); i++){
                Database.SaveResult ins = lins[i];
                if(!ins.isSuccess()){
                    List<Database.Error> errors = ins.getErrors(); 
                    String errores = '';
                    for(Database.Error e : errors){
                        errores += e.getMessage() + '\n';
                    }
                    Log__c log = new Log__c();
                    log.ID_Registro_Origen__c = origenIds.get(i);
                    log.Lote__c = lote.ID;
                    log.Errores__c = 'Transacción: ' + errores;
                    logs.add(log);
                } else {
                    Transaccion__c t = transaccionesNuevas.get(i);
                    if(!mapRemesas.containsKey(t.Nombre_de_la_cuenta__c)){
                        Remesa__c r = new Remesa__c();
                        r.Productor__c = t.Nombre_de_la_cuenta__c;
                        r.Lote__c = lote.ID;
                        
                        //r.Contacto__c = mapContactos.get(t.Nombre_de_la_cuenta__c) != null ? mapContactos.get(t.Nombre_de_la_cuenta__c).ID : null;
                            

                        // Revisamos si tenemos que crear un contacto remesa
                        if(mapContactos.containsKey(t.Nombre_de_la_cuenta__c)){

                            // Obtenemos la lista Contactos
                            List<Contact> cs = mapContactos.get(t.Nombre_de_la_cuenta__c);
                            
                            for(Contact c : cs){      

                                // Instanciamos un Wrapper Remesa
                                WrapperContactoRemesa wcr = new WrapperContactoRemesa();

                                wcr.remesa = r;

                                wcr.contacto = new Contacto_Remesa__c();

                                wcr.contacto.Name = c.Name;

                                wcr.contacto.Contacto__c = c.Id;

                                // Agregamos el wrapper a la lista de wrappers
                                wrappers.add(wcr);

                            }

                        }

                        mapRemesas.put(t.Nombre_de_la_cuenta__c, r);
                        remesasNuevas.add(r);
                    }
                    transaccionesIdsUpdate.add(t.ID);
                }       
            }
            
        }
        if(!remesasNuevas.isEmpty()){
            lins = Database.insert(remesasNuevas, false);
        
            for(Integer i = 0; i < lins.size(); i++){
                Database.SaveResult ins = lins[i];
                if(!ins.isSuccess()){
                    List<Database.Error> errors = ins.getErrors(); 
                    String errores = '';
                    for(Database.Error e : errors){
                        errores += e.getMessage() + '\n';
                    }
                    Log__c log = new Log__c();
                    log.ID_Registro_Origen__c = origenIds.get(i);
                    log.Lote__c = lote.ID;
                    log.Errores__c = 'Remesa: ' + errores;
                    logs.add(log);
                }        
            }

            // Insertamos los contactos remesa
            List<Contacto_Remesa__c> contactosRemesasNuevos = new List<Contacto_Remesa__c>();

            for(WrapperContactoRemesa wcr : wrappers){

                if(String.isNotEmpty(wcr.remesa.Id)){

                    // Agregamos la remesa al contacto
                    wcr.contacto.Remesa__c = wcr.remesa.Id;

                    // Agregamos el contacto a la lista
                    contactosRemesasNuevos.add(wcr.contacto);

                }

            }

            // Insertamos la lista de contactos remesas
            Utils.insertList(contactosRemesasNuevos);
            
        }
        mapTransaciones.clear();
        List<Transaccion__c> transaccionesUpdate = [SELECT ID, Nombre_de_la_cuenta__c, Cultivo__c, Campana__c, Obtentor__c FROM Transaccion__c WHERE ID IN :transaccionesIdsUpdate];
        for(Transaccion__c t : transaccionesUpdate){
            t.Remesa__c = mapRemesas.get(t.Nombre_de_la_cuenta__c).ID;
        }
        update transaccionesUpdate;
        
        String keyObtentor;
        List<Transaccion__c> transacciones = [SELECT Nombre_de_la_cuenta__c, Cultivo__c, Campana__c, Obtentor__c, (SELECT Producto__c FROM Item_de_DUP__r) FROM Transaccion__c WHERE Lote__c = :lote.ID AND Nombre_de_la_cuenta__c IN :destinatarios AND Cultivo__c IN :cultivos AND Obtentor__c IN :obtentores];
        for(Transaccion__c t : transacciones){
            String key = String.valueOf(t.Nombre_de_la_cuenta__c) + String.valueOf(t.Cultivo__c) + String.valueOf(t.Campana__c) + String.valueOf(t.Obtentor__c);
            mapTransaciones.put(key, t);
            keyObtentor = ''+t.Nombre_de_la_cuenta__c+t.Obtentor__c;
            if(!mapObtentorProductos.containsKey(keyObtentor)){
                mapObtentorProductos.put(keyObtentor, new Set<ID>());
            }
            for(Item_de_DUP__c i : t.Item_de_DUP__r){
                mapObtentorProductos.get(keyObtentor).add(i.Producto__c);
            }
        }
        
        System.debug(LoggingLevel.INFO, 'mapTransaciones: ' + mapTransaciones);
        
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        origenIds.clear();
        for(Venta__c v : ventas){
            keyObtentor = ''+v.Destinatario__c+v.Producto__r.Obtentor_Comercializa__c;
            if(mapObtentorProductos.get(keyObtentor)==null || !mapObtentorProductos.get(keyObtentor).contains(mapVariedadesRegalias.get(v.Producto__r.Variedad__c))){
                String key = String.valueOf(v.Destinatario__c) + String.valueOf(v.Cultivo__c) + String.valueOf(lote.Campana__c) + String.valueOf(v.Producto__r.Obtentor_Comercializa__c);
                System.debug(LoggingLevel.INFO, 'key: ' + key);
                System.debug(LoggingLevel.INFO, 'mapTransaciones.get(key): ' + mapTransaciones.get(key));
                if(mapTransaciones.get(key)!=null){
                    Item_de_DUP__c item = new Item_de_DUP__c();
                    item.Obtentor__c = v.Producto__r.Obtentor_Comercializa__c;
                    item.Producto__c = mapVariedadesRegalias.get(v.Producto__r.Variedad__c);
                    item.Transaccion__c = mapTransaciones.get(key ).ID;
                    item.ID_Origen__c = v.ID;
                    item.Tipo_Origen__c = v.Tipo_de_Venta__c;
                    item.Campana_Agricola__c = lote.Campana__c;
                    item.Checkear_Duplicado__c = true;
                    items.add(item);
                    if(mapObtentorProductos.get(keyObtentor)==null){
                        mapObtentorProductos.put(keyObtentor, new Set<ID>());
                    }
                    mapObtentorProductos.get(keyObtentor).add(v.Producto__c);
                    origenIds.add(v.ID);
                }
            }
        }
        
        lins = Database.insert(items, false);
        
        for(Integer i = 0; i < lins.size(); i++){
            Database.SaveResult ins = lins[i];
            if(!ins.isSuccess()){
                List<Database.Error> errors = ins.getErrors(); 
                String errores = '';
                for(Database.Error e : errors){
                    if(e.getMessage() != Label.Error_Item_DUP_Duplicado){
                        errores += e.getMessage() + '\n';
                    }
                }
                if(errores != ''){
                    Log__c log = new Log__c();
                    log.ID_Registro_Origen__c = origenIds.get(i);
                    log.Lote__c = lote.ID;
                    log.Errores__c = 'Item: ' + errores;
                    logs.add(log);
                }
            }        
        }
        
        if(!logs.isEmpty()){
            insert logs;
        }
        
    }
    
    public void dupsTransacciones(List<Transaccion__c> transacciones, Lote__c lote) {
        armaSetsTransacciones(transacciones);
        
        armaMaps(lote);
    
        List<Remesa__c> remesasNuevas = new List<Remesa__c>();
        List<WrapperContactoRemesa> wrappers = new List<WrapperContactoRemesa>();
        Map<String, ID> mapVariedadesRegalias = new Map<String, ID>();
        List<String> origenIds = new List<String>();
        Database.SaveResult[] lins;
        
        for(Product2 p : [SELECT ID, Variedad__c FROM Product2 WHERE Family = 'Regalía Extendida' AND IsActive = true]){
            mapVariedadesRegalias.put(p.Variedad__c, p.ID);
        }
        Set<String> cuentasIds = new Set<String>();
        List<Transaccion__c> transaccionesNuevas = new List<Transaccion__c>();
        Integer idExterno = 0;
        //String keyObtentor;
        for(Transaccion__c to : transacciones){
            String key = String.valueOf(to.Nombre_de_la_cuenta__c) + String.valueOf(to.Cultivo__c ) + String.valueOf(lote.Campana__c) + String.valueOf(to.Obtentor__c );
            if(!mapTransaciones.containsKey(key)){

                if(System.isBatch() && to.Nombre_de_la_cuenta__r.No_Generar_DUP__c)
                    continue;

                Transaccion__c t = new Transaccion__c ();
                t.Nombre_de_la_cuenta__c = to.Nombre_de_la_cuenta__c;
                t.Cultivo__c = to.Cultivo__c;
                t.Campana__c = lote.Campana__c;
                t.Obtentor__c = to.Obtentor__c ;
                t.Lote__c = lote.ID;
                t.RecordTypeID = rtTransaccionDUP ;
                t.Id_Externo__c = '' + idExterno;
                t.Name = '' + idExterno;
                mapTransaciones.put(key, t);
                transaccionesNuevas.add(t);
                origenIds.add(t.ID);
                cuentasIds.add(to.Nombre_de_la_cuenta__c);
                idExterno++;



            }
        }
        //Obtengo los contactos
        if(!cuentasIds.isEmpty()){
            // Recorremos las cuentas y sus contactos
            for(Account a : [SELECT Id, (SELECT Id, Name FROM Contacts WHERE Contacto_Remesa__c = true) FROM Account WHERE Id IN :cuentasIds]){

                if(!mapContactos.containsKey(a.Id)){
                    mapContactos.put(a.Id, a.Contacts);    
                }

            }
        }
        
        List<Log__c> logs = new List<Log__c>();
        Set<String> transaccionesIdsUpdate = new Set<String>();
        if(!transaccionesNuevas.isEmpty()){
            lins = Database.insert(transaccionesNuevas, false);
        
            for(Integer i = 0; i < lins.size(); i++){
                Database.SaveResult ins = lins[i];
                if(!ins.isSuccess()){
                    List<Database.Error> errors = ins.getErrors(); 
                    String errores = '';
                    for(Database.Error e : errors){
                        errores += e.getMessage() + '\n';
                    }
                    Log__c log = new Log__c();
                    log.ID_Registro_Origen__c = origenIds.get(i);
                    log.Lote__c = lote.ID;
                    log.Errores__c ='Transacción: ' +  errores;
                    logs.add(log);
                } else {
                    Transaccion__c t = transaccionesNuevas.get(i);
                    if(!mapRemesas.containsKey(t.Nombre_de_la_cuenta__c)){
                        Remesa__c r = new Remesa__c();
                        r.Productor__c = t.Nombre_de_la_cuenta__c;
                        r.Lote__c = lote.ID;
                        //r.Contacto__c = mapContactos.get(t.Nombre_de_la_cuenta__c)!=null ? mapContactos.get(t.Nombre_de_la_cuenta__c).ID : null;
                        
                        // Revisamos si tenemos que crear un contacto remesa
                        if(mapContactos.containsKey(t.Nombre_de_la_cuenta__c)){

                            // Obtenemos el Contacto
                            List<Contact> cs = mapContactos.get(t.Nombre_de_la_cuenta__c);
                            
                            for(Contact c : cs){

                                // Instanciamos un Wrapper Remesa
                                WrapperContactoRemesa wcr = new WrapperContactoRemesa();

                                wcr.remesa = r;

                                wcr.contacto = new Contacto_Remesa__c();

                                wcr.contacto.Name = c.Name;

                                wcr.contacto.Contacto__c = c.Id;

                                // Agregamos el wrapper a la lista de wrappers
                                wrappers.add(wcr);

                            }

                        }    

                        mapRemesas.put(t.Nombre_de_la_cuenta__c, r);
                        remesasNuevas.add(r);
                        origenIds.add(t.ID);
                    }
                    transaccionesIdsUpdate.add(t.ID);
                }       
            }
        }
        System.debug(LoggingLevel.INFO, 'remesasNuevas: ' + remesasNuevas);
        if(!remesasNuevas.isEmpty()){
            lins = Database.insert(remesasNuevas, false);
        
            for(Integer i = 0; i < lins.size(); i++){
                Database.SaveResult ins = lins[i];
                if(!ins.isSuccess()){
                    List<Database.Error> errors = ins.getErrors(); 
                    String errores = '';
                    for(Database.Error e : errors){
                        errores += e.getMessage() + '\n';
                    }
                    Log__c log = new Log__c();
                    log.ID_Registro_Origen__c = origenIds.get(i);
                    log.Lote__c = lote.ID;
                    log.Errores__c = 'Remesa: ' + errores;
                    logs.add(log);
                }        
            }


            // Insertamos los contactos remesa
            List<Contacto_Remesa__c> contactosRemesasNuevos = new List<Contacto_Remesa__c>();

            for(WrapperContactoRemesa wcr : wrappers){

                if(String.isNotEmpty(wcr.remesa.Id)){

                    // Agregamos la remesa al contacto
                    wcr.contacto.Remesa__c = wcr.remesa.Id;

                    // Agregamos el contacto a la lista
                    contactosRemesasNuevos.add(wcr.contacto);

                }

            }

            // Insertamos la lista de contactos remesas
            Utils.insertList(contactosRemesasNuevos);

        }
        mapTransaciones.clear();
        
        List<Transaccion__c> transaccionesUpdate = [SELECT ID, Nombre_de_la_cuenta__c, Cultivo__c, Campana__c, Obtentor__c FROM Transaccion__c WHERE ID IN :transaccionesIdsUpdate];
        for(Transaccion__c t : transaccionesUpdate){
            t.Remesa__c = mapRemesas.get(t.Nombre_de_la_cuenta__c).ID;
        }
        update transaccionesUpdate;
  
        String keyObtentor;
        List<Transaccion__c> transaccionesAux = [SELECT Nombre_de_la_cuenta__c, Cultivo__c, Campana__c, Obtentor__c, (SELECT Producto__c, Obtentor__c FROM Item_de_DUP__r) FROM Transaccion__c WHERE Lote__c = :lote.ID AND Nombre_de_la_cuenta__c IN :destinatarios AND Cultivo__c IN :cultivos AND Obtentor__c IN :obtentores];
        for(Transaccion__c t : transaccionesAux ){
            String key = String.valueOf(t.Nombre_de_la_cuenta__c) + String.valueOf(t.Cultivo__c) + String.valueOf(t.Campana__c) + String.valueOf(t.Obtentor__c);
            mapTransaciones.put(key, t);
            keyObtentor = ''+t.Nombre_de_la_cuenta__c+t.Obtentor__c;
            if(!mapObtentorProductos.containsKey(keyObtentor)){
                mapObtentorProductos.put(keyObtentor, new Set<ID>());
            }
            for(Item_de_DUP__c i : t.Item_de_DUP__r){
                mapObtentorProductos.get(keyObtentor).add(i.Producto__c);
            }
        }
       
        System.debug(LoggingLevel.INFO, 'mapTransaciones: ' + mapTransaciones);
        List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
        origenIds.clear();
        
        for(Transaccion__c t : transacciones){
            System.debug(LoggingLevel.INFO, 't.Item_de_DUP__r: ' + t.Item_de_DUP__r);
            keyObtentor = ''+t.Nombre_de_la_cuenta__c+t.Obtentor__c;
            for(Item_de_DUP__c id : t.Item_de_DUP__r){
                if(mapObtentorProductos.get(keyObtentor) == null || !mapObtentorProductos.get(keyObtentor).contains(id.Producto__c)){
                    String key = String.valueOf(t.Nombre_de_la_cuenta__c) + String.valueOf(t.Cultivo__c) + String.valueOf(lote.Campana__c) + String.valueOf(t.Obtentor__c );
                    System.debug(LoggingLevel.INFO, 'key: ' + key);
                    System.debug(LoggingLevel.INFO, 'mapTransaciones.get(key): ' + mapTransaciones.get(key));
                    if(mapTransaciones.get(key)!=null){
                        Item_de_DUP__c item = new Item_de_DUP__c();
                        item.Obtentor__c = t.Obtentor__c;
                        item.Producto__c = id.Producto__c;
                        item.Transaccion__c = mapTransaciones.get(key).ID;
                        item.ID_Origen__c = id.ID;
                        item.Tipo_Origen__c = 'DUP';
                        item.Campana_Agricola__c = lote.Campana__c;
                        item.Checkear_Duplicado__c = true;
                        items.add(item);
                        if(mapObtentorProductos.get(keyObtentor) == null){
                            mapObtentorProductos.put(keyObtentor, new Set<ID>());
                        }
                        mapObtentorProductos.get(keyObtentor).add(id.Producto__c);
                        origenIds.add(id.ID);
                    }
                }    
            }
            System.debug(LoggingLevel.INFO, 't.Items_Auditorias__r: ' + t.Items_Auditorias__r);
            for(Item_Auditoria__c ia : t.Items_Auditorias__r){
                if(ia.Campana__c == lote.Campana__r.Nombre_de_Campana_Anterior__c){
                    if(mapObtentorProductos.get(keyObtentor) == null || !mapObtentorProductos.get(keyObtentor).contains(ia.Producto__c)){
                        String key = String.valueOf(t.Nombre_de_la_cuenta__c) + String.valueOf(t.Cultivo__c) + String.valueOf(lote.Campana__c) + String.valueOf(t.Obtentor__c);
                        System.debug(LoggingLevel.INFO, 'key: ' + key);
                        System.debug(LoggingLevel.INFO, 'mapTransaciones.get(key): ' + mapTransaciones.get(key));
                        if(mapTransaciones.get(key)!=null){
                            Item_de_DUP__c item = new Item_de_DUP__c();
                            item.Obtentor__c = t.Obtentor__c;
                            item.Producto__c = mapVariedadesRegalias.get(ia.Producto__r.Variedad__c);
                            item.Transaccion__c = mapTransaciones.get(key).ID;
                            item.ID_Origen__c = ia.ID;
                            item.Tipo_Origen__c = 'Auditoría';
                            item.Campana_Agricola__c = lote.Campana__c;
                            items.add(item);
                            if(mapObtentorProductos.get(keyObtentor) == null){
                                mapObtentorProductos.put(keyObtentor, new Set<ID>());
                            }
                            mapObtentorProductos.get(keyObtentor).add(ia.Producto__c);
                            origenIds.add(ia.ID);
                        }
                    }   
                } 
            }
            
        }
        
        lins = Database.insert(items, false);
        
        for(Integer i = 0; i < lins.size(); i++){
            Database.SaveResult ins = lins[i];
            if(!ins.isSuccess()){
                List<Database.Error> errors = ins.getErrors(); 
                String errores = '';
                for(Database.Error e : errors){
                    if(e.getMessage() != Label.Error_Item_DUP_Duplicado){
                        errores += e.getMessage() + '\n';
                    }
                }
                if(errores != ''){
                    Log__c log = new Log__c();
                    log.ID_Registro_Origen__c = origenIds.get(i);
                    log.Lote__c = lote.ID;
                    log.Errores__c = 'Item: ' + errores;
                    logs.add(log);
                    System.debug(LoggingLevel.INFO, 'item: ' + items.get(i));
                    System.debug(LoggingLevel.INFO, 'items producto: ' + items.get(i).Producto__c);
                    System.debug(LoggingLevel.INFO, 'items transaccion: ' + items.get(i).Transaccion__c);
                }
            }        
        }
        
        if(!logs.isEmpty()){
            insert logs;
        }
        
        
    }
    
    private void armaSetsVentas(List<Venta__c> ventas){
        destinatarios.clear();
        cultivos.clear();
        obtentores.clear();
        for(Venta__c v : ventas){
            destinatarios.add(v.Destinatario__c);
            cultivos.add(v.Cultivo__c);
            obtentores.add(v.Producto__r.Obtentor_Comercializa__c);
        }
    }
    
    private void armaSetsTransacciones(List<Transaccion__c> transacciones){
        destinatarios.clear();
        cultivos.clear();
        obtentores.clear();
        for(Transaccion__c t : transacciones){
            destinatarios.add(t.Nombre_de_la_cuenta__c);
            cultivos.add(t.Cultivo__c);
            obtentores.add(t.Obtentor__c);
        }
    }
    
    private void armaMaps(Lote__c lote){
        List<Transaccion__c> transacciones = [SELECT Nombre_de_la_cuenta__c, Cultivo__c, Campana__c, Obtentor__c, (SELECT Producto__c FROM Item_de_DUP__r) FROM Transaccion__c WHERE Lote__c = :lote.ID AND Nombre_de_la_cuenta__c IN :destinatarios AND Cultivo__c IN :cultivos AND Obtentor__c IN :obtentores];
        Set<String> cuentasIds = new Set<String>();
        String keyObtentor;
        for(Transaccion__c t : transacciones){
            String key = String.valueOf(t.Nombre_de_la_cuenta__c) + String.valueOf(t.Cultivo__c) + String.valueOf(t.Campana__c) + String.valueOf(t.Obtentor__c);
            mapTransaciones.put(key, t);
            keyObtentor = ''+t.Nombre_de_la_cuenta__c+t.Obtentor__c;
            if(!mapObtentorProductos.containsKey(keyObtentor)){
                mapObtentorProductos.put(keyObtentor, new Set<ID>());
            }
            for(Item_de_DUP__c i : t.Item_de_DUP__r){
                mapObtentorProductos.get(keyObtentor).add(i.Producto__c);
            }
            cuentasIds.add(t.Nombre_de_la_cuenta__c);
        }
        if(!cuentasIds.isEmpty()){
            // Recorremos las cuentas y sus contactos
            for(Account a : [SELECT Id, (SELECT Id, Name FROM Contacts WHERE Contacto_Remesa__c = true) FROM Account WHERE Id IN :cuentasIds]){

                if(!mapContactos.containsKey(a.Id)){
                    mapContactos.put(a.Id, a.Contacts);    
                }

            }
        }
        List<Remesa__c> remesas = [SELECT Productor__c FROM Remesa__c WHERE Lote__c = :lote.ID AND Productor__c IN :cuentasIds];
        for(Remesa__c r : remesas){
            String key = String.valueOf(r.Productor__c);
            mapRemesas.put(key, r);
        }
    }


    public class WrapperContactoRemesa {
        
        public Remesa__c remesa {get; set;}
        public Contacto_Remesa__c contacto {get; set;}

    }
    
}