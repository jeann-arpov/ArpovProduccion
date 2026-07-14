public without sharing class UtilsCasos{
    
    public static final String ASUNTO_DUP = 'Gestionar Respuesta';
    private static final String ASUNTO_FACTURA = 'Gestionar Cobranza';
    private static final String ASUNTO_VENTA = 'Gestionar Venta';
    private static final String ASUNTO_PADRE = 'Gestion de CUIT';
    
    public static final String STATUS_CERRADO = 'Cerrado';
    
    public static final String STATUS_ABIERTO = 'Abierto';

    /**
    * @author Maximo Martinez
    * @date 17/09/2014
    * @description Metodo que verifica si una Transaccion que tenia un caso creado, y ahora no tiene items de dup, ya no tenga mas el caso creado
    */
    public static void eliminarCasosDUPS(List<Item_de_DUP__c> lista){

        //Obtenemos el RecordType de una DUP
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');
        
        //Obtenemos el RecordType de un Padre
        Id rtPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');
        
        //Lista que contendra los casos a insertar
        List<Case> casosToInsert = new List<Case>();
        
        //Set para coleccionar los ids de las cuentas de las transacciones
        Set<Id> idsCuentas = new Set<Id>();
        
        //Set para coleccionar los ids de las transacciones
        Set<Id> idsTransacciones = new Set<Id>();

        //Set para coleccionar las transacciones que efectivamente tienen casos DUP
        Set<Id> idsTransaccionesConCaso = new Set<Id>();
        
        //Set con los ids de las transacciones a las cual voy a eliminar su caso porque no tienen items de dup
        Set<Id> idsTransaccionesAEliminarCasos = new Set<Id>();

        //Ciclamos sobre los item de dup y coleccionamos los ids de las transacciones
        for(Item_de_DUP__c item : lista){
            idsTransacciones.add(item.Transaccion__c);
        }

        //Checkeamos si las transacciones ya tenian un caso y coleccionamos su id
        for(Case caso : [SELECT Id, DUP__c FROM Case WHERE DUP__c IN :idsTransacciones AND RecordTypeId = :rtId]){
            idsTransaccionesConCaso.add(caso.DUP__c);
        }

        //Obtenemos por cada transaccion sus item de dup y en aquella que no tienen item de dup eliminamos su caso
        for(Transaccion__c transaccion : [SELECT Id, (SELECT Id FROM Item_de_DUP__r LIMIT 1) FROM Transaccion__c WHERE Id IN :idsTransaccionesConCaso]){

            if(transaccion.Item_de_DUP__r.size() == 0){

                idsTransaccionesAEliminarCasos.add(transaccion.Id);

            }

        }


        //Lista que contendra los casos a eliminar
        List<Case> toDelete = new List<Case>();

        for(Case caso : [SELECT Id, DUP__c FROM Case WHERE DUP__c IN :idsTransaccionesAEliminarCasos AND RecordTypeId = :rtId]){
            toDelete.add(caso); 
        }


        //Llamamos al metodo que elimina casos
        if(toDelete.size() > 0){
            Utils.deleteList(toDelete,true);
        }


    }

    

    public static void crearCasosDups(List<Item_de_DUP__c> lista){
        /*
        //Obtenemos el RecordType de una DUP
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');
        
        //Obtenemos el RecordType de un Padre
        Id rtPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');
        
        //Lista que contendra los casos a insertar
        List<Case> casosToInsert = new List<Case>();
        
        //Set para coleccionar los ids de las cuentas de las transacciones
        Set<Id> idsCuentas = new Set<Id>();
        
        //Set para coleccionar los ids de las transacciones
        Set<Id> idsTransacciones = new Set<Id>();
        
        //Ciclamos sobre los item de dup y coleccionamos los ids de las transacciones
        for(Item_de_DUP__c item : lista){
            idsTransacciones.add(item.Transaccion__c);
        }

        //Checkeamos si las transacciones ya tenian un caso y eliminamos dicha transaccion del map
        for(Case caso : [SELECT Id, DUP__c FROM Case WHERE DUP__c IN :idsTransacciones AND RecordTypeId = :rtId]){
            idsTransacciones.remove(caso.DUP__c);
        }
        
        for(Transaccion__c transaccion : [SELECT Id,Nombre_de_la_cuenta__c FROM Transaccion__c WHERE Id IN : idsTransacciones AND Subestado__c = 'Positiva']){
            idsCuentas.add(transaccion.Nombre_de_la_cuenta__c);
        }
        
        //Map que contendra los casos padre que tiene cada transaccion (si hay)
        Map<Id,Case> casosByTransaccion = new Map<Id,Case>();
        
        //Ciclamos sobre los casos padre, de las cuentas
        for(Case caso : [SELECT Id,AccountId,Propietario_original__c, Status FROM Case WHERE AccountId IN : idsCuentas AND RecordTypeId = :rtPId]){
            if(!casosByTransaccion.containsKey(caso.AccountId)){
                casosByTransaccion.put(caso.AccountId,caso);
            }
        }
        
        //Recorremos las cuentas asociadas a las transacciones
        
        for(Account cuenta : [SELECT Id,Operador__c FROM Account WHERE Id IN :idsCuentas]){
  
            //Si la transaccion no tiene un caso padre, lo creamos
            if(!casosByTransaccion.containsKey(cuenta.Id)){
            
                //Creamos un caso
                Case caso = new Case();
                
                //Seteamos la cuenta a la que esta asociada el caso
                caso.AccountId = cuenta.Id;
                
                //Seteamos el asunto
                caso.Subject = ASUNTO_PADRE;

                caso.Status = STATUS_ABIERTO;
                
                //Seteamos el RecordType Id del Record Type DUP
                caso.RecordTypeId = rtPId;
                
                //Asociamos al Operador
                caso.Propietario_original__c = cuenta.Operador__c;
                
                if(cuenta.Operador__c != null)
                    caso.OwnerId = cuenta.Operador__c;
                
                //Insertamos el caso en la lista de casos a insertar
                casosToInsert.add(caso); 
                
                //Lo agragamos al map de casos
                casosByTransaccion.put(cuenta.Id,caso);
            
            }     
            
        }
        
        if(casosToInsert.size() > 0){
            insertList(casosToInsert);
            casosToInsert.clear();
        }
        
        //Recorremos las transacciones y por cada una creamos un hijo y lo asociamos al padre de la cuenta
        for(Transaccion__c transaccion : [SELECT Id, Campana__c, Nombre_de_la_cuenta__c, Nombre_de_la_cuenta__r.Operador__c, Obtentor__c, Estado__c FROM Transaccion__c WHERE Id IN :idsTransacciones AND Subestado__c = 'Positiva']){
            
            if(casosByTransaccion.containsKey(transaccion.Nombre_de_la_cuenta__c)){
            
                //Obtenemos el padre
                Case cP = casosByTransaccion.get(transaccion.Nombre_de_la_cuenta__c);
                
                //Creamos un caso
                Case caso = new Case();
                
                //Seteamos el Item de DUP
                caso.DUP__c = transaccion.Id;
                
                //Seteamos la cuenta asociada al caso
                caso.AccountId = cP.AccountId;
                
                //Seteamos el obtentor
                caso.Obtentor__c = transaccion.Obtentor__c;
                
                //Seteamos el asunto
                caso.Subject = ASUNTO_DUP;
                
                //Seteamos el RecordType Id del Record Type DUP
                caso.RecordTypeId = rtId;
                
                //Seteamos el caso padre
                caso.ParentId = cP.Id;

                caso.Status = STATUS_ABIERTO;
                
                caso.Propietario_original__c = cP.Propietario_original__c;
                
                if(transaccion.Nombre_de_la_cuenta__r.Operador__c != null)
                    caso.OwnerId = transaccion.Nombre_de_la_cuenta__r.Operador__c;
                
                //Seteamos la campaña
                caso.Campana__c = transaccion.Campana__c;

                if(transaccion.Estado__c == 'Respondida' || transaccion.Estado__c == 'Respondida Parcialmente')
                    caso.Status = STATUS_CERRADO;

                //Insertamos el caso en la lista de casos a insertar
                casosToInsert.add(caso); 
            
            }
        }
        
        if(!casosToInsert.isEmpty())
            insertList(casosToInsert);
        */      
    }
    
    /*
    public static void crearCasosFromFacturas(Set<Id> idsOportunidades){
        
        //Obtenemos el RecordType de una Cobranza
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');
        
        //Obtenemos el RecordType de un Padre
        Id rtPId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');
        
        //Set para coleccionar el id de las cuentas asociadas a los casos
        Set<Id> idsCuentas = new Set<Id>();
        
        //List que contendra los cases a Insertar
        List<Case> casosToInsert = new List<Case>();
        
        //Map para contener los casos padres por oportunidad
        Map<Id, Case> casosByAccount = new Map<Id, Case>();
        
        //Recorremos las oportunidades y coleccionamos sus cuentas asociadas
        for(Opportunity oportunidad : [SELECT Id, AccountId FROM Opportunity WHERE Id IN :idsOportunidades]){
            idsCuentas.add(oportunidad.AccountId);
        }
        
        //Ciclamos sobre los casos padres de las cuentas
        for(Case caso : [SELECT Id,AccountId,Propietario_original__c FROM Case WHERE AccountId IN : idsCuentas AND RecordTypeId = :rtPId]){
            if(!casosByAccount.containsKey(caso.AccountId)){
                casosByAccount.put(caso.AccountId,caso);
            }
        }
        
        //Set que contendra las oportunidades que ya tienen casos para evitar crear mas de un caso cobranza
        Set<Id> idsOportunidadesConCasos = new Set<Id>();

        for(AggregateResult ag : [SELECT Factura__c Factura, COUNT(Id) Cantidad FROM Case WHERE Factura__c IN :idsOportunidades AND RecordTypeId = :rtId GROUP BY Factura__c]){

            //Obtengo el id de la factura
            Id idFactura = (Id)ag.get('Factura');
            Double cantidad = (Double)ag.get('Cantidad');

            //Si la cantidad es mayor a 0 agrego la factura al set
            if(cantidad > 0){

                idsOportunidadesConCasos.add(idFactura);

            }
        }
        

        //Recorremos las cuentas asociadas a las oportunidades
        for(Account cuenta : [SELECT Id,Operador__c, Operador_de_Cobranza__c FROM Account WHERE Id IN :idsCuentas]){
            
            //Si la transaccion no tiene un caso padre, lo creamos
            if(!casosByAccount.containsKey(cuenta.Id)){
                
                //Creamos un caso
                Case caso = new Case();
                
                //Seteamos la cuenta a la que esta asociada el caso
                caso.AccountId = cuenta.Id;
                
                //Seteamos el asunto
                caso.Subject = ASUNTO_PADRE;
                
                caso.Propietario_original__c = cuenta.Operador__c;

                caso.Status = STATUS_ABIERTO;
                
                //Seteamos el RecordType Id del Record Type DUP
                caso.RecordTypeId = rtPId;
                
                if(cuenta.Operador__c != null)
                    caso.OwnerId = cuenta.Operador__c;
                
                //Insertamos el caso en la lista de casos a insertar
                casosToInsert.add(caso); 
                
                //Lo agragamos al map de casos
                casosByAccount.put(cuenta.Id,caso);
            
            }     
            
        }
        
        //Hacemos la insercion de los casos
        if(casosToInsert.size() > 0){
            
            //Llamamos al metodo de insercion por lotes
            insertList(casosToInsert);
            
            //Borramos la lista
            casosToInsert.clear();
            
        }
        
        //Ciclamos sobre las oportunidades y creamos nuevos hijos
        for(Opportunity oportunidad : [SELECT Id, Account.Operador_de_Cobranza__c , Account.Operador__c, Campana__c,AccountId,Obtentor__c FROM Opportunity WHERE Id IN :idsOportunidades AND Id NOT IN :idsOportunidadesConCasos]){
            
            if(casosByAccount.containsKey(oportunidad.AccountId)){

                Id idOperador = (String.isNotEmpty(oportunidad.Account.Operador_de_Cobranza__c))?oportunidad.Account.Operador_de_Cobranza__c:oportunidad.Account.Operador__c;

                //Obtenemos el caso padre
                Case cP = casosByAccount.get(oportunidad.AccountId);
                
                //Creamos un caso Hijo
                Case caso = new Case();
                
                //Seteamos la cuenta
                caso.AccountId = cP.AccountId;
                
                //Seteamos el asunto
                caso.Subject = ASUNTO_FACTURA;
                
                //Seteamos la oportunidad
                caso.Factura__c = oportunidad.Id;
                
                //Seteamos el Record Type Id al caso que sera el del tipo Cobranzas
                caso.RecordTypeId = rtId;
                
                //Seteamos el Parent
                caso.ParentId = cP.Id;

                caso.Status = STATUS_ABIERTO;
                
                caso.Propietario_original__c = cP.Propietario_original__c;
                
                if(idOperador != null)
                    caso.OwnerId = idOperador;
                
                //Seteamos el obtentor
                caso.Obtentor__c = oportunidad.Obtentor__c;
                
                caso.Campana__c = oportunidad.Campana__c;
                
                System.Debug(LoggingLevel.INFO,'Crear Caso Factura'+oportunidad.Id);
                
                //Insertamos el caso en la lista de casos a insertar
                casosToInsert.add(caso);
                
            }
        }
    
        
        if(!casosToInsert.isEmpty())
            //Llamamos al metodo de insercion por lotes
            insertList(casosToInsert);
        
        
    }*/
    
    public static void cerrarCasosFromVentas(List<Venta__c> lista){
        
        //Obtenemos el RecordType de Ventas
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');
        
        //Obtenemos el RecordType para un Distribuidor
        Id rtD = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        
        //Obtenemos el RecordType para un Comercio
        Id rtC = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Comercio');
        
        //Set para coleccionar el id de las ventas
        Set<Id> idsVentas = new Set<Id>();
        
        //Recorremos las ventas y coleccionamos los ids de estas
        for(Venta__c venta : lista){
            idsVentas.add(venta.Id);
        }
        
        System.Debug(LoggingLevel.INFO, idsVentas);
        
        //Set que contendra los ids de los originantes que son Distribuidor o Comercio
        Set<Id> idsOriginantes = new Set<Id>();
        
        //Obtenemos los ids de los originantes que son Distribuidor o Comercio
        for(Venta__c venta : [SELECT Id, Originante__c FROM Venta__c WHERE (Originante__r.RecordTypeId = :rtD OR Originante__r.RecordTypeId = :rtC) AND Id IN :idsVentas]){
            
            idsOriginantes.add(venta.Originante__c);
            
        }
        
        //Map para coleccionar las ventas por cultivo por campaña por obtentor y por producto
        Map<String,List<Venta__c>> groupByAll =new Map<String,List<Venta__c>>();
        
        //Lista de ventas
        List<Venta__c> ventas = null;
        
        //Recorremos todas las ventas que tienen las cuentas
        for(Venta__c venta : [SELECT Id, Producto__r.Variedad__c, Categoria__c, UM__c,Tipo_de_Producto__c, Cultivo__c,Destinatario__c, Id_Obtentor__c,Originante__c, Cantidad_Bolsas_40__c, Campana_Agricola__c, Producto__c FROM Venta__c WHERE (Destinatario__c IN :idsOriginantes OR Originante__c IN :idsOriginantes)]){
            
            System.Debug(LoggingLevel.INFO,venta.Id);
            
            Id id = null;
            
            if(venta.Destinatario__c != venta.Originante__c){
            
                if(idsOriginantes.contains(venta.Destinatario__c)){
                    id = venta.Destinatario__c;
                }else{
                    id = venta.Originante__c;
                }

                String key = String.valueOf(Id)+String.valueOf(venta.Cultivo__c)+String.valueOf(venta.Campana_Agricola__c)+String.valueOf(venta.Id_Obtentor__c)+String.valueOf(venta.Producto__r.Variedad__c)+String.valueOf(venta.Tipo_de_Producto__c)+String.valueOf(venta.Categoria__c)+String.valueOf(venta.UM__c);
                
                //Si no esta creo la entrada
                if(!groupByAll.containsKey(key)){
                    groupByAll.put(key,new List<Venta__c>());
                }
                
                groupByAll.get(key).add(venta);

            }
            
        }
        
        //Set de Ventas cuyos casos debo cerrar
        Set<Id> ventasToClose = new Set<Id>();
        
        //Recorro el Map de Cuentas
        for(String key : groupByAll.keySet()){
            
            //Obtengo la lista de ventas
            ventas =  groupByAll.get(key);
            
            //Sumarizador de cantidades de compras
            Double cantidadesCompra = 0;
            
            //Set de posibls ventas a cerrar
            Set<Id> posiblesCierres = new Set<Id>();
            
            //Recorro las ventas y sumarizo las compras
            for(Venta__c venta : ventas){

                Id idCuenta;

                if(idsOriginantes.contains(venta.Destinatario__c)){
                    idCuenta = venta.Destinatario__c;
                }else{
                    idCuenta = venta.Originante__c;
                }

                
                //Verificamos si es una compra
                if((venta.Destinatario__c != venta.Originante__c) && (venta.Destinatario__c == idCuenta)){
                    cantidadesCompra += venta.Cantidad_Bolsas_40__c;
                    posiblesCierres.add(venta.Id);
                }
                
            }
            
            if(cantidadesCompra > 0){
                
                //Recorro las ventas y cierro las ventas que me quedan en 0
                for(Venta__c venta : ventas){
                    
                    Id idCuenta;

                    if(idsOriginantes.contains(venta.Destinatario__c)){
                        idCuenta = venta.Destinatario__c;
                    }else{
                        idCuenta = venta.Originante__c;
                    }


                    //Verificamos si es una venta
                    if((venta.Destinatario__c != venta.Originante__c) && (venta.Originante__c == idCuenta)){
                        
                        //Resto a las cantidades
                        cantidadesCompra -= venta.Cantidad_Bolsas_40__c;
                        
                    }
                    
                }
                
                if(cantidadesCompra == 0){
                    ventasToClose.addAll(posiblesCierres);
                }
            
            }

        }
        
        System.Debug(LoggingLevel.INFO,ventasToClose);
        
        
        //Lista de casos a cerrar
        List<Case> casosToUpdate = new List<Case>();
        for(Case caso : [SELECT Id, Status FROM Case WHERE RecordTypeId = :rtId AND AccountId IN :idsOriginantes AND Venta__c IN :ventasToClose AND Status != :STATUS_CERRADO]){
            
            //Cerramos el caso
            caso.Status = STATUS_CERRADO;
            
            //Insertamos el caso en la lista de casos a cerrar
            casosToUpdate.add(caso);
            
        }
        
        System.Debug(LoggingLevel.INFO,casosToUpdate);
        
        if(casosToUpdate.size() > 0){
            Utils.updateList(casosToUpdate,true);
        }
        
    }
    
    
    // public static void crearCasosFromVentas(List<Venta__c> lista){
        
    //     //Obtenemos el RecordType de Ventas
    //     Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');
         
    //     //Obtenemos el RecordType para un Distribuidor
    //     Id rtD = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        
    //     //Obtenemos el RecordType para un Comercio
    //     Id rtC = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Comercio');
            
    //     //Set para coleccionar el id de las ventas
    //     Set<Id> idsVentas = new Set<Id>();
        
    //     //Lista que contendra los casos a insertar
    //     List<Case> casosToInsert = new List<Case>();
        
    //     //Recorremos las ventas y coleccionamos los ids de estas
    //     for(Venta__c venta : lista){
    //         idsVentas.add(venta.Id);
    //     }
        
    //     //Set para coleccionar los ids destinatarios que sean Distribuidor o Comercio
    //     Set<Id> idsDestinatarios = new Set<Id>();
        
    //     //Set para coleccionar los ids originates
    //     Set<Id> idsOriginantes = new Set<Id>();
        
    //     //Map para almacenar los casos por cuenta, por originante y por campaña
    //     Map<Id,Map<Id,Map<Id,Case>>> agrupador = new Map<Id,Map<Id,Map<Id,Case>>>();
        
    //     //Recorremos las ventas cuyo destinatario es Distribuidor o Comercio
    //     for(Venta__c venta : [SELECT Id, Campana_Agricola__c,  Destinatario__r.Operador__c ,Destinatario__r.Id, Originante__c FROM Venta__c WHERE (Destinatario__r.RecordTypeId = :rtD OR Destinatario__r.RecordTypeId = :rtC) AND Id IN :idsVentas]){
            
    //         //Colecciono el id del destinatario
    //         idsDestinatarios.add(venta.Destinatario__c);
            
    //         //Colecciono el id del originante
    //         idsOriginantes.add(venta.Originante__c);
             
    //     }
        
       
        
    //     //Recorremos los casos venta creados para los Originantes y Destinatarios
    //     for(Case caso : [SELECT AccountId,Obtentor__c,Campana__c FROM Case WHERE RecordTypeId = :rtId AND AccountId IN :idsDestinatarios AND Obtentor__c IN :idsOriginantes]){
                
    //         //Verificamos si el Destinatario esta en el Map
    //         if(!agrupador.containsKey(caso.AccountId)){
                
    //             //Creamos la entrada en el map
    //             agrupador.put(caso.AccountId, new Map<Id,Map<Id,Case>>());
                
    //         }
            
    //         //Obtenemos la agrupacion por cuenta Destinatario
    //         Map<Id,Map<Id,Case>> agrupadorPorObtentor = agrupador.get(caso.AccountId);
            
    //         if(!agrupadorPorObtentor.containsKey(caso.Obtentor__c)){
                
    //             //Creamos la entrada en el map
    //             agrupadorPorObtentor.put(caso.Obtentor__c,new Map<Id,Case>());
                
    //         }
            
    //         //Obtenemos la agrupacion por Campaña
    //         Map<Id,Case> agrupadorPorCampania = agrupadorPorObtentor.get(caso.Obtentor__c);
            
    //         if(!agrupadorPorCampania.containsKey(caso.Campana__c)){
                
    //             //Creamos la entrada en el map
    //             agrupadorPorCampania.put(caso.Campana__c,caso);
                
    //         }
            
           
                
    //     }
        
    //     System.Debug(LoggingLevel.INFO,agrupador);
        
    //     //Recorremos las ventas nuevamente y vamos creando casos en funcion de lo siguiente
    //     //Que no exista ya un caso con el mismo Destinatario Y mismo Originante, para la Misma Campaña
    //     for(Venta__c venta : [SELECT Id, Campana_Agricola__c, Destinatario__r.Operador__c,Destinatario__r.Operador_Venta__c ,Destinatario__r.Id, Originante__c FROM Venta__c WHERE (Destinatario__r.RecordTypeId = :rtD OR Destinatario__r.RecordTypeId = :rtC) AND Id IN :idsVentas]){
            
    //         //Solo generamos casos de ventas cuyo Destinatario y Originante sean distintos
           
    //         if(venta.Destinatario__c != venta.Originante__c){
            
    //             //Verificamos si el Destinatario esta en el Map
    //             if(!agrupador.containsKey(venta.Destinatario__c)){
                    
    //                 //Creamos la entrada en el map
    //                 agrupador.put(venta.Destinatario__c, new Map<Id,Map<Id,Case>>());
                    
    //             }
                
    //             //Obtenemos la agrupacion por cuenta Destinatario
    //             Map<Id,Map<Id,Case>> agrupadorPorObtentor = agrupador.get(venta.Destinatario__c);
                
    //             if(!agrupadorPorObtentor.containsKey(venta.Originante__c)){
                    
    //                 //Creamos la entrada en el map
    //                 agrupadorPorObtentor.put(venta.Originante__c,new Map<Id,Case>());
                    
    //             }
                
    //             //Obtenemos la agrupacion por Campaña
    //             Map<Id,Case> agrupadorPorCampania = agrupadorPorObtentor.get(venta.Originante__c);
                
    //             System.Debug(LoggingLevel.INFO,agrupadorPorCampania);
                
    //             /* Se comenta a pedido - ticket 811 */
    //             // if(!agrupadorPorCampania.containsKey(venta.Campana_Agricola__c)){
                
    //                 // System.Debug(LoggingLevel.INFO,'Test');
                    
    //                 // //Creamos un caso
    //                 // Case caso = new Case();
                    
    //                 // //Seteamos algunos datos
    //                 // caso.Venta__c = venta.Id;
    //                 // caso.Obtentor__c = venta.Originante__c;
    //                 // caso.AccountId = venta.Destinatario__r.Id;
    //                 // caso.Propietario_original__c = venta.Destinatario__r.Operador__c;
    //                 // caso.Subject = ASUNTO_VENTA;
    //                 // caso.RecordTypeId = rtId;
    //                 // caso.Campana__c = venta.Campana_Agricola__c;
    //                 // caso.Status = STATUS_ABIERTO;
                    
    //                 // if(venta.Destinatario__r.Operador_Venta__c != null)
    //                 //     caso.OwnerId = venta.Destinatario__r.Operador_Venta__c;
                    
    //                 // //Insertamos el caso en la lista de casos
    //                 // casosToInsert.add(caso);
                    
    //                 //Creamos la entrada en el map, esto ayudara a evitar casos duplicados
    //             //     agrupadorPorCampania.put(venta.Campana_Agricola__c, caso);
                    
    //             // }
            
    //         }
            
    //     }
        
    //     System.Debug(LoggingLevel.INFO,agrupador);
        
    //     //Insertamos los casos
    //     if(casosToInsert.size() > 0){
            
    //         //Cremos una copia de la lista
    //         List<Case> nuevosCasos = new List<Case>();
            
    //         //Agregamos los casos a la lista
    //         nuevosCasos.addAll(casosToInsert);
            
    //         //Insertamos los casos
    //         Utils.insertList(casosToInsert,true);
            
    //         //Agrupamos los casos si es que no tienen agrupacion
    //         agruparCasosVentas(nuevosCasos);        
    //     }
        
    // }
    
    public static void cerrarCasosFromDups(List<Transaccion__c> lista){

        //Obtenemos el RecordType de una DUP
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Lista que contendra los casos a actualizar
        List<Case> casosToUpdate = new List<Case>();
        
        //Set para almacenar los id de las DUP
        Set<Id> idsTransacciones = new Set<Id>();
        
        //Recorremos los Item de Dup
        for(Transaccion__c transaccion : lista){
            idsTransacciones.add(transaccion.Id);
        }
        
        //Obtenemos los casos de las transacciones
        for(Case caso : [SELECT Id FROM Case WHERE DUP__c IN :idsTransacciones AND RecordTypeId =:rtId AND Status != :STATUS_CERRADO ]){
            //Pasamos el caso a cerrado
            caso.Status = STATUS_CERRADO;
            casosToUpdate.add(caso);
        }
        
        if(casosToUpdate.size() > 0){
            Utils.updateList(casosToUpdate,true);
        }
        
        
    }
    
    public static void cerrarCasosFromFactura(Set<Id> idsOportunidades){

        //Obtenemos el RecordType de una Cobranza
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');
        
        //Lista que contendra los casos a actualizar
        List<Case> casosToUpdate = new List<Case>();
        
        //Obtenemos los casos de las oportunidades
        for(Case caso : [SELECT Id FROM Case WHERE Factura__c IN :idsOportunidades AND Status != :STATUS_CERRADO AND RecordTypeId = :rtId]){
            //Pasamos el caso a cerrado
            caso.Status = STATUS_CERRADO;
            casosToUpdate.add(caso);
        }
        
        if(casosToUpdate.size() > 0){
            Utils.updateList(casosToUpdate,true);
        }
        
    }
    
    /*
    public static void reabrirCasosCobranzas(Set<Id> idsOportunidades){

        //Obtenemos el RecordType de una Cobranza
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        //Lista que contendra los casos a actualizar
        List<Case> casosToUpdate = new List<Case>();
        
        //Obtenemos los casos de las oportunidades
        for(Case caso : [SELECT Id FROM Case WHERE Factura__c IN :idsOportunidades AND Status = :STATUS_CERRADO AND RecordTypeId = :rtId]){
            //Pasamos el caso a abierto
            caso.Status = STATUS_ABIERTO;
            casosToUpdate.add(caso);
        }
        
        if(casosToUpdate.size() > 0){
            updateList(casosToUpdate);
        }
        
        
    }*/
    
    public static void agruparCasosVentas(List<Case> casos){
        
        //Recorremos los casos y coleccionamos los ids de sus cuentas
        
        //Set para coleccionar los ids de las cuentas
        Set<Id> idsAccounts = new Set<Id>();
        
        for(Case caso : casos){
            
            idsAccounts.add(caso.AccountId);
            
        }
        
        //Buscamos los casos padres de dichos casos y si no los encontramos creamos casos padre y luego
        //los agrupamos
        
        //Obtenemos el record type que corresponde a los casos padres de ventas
        Id rtId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_Venta');
        
        //Map para agrupar los casos de venta padre por cuenta
        Map<Id,Case> parentCasesByAccounts = new Map<Id,Case>();
        
        for(Case caso: [SELECT Id,AccountId, Account.Operador_Venta__c FROM Case WHERE AccountId IN :idsAccounts AND RecordTypeId = :rtId]){
            
            parentCasesByAccounts.put(caso.AccountId, caso);
            
        }
        
        //Para las cuentas que no existen casos de venta padre, creamos uno
        
        //Lista que contendra los casos a insertar
        List<Case> casosToInsert = new List<Case>();
        
        /* se comenta a pedido - ticket 811*/
        // for(Account cuenta : [SELECT Id, Operador_Venta__c FROM Account WHERE Id IN :idsAccounts]){
            
        //     //Si el id no es una llave del map, entonces creamos un caso
        //     if(!parentCasesByAccounts.containsKey(cuenta.Id)){
                
        //         //Creamos el caso
        //         Case caso = new Case();
                
        //         //Seteamos algunos casos
        //         caso.AccountId = cuenta.Id;
        //         caso.RecordTypeId = rtId;
        //         caso.Subject = 'Gestión de Venta';
        //         caso.Status = STATUS_ABIERTO;
                
        //         if(cuenta.Operador_Venta__c != null)
        //             caso.OwnerId = cuenta.Operador_Venta__c;
                
        //         //Agregamos el caso a la lista de casos a agregar
        //         casosToInsert.add(caso);
                
        //         //Agregamos el caso al map
        //         parentCasesByAccounts.put(cuenta.Id, caso);
                
        //     }
            
        // }
        
        //Insertamos los casos padres
        if(casosToInsert.size() > 0){
            Utils.insertList(casosToInsert,true);
        }
        
        
        //Recorremos por ultima vez los casos hijos y los relacionamos con sus padres
        
        //Lista de casos a actualizar
        List<Case> casosToUpdate = new List<Case>();
        
        for(Case caso : casos){
            
            if(parentCasesByAccounts.containsKey(caso.AccountId)){
                
                //Obtenemos el caso padre
                Case cP = parentCasesByAccounts.get(caso.AccountId);
                
                //Vinculamos al hijo con su padre
                caso.ParentId = cP.Id;
                
                //Agregamos el caso a la lista de casos a actualizar
                casosToUpdate.add(caso);
                
            }
            
        }
        
        //Actualizamos los casos
        if(!casosToUpdate.isEmpty())
            Utils.updateList(casosToUpdate,true);
        
        
    }
    
    public static void abrirCasosPadres(List<Case> lista){

        //Obtenemos el RecordType de un Padre
        Id rtPGCId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');
        
        //Obtenemos el record type que corresponde a los casos padres de ventas
        Id rtGVId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_Venta');

        // Set que contendra los ids de los casos padres a abrir 
        
        Set<Id> idsPadres = new Set<Id>();

        for(Case c : lista){
            if(c.ParentId != null)
                idsPadres.add(c.ParentId);
        }

        // Lista que contendra los casos a actualizar
        List<Case> toUpdate = new List<Case>();

        for(Case c : [SELECT Id FROM Case WHERE (RecordTypeId =:rtPGCId OR RecordTypeId =:rtGVId) AND Status = :STATUS_CERRADO AND ParentId = null AND Id IN :idsPadres]){
            // Seteamos el Status en abierto
            c.Status = STATUS_ABIERTO;
            toUpdate.add(c);
        }

        if(!toUpdate.isEmpty())
            Utils.updateList(toUpdate,true);

    }

    public static void cerrarCasosPadres(List<Case> lista){
        
        //Obtenemos los ids de los casos hijos a partir de los casos padres 
        
        //Obtenemos los record type de los casos hijos
        Id rtIdVentas = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Ventas');
        
        Id rtIdDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');
        
        Id rtIdCob = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');
        
        //Set para coleccionar los padres
        Map<String,WrapperCasoPadre> wrappers = new Map<String,WrapperCasoPadre>();
        
        for(Case caso : lista){
            
            //Verificamos si el campo Status es igual a Cerrado
            if(caso.Status == 'Cerrado'){
            
                //Verificamos si tiene padre
                if(caso.ParentId != null){
                    
                    //Verificamos si es de alguno de los tipos de casos hijos validos
                    if(caso.RecordTypeId == rtIdVentas || caso.RecordTypeId == rtIdDUP || caso.RecordTypeId == rtIdCob){
                        
                        //Verificamos si no esta la entrada en el map, y la creamos
                        if(!wrappers.containsKey(caso.ParentId)){
                            
                            wrappers.put(caso.ParentId, new WrapperCasoPadre());
                            
                        }
                        
                    }
                    
                }
            
            }
            
        }
        
        //Obtenemos por cada caso padre la cantidad de casos hijos que tiene
        for(AggregateResult ag : [SELECT ParentId IdPadre,COUNT(Id) CantidadHijos FROM Case WHERE ParentId != null AND ParentId IN :wrappers.keySet() GROUP BY ParentId]){
            
            //Obtenemos los datos del agrupamiento
            String idPadre = String.valueOf(ag.get('IdPadre'));
            Integer cantidadHijos = Integer.valueOf(ag.get('CantidadHijos'));
            
            //Verificamos si esta la entrada en el map
            if(wrappers.containsKey(idPadre)){
                            
                //Obtenemos el Wrapper
                WrapperCasoPadre wp = wrappers.get(idPadre);
                
                //Agregamos al wrapper la cantidad de hijos del caso padre
                wp.cantCasosHijos = cantidadHijos;
                            
            }
            
        }
        
        //Obtenemos por cada caso padre la cantidad de casos hijos cerrados que tiene
        for(AggregateResult ag : [SELECT ParentId IdPadre,COUNT(Id) CantidadHijos FROM Case WHERE ParentId != null AND ParentId IN :wrappers.keySet() AND Status = :STATUS_CERRADO GROUP BY ParentId]){
            
            //Obtenemos los datos del agrupamiento
            String idPadre = String.valueOf(ag.get('IdPadre'));
            Integer cantidadHijos = Integer.valueOf(ag.get('CantidadHijos'));
            
            //Verificamos si esta la entrada en el map
            if(wrappers.containsKey(idPadre)){
                            
                //Obtenemos el Wrapper
                WrapperCasoPadre wp = wrappers.get(idPadre);
                
                //Agregamos al wrapper la cantidad de hijos del caso padre
                wp.cantCasosHijosCerrados = cantidadHijos;
                            
            }
            
        }
        
        //Recorremos los casos padres y cerramos aquellos cuya cantidad de hijos es igual a la cantidad de hijos con
        //Status cerrado
        
        //LIsta que contendra los casos a actualizar
        List<Case> toUpdate = new List<Case>();
        
        for(Case caso : [SELECT Id, Status FROM Case WHERE Id IN :wrappers.keySet()]){
            
            //Verificamos si esta la entrada ene l map
            if(wrappers.containsKey(caso.Id)){
                
                //Obtenemos el Wrapper
                WrapperCasoPadre wp = wrappers.get(caso.Id);
                
                //Si la cantidad de casos hijos es la misma que casos hijos cerrados
                //entonces todos sus hijos estan cerrados, por ende cambiamos el estado del padre a cerrado
                if(wp.cantCasosHijos == wp.cantCasosHijosCerrados){
                    
                    //Cambiamos el status a cerrado
                    caso.Status = STATUS_CERRADO;
                    
                    //Agregamos a la lista de casos a actualizar
                    toUpdate.add(caso);
                    
                }
                
            }
            
        }
        
        //Si tenemos casos para actualizar, actualizamos
        if(toUpdate.size() > 0){
            Utils.updateList(toUpdate,true);
        }
        
    }

    /**
    * @author Maximo Martinez
    * @date 06/06/2014
    * @description Metodo que a partir de una Opportunidad que ha pasado a "Gestiona Legales" 
    * @description cambia el owner de su caso a la cola de "Legales"
    */
    public static void setOwnerToLegalesQueue(Set<Id> idsOpps){

        //Obtenemos la cola de "legales"
        Id idQueueLegales = Utils.getGroupId('Legales','Queue');

        if(idQueueLegales != null){
        
            //Obtenemos los casos de las oportunidades y cambiamos el Owner a dicho Gropo/Cola

            //Lista que contendra los casos a actualizar
            List<Case> toUpdate = new List<Case>();

            for(Case c : [SELECT Id FROM Case WHERE Factura__c IN :idsOpps]){

                //Cambiamos el owner 
                c.OwnerId = idQueueLegales;

                //Agregamos a la lista
                toUpdate.add(c);

            }        

            if(toUpdate.size() > 0)
                Utils.updateList(toUpdate,true);

        }    

    }

    
    //Clase Auxiliar
    public class WrapperCasoPadre{
        
        //Atributos
        public Integer cantCasosHijos {get; set;}
        public Integer cantCasosHijosCerrados {get; set;}
        
    }
    
    //Clase auxiliar 
    public class WrapperVentasPorDistribuidorComercio{
        
        //Atributos
        public List<Venta__c> compras {get; set;}
        public List<Venta__c> ventas {get; set;}
        
    }
    
    
}