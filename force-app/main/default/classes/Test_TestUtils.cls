@isTest
public class Test_TestUtils{

    public static void disableFlows() {
        Testing__c conf = Testing__c.getOrgDefaults();

        if (conf == null) {
            conf = new Testing__c();
        }

        conf.Deshabilitar_Flows__c = true;
        upsert conf;
    }
    
    public static Product2 crearProducto(Boolean isActive,String name,String conversion, String variedad, Cultivo__c cultivo, String family, Double precio, Account obtentorComersializa){
    	return crearProducto(isActive, name, conversion, variedad, cultivo, family, precio, obtentorComersializa, true);    	
    }

    public static Product2 crearProducto(Boolean isActive,String name,String conversion, String variedad, Cultivo__c cultivo, String family, Double precio, Account obtentorComersializa, Boolean doDML){
        disableFlows();
        Variedad__c variedad2 = new Variedad__c(Name = variedad, Sembra_Evolucion__c = false);
        insert variedad2;
        return crearProducto(isActive, name, conversion, variedad, cultivo, family, precio, obtentorComersializa, variedad2.Id, doDML);    
    }
    
    public static Product2 crearProducto(Boolean isActive,String name,String conversion, String variedad, Cultivo__c cultivo, String family, Double precio, Account obtentorComersializa, Id variedad2, Boolean doDML){
        disableFlows();
        //Creamos el producto
        Product2 producto = new Product2(IsActive = isActive, Name = name,Conversion__c = conversion, Variedad__c = variedad, Cultivo__c = cultivo.Id, Family = family,Precio__c = precio, Obtentor_Comercializa__c = obtentorComersializa.Id, Variedad2__c = variedad2);
        
        //Agregamos el obtentor propietario
        producto.Obtentor_Propietario__c = obtentorComersializa.Id;
        
        //Agregamos la categoria
        producto.Categoria__c = 'Uso Propio';

        System.debug(LoggingLevel.WARN, producto);
        
        if(doDML){
        	//Insertamos el producto en la base de datos
        	insert producto;
        }
        
        //Devolvemos el producto
        return producto; 
    } 
    
    public static Pricebook2 crearListaDePrecios(Boolean isActive, String name){
        
        //Creamos la lista
        Pricebook2 pb = new Pricebook2(isActive = isActive, name = name); 
        
        //Insertamos la lista
        insert pb;
        
        //Retornamos la lista
        return pb;
        
    }
    
    public static Venta__c crearVenta(Product2 product, Campana_Agricola__c campanaAgricola, Cultivo__c  cultivo, Double cantidad, Account originante, Account destinatario, String tipoVenta){
        
        //Creamos una venta 
        Venta__c venta = new Venta__c(Producto__c = product.Id, Campana_Agricola__c = campanaAgricola.Id, Cultivo__c = cultivo.Id, Cantidad__c = cantidad, Originante__c = originante.Id, Destinatario__c = destinatario.Id, Tipo_de_Venta__c = tipoVenta);
        venta.Rol_Destinatario__c = 'Distribuidor';
        venta.Rol_Originante__c = 'Distribuidor';
        //Insertamos la venta
        insert venta;
        
        //Retornamos la venta
        return venta;
    }  
    
    public static Cultivo__c crearCultivo(String tipoDeEspecie, Double dencidadDeSiembra){
    	return crearCultivo(tipoDeEspecie, dencidadDeSiembra, true);
    }
    
    public static Cultivo__c crearCultivo(String tipoDeEspecie, Double dencidadDeSiembra, Boolean doDML){
        //Creamos el cultivo
        Cultivo__c cultivo = new Cultivo__c(Name = tipoDeEspecie, Tipo_de_Especie__c = tipoDeEspecie,Densidad_de_Siembra__c = dencidadDeSiembra);
        
        //Insertamos el cultivo
        if(doDML){
        	insert cultivo;
        }
        
        //Devolvemos el cultivo
        return cultivo;
    } 
    
    public static PricebookEntry crearPricebookEntry(Pricebook2 priceBook, Product2 producto, Boolean isActive, Double unitPrice){
        //Creamos el pricebook entry
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = priceBook.Id, Product2Id = producto.Id, IsActive = isActive, UnitPrice = unitPrice);
        
        
        
        System.Debug(LoggingLevel.INFO,[SELECT Id FROM PricebookEntry WHERE Product2Id = :producto.Id]);
        
        //Insertamos el pricebook entry
        insert pbe;
        
        //Retornamos el pricebook entry
        return pbe;
    }
    
    public static Transaccion__c crearTransaccion(RecordType recordType, String nombre, Account obtentor, Cultivo__c cultivo, Campana_Agricola__c campana, Account nombreDeLaCuenta, String estado, Date fechaVisita){
    	return crearTransaccion(recordType, nombre, obtentor, cultivo, campana, nombreDeLaCuenta, estado, fechaVisita, true);
    } 
    
    public static Transaccion__c crearTransaccion(RecordType recordType, String nombre, Account obtentor, Cultivo__c cultivo, Campana_Agricola__c campana, Account nombreDeLaCuenta, String estado, Date fechaVisita, Boolean doDML){
        //se agrega este dato para que no rompa el flow Transaccion.actualizaInformoPorPortal
        nombreDeLaCuenta.Operador__c = UserInfo.getUserId();
        update nombreDeLaCuenta;
        //Creamos la transaccion
        Transaccion__c transaccion =new Transaccion__c(RecordTypeId = recordType.Id, Name = nombre,Cultivo__c = cultivo.Id, Obtentor__c = obtentor.Id, Campana__c = (campana!=null?campana.Id:null), Nombre_de_la_cuenta__c = nombreDeLaCuenta.Id, Estado__c = estado, Fecha_de_la_Visita__c  = fechaVisita);
        
        //Insertamos la transaccion
        if(doDML){
        	insert transaccion;
        }
        
        //Retornamosla transaccion
        return transaccion;
    }
    
    public static Item_de_DUP__c crearItemDeDUP(Product2 producto, Transaccion__c transaccion, Double cantidad, String estado,Double tipoCambio){
    	return crearItemDeDUP(producto, transaccion, null, estado, tipoCambio, true);	    	
    }

    public static Item_de_DUP__c crearItemDeDUP(Product2 producto, Transaccion__c transaccion, Double cantidad, String estado,Double tipoCambio, String lugarSiembraId){
        return crearItemDeDUP(producto, transaccion, null, estado, tipoCambio, true, lugarSiembraId);         
    }

    public static Item_de_DUP__c crearItemDeDUP(Product2 producto, Transaccion__c transaccion, Double cantidad, String estado, Double tipoCambio, Boolean doDML){
        return crearItemDeDUP(producto, transaccion, cantidad, estado, tipoCambio, doDML, null);         
    }
    
    public static Item_de_DUP__c crearItemDeDUP(Product2 producto, Transaccion__c transaccion, Double cantidad, String estado, Double tipoCambio, Boolean doDML, String lugarSiembraId){
         
         //Item de DUP
         //27/03/2014 - JL.IUDICA: cambio Cantidad__c por Cantidad_Declarada__c
         Item_de_DUP__c item = new Item_de_DUP__c(Producto__c = producto.Id, Cantidad_Declarada__c = cantidad, Transaccion__c = transaccion.id, Estado__c = estado,Tipo_de_Cambio__c = tipoCambio);
         
         //Seteamos el obtentor
         item.Obtentor__c = producto.Obtentor_Comercializa__c;

         item.Campana_Agricola__c = transaccion.Campana__c;

         item.Lugar_de_Siembra__c = lugarSiembraId;

         item.Unidad_de_Medida_Declarada__c = 'Granel';

         item.Densidad_de_Siembra__c = 1;
         
         //Insertamos el item 
         if(doDML){ 
         	insert item;
         }
         
         //Retornamos el item
         return item;
    }

    public static Item_Auditoria__c crearItemAuditoria(Product2 producto, Transaccion__c transaccion,  Campana_Agricola__c campana, String resultado, String unidadMedidaRelevada, Double cantidadRelevada, Double tipoCambio){
        return crearItemAuditoria(producto, transaccion, campana, resultado, unidadMedidaRelevada, cantidadRelevada, tipoCambio, true);
    }
    
    public static Item_Auditoria__c crearItemAuditoria(Product2 producto, Transaccion__c transaccion,  Campana_Agricola__c campana, String resultado, String unidadMedidaRelevada, Double cantidadRelevada, Double tipoCambio, Boolean doDML){
        //Creamos el item
        Item_Auditoria__c item = new Item_Auditoria__c(Auditoria__c = transaccion.Id, Campana__c = campana.Id, Producto__c = producto.Id,Resultado__c = resultado, Unidad_de_Medida_Relevada__c = unidadMedidaRelevada, Cantidad_Relevada__c = cantidadRelevada,Tipo_de_Cambio__c = tipoCambio, Obtentor__c = transaccion.Obtentor__c, Densidad_de_Siembra__c = 1); 
        
        if(doDML){
            //Insertamos el item
            insert item;
        }
        //Retornamos el item
        return item;  
    } 
    
    public static Moneda__c crearMoneda(String codigoUnivoco, String name,Boolean isMonedaDeLaConpania){
    	return crearMoneda(codigoUnivoco, name, isMonedaDeLaConpania, true);
    }
    
    public static Moneda__c crearMoneda(String codigoUnivoco, String name,Boolean isMonedaDeLaConpania, Boolean doDML){

        //Creamos la moneda
        Moneda__c moneda = new Moneda__c(Name=name, Moneda_de_la_compania__c = isMonedaDeLaConpania, Codigo_Univoco__c = codigoUnivoco);
        
        //Insertamos la moneda
        if(doDML){
        	insert moneda;
        }
        
        //Retornamos la moneda
        return moneda;
    }
    
    public static Tipo_de_Cambio__c crearTipodeCambio(Moneda__c moneda,Double cotizacion,Date fecha){
    	return crearTipodeCambio(moneda, cotizacion, fecha, true);
    }
    
    public static Tipo_de_Cambio__c crearTipodeCambio(Moneda__c moneda,Double cotizacion,Date fecha, Boolean doDML){
        //Creamos el tipo de cambio
        Tipo_de_Cambio__c tipoCambio = new Tipo_de_Cambio__c(Moneda__c = moneda.Id, Cotizacion__c = cotizacion, Fecha__c= fecha);
    
        //Insertamos el tipo de cambio
        if(doDML){
        	insert tipoCambio;
        }
        
        //Retornamos el tipo de cambio
        return tipoCambio;
    }
    
    public static List<Tipo_de_cambio__c> crearTiposDeCambio(List<Moneda__c> monedas){
       
       //Lista para almacenar los tipos de cambio creados
       List<Tipo_de_cambio__c> tiposDeCambio = new List<Tipo_de_cambio__c>();
       
       //Obtenemos la fecha actual
       Date fechaActual = Date.today();
       
       //Recorremos la lista de monedas y generamos un tipo de cambio para las que no son de la compania
       for(Moneda__c moneda : monedas){
           if(!moneda.Moneda_de_la_compania__c){
               tiposDeCambio.add(crearTipodeCambio(moneda,Math.round(Math.random()*10),fechaActual));
           }
       }    
       
       return tiposDeCambio;
       
    }
    
    public static List<Product2> crearProductos(Cultivo__c cultivo, String familia,Account obtentorComersializa){
        //Creo una lista para almacenar algunos productos
        List<Product2> productos = new List<Product2>();
        
            
        productos.add(crearProducto(true,'Producto Test 1','TEST1', 'Variedad Test', cultivo, familia,Math.round(Math.random()*10),obtentorComersializa));
        
        productos.add(crearProducto(true,'Producto Test 2','TEST1', 'Variedad Test', cultivo, familia,Math.round(Math.random()*10),obtentorComersializa));
        
        productos.add(crearProducto(true,'Producto Test 3','TEST2', 'Variedad Test', cultivo, familia,Math.round(Math.random()*10),obtentorComersializa));
        
        productos.add(crearProducto(true,'Producto Test 4','TEST2', 'Variedad Test', cultivo, familia,Math.round(Math.random()*10),obtentorComersializa));
        
        //Retornamos los productos
        return productos;
    
    }
    
    public static List<PricebookEntry> crearPricebookEntry(List<Product2> productos, Pricebook2 listaPrecios){
        //Creo una lista para almacenar los PricebookEntry
        List<PricebookEntry> psbe = new List<PricebookEntry>();
        
        //Recorro los productos y creo una entrada por cada uno
        for(Product2 producto : productos){
            psbe.add(crearPricebookEntry(listaPrecios,producto, true, Math.round(Math.random()*10)));
        }
        
        //Retorno los pricebookentries
        return psbe;
    }
    
    public static Account crearObtentor(){
    	return crearObtentor(true);
    }
    
    public static Account crearObtentor(Boolean doDML){
        
        //Creamos una localidad
        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;
        
        //Creamos una cuenta de tipo Obtentor
        Account obtentor = new Account();
        obtentor.Name = 'Obtentor';
        obtentor.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Obtentor');
        obtentor.Clave_Unica__c = 'obtentor';
        obtentor.N_CUIT__c = '33693450239';
        obtentor.Condicion_Impositiva__c = 'No Aplica';
        obtentor.Localidad_Envio__c = localidad.Id;
        obtentor.Type = 'Obtentor';
        obtentor.Id_Obtentor__c = '11';
        obtentor.Nombre_Obtentor__c = 'Test';
        
        if(doDML){
        	insert obtentor;
        }
        
        return obtentor;
        
    }
    
    public static Account crearDistribuidor(){
    	return crearDistribuidor(true);
    }
    
    public static Account crearDistribuidor(Boolean doDML){
        
         //Creamos una localidad
        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;
        
         //Creamos un distribuidor
        Account distribuidor = new Account();
        distribuidor.Name = 'Distribuidor';
        distribuidor.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Distribuidor');
        distribuidor.Clave_Unica__c = 'distribuidor';
        distribuidor.N_CUIT__c = '30537647716';
        distribuidor.Direccion_de_Correo_electronico_del_CUIT__c = 'distribuidor@test.com';
        distribuidor.Localidad_Envio__c = localidad.Id;
        distribuidor.Condicion_Impositiva__c = 'No Aplica';
        distribuidor.Type = 'Distribuidor';
        
        if(doDML){
        	insert distribuidor;
        }
        
        //Retornamos el obtentor
        return distribuidor;
    }
    
     public static Account crearProductor(){
        
         //Creamos una localidad
        Localidad__c localidad = new Localidad__c();
        localidad.Zona_Bolsa_Cereales__c = 'Test';
        insert localidad;
        
         //Creamos un distribuidor
        Account productor = new Account();
        productor.Name = 'productor';
        productor.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Account.SObjectType).get('Productor');
        productor.Clave_Unica__c = 'productor';
        productor.N_CUIT__c = '30526904792';
        productor.Direccion_de_Correo_electronico_del_CUIT__c = 'productor@test.com';
        productor.Localidad_Envio__c = localidad.Id;
        productor.Condicion_Impositiva__c = 'No Aplica';
        productor.Type = 'Productor';
        insert productor;
        
        
        //Retornamos el obtentor
        return productor;
    }
    
    public static Campana_Agricola__c crearCampanaAgricola(String anio, Cultivo__c cultivo, Date fechaInicio, Date fechaFin, String name){
    	return crearCampanaAgricola(anio, cultivo, fechaInicio, fechaFin, name, true);
    }
    
    public static Campana_Agricola__c crearCampanaAgricola(String anio, Cultivo__c cultivo, Date fechaInicio, Date fechaFin, String name, Boolean doDML){
        //Creamos la campaña
        Campana_Agricola__c campanaAgricola = new Campana_Agricola__c(Ano__c = anio, Cultivo__c = cultivo.id, Fecha_de_Inicio__c = fechaInicio, Fecha_de_Fin__c = fechaFin, Name = name); 
        
        //Obtenemos un SKEY
        campanaAgricola.SKEY_CAMPANIA__c = Utils.getRandomLong(10);

        //Insertamos la campaña
        if(doDML){
        	insert campanaAgricola;
        }
        
        //Retornamos la campaña
        return campanaAgricola;
    }
    
    public static Opportunity crearOpportunity(Pricebook2 listaPrecios, String stageName, Date closeDate, String name, Transaccion__c transaccion, String tipoComprobante, Boolean doDML){
        //Creamos la opportunidad
        Opportunity oportunidad = new Opportunity(Pricebook2Id = listaPrecios.Id, StageName = stageName,CloseDate = closeDate, AccountId = transaccion.Nombre_de_la_cuenta__c, Obtentor__c = transaccion.Obtentor__c, Name = name,Transaccion__c = transaccion.Id, Tipo_de_Comprobante__c = tipoComprobante, Type = transaccion.RecordType.Name);
        
        if(doDML){
            //Insertamos la oportunidad
            insert oportunidad;
        }
        //Retornamos la opportunidad
        return oportunidad;
        
    }

    public static Opportunity crearOpportunity(Pricebook2 listaPrecios, String stageName, Date closeDate, String name, Transaccion__c transaccion, String tipoComprobante){
        return crearOpportunity(listaPrecios, stageName, closeDate, name, transaccion, tipoComprobante, true);
    }
    
    
    public static OpportunityLineItem crearOpportunityLineItem(Opportunity oportunidad, PricebookEntry pe, Double cantidad, Double precioUnitario, Double tipoCambio){
        //Creamos la linea de oportunidad
        OpportunityLineItem lineaDeOportunidad = new OpportunityLineItem(OpportunityId = oportunidad.Id, PricebookEntryId = pe.Id, Quantity = cantidad,UnitPrice = precioUnitario, Tipo_de_Cambio__c = tipoCambio);
    
        //Insertamos la linea de oportunidad
        insert lineaDeOportunidad;
        
        //Retornamos la linea de oportunidad
        return lineaDeOportunidad;
    }
    
    public static Task crearTask(Opportunity oportunidad, String estado, String asunto){
        //Creamos la Task
        Task tarea = new Task(WhatId = oportunidad.Id, Status = estado, Subject = asunto);
        
        //Insertamos la Task
        insert tarea;
        
        //Retornamos la task
        return tarea;
    }
    
    public static Case crearCasoGestionCUIT(Account a){
        //Creamos el caso
        Case caso = new Case();
        
        //Seteamos los parametros necesarios
        caso.RecordTypeId = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Gestion_de_CUIT');
        caso.AccountId = a.Id;
        caso.Subject = 'Gestion de CUIT';
        
        //Insertamos en la BD
        insert caso;
        
        return caso;
    }
    
    public static Interaccion__c crearInteraccion(Case caso){
         
         //Creamos la interaccion
         Interaccion__c interaccion = new Interaccion__c();
        
         //Seteamos los parametros necesarios
         interaccion.Caso__c = caso.Id;
         
         //Insertamos en la BD
         insert interaccion;
         
         return interaccion;
        
    }

    public static Lote__c crearLote(Campana_Agricola__c campanaAgricola, Cultivo__c cultivo, String tipo){

        //Creamos un lote
        Lote__c lote = Test_TestUtils.crearLote();
        
        //Seteamos los parametros necesarios
        lote.Campana__c = campanaAgricola.Id;
        lote.Cultivo__c = cultivo.Id;
        lote.Tipo__c = tipo;

        //Retornamos la instancia del lote
        return lote;
    }

    public static Remesa__c crearRemesa(String estado, String modoEnvio, Lote__c lote, Account productor){

        //Creamos la remesa
        Remesa__c remesa = new Remesa__c();    

        //Seteamos algunos datos
        remesa.Estado__c = estado;
        remesa.Modo_de_Envio__c = modoEnvio;
        remesa.Lote__c = lote.Id;
        remesa.Productor__c = productor.Id;

        //Retornamos la instancia de la remesa
        return remesa;
    }

    public static Localidad__c crearLocalidad(String zonaBolsasCereales){

        //Creamos una localidad
        Localidad__c localidad = new Localidad__c();
        
        //Seteamos algunos datos
        localidad.Zona_Bolsa_Cereales__c = zonaBolsasCereales;

        //Retornamos la instancia de la localidad
        return localidad;
        
    }

    public static GestionCaso__c crearGestionCaso(String name,String campo, String label, Boolean agregarLink, Boolean mostrarPopUp, String fieldSet, Double orden, String recordType){

        //Creamos una Gestion de Caso
        GestionCaso__c gc = new GestionCaso__c();

        //Seteamos algunos datos
        gc.Agregar_Link__c = agregarLink;
        gc.Label__c = label;
        gc.Mostrar_Popup__c = mostrarPopUp;
        gc.FieldSet__c = fieldSet;
        gc.Orden__c = orden;
        gc.Campo__c = campo;
        gc.RecordType__c = recordType;
        gc.Name = name;

        //Retornamos la instancia
        return gc;

    }

    public static Case crearCasoDUP(Account cuenta, Case casoPadre){

        //Obtenemos el recordtype del caso
        Id rtDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');

        //Creamos el caso
        Case caso = new Case();

        //Seteamos algunos datos
        caso.AccountId = cuenta.Id;
        caso.RecordTypeId = rtDUP;
        caso.ParentId = casoPadre.Id;
        caso.Subject = 'Gestionar Respuesta';

        //Retornamos el caso
        return caso;

    }

    public static Case crearCasoCobranza(Account cuenta, Case casoPadre){

        //Obtenemos el recordtype del caso
        Id rtCobranza = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('Cobranzas');

        //Creamos el caso
        Case caso = new Case();

        //Seteamos algunos datos
        caso.AccountId = cuenta.Id;
        caso.RecordTypeId = rtCobranza;
        caso.ParentId = casoPadre.Id;
        caso.Subject = 'Gestionar Cobranza';

        //Retornamos el caso
        return caso;

    }

    public static Caso_Gestionado__c crearCasoGestionado(Case caso, String comentarioCodificado, Interaccion__c interaccion, Account cuenta){

        //Creamos el caso Gestionado
        Caso_Gestionado__c casoGestionado = new Caso_Gestionado__c();

        //Seteamos algunos datos
        casoGestionado.Caso__c = caso.Id;
        casoGestionado.Comentario_Codificado__c = comentarioCodificado;
        casoGestionado.Interaccion__c = interaccion.Id;
        casoGestionado.Cuenta__c = cuenta.Id;

        //Retornamos el caso gestionado
        return casoGestionado;

    }


    public static Task crearTask(Case caso, String comentarioCodificado){

        //Creamos el caso Gestionado
        Task tarea = new Task();

        //Seteamos algunos datos
        tarea.WhatId = caso.Id;
        tarea.Comentario_Codificado__c = comentarioCodificado;

        //Retornamos el caso gestionado
        return tarea;

    }




    public static Lote__c crearLote(){
        Lote__c lote = new Lote__c();
        
        // Agregamos los campos obligatorios que piden las validation rules
        lote.Descripcion__c = 'Test';
        
        return lote;

    }

    public static Contacto_Remesa__c crearContactoRemesa(String nombre, Remesa__c remesa, Contact contacto, Boolean doDML){

        Contacto_Remesa__c c = new Contacto_Remesa__c();

        c.Name = nombre;
        c.Remesa__c = remesa.Id;
        c.Contacto__c = contacto.Id;

        if(doDML){
            insert c;
        }

        return c;

    }

}