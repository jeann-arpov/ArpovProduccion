public without sharing class DOABMDUPController{
    
    //Atributos
    public String selectedCultivo {get; set;}
    
    public String selectedObtentor {get; set;}
    
    public String selectedCampana {get; set;}

    public String selectedLocalidad {get; set;}

    public String selectedProvincia {get; set;}
    
    public List<WrapperDup> items {get;set;}
    
    public List<WrapperDup> itemsConfirmacion {get;set;}
    
    public Transaccion__c transaccion {get; set;}
    
    public String url {get; set;}
    
    public Boolean etapaConfirmacion {get; set;}
    
    public Integer alertState {get; set;}
    
    public String idProductor {get; set;}
    
    public String tokenProductor {get; set;}

    public Id idLocalidad;
    
    public Set<Id> productosUMHectareas {get; set;}

    public Map<Id, Cultivo__c> mapCultivos = new Map<Id, Cultivo__c>();
    
    public DOABMDUPController(ApexPages.StandardController controller){
        
        //Obtenemos el token pasado como parametro
        String token = ApexPages.currentPage().getParameters().get('token');
        
        if(token != null){
           String data = Utils.decryptToken(token.trim());
           init(data);
        }
    }
    
    private void init(String id){
        
        Id idObtenido = id;
        Id idTransaccion;
        
        //Checkeamos a que objeto pertenece el id
        if(String.valueOf(idObtenido.getSObjectType()) == 'Account'){
            idProductor = id;
        }else if(String.valueOf(idObtenido.getSObjectType()) == 'Transaccion__c'){
            idTransaccion = id;
        }
        
        //Verificamos si la accion es alta o modificacion
        if(idTransaccion != null){
            //Obtenemos los datos de la misma
            List<Transaccion__c> transacciones = [SELECT Id,Name, Localidad__c, Provincia__c, Nombre_de_la_cuenta__c,Apellido_y_Nombre__c, Tipo_de_Documento__c, Caracter__c, Numero_de_Documento__c, Obtentor__c, Campana__c, Cultivo__c, Fecha_de_Respuesta__c  FROM Transaccion__c WHERE Id = :idTransaccion LIMIT 1];
            
            if(transacciones.size() > 0){
                
                transaccion = transacciones.get(0);
                
                // Seteamos el idLocalidad
                idLocalidad = transaccion.Localidad__c;

            }


        }else{
            transaccion = new Transaccion__c();
        }
        
        if(idProductor == null){
            idProductor = transaccion.Nombre_de_la_cuenta__c;
        }
        
        //Generamos un token con el id del productor
        tokenProductor = Utils.createToken(idProductor);
        
        if(transaccion.Nombre_de_la_cuenta__c == null)
           transaccion.Nombre_de_la_cuenta__c = idProductor; 
        
        items = new List<WrapperDup>();
        
        if(transaccion.Id != null){
            //Obtenemos los items de dup de la transaccion
            for(Item_de_DUP__c item : [SELECT Id, Producto__c, Producto__r.Unidad_de_Medida__c, Cantidad_Declarada__c,Densidad_de_Siembra__c, Hectareas_Declaradas__c, CreatedBy.UserType FROM Item_de_DUP__c WHERE Transaccion__c = :transaccion.Id]){
                
                //Creamos un Wrapper
                WrapperDup wp = new WrapperDup();
                wp.item = item;
                wp.index = items.size();
                wp.showHectareas = false;
                wp.canDelete = (item.CreatedBy.UserType == 'Guest')?true:false;
                
                //Si la UM del Producto es igual a Hectáreas indico que se pueden cargar hectareas
                if(item.Producto__r.Unidad_de_Medida__c == 'Hectáreas'){
                    wp.showHectareas = true;
                    if( item.Densidad_de_Siembra__c != null){
                        if(item.Densidad_de_Siembra__c > 0){
                            wp.item.Hectareas_Declaradas__c = item.Cantidad_Declarada__c / item.Densidad_de_Siembra__c;
                        }
                    }
                }
                
                //Agregamos a la lista de wrappers
                items.add(wp);
            }
        } 
        
        etapaConfirmacion = false;
        
        alertState = 0;
        
    }

    public Id getIdLocalidad(){
        return idLocalidad;
    }

    public void setIdLocalidad(Id idLoc){
        if(!String.isEmpty(idLoc)){
            idLocalidad = idLoc;
            transaccion.Localidad__c = idLoc;
        }
    }
    
    public List<SelectOption> getObtentores(){
        
        //Lista de obtentores
        List<SelectOption> obtentores = new List<SelectOption>();
        
        //Obtenemos el recordtype de un Obtentor
        Id rtO = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
        
        obtentores.add(new  SelectOption('', '--Ninguno--'));
        
        //Obtenemos todos los obtentores
        for(Account a : [SELECT Id, Name FROM Account WHERE RecordTypeId = :rtO ORDER BY Name ASC]){
            
            //Por cada obtentor generamos una opcion en una lista de seleccion
            obtentores.add(new  SelectOption(a.id, a.Name));
        
        }        
        
        //Devolvemos los obtentores
        return obtentores;
        
    }
    
    public List<SelectOption> getCultivos(){
        
        //Lista de obtentores
        List<SelectOption> cultivos = new List<SelectOption>();
        
        cultivos.add(new  SelectOption('', '--Ninguno--'));

        mapCultivos.clear();
        
        //Obtenemos todos los obtentores
        for(Cultivo__c c : [SELECT Id, Name, Temporada__c FROM Cultivo__c ORDER BY Name ASC]){
            
            //Por cada cultivo generamos una opcion en una lista de seleccion
            cultivos.add(new  SelectOption(c.id, c.Name));

            mapCultivos.put(c.Id, c);
        
        }        
        
        //Devolvemos los obtentores
        return cultivos;
        
    }
    
    public List<SelectOption> getCampanas(){
        
        System.Debug(LoggingLevel.INFO,selectedCultivo);
        
        //Lista de obtentores
        List<SelectOption> campanas = new List<SelectOption>();
        
        campanas.add(new  SelectOption('', '--Ninguno--'));
        
        

        if(transaccion.Cultivo__c != null){
            
            // Obtenemos la temporada
            if(!mapCultivos.containsKey(transaccion.Cultivo__c)){
                return campanas;
            }

            // Obtenemos la temporada
            String temporada = mapCultivos.get(transaccion.Cultivo__c).Temporada__c;

            //Obtenemos todos los obtentores
            for(Campana_Agricola__c c : [SELECT Id, Name FROM Campana_Agricola__c WHERE Temporada__c = :temporada AND Mostrar_en_Minisitio__c = true ORDER BY Name ASC]){
                
                //Por cada campaña agricla generamos una opcion en una lista de seleccion
                campanas.add(new  SelectOption(c.id, c.Name));
            
            }        
        
        }
        
        //Devolvemos los obtentores
        return campanas;
    }

    public List<List<SelectOption>> getLocalidades(){
        
        List<List<SelectOption>> result = new List<List<SelectOption>>();

        //Lista de productos
        List<SelectOption> localidades = new List<SelectOption>();
        
        System.debug(LoggingLevel.DEBUG, transaccion.Provincia__c);

        if(transaccion.Provincia__c != null){
            
            //Obtenemos todos los productos cuyo obtentor comercializa sea el que se selecciono
            for(Localidad__c l : [SELECT Id, Name FROM Localidad__c WHERE Provincia__c = :transaccion.Provincia__c ORDER BY Name ASC LIMIT 10000]){
                
                //Por cada producto generamos una opcion para rellenar el select
                localidades.add(new  SelectOption(l.id, l.Name));

                if(localidades.size() == 1000){

                    List<SelectOption> aux = new List<SelectOption>();

                    aux.addAll(localidades);

                    result.add(aux);

                    localidades.clear();

                }

                
            }    

            if(!localidades.isEmpty()){

                List<SelectOption> aux = new List<SelectOption>();

                aux.addAll(localidades);

                result.add(aux);

                localidades.clear();

            }    
        
        }
        
        //Devolvemos los obtentores
        return result;
    }

    public List<SelectOption> getProvincias(){
        
        //Lista de productos
        List<SelectOption> provincias = new List<SelectOption>();
    
        provincias.add(new  SelectOption('', '--Ninguno--'));
        
        //Obtenemos todos los productos cuyo obtentor comercializa sea el que se selecciono
        for(Provincia__c p : [SELECT Id, Name FROM Provincia__c WHERE Name != 'CAPITAL FEDERAL' ORDER BY Name ASC]){

            //Por cada producto generamos una opcion para rellenar el select
            provincias.add(new  SelectOption(p.Id, p.Name));

            
        }        
        
        //Devolvemos los obtentores
        return provincias;
    }
    
    public List<SelectOption> getProductos(){
        
        System.Debug(LoggingLevel.INFO,selectedCultivo);
        
        //Lista de productos
        List<SelectOption> productos = new List<SelectOption>();
        
        productos.add(new  SelectOption('', '--Ninguno--'));
        
        if(transaccion.Obtentor__c != null && transaccion.Cultivo__c != null){
            
            //Instanciamos el set
            productosUMHectareas = new Set<Id>();
            
            //Obtenemos todos los productos cuyo obtentor comercializa sea el que se selecciono
            for(Product2 p : [SELECT Id, Variedad__c,Unidad_de_Medida__c FROM Product2 WHERE Obtentor_Comercializa__c = :transaccion.Obtentor__c AND Family = 'Regalía Extendida' AND Cultivo__c = :transaccion.Cultivo__c AND IsActive = true ORDER BY Variedad__c ASC]){
                
                //Por cada producto generamos una opcion para rellenar el select
                productos.add(new  SelectOption(p.id, p.Variedad__c));
                
                //Si el la UM del Producto es igual a Hectareas lo agregamos al set
                if(p.Unidad_de_Medida__c == 'Hectáreas'){
                    productosUMHectareas.add(p.id);
                }
                
            }        
        
        }
        
        //Devolvemos los obtentores
        return productos;
    }
    
    @RemoteAction    
    public static Boolean isProductHectarea(Id idProducto){
        
        Product2 p = [SELECT Id, Variedad__c,Unidad_de_Medida__c FROM Product2 WHERE Id =:idProducto];

        return p.Unidad_de_Medida__c == 'Hectáreas';

    }
    
    public void agregarVariedad(){
       
       //Creamos un nuevo Wrapper
       WrapperDup wp = new WrapperDup();
       
       //Creamos una nueva item de DUP
       wp.item = new Item_de_DUP__c();
       
       //Seteamos el indice
       wp.index = items.size();
       
       //Seteamos si se muestra o no la variedad
       wp.showHectareas = false;
       
       // Seteamos que si puede eliminar la variedad
       wp.canDelete = true;
       
       //Insertamos la misma en la lista de wrappers
       items.add(wp);
       
    }
    
    public void eliminarVariedad(){
        
        //Obtenemos el Indice de la Variedad a eliminar
        Integer indexVariedad = Integer.valueOf(Apexpages.currentPage().getParameters().get('indexVariedad'));
        
        if(items.size() > indexVariedad){
            
            //Obtengo el item y lo saco de la lista
            WrapperDup wp = items.remove(indexVariedad);
            
            //Verifico si tiene un Id, en este caso tambien debo sacarlo de la base de datos
            if(wp.item.Id != null){
                
                //Consulto a la BD para verificar que el item exista
                List<Item_de_DUP__c> its = [SELECT Id FROM Item_de_DUP__c WHERE Id = :wp.item.Id LIMIT 1];
                
                //Si existe el item lo elimino
                if(its.size() == 1){
                    
                    delete its;
                
                }
                
            }
            
        }
        
    }
    
    public void grabar(){
        
        //Seteamos la variable para indicar que estamos en la etapa de confirmacion
        etapaConfirmacion = true;
        
        //Instanciamos la lista de confirmacion
        itemsConfirmacion = new List<WrapperDup>();

        //Creamos un item de confirmacion por cada item que se creo asi el usuario confima nuevamente la carga
        for(WrapperDup wp : items){
            
            //Creamos un wrapper
            WrapperDup wrC = new WrapperDup();
            
            //Creamos un item de Dup
            wrC.item = wp.item.clone(false, false);
            
            //Seteamos la cantidad en 0 puesto que es lo que tiene que confirmar
            wrC.item.Cantidad_Declarada__c = null;
            
            //Seteamos las hectareas
            wrC.item.Hectareas_Declaradas__c = null;
            
            // Verificamos si tiene que agregar hectareas o no
            wp.showHectareas = productosUMHectareas.contains(wp.item.Producto__c);

            //Seteamos el show hectarea
            wrC.showHectareas = wp.showHectareas;

            //Agregamos el item a la lista de items a confirmar
            itemsConfirmacion.add(wrC);
            
        }
    
    }
    
    public PageReference grabarConfirmacion(){
        
        //Obtenemos el RecordSet de las DUP
        Id rtTransaccionDUP = RecordTypeTool.getRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
        
        //Pagina que indica si la operacion se realizo con exito
        alertState = 1;
        
        //Page Reference a Retornar
        PageReference pr = null;
        
        //Obtengo los datos necesarios para grabar
        Id idObtentor = selectedObtentor;
        Id idCultivo = selectedCultivo;
        Id idCampana = selectedCampana;
        Id idProvincia = selectedProvincia;
        Id idLocalidad = selectedLocalidad;
        
        
        //Seteamos algunos datos a la transaccion
        transaccion.Respondida_via_Minisitio__c = true;
        transaccion.Fecha_de_Respuesta__c = Date.today();
        
        //Lista de Items de Dup a Insertar
        List<Item_de_DUP__c> itemsToInsert = new List<Item_de_DUP__c>();
        
        //Lista de Items de DUP a Actializar
        List<Item_de_DUP__c> itemsToUpdate = new List<Item_de_DUP__c>();
        
        //Verificaciones antes de Guardar
        if(items.size() != itemsConfirmacion.size()){
            
            //Error la cantidad items y los items de confirmacion deberian ser los mismos
            return pr;
        }
        
        //Recorremos ambos items en simultaneo
        Integer i = 0;
        
        //Variable que usaremos para indicar si se encontraron items distintos
        Boolean distintos = false;
        
        //Ciclamos sobre ambos set de datos
        while(i < items.size() && !distintos){
            if(items[i].item.Producto__c != itemsConfirmacion[i].item.Producto__c || items[i].item.Cantidad_Declarada__c != itemsConfirmacion[i].item.Cantidad_Declarada__c || (items[i].item.Hectareas_Declaradas__c != itemsConfirmacion[i].item.Hectareas_Declaradas__c && items[i].showHectareas == true)){
                distintos = true;
            }else{
                
                //Obtenemos el Item de DUP
                Item_de_DUP__c item = items[i].item;
                
                //Seteamos algunos datos
                item.Obtentor__c = transaccion.Obtentor__c;
                item.Transaccion__c = transaccion.Id;
                item.Campana_Agricola__c = transaccion.Campana__c;
                item.Lugar_de_Siembra__c = transaccion.Provincia__c;
                
                if( items[i].showHectareas = true && item.Hectareas_Declaradas__c != null && item.Cantidad_Declarada__c != null){
                    
                    if(item.Hectareas_Declaradas__c > 0){
                        //Seteo la Densidad_de_Siembra__c
                        item.Densidad_de_Siembra__c = item.Cantidad_Declarada__c / item.Hectareas_Declaradas__c;
                    }
                    
                }
                
                if(item.Id == null){
                    //Indicamos que la variedad se agrego manualmente
                    item.Variedad_Agregada_Manualmente__c = true;
                    //Agregamos el item a los items a Insertar
                    itemsToInsert.add(item);
                }else{
                    itemsToUpdate.add(item);
                }
                i++;
            }
        }
        
        try{
            

            
            ApexPages.Message myMsg = null;
            
            if(!distintos){

                if(transaccion.Id != null){
                    //Actualizamos la transaccion
                    update transaccion;
                }else{
                    
                    //Indicamos que la transaccion se dio de alta via minisitio
                    transaccion.Cargada_via_Minisitio__c = true;
                    
                    //Indicamos que la transaccion es de tipo dup
                    transaccion.RecordTypeId = rtTransaccionDUP;
                    
                    insert transaccion;
                    
                    //Recorremos las DUPS a insertar y agregamos el id
                    for(Item_de_DUP__c item : itemsToInsert){
                        item.Transaccion__c = transaccion.Id;
                    }
                    
                }
                
                //Si no hay diferencias entonces nos preparamos a guardar
                if(!distintos && itemsToInsert.size() > 0){
                    Utils.insertList(itemsToInsert,true);
                }
                
                if(!distintos && itemsToUpdate.size() > 0){
                    Utils.updateList(itemsToUpdate,true);
                }
            
                //Creamos un mensaje indicando que la operacion se realizo con exito
                myMsg = new ApexPages.Message(ApexPages.Severity.INFO, 'La operación se realizo con exito.');
                
                //Seteamos la variable success en true
                alertState = 2;
                
            }else{
                
                //Creamos un mensaje indicando que hay datos distintos 
                myMsg = new ApexPages.Message(ApexPages.Severity.ERROR, 'La información ingresada, no concuerda con la información ingresada para la confirmación. Por favor revise sus datos.');
                
            }
            
            ApexPages.addMessage(myMsg);
        }catch(Exception e){
            ApexPages.addMessages(e);
        }
        
        
        
        return pr;
    }
    
    
    public PageReference salirSinGrabar(){
        /*
        //Obtenemos la URL actual
        String url = ApexPages.currentPage().getHeaders().get('Host');
        
        //Redirigimos a la Home
        PageReference prRef = new PageReference(url+'/?id=' + transaccion.Nombre_de_la_cuenta__c);
        
        prRef.setRedirect(true);
        */
        return null;
    }
    
    /**
    * @author Maximo Martinez
    * @date 6/06/2014
    * @description Clase Auxiliar que permite mantener el indice de un elemente en la lista 
    */
    public class WrapperDup{
        
        //Atributos 
        public Item_de_DUP__c item {get; set;}
        public Integer index {get; set;}
        public Boolean showHectareas {get; set;}
        public Boolean canDelete {get; set;}
        
    }
    

    
    
}