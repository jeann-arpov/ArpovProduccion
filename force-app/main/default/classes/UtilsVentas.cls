/**
* @author Maximo Martinez
* @date 03/06/2014
* @description Clase con Metodos Utilitarios para el Objeto Venta__c
*/
public with sharing class UtilsVentas{

    private static final Set<String> CATEGORIAS = new Set<String>{'Primera Multiplicación', 'Segunda Multiplicación', 'Tercera Multiplicación', 'No Definida'};

    /**
    * @author Maximo Martinez
    * @date 14/11/2014
    * @description Calcula el Saldo Total de un conjunto de cuentas y campañas a partir de las ventas
    */
    public static Map<Id,Double> calcularSaldoTotal(Set<String> accIds, Id campanaId){

        // Map para devolver cada cuenta con su respectivo saldo
        Map<Id, Double> saldosByAccounts = new Map<Id, Double>();

        Map<Id, AuxSaldos> auxSaldosByAccounts = new Map<Id, AuxSaldos>();

        AuxSaldos auxSld = null;

        for(Venta__c v : [SELECT Producto__r.Obtentor_Comercializa__c, Campana_Agricola__r.Ano__c ,Id_Obtentor__c ,Producto__r.Variedad__c ,Tipo_de_Producto__c ,Categoria__c ,UM__c ,Originante__c ,Destinatario__c ,Cantidad_Bolsas_40__c, Id, Tipo_de_Venta__c FROM Venta__c WHERE Campana_Agricola__c = :campanaId AND (Originante__c IN :accIds OR Destinatario__c IN :accIds ) Order By Campana_Agricola__r.Ano__c ,Id_Obtentor__c ,Producto__r.Variedad__c ,Tipo_de_Producto__c ,Categoria__c ,UM__c ,Originante__c ,Destinatario__c ,Cantidad_Bolsas_40__c, Tipo_de_Venta__c DESC]){

            Set<String> idsAcc = new Set<String>{v.Originante__c, v.Destinatario__c};

            for(String idAcc : idsAcc){

                if(!accIds.contains(idAcc))continue;

                if(v.Producto__r.Obtentor_Comercializa__c != idAcc){

                    if(!auxSaldosByAccounts.containsKey(idAcc))
                        auxSaldosByAccounts.put(idAcc, new AuxSaldos());
                        
                    // Obtenemos AuxSaldos
                    auxSld = (AuxSaldos)auxSaldosByAccounts.get(idAcc);

                    if(auxSld.obtentor == '' || auxSld.obtentor != v.Id_Obtentor__c){

                        System.debug(LoggingLevel.INFO, v.Id_Obtentor__c);

                        System.debug(LoggingLevel.INFO, auxSld.cantidad);

                        System.debug(LoggingLevel.INFO, auxSld.cantidadByObtentor);

                        System.debug(LoggingLevel.INFO, auxSld.saldoTotal);

                        if(auxSld.cantidad > 0)
                            auxSld.cantidadByObtentor+= auxSld.cantidad;

                        if(auxSld.cantidadByObtentor > 0)
                            auxSld.saldoTotal += auxSld.cantidadByObtentor;

                        //Variable que contendra la variedad del producto
                        auxSld.variedad = '';
                        
                        //Variable que contendra el tipo del producto
                        auxSld.tipo = '';
                        
                        //Variable que contendra la categoria del producto
                        auxSld.categoria = '';
                        
                        //Variable que contendra la UM del producto
                        auxSld.um = '';

                        auxSld.cantidadByObtentor = 0;

                        auxSld.cantidad = 0;
                        
                        //Seteamos el cultivo en la variable
                        auxSld.obtentor = v.Id_Obtentor__c;

                    } 


                    if( (auxSld.variedad == '' && auxSld.tipo == '' && auxSld.categoria == '' && auxSld.um == '') || (auxSld.variedad != v.Producto__r.Variedad__c || auxSld.tipo != v.Tipo_de_Producto__c || auxSld.categoria != v.Categoria__c || auxSld.um != v.UM__c)){
                            
                            if(auxSld.cantidad > 0)
                                auxSld.cantidadByObtentor+= auxSld.cantidad;

                            //Seteamos la variedad del producto
                            auxSld.variedad = v.Producto__r.Variedad__c;
                            
                            //Seteamos el tipo 
                            auxSld.tipo = v.Tipo_de_Producto__c;
                            
                            //Seteamos la categoria del producto
                            auxSld.categoria =  v.Categoria__c;
                            
                            //Seteamos el um del producto
                            auxSld.um = v.UM__c;
                            
                            auxSld.cantidad = 0;

                    }

                    if(!CATEGORIAS.contains(v.Categoria__c))
                        continue;
                        
                    if(v.Cantidad_Bolsas_40__c != null){

                         // Si es un Movimiento TRC o el Originante no es la cuenta que se consulta entonces se suma
                        if( (v.Originante__c == v.Destinatario__c && v.Tipo_de_Venta__c == 'TRC' && v.Tipo_de_Producto__c == 'Semilla Fiscalizada') || v.Originante__c != idAcc )
                            auxSld.cantidad += v.Cantidad_Bolsas_40__c;
                        else if(v.Originante__c == idAcc)// Si el Originante es la cuenta que se consulta entonces se Resta
                            auxSld.cantidad += (-1)*v.Cantidad_Bolsas_40__c;    

                    }

                }

            }

        }

        for(String idAcc : auxSaldosByAccounts.keySet()){

            auxSld = (AuxSaldos)auxSaldosByAccounts.get(idAcc);

            if(auxSld.cantidad > 0)
                auxSld.cantidadByObtentor+= auxSld.cantidad;

            if(auxSld.cantidadByObtentor > 0)
                auxSld.saldoTotal += auxSld.cantidadByObtentor;

        }

        for(Id accId : accIds){

            if(auxSaldosByAccounts.containsKey(accId)){
    
                Double saldoTotal = auxSaldosByAccounts.get(accId).saldoTotal;
                saldosByAccounts.put(accId, saldoTotal);
    
            }
        }

        return saldosByAccounts;

    } 

   
    /**
    * @author Maximo Martinez
    * @date 07/11/2014
    * @description Setea el tipo de venta segun el custom Settings "Comportamiento Segun Rol Ventas"
    */
    public static void setTipoDeVenta(List<Venta__c> lista){

        // Obtenemos los ids de los productos de las ventas

        Set<Id> idsProductos = new Set<Id>();

        for(Venta__c v : lista){
            if(v.Producto__c != null)
                idsProductos.add(v.Producto__c);
        }

        Map<Id, Product2> productos = new Map<Id, Product2>([SELECT Id, Obtentor_Comercializa__c FROM Product2 WHERE Id IN :idsProductos]);

        // Obtenemos los valores seteados en el custom settings
        List<Comportamiento_Segun_Rol_Ventas__c> csrvs = Comportamiento_Segun_Rol_Ventas__c.getall().values();

        Map<String, List<Comportamiento_Segun_Rol_Ventas__c>> csrvsByKey = new Map<String, List<Comportamiento_Segun_Rol_Ventas__c>>();
        for(Comportamiento_Segun_Rol_Ventas__c csrv : csrvs){
            String key = csrv.Tipo_de_Producto__c + '-' + csrv.Categoria__c + '-' + csrv.Rol_Destinatario__c + '-' + csrv.Rol_Originante__c; 
            if(!csrvsByKey.containsKey(key)){
                csrvsByKey.put(key, new List<Comportamiento_Segun_Rol_Ventas__c>());
            }

            csrvsByKey.get(key).add(csrv);
        }

        // Recorro una ves mas las ventas y seteo su tipo
        for(Venta__c v : lista){
            if(v.Tipo_de_Venta__c == null) {
                // Recorro los valores del custom settings que coinciden con los criterios
                csrvs = csrvsByKey.get(v.Tipo_de_Producto__c + '-' + v.Categoria__c + '-' + v.Rol_Destinatario__c + '-' + v.Rol_Originante__c);
                if(csrvs != null) {
                    for(Comportamiento_Segun_Rol_Ventas__c csrv : csrvs){                           
                        if(productos.containsKey(v.Producto__c)){

                            // Obtenemos el producto
                            Product2 producto = productos.get(v.Producto__c);
                        
                            if(csrv.Variedad__c == 'Propia' && v.Originante__c != producto.Obtentor_Comercializa__c)continue;
                            if(csrv.Variedad__c == 'No Propia' && v.Originante__c == producto.Obtentor_Comercializa__c)continue;

                        }else{
                            continue;
                        }

                        if(csrv.Mismo_Originante_Destinatario__c && (v.Destinatario__c != v.Originante__c))continue;

                        if(csrv.Tipo_de_Comprobante__c != null && csrv.Tipo_de_comprobante__c != v.Tipo_de_Comprobante__c) continue;

                        // La venta coincide con los criterios, seteamos el tipo de venta desde el CS
                        v.Tipo_de_Venta__c = csrv.Tipo_de_Venta__c;

                        // Salimos del for
                        break;
                    }
                }
            }
        }

    }



    /**
    * @description Método que a partir de un listado de ventas C genera ventas TRC
    * @param lista: Ventas que serán procesadas
    */
    public static void generarVentasTipoTRC(List<Venta__c> lista){

        //Set que contendra el id de las ventas
        Set<Id> idsVentas = new Set<Id>();

        //Recorro las ventas y solo me quedo con aquellas que son de tipo C
        for(Venta__c v : lista){

            if(v.Tipo_de_Venta__c == 'C'){

                idsVentas.add(v.Id);

            }

        }

        //Obtenemos los datos que necesitamos para realizar el filtrado de ventas

        //Obtenemos los recordtype de Cuenta Distribuidor, Cuenta Comercio y Cuenta Originante
        Id rtDistribuidor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        Id rtComercio =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Comercio');
        Id rtObtentor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');

        //Set para coleccionar la variedad de los productos
        Set<String> variedadesProductos = new Set<String>();

        //Set para coleccionar la um de los productos
        Set<String> umsProductos = new Set<String>();

        //Set para coleccionar la categoria de los productos
        Set<String> categoriasProductos = new Set<String>();

        //Set que contiene las ventas a clonar
        Set<Id> ventasToClone = new Set<Id>();

        //Map que contiene los productos y sus variedades
        Map<Id, Product2> productosByIds = new Map<Id, Product2>();

        for(Venta__c v : [SELECT Id, Producto__r.Id, Producto__r.Variedad__c, Producto__r.Unidad_de_Medida__c, Producto__r.Categoria__c FROM Venta__c WHERE Originante__r.RecordTypeId = :rtObtentor AND (Destinatario__r.RecordTypeId = :rtComercio OR Destinatario__r.RecordTypeId = :rtDistribuidor) AND Producto__r.Family = 'Regalía Comercial' AND Categoria__c IN ('Primera Multiplicación','Auditada','Segunda Multiplicación','Tercera Multiplicación', 'Original o Fundadora') AND Tipo_de_Venta__c = 'C' AND Id IN :idsVentas]){

            //Agregamos la variedad del producto
            variedadesProductos.add(v.Producto__r.Variedad__c);

            umsProductos.add(v.Producto__r.Unidad_de_Medida__c);

            //Agregamos al map la variedad y el producto
            productosByIds.put(v.Producto__r.Id, v.Producto__r);

            //Agregamos la ventas a clonar al set
            ventasToClone.add(v.Id);


        }       

        //Consultamos por los productos cuya variedades son las que tenemos en el map, pero cuya Family es Semilla Fiscalizada
        
        //Map que contiene los productos ordenados por key que es la concatenacion de variedad y unidad de medida
        Map<String, Product2> productos = new Map<String, Product2>(); 

        for(Product2 p : [SELECT Id, Variedad__c, Categoria__c, Unidad_de_Medida__c FROM Product2 WHERE Family = 'Semilla Fiscalizada' AND Variedad__c IN :variedadesProductos AND Unidad_de_Medida__c IN :umsProductos]){

            String key = p.Categoria__c + '_' + p.Variedad__c + '_' + p.Unidad_de_Medida__c;

            // Agregamos al map
            productos.put(key, p);  

        }   

        //Volvemos a recorrer las ventas y generamos las TRC ahora con toda la informacion recopilada
        
        //Lista que contendra las ventas a insertar
        List<Venta__c> toInsert = new List<Venta__c>();

        //Creamos el filtro adicionar
        String filtro = 'WHERE Id IN :ventasToClone';

        //Llamamos a un metodo auxiliar que hace un SELECT * FROM Venta__c asi se clonan todos los campos
        //incluyendo los obligatorios que podrian variar con el tiempo
        for(Venta__c v : Database.query(Utils.selectByName('Venta__c', filtro))){

            // Creamos la TRC que es de Semilla Fiscalizada

            //Verificamos si el producto de la venta esta en el map
            if(productosByIds.containsKey(v.Producto__c)){

                //Obtenemos el producto de la Venta
                Product2 productVentaC = productosByIds.get(v.Producto__c);

                //Armamos la key para verificar si existe un producto con
                
                // Family = 'Semilla Fiscalizada'
                // Categoria__c = 'Primera Multiplicación'
                String key = productVentaC.Categoria__c + '_' + productVentaC.Variedad__c + '_' + productVentaC.Unidad_de_Medida__c;

                if(productos.containsKey(key)){

                    //Obtenemos el producto
                    Product2 p = productos.get(key);

                    //Generamos la venta TRC
                    Venta__c ventaTRC = v.clone(false, true);

                    //Seteamos sus atributos
                    ventaTRC.Originante__c = v.Destinatario__c;
                    ventaTRC.Destinatario__c = v.Destinatario__c;

                    // Si la categoria del producto es 'Auditada' es 'RCA'
                    if(productVentaC.Categoria__c == 'Auditada'){
                        ventaTRC.Tipo_de_Venta__c = 'RCA';
                    }else {
                        ventaTRC.Tipo_de_Venta__c = 'TRC';
                    }

                    ventaTRC.Producto__c = p.Id;
                    ventaTRC.Cargado_desde_Archivo__c = false;

                    //Insertamos en la lista
                    toInsert.add(ventaTRC);


                }

                 // Creamos la TRC que es Regalia Comercial ó Si la categoria del producto es 'Auditada' es 'RCA'
            
                //Generamos la venta TRC
                Venta__c ventaTRC = v.clone(false, true);

                //Seteamos sus atributos
                ventaTRC.Originante__c = v.Destinatario__c;
                ventaTRC.Destinatario__c = v.Destinatario__c;

                // Si la categoria del producto es 'Auditada' es 'RCA'
                if(productVentaC.Categoria__c == 'Auditada'){
                    ventaTRC.Tipo_de_Venta__c = 'RCA';
                }else {
                    ventaTRC.Tipo_de_Venta__c = 'TRC';
                }

                ventaTRC.Cargado_desde_Archivo__c = false;

                //Insertamos en la lista
                toInsert.add(ventaTRC);

            }


           

        }

        if(toInsert.size() > 0){
            insertList(toInsert);
        }

        System.debug(LoggingLevel.INFO, toInsert);    
        System.debug(LoggingLevel.INFO, toInsert.size()); 

    }
    
    /**
    * @description Método que a partir de un listado de ventas TC elimina sus correspondientes CA
    * @param lista: Ventas que serán procesadas
    */
    public static void eliminarVentasCA(List<Venta__c> lista){

        //Set que contendra los posibles destinatarios de la CA
        Set<Id> idsDestinatarios = new Set<Id>(); 

        //Set que contendra los posible originantes de la CA
        Set<Id> idsOriginantes = new Set<Id>();

        //Set que contendra los posibles productos de la CA
        Set<Id> idsProductos = new Set<Id>();

        //Set que contendra los cultivos de la CA 
        Set<Id> idsCultivos = new Set<Id>();

        //Set que que contendra las campañas agricolas anteriores a la campaña agricola
        //de la venta TC
        Set<Id> idsCampanas = new Set<Id>();

        for(Venta__c venta : lista){

            if(venta.Tipo_de_Venta__c == 'TC'){

                //El Destinarario de la CA es el Originante de la TC
                idsDestinatarios.add(venta.Originante__c);

                //El Originante de la CA es el Destinatario de la TC
                idsOriginantes.add(venta.Destinatario__c);

                idsProductos.add(venta.Producto__c);

                idsCultivos.add(venta.Cultivo__c);

                idsCampanas.add(venta.Campana_Agricola__c);
            }

        }


        //Obtenemos las ventas de tipo CA que contienen los datos que hemos recopilado
        //anteriormente

        //Creamos un map que nos servira para relacionar una Venta TC con una Venta CA
        Map<Venta__c, Venta__c> ventas = new Map<Venta__c, Venta__c>();

        for(Venta__c ventaCA : [SELECT Id, Originante__c, Destinatario__c, Producto__c, Cultivo__c, Cantidad_Bolsas_40__c, Cantidad__c, Campana_Agricola__r.Nombre_de_Campana_Anterior__c,Tipo_de_Venta__c FROM Venta__c WHERE Destinatario__c IN :idsDestinatarios AND Originante__c IN :idsOriginantes AND Cultivo__c IN :idsCultivos AND Campana_Agricola__r.Nombre_de_Campana_Anterior__c IN :idsCampanas AND Tipo_de_Venta__c = 'CA']){

            //Recorremos las ventas 
            for(Venta__c venta : lista){

                if(venta.Tipo_de_Venta__c == 'TC'){

                    if(!ventas.containsKey(venta)){

                        if(venta.Destinatario__c == ventaCA.Originante__c && venta.Originante__c == ventaCA.Destinatario__c && venta.Cultivo__c == ventaCA.Cultivo__c && venta.Campana_Agricola__c == ventaCA.Campana_Agricola__r.Nombre_de_Campana_Anterior__c && venta.Cantidad_Bolsas_40__c == ventaCA.Cantidad_Bolsas_40__c && venta.Cantidad__c == ventaCA.Cantidad__c){
                            ventas.put(venta, ventaCA);
                        }

                    }    

                }        


            }

        }


        //Eliminamos las ventas CA
        if(ventas.values().size() > 0){
            System.debug(LoggingLevel.INFO, ventas.values());
            deleteList(ventas.values());
        }

    }


    /**
    * @description Método que a partir de un listado de ventas TC genera ventas del tipo CA
    * @param lista: Ventas que serán procesadas
    */
    public static void generarVentasTipoCA(List<Venta__c> lista){

        //Set de ids de las campañas
        Set<Id> idsCampanas = new Set<Id>();

        //Recorremos las ventas
        for(Venta__c venta : lista){

            if(venta.Tipo_de_Venta__c == 'TC'){
            
                //La campaña debe ser la campaña del año siguiente, almaceno el id de la campaña
                //para ir a buscar su campaña siguiente
                idsCampanas.add(venta.Campana_Agricola__c); 

            }
        }

        //Map para relacionar la campaña que tienen hoy por hoy las ventas y su campaña siguiente
        Map<String, String> campanas = new Map<String, String>();

        //Recorremos las campanas agricolas
        for(Campana_Agricola__c ca : [SELECT Id, Nombre_de_Campana_Anterior__c FROM Campana_Agricola__c WHERE Nombre_de_Campana_Anterior__c IN :idsCampanas]){

            campanas.put(ca.Nombre_de_Campana_Anterior__c, ca.Id);

        }

        //Lista que contendra las ventas a insertar
        List<Venta__c> toInsert = new List<Venta__c>();

        //Recorremos una vez mas las ventas
        for(Venta__c venta : lista){

            if(venta.Tipo_de_Venta__c == 'TC'){
                
                if(campanas.containsKey(venta.Campana_Agricola__c)){

                    //Obtenemos la campaña siguiente
                    String idCampanaSiguiente = campanas.get(venta.Campana_Agricola__c);

                    //Creamos una nueva venta a partir de una clonacion
                    Venta__c nuevaVenta = venta.clone();

                    //Intercambiamos el Originante y el Destinatario Respectivamente
                    nuevaVenta.Destinatario__c = venta.Originante__c;
                    nuevaVenta.Originante__c = venta.Destinatario__c;
                    nuevaVenta.Rol_Destinatario__c = 'Distribuidor';
                    nuevaVenta.Rol_Originante__c = 'Obtentor';

                    //Seteamos el tipo de venta como CA
                    nuevaVenta.Tipo_de_Venta__c = 'CA';

                    nuevaVenta.Cargado_desde_Archivo__c = false;

                    //Seteamos la nueva campaña
                    nuevaVenta.Campana_Agricola__c = idCampanaSiguiente;

                    //Agregamos a la lista de elementos a insertar
                    toInsert.add(nuevaVenta);
                }else{

                    venta.addError('No se cargo la campaña siguiente.');

                }

            }

        }


        if(toInsert.size() > 0)
            insertList(toInsert);



    }

    
    /**
    * @description Método que a partir de un listado de ventas setea el origen
    * @param lista: Ventas que serán procesadas
    */
    public static void agregaOrigen(List<Venta__c> lista){
        
        //Obtenemos los recordtype de Cuenta Distribuidor y Cuenta Comercio
        Id rtDistribuidor = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        Id rtComercio =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Comercio');
        
        //Recorremos las ventas y coleccionamos sus ids
        
        //Set para coleccionar el Id de las ventas
        Set<Id> idsVentas = new Set<Id>();
        
        //Set para coleccionar el Id de los Originantes
        Set<Id> idsOriginantes = new Set<Id>();
        
        //Set para coleccionar el Id de los productos
        Set<Id> idsProductos = new Set<Id>();
        
        for(Venta__c venta : lista){
            
            //Colecciono el id
            idsVentas.add(venta.Id);
            
            //Colecciono el Id de los Originantes
            idsOriginantes.add(venta.Originante__c);
            
            //Colecciono el Id de los Productos
            idsProductos.add(venta.Producto__c);
            
        }

        // Workaround para tener mas de 50000 registros de query
        Integer recordCount = [SELECT COUNT() FROM Venta__c WHERE Id NOT IN :idsVentas AND (Destinatario__r.RecordTypeId = :rtDistribuidor OR Destinatario__r.RecordTypeId = :rtComercio) AND (Destinatario__c IN :idsOriginantes) AND (Producto__c IN :idsProductos)];
        Integer sizeBlock = recordCount/Limits.getLimitQueryRows() + (math.mod(recordCount,Limits.getLimitQueryRows())!=0?1:0);

        //Recorro las ventas, pero solo aquellas cuyo originante es un Comercio o un Distribuidor
        
        //Por cada Originante colecciono los productos que que estan en las ventas
        //donde el era Destinatario
        Map<String,Map<String,Set<String>>> agrupador = new Map<String,Map<String,Set<String>>>();
        
        for(Integer i=0;i<sizeBlock;i++){   

            // Si estamos por superar el limite de Queries
            if(Limits.getQueries() >= Limits.getLimitQueries()){
                break;
            }

            for(Venta__c vt : [SELECT Destinatario__c, Originante__c,Campana_Agricola__c,Producto__c, Id FROM Venta__c WHERE Id NOT IN :idsVentas AND (Destinatario__r.RecordTypeId = :rtDistribuidor OR Destinatario__r.RecordTypeId = :rtComercio) AND (Destinatario__c IN :idsOriginantes) AND (Producto__c IN :idsProductos)  LIMIT :Limits.getLimitQueryRows()]){
                
                //Obtengo los datos que necesito
                String idDestinatario = vt.Destinatario__c;
                String idOriginante = vt.Originante__c;
                String idCampana = vt.Campana_Agricola__c;
                String idProducto = vt.Producto__c;

                idsVentas.add(vt.Id);
                
                if(idDestinatario != idOriginante){
                
                    //Si no esta creada la entrada en el map, la creamos
                    if(!agrupador.containsKey(idDestinatario)){
                        
                        //Creamos la entrada
                        agrupador.put(idDestinatario,new Map<String,Set<String>>());
                        
                    }
                    
                    //Obtengo el Map de Campañas y Productos
                    Map<String,Set<String>> productosByCampanas =  agrupador.get(idDestinatario);
                    
                    //Si no esta creada la entrada en el map, la creamos
                    if(!productosByCampanas.containsKey(idCampana)){
                        
                        //Creamos la entrada
                        productosByCampanas.put(idCampana,new Set<String>());
                        
                    }
                    
                    //Obtengo la lista de productos y lo agrego
                    Set<String> productos = productosByCampanas.get(idCampana);
                    
                    //Agregoel producto
                    productos.add(idProducto);
                    
                    System.Debug(productos);
                
                }
                
            }
        }
        
        System.Debug(LoggingLevel.INFO,agrupador);
        
        //Recorremos nuevamente las ventas, y lo que hacemos es checkear si el producto habia sido
        //Comprado antes, si no se compro la venta la colocamos como sin origen
        for(Venta__c venta : lista){
            
            //Por defecto indicamos que la venta no tiene origen
            venta.Sin_Origen__c = true;
            
            //Verifico si esta la entrada en el map, que contiene los productos que me han sido "vendidos"
            //Osea tienen como Destinatario al Originante que estamos procesando
            if(agrupador.containsKey(venta.Originante__c)){
                
                //Obtengo el Map de Campañas y Productos
                Map<String,Set<String>> productosByCampanas =  agrupador.get(venta.Originante__c);
                
                //Si no esta creada la entrada en el map, la creamos
                if(!productosByCampanas.containsKey(venta.Campana_Agricola__c)){
                    
                    //Creamos la entrada
                    productosByCampanas.put(venta.Campana_Agricola__c,new Set<String>());
                    
                }
                
                //Obtengo la lista de productos 
                Set<String> productos = productosByCampanas.get(venta.Campana_Agricola__c);
                
                //Si el producto de la venta esta en la lista de productos que alguna vez adquiri como Destinatario
                //entonces la venta tiene origen
                if(productos.contains(venta.Producto__c)){
                    
                    venta.Sin_Origen__c = false;
                    
                }
                
            }
            
            //Luego si la venta tiene distintos originante y destinatario, agrego los datos al map
            //Para futuro proceso en el lote
            if(venta.Destinatario__c != venta.Originante__c){
                
                //Si no esta creada la entrada en el map, la creamos
                if(!agrupador.containsKey(venta.Destinatario__c)){
                    
                    //Creamos la entrada
                    agrupador.put(venta.Destinatario__c,new Map<String,Set<String>>());
                    
                }
                
                //Obtengo el Map de Campañas y Productos
                Map<String,Set<String>> productosByCampanas =  agrupador.get(venta.Destinatario__c);
                
                //Si no esta creada la entrada en el map, la creamos
                if(!productosByCampanas.containsKey(venta.Campana_Agricola__c)){
                    
                    //Creamos la entrada
                    productosByCampanas.put(venta.Campana_Agricola__c,new Set<String>());
                    
                }
                
                //Obtengo la lista de productos y lo agrego
                Set<String> productos = productosByCampanas.get(venta.Campana_Agricola__c);
                
                //Agregoel producto
                productos.add(venta.Producto__c);
                
            }
            
            
            
        }
        
        System.Debug(LoggingLevel.INFO,agrupador);
        
        
    }
    
    
    /**
    * @description Método que a partir de un listado de ventas las inserta en la Base de Datos en lotes de no mas de 200 registros
    * @param lista: Ventas que serán procesadas
    */
    public static void insertList(List<Venta__c> lista){
        List<Venta__c> toInsert = new List<Venta__c>();
        for(Venta__c v : lista){
            toInsert.add(v);
        
            if(toInsert.size() == 200){
                insert toInsert;
                toInsert.clear();
            }
        }
        
        if(toInsert.size() > 0){
            insert toInsert;
            toInsert.clear();
        }

    }


    /**
    * @description Método que a partir de un listado de ventas las elimina de la Base de Datos en lotes de no mas de 200 registros
    * @param lista: Ventas que serán procesadas
    */
    public static void deleteList(List<Venta__c> lista){
        List<Venta__c> toDelete = new List<Venta__c>();
        for(Venta__c v : lista){
            toDelete.add(v);
        
            if(toDelete.size() == 200){
                delete toDelete;
                toDelete.clear();
            }
        }
        
        if(toDelete.size() > 0){
            delete toDelete;
            toDelete.clear();
        }

    }

    /**
    * @description Metodo de Insercion por lotes Parciales, es decir si un registro falla, intenta con el que le sigue
    * @param lista: Ventas que serán procesadas
    */
    public static List<Database.SaveResult> insertPartialList(List<Venta__c> lista){

        List<Database.SaveResult> svrs = new List<Database.SaveResult>();

        List<Venta__c> toInsert = new List<Venta__c>();
        for(Venta__c v : lista){
            toInsert.add(v);
        
            if(toInsert.size() == 200){
                svrs.addAll(Database.insert(toInsert,false));
                toInsert.clear();
            }
        }
        
        if(toInsert.size() > 0){
            svrs.addAll(Database.insert(toInsert,false));
            toInsert.clear();
        }

        return svrs;
    }


    /**
    * @author Maximo Martinez
    * @date 19/11/2014
    * @description Clase Auxiliar para calculo de Saldos
    */
    public class AuxSaldos{

        public String campana {get; set;}
        public String obtentor {get; set;}
        public String variedad {get; set;}
        public String tipo {get; set;}
        public String categoria {get; set;}
        public String um {get; set;}
        public Double cantidad {get; set;}
        public Double cantidadByObtentor {get; set;}
        public Double saldoTotal {get; set;}

        public AuxSaldos(){
            campana = '';
            obtentor = '';
            variedad = '';
            tipo = '';
            categoria = '';
            um = '';
            cantidad = 0;
            cantidadByObtentor = 0;
            saldoTotal = 0;
        }

    }
}