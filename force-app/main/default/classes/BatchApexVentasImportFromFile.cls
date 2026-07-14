global class BatchApexVentasImportFromFile implements Database.Batchable<String>, Database.Stateful {
	
	/*
	*Atributos
	*/
	private List<Venta__c> ventas;
	private String csvFile;
	private String introValue;
	private Map<String, List<Integer>> ventasDuplicadasError;
	private Map<Integer, VentaCSVErrores> ventasCSVErrores;
	private String fileName;
	private String timeStamp;
	private Integer offset;
	private Integer blankLineCounter;
	private Integer ventasExitosas;
	private Integer errores;
	private Integer ventasSinCuenta;
	
	/*
	*Constantes
	*/
	public static final String HEADER = 'Obtentor,CUIT Originante,CP Originante,Calle del Originante,Número del Originante,Provincia del Originante,Depto/Partido del Originante,Localidad del Originante,Rol de Originante,CUIT Destinatario,Razón Social detinatario,Calle del Destinatario,Número del Destinatario,Provincia del Destinatario,Depto/Partido del Destinatario,Localidad del Destinatario,Código Postal del Destinatario,Nombre del Contacto del Destinatario,Apellido del Contacto del Destinatario,Tel fijo del Contacto del Destinatario,Tel celular del Contacto del Destinatario,Correo Electrónico del Contacto del Destinatario,Rol de Destinatario,Zona de Venta,Campaña de Ventas,Gestor,Origen del Registro,Canal,Fecha,Fecha Facturación,N° de Comprobante,Cantidad de Bolsas,Kilos por Bolsa,Variedad,Categoría,Tipo de Producto,Unidad de Medida,Cultivo,Campana';
	public static final Integer SCOPE_SIZE = 100;
	private static final String FOLDER_DEVELOPER_NAME = 'Importacion_Masiva_Ventas';
    private static final Integer COL_RAZON_SOCIAL_ORIGINANTE = 0;
    private static final Integer COL_CUIT_ORIGINANTE = 1;
    private static final Integer COL_CP_ORIGINANTE = 2;
    private static final Integer COL_CALLE_ORIGINANTE = 3;
    private static final Integer COL_NUMERO_ORIGINANTE = 4;
    private static final Integer COL_PROVINCIA_ORIGINANTE = 5;
    private static final Integer COL_PARTIDO_ORIGINANTE = 6;
    private static final Integer COL_LOCALIDAD_ORIGINANTE = 7;
    private static final Integer COL_ROL_ORIGINANTE = 8;
    private static final Integer COL_CUIT_DESTINATARIO = 9;
    private static final Integer COL_RAZON_SOCIAL_DESTINATARIO = 10;
    private static final Integer COL_CALLE_DESTINATARIO = 11;
    private static final Integer COL_NUMERO_DESTINATARIO = 12;
    private static final Integer COL_PROVINCIA_DESTINATARIO = 13;
    private static final Integer COL_PARTIDO_DESTINATARIO = 14;
    private static final Integer COL_LOCALIDAD_DESTINATARIO = 15;
    private static final Integer COL_CP_DESTINATARIO = 16;
    private static final Integer COL_ROL_DESTINATARIO = 22;
    private static final Integer COL_ZONA_VENTA = 23;
    private static final Integer COL_CAMPANA_VENTAS = 24;
    private static final Integer COL_GESTOR = 25;
    private static final Integer COL_ORIGEN_REGISTRO = 26;
    private static final Integer COL_CANAL = 27;
    private static final Integer COL_FECHA = 28;
    private static final Integer COL_FECHA_FACTURACION = 29;
    private static final Integer COL_NUMERO_COMPROBANTE = 30;
    private static final Integer COL_CANTIDAD_BOLSAS = 31;
    private static final Integer COL_KILOS_POR_BOLSA = 32;
    private static final Integer COL_VARIEDAD_PRODUCTO = 33;
    private static final Integer COL_CATEGORIA_PRODUCTO = 34;
    private static final Integer COL_TIPO_PRODUCTO = 35;
    private static final Integer COL_UM_PRODUCTO = 36;
    private static final Integer COL_CULTIVO = 37;
    private static final Integer COL_CAMPANA = 38;
    public static final String ERROR_PRODUCT_NOT_FOUND = 'Producto no encontrado.';
    public static final String ERROR_CULTIVO_NOT_FOUND = 'Cultivo no encontrado.';
    public static final String ERROR_CAMPANA_NOT_FOUND = 'Campaña Agricola no encontrada.';
    public static final String ERROR_ORIGINANTE_INSERTION_FAILURE = 'Error al intentar dar de alta la cuenta Originante:';
    public static final String ERROR_DESTINATARIO_INSERTION_FAILURE = 'Error al intentar dar de alta la cuenta Destinataria:';
    public static final String ERROR_VENTA_INSERTION_FAILURE = 'Error al intentar dar de alta la venta:';

	
	global BatchApexVentasImportFromFile(String csvFile, String introValue, String fileName, String timeStamp) {
	
		this.csvFile = csvFile;
		this.introValue = introValue;
		this.fileName = fileName;
		this.timeStamp = timeStamp;

	    //Map que contendra las lineas que estas duplicadas luego de la importaccion
	    ventasDuplicadasError = new Map<String, List<Integer>>(); 

        //Map que contiene los posibles errores en las lineas de venta
	    ventasCSVErrores = new Map<Integer, VentaCSVErrores>();

	    offset = 0;

	    blankLineCounter = 0;
		
		ventasExitosas = 0;

		errores = 0;

		ventasSinCuenta = 0;
	}
	
	global Iterable<String> start(Database.batchableContext batchableContext){
		// Obtenemos las lineas del archivo
		//return new CSVIterator(csvFile, introValue);
        return new CSVIterator(csvFile);
	}


   	global void execute(Database.BatchableContext BC, List<String> csvLines){

   		// Procesamos las lineas del archivo

   		ventasCSVErrores = new Map<Integer, VentaCSVErrores>();

   		//Map que contendra las ventas que levantamos del archivo agrupadas con su numero de linea
	    Map<Integer,VentaCSV> ventasCSV = new Map<Integer,VentaCSV>();

	    //Set que contendra las Cuentas a insertar
	    Set<Account> cuentasToInsert = new Set<Account>();

	    //Lista que contendra las ventas a insertar
	    List<Venta__c> ventasToInsert = new List<Venta__c>();

	    Map<Integer, VentaCSV> ventasCSVToInsert = new Map<Integer, VentaCSV>();

	    //Lista que contendra ventas pendientes a procesar cuentas
	    List<VentaCSV> ventasPendientes = new List<VentaCSV>();

	    //Instanciamos la clase que contiene los diferentes set de datos
	    DatosVentas datosVentas = new DatosVentas();

	    //Recorremos las lineas del archivo
	    for(Integer i = 0 ; i < csvLines.size() ; i++){

	        //Obtenemos la linea actual del archivo
	        String csvLine = csvLines.get(i);
	      
	        if(isEmptyLine(csvLine, ',')){
	        	blankLineCounter++;
	        	continue;
	        }	
	        
	        System.debug(LoggingLevel.INFO, String.valueOf((i+offset))+' '+csvLine);

	        //Verificamos si esta la entrada en el map
	        if(!ventasDuplicadasError.containsKey(csvLine.trim())){
	            ventasDuplicadasError.put(csvLine.trim(),new List<Integer>());
	        }

	        //Obtengo la lista de lineas duplicadas
	        List<Integer> listaLineasDuplicadas = ventasDuplicadasError.get(csvLine.trim());

	        //Agregamos la linea a la lista
	        listaLineasDuplicadas.add((i+offset));

	        //Por el momento la linea no esta duplicada, procesamos la venta
	        if(listaLineasDuplicadas.size() == 1){

	            //Obtengo la linea en formato VentaCSV
	            VentaCSV ventaCSV = getVentaCSVFromLine(csvLine);

	            //Agregamos la linea del archivo a la venta
	            ventaCSV.linea = (i+offset);

	            //Agregamos la venta al file
	            ventasCSV.put((i+offset),ventaCSV);

	            //Cargamos los datos en los diferentes SET que nos permitiran realizar las busquedas afines

	            //Cargamos los numero de CUIT tanto de Destinatario como Originante
	            datosVentas.numerosCUIT.add(ventaCSV.originante.N_CUIT__c);
	            datosVentas.numerosCUIT.add(ventaCSV.destinatario.N_CUIT__c);

	            //Cargamos los codigos postales tanto de Destinatario como Originante
	            datosVentas.codigosPostales.add(ventaCSV.localidadOriginante.CP__c);
	            datosVentas.codigosPostales.add(ventaCSV.localidadDestinatario.CP__c);
	    
	            //Cargamos la variedad del productos
	            datosVentas.variedades.add(ventaCSV.producto.Variedad__c);

	            //Cargamos el tipo de producto
	            datosVentas.tiposDeProductos.add(ventaCSV.producto.Family);

	            //Cargamos la categoria del producto
	            datosVentas.categorias.add(ventaCSV.producto.Categoria__c);

	            //Cargamos la unidad de medida del producto
	            datosVentas.unidadesDeMedida.add(ventaCSV.producto.Unidad_de_Medida__c);

	            //Cargamos los anos de las campanas
	            datosVentas.campanasVentas.add(ventaCSV.campanaVenta.Name);

	            //Cargamos los cultivos
	            datosVentas.cultivosVentas.add(ventaCSV.cultivo.Name);

	            //Cargamos los roles de las cuentas
	            datosVentas.roles.add(ventaCSV.rolDestinatario);
	            datosVentas.roles.add(ventaCSV.rolOriginante);

	            //Cargamos las provincias
	            datosVentas.provincias.add(ventaCSV.provinciaOriginante.Name);
	            datosVentas.provincias.add(ventaCSV.provinciaDestinatario.Name);

	            //Cargamos los partidos
	            datosVentas.partidos.add(ventaCSV.partidoOriginante.Name);
	            datosVentas.partidos.add(ventaCSV.partidoDestinatario.Name);

	            //Cargamos las ciudades
	            datosVentas.ciudades.add(ventaCSV.localidadOriginante.Name);
	            datosVentas.ciudades.add(ventaCSV.localidadDestinatario.Name);

	        }else{

	            //Verifico si esta la entrada en el map
	            if(!ventasCSVErrores.containsKey((i+offset))){
	                ventasCSVErrores.put((i+offset),new VentaCSVErrores());
	            }

	            //Indico que es una venta duplicada
	            ventasCSVErrores.get((i+offset)).ventaDuplicada = true;

	            errores++;

	        } 

	    }

	    //Buscamos los datos necesarios para armar la venta en la BD

	    //Buscamos las cuentas
	    for(Account cuenta : [SELECT Id, Codigo_Postal_Envio__c,N_CUIT__c FROM Account WHERE N_CUIT__c IN :datosVentas.numerosCUIT AND Codigo_Postal_Envio__c IN :datosVentas.codigosPostales and ((N_CUIT__c in ('30569723023', '30715468294') and Type = 'Obtentor') or parentId = null)]){
	        
	        //Agrupamos las cuentas por Codigo Postal y Por CUIT

	        //Verificamos si esta la entrada
	        if(!datosVentas.cuentas.containsKey(cuenta.Codigo_Postal_Envio__c)){
	            //Creamos la entrada
	            datosVentas.cuentas.put(cuenta.Codigo_Postal_Envio__c,new Map<String,Account>());
	        }

	        //Agregamos al map
	        datosVentas.cuentas.get(cuenta.Codigo_Postal_Envio__c).put(cuenta.N_CUIT__c, cuenta);

	    }


	    //Buscamos los productos
	    for(Product2 producto : [SELECT Id, Variedad__c, Categoria__c, Family, Cultivo__c,Unidad_de_Medida__c FROM Product2 WHERE Variedad__c IN :datosVentas.variedades AND Categoria__c IN :datosVentas.categorias AND Family IN :datosVentas.tiposDeProductos AND Unidad_de_Medida__c IN :datosVentas.unidadesDeMedida]){
	        
	        //Agrupamos los productos por Veriedad, Family, Categoria y UM

	        //Verificamos si esta la entrada en el map
	        if(!datosVentas.productos.containsKey(producto.Variedad__c)){
	            //Creamos la entrada
	            datosVentas.productos.put(producto.Variedad__c,new Map<String,Map<String,Map<String,Product2>>>());
	        }

	        //Verificamos si esta la entrada en el map
	        if(!datosVentas.productos.get(producto.Variedad__c).containsKey(producto.Family)){
	            //Creamos la entrada
	            datosVentas.productos.get(producto.Variedad__c).put(producto.Family, new Map<String,Map<String,Product2>>());
	        }

	        //Verificamos si esta la entrada en el map
	        if(!datosVentas.productos.get(producto.Variedad__c).get(producto.Family).containsKey(producto.Categoria__c)){
	            //Creamos la entrada
	            datosVentas.productos.get(producto.Variedad__c).get(producto.Family).put(producto.Categoria__c, new Map<String, Product2>());
	        }

	        //Verificamos si esta la entrada en el map
	        if(!datosVentas.productos.get(producto.Variedad__c).get(producto.Family).get(producto.Categoria__c).containsKey(producto.Unidad_de_Medida__c)){
	            //Creamos la entrada
	            datosVentas.productos.get(producto.Variedad__c).get(producto.Family).get(producto.Categoria__c).put(producto.Unidad_de_Medida__c, producto);
	        }

	    }


	    //Buscamos las localidades
	    for(Localidad__c localidad : [SELECT Id, Name, CP__c, Provincia__r.Name, Partido__r.Name FROM Localidad__c WHERE CP__c IN :datosVentas.codigosPostales AND Partido__r.Name IN :datosVentas.partidos AND Provincia__r.Name IN :datosVentas.provincias AND Name IN :datosVentas.ciudades]){

	        //Verificamos si esya la entrada en el map
	        if(!datosVentas.localidades.containsKey(localidad.Provincia__r.Name)){
	            datosVentas.localidades.put(localidad.Provincia__r.Name, new Map<String, Map<String, Map<String, Localidad__c>>>());
	        }

	        //Verificamos si esya la entrada en el map
	        if(!datosVentas.localidades.get(localidad.Provincia__r.Name).containsKey(localidad.Partido__r.Name)){
	            datosVentas.localidades.get(localidad.Provincia__r.Name).put(localidad.Partido__r.Name, new Map<String, Map<String, Localidad__c>>());
	        }

	        //Verificamos si esya la entrada en el map
	        if(!datosVentas.localidades.get(localidad.Provincia__r.Name).get(localidad.Partido__r.Name).containsKey(localidad.CP__c)){
	            datosVentas.localidades.get(localidad.Provincia__r.Name).get(localidad.Partido__r.Name).put(localidad.CP__c,new Map<String, Localidad__c>());
	        }

	        
	        datosVentas.localidades.get(localidad.Provincia__r.Name).get(localidad.Partido__r.Name).get(localidad.CP__c).put(localidad.Name, localidad);
	    
	    }

	    //Buscamos los cultivos
	    for(Cultivo__c cultivo : [SELECT Name FROM Cultivo__c WHERE Name IN :datosVentas.cultivosVentas]){
	        //Agrupamos los cultivos por su nombre
	        datosVentas.cultivos.put(cultivo.Name,cultivo);
	    }

	    //Buscamos las campanas
	    for(Campana_Agricola__c campana : [SELECT Name FROM Campana_Agricola__c WHERE Name IN :datosVentas.campanasVentas]){
	        //Agrupamos las campanas por su nombre
	        datosVentas.campanas.put(campana.Name,campana);
	    }

	    //Buscamos los RecordType
	    for(RecordType rt : [SELECT Id, Name, DeveloperName FROM RecordType WHERE Name IN :datosVentas.roles]){
	        //Agrupamos los rt por su nombre
	        datosVentas.tiposDeRegistros.put(rt.Name,rt);
	    }

	    //Recorremos la ventas y vamos armando la venta que se insertara en la BD finalmente
	    for(VentaCSV ventaCSV : ventasCSV.values()){

	        //Buscamos su producto
	        if(datosVentas.productos.containsKey(ventaCSV.producto.Variedad__c)){

	            if(datosVentas.productos.get(ventaCSV.producto.Variedad__c).containsKey(ventaCSV.producto.Family)){

	                if(datosVentas.productos.get(ventaCSV.producto.Variedad__c).get(ventaCSV.producto.Family).containsKey(ventaCSV.producto.Categoria__c)){

	                    if(datosVentas.productos.get(ventaCSV.producto.Variedad__c).get(ventaCSV.producto.Family).get(ventaCSV.producto.Categoria__c).containsKey(ventaCSV.producto.Unidad_de_Medida__c)){

	                        ventaCSV.producto = datosVentas.productos.get(ventaCSV.producto.Variedad__c).get(ventaCSV.producto.Family).get(ventaCSV.producto.Categoria__c).get(ventaCSV.producto.Unidad_de_Medida__c);

	                    }

	                }

	            }

	        }

	        //Buscamos su cultivo
	        if(datosVentas.cultivos.containsKey(ventaCSV.cultivo.Name)){
	            ventaCSV.cultivo = datosVentas.cultivos.get(ventaCSV.cultivo.Name);
	        }

	        //Buscamos su campana agricola
	        if(datosVentas.campanas.containsKey(ventaCSV.campanaVenta.Name)){
	            ventaCSV.campanaVenta = datosVentas.campanas.get(ventaCSV.campanaVenta.Name);
	        }

	        if(ventaCSV.producto.Id != null && ventaCSV.cultivo.Id != null && ventaCSV.campanaVenta.Id != null ){

	            //Buscamos el originante
	            if(datosVentas.cuentas.containsKey(ventaCSV.localidadOriginante.CP__c)){
	                if(datosVentas.cuentas.get(ventaCSV.localidadOriginante.CP__c).containsKey(ventaCSV.originante.N_CUIT__c)){
	                    ventaCSV.originante = datosVentas.cuentas.get(ventaCSV.localidadOriginante.CP__c).get(ventaCSV.originante.N_CUIT__c);
	                }
	            }

	            //Buscamos el destinatario
	            if(datosVentas.cuentas.containsKey(ventaCSV.localidadDestinatario.CP__c)){
	                if(datosVentas.cuentas.get(ventaCSV.localidadDestinatario.CP__c).containsKey(ventaCSV.destinatario.N_CUIT__c)){
	                    ventaCSV.destinatario = datosVentas.cuentas.get(ventaCSV.localidadDestinatario.CP__c).get(ventaCSV.destinatario.N_CUIT__c);
	                }
	            }

	            //Verificamos si la cuenta originante se encuentra
	            if(ventaCSV.originante.Id == null){
	                //Debemos crear una nueva cuenta
	                cuentasToInsert.add(crearCuenta(ventaCSV.originante, ventaCSV.localidadOriginante, ventaCSV.provinciaOriginante, ventaCSV.partidoOriginante,ventaCSV.rolOriginante, datosVentas.tiposDeRegistros, datosVentas.localidades));
	            }

	            //Verificamos si la cuenta destinatario se encuentra
	            if(ventaCSV.destinatario.Id == null){
	                //Debemos crear una nueva cuenta
	                cuentasToInsert.add(crearCuenta(ventaCSV.destinatario, ventaCSV.localidadDestinatario, ventaCSV.provinciaDestinatario, ventaCSV.partidoDestinatario,ventaCSV.rolDestinatario, datosVentas.tiposDeRegistros, datosVentas.localidades));
	            }

	            //Verificamos si la venta se puede insertar en la BD, es decir si la venta tiene todos sus datos
	            if(ventaCSV.originante.Id != null && ventaCSV.destinatario.Id != null){

	                //Seteamos las correspondientes relaciones
	                ventaCSV.venta.Cultivo__c = ventaCSV.cultivo.Id;
	                ventaCSV.venta.Campana_Agricola__c = ventaCSV.campanaVenta.Id;
	                ventaCSV.venta.Producto__c = ventaCSV.producto.Id;
	                ventaCSV.venta.Originante__c = ventaCSV.originante.Id;
	                ventaCSV.venta.Destinatario__c = ventaCSV.destinatario.Id;
	                ventaCSV.venta.Cargado_desde_Archivo__c = true;

	                ventasCSVToInsert.put(ventasToInsert.size(), ventaCSV);

	                //Agregamos a la lista de ventas a insertar
	                ventasToInsert.add(ventaCSV.venta);

	            }else{

	                //Las agregamos a una lista de ventas pendientes a procesar cuentas
	                ventasPendientes.add(ventaCSV);

	            }    

	        }else{

	            //Si la campana , el cultivo o el producto, no se encontraron indicamos el error,
	            //ya que no vamos a crear una campana, un cultivo o un producto

	            //Verifico si esta la entrada en el map
	            if(!ventasCSVErrores.containsKey(ventaCSV.linea)){
	                ventasCSVErrores.put(ventaCSV.linea,new VentaCSVErrores());
	            }

	            //Verifico si no esta el producto
	            if(ventaCSV.producto.Id == null){

	            	System.debug(LoggingLevel.INFO, ventaCSV.producto);

	                //El producto no esta, indico este error, asi luego se imprime en el archivo de errores
	                ventasCSVErrores.get(ventaCSV.linea).productoNoEncontrado = true;

	            }

	            //Verifico si no esta el cultivo
	            if(ventaCSV.cultivo.Id == null){

	                //El cultivo no esta, indico este error, asi luego se imprime en el archivo de errores
	                ventasCSVErrores.get(ventaCSV.linea).cultivoNoEncontrado = true;

	            }

	            //Verifico si no esta la campana
	            if(ventaCSV.campanaVenta.Id == null){

	            	System.debug(LoggingLevel.INFO, ventaCSV.campanaVenta.Name);

	                //La campana no esta, indico este error, asi luego se imprime en el archivo de errores
	                ventasCSVErrores.get(ventaCSV.linea).campanaNoEncontrada = true;

	            }

	            errores++;


	        }
	        
	        
	    }

	    if(cuentasToInsert.size() > 0){

	    	System.debug(LoggingLevel.INFO, 'INSERTANDO CUENTAS');
	        
	        //Lista que contendra la cuentas a insertar
	        List<Account> ctoInsert = new List<Account>();

	        //Agregamos el set a la lista
	        ctoInsert.addAll(cuentasToInsert); 

	        //Hacemos un insercion parcial de las cuentas, de manera que si falla una cuenta no se interrumpa el
	        //proceso
	        List<Database.SaveResult> cuentasSaveResult = UtilsAccount.insertPartialList(ctoInsert);

	        //Iteramos sobre las ventas que han quedado pendientes a procesar sus cuentas
	        // y revisamos si se puedo insertar el Originante y el Destinatario
	        for(VentaCSV ventaCSV : ventasPendientes){

	            //Se inserto el originante, el destinatario o ambos.
	            if(ventaCSV.originante.Id != null && ventaCSV.destinatario.Id != null){

	                //Seteamos las correspondientes relaciones
	                ventaCSV.venta.Cultivo__c = ventaCSV.cultivo.Id;
	                ventaCSV.venta.Campana_Agricola__c = ventaCSV.campanaVenta.Id;
	                ventaCSV.venta.Producto__c = ventaCSV.producto.Id;
	                ventaCSV.venta.Originante__c = ventaCSV.originante.Id;
	                ventaCSV.venta.Destinatario__c = ventaCSV.destinatario.Id;
	                ventaCSV.venta.Cargado_desde_Archivo__c = true;

	                ventasCSVToInsert.put(ventasToInsert.size(), ventaCSV);

	                //Agregamos a la lista de ventas a insertar
	                ventasToInsert.add(ventaCSV.venta);

	                System.debug(LoggingLevel.INFO, 'INSERTANDO VENTA SIN CUENTA');

	                ventasSinCuenta++;

	            }else{ //Ocurrio un Error al Insertar el Destinatario o el Originante

	            	errores++;

	                //Verifico si esta la entrada en el map
	                if(!ventasCSVErrores.containsKey(ventaCSV.linea)){
	                    ventasCSVErrores.put(ventaCSV.linea,new VentaCSVErrores());
	                }

	                if(ventaCSV.originante.Id == null)
	                    ventasCSVErrores.get(ventaCSV.linea).errorCargaOriginante = obtenerErrorInsercionDeCuentas(cuentasToInsert, ventaCSV.originante,cuentasSaveResult);

	                if(ventaCSV.destinatario.Id == null)
	                    ventasCSVErrores.get(ventaCSV.linea).errorCargaDestinatario = obtenerErrorInsercionDeCuentas(cuentasToInsert, ventaCSV.destinatario,cuentasSaveResult);    
	                    
	            }

	        } 
	    
	    }

	    //Hacemos una insercion parcial de las ventas
	    List<Database.SaveResult> ventasSaveResult = UtilsVentas.insertPartialList(ventasToInsert);

	    // Set con ventas que se insertaron eficasmente
	    Set<Id> idsVentas = new Set<Id>();

	    //Recorremos los resultados, agregamos a la lista de ventas que se muestra en pantalla, las ventas
	    //que se han cargado correctamente
	    for(Integer i = 0 ; i < ventasSaveResult.size() ; i++){

	        //Obtenemos el SVR
	        Database.SaveResult svr = ventasSaveResult.get(i);

	        if(svr.isSuccess()){

	            //Obtengo la venta del map
	            if(ventasToInsert.size() > i){


	                idsVentas.add(ventasToInsert.get(i).Id);

	            }    

	            ventasExitosas++;

	        }else{

	        	errores++;

	        	if(!ventasCSVToInsert.containsKey(i)) continue;

	        	VentaCSV ventaCSV = ventasCSVToInsert.get(i);

	            //Agrego el error a la venta

	            //Verifico si esta la entrada en el map
	            if(!ventasCSVErrores.containsKey(ventaCSV.linea)){
	                ventasCSVErrores.put(ventaCSV.linea,new VentaCSVErrores());
	            }

	            //Agrego el error          
	            for(Database.Error err : svr.getErrors()) {                   

	                ventasCSVErrores.get(ventaCSV.linea).errorCargaVenta += err.getStatusCode() + ': ' + err.getMessage();

	            }

	        }

	    }

	    //offset += csvLines.size();

	    appendToSuccessFile(csvLines);
	    appendToErrorFile(csvLines);

	    System.debug(LoggingLevel.INFO, ventasCSVErrores.size());

	    System.debug(LoggingLevel.INFO, ventasExitosas);

     	System.debug(LoggingLevel.INFO, errores);

     	System.debug(LoggingLevel.INFO, ventasSinCuenta);

     	System.debug(LoggingLevel.INFO, cuentasToInsert);

   	}
	
	global void finish(Database.BatchableContext BC){

		/*
		
		// Obtengo la carpeta donde almacenare el archivo de exitos y/o errores
		List<Folder> fs = [SELECT Id,DeveloperName FROM Folder WHERE DeveloperName = :FOLDER_DEVELOPER_NAME];



		if(fs.size() == 1){

		    if(ventasCSVErrores.size() > 0){
		        
    			// Creamos un documento de errores
		        Document d = new Document();
		        d.name = timeStamp+'_errors';
		        d.body = Blob.valueOf(getErrorFileLines());
		        d.type = 'csv';
		        d.FolderId = fs.get(0).Id;
		        insert d;

		    }

		    if(getVentasCargadasCorrectamente()){

		    	// Creamos un documento de errores
		        Document d = new Document();
		        d.name = timeStamp+'_success';
		        d.body = Blob.valueOf(getSuccessFileLines());
		        d.type = 'csv';
		        d.FolderId = fs.get(0).Id;
		        insert d;

		    		
		    }
		}

		*/
	}

	/*
	* Metodos Auxiliares
	*/

	private void appendToSuccessFile(List<String> csvLines){

        String successFileLines = getSuccessFileLines(csvLines);

        if(String.isEmpty(successFileLines) || successFileLines.trim().length() == 0){
            return;
        }
		
		// Obtengo la carpeta donde almacenare el archivo de exitos y/o errores
		List<Folder> fs = [SELECT Id,DeveloperName FROM Folder WHERE DeveloperName = :FOLDER_DEVELOPER_NAME];

		if(fs.size() == 1){

			String fileName = timeStamp+'_success';

		    List<Document> ds = [SELECT Id, Body FROM Document WHERE Name = :fileName AND Type = 'csv' AND FolderId = :fs.get(0).Id];

		    Document d = null;

		    if(ds.size() == 1){

		    	d = ds.get(0);

		    	String sCurrentBody = d.Body.toString();
		    	sCurrentBody += successFileLines;
		    	d.Body = Blob.valueOf(sCurrentBody);
        		

		    }else{

		    	// Al crear el file tengo que agregarle el header

		    	d = new Document();
		        d.name = fileName;
		        d.body = Blob.valueOf(HEADER+'\n'+successFileLines);
		        d.type = 'csv';
		        d.FolderId = fs.get(0).Id;
		        
		    }

		    upsert d;

		}    


	}


	private void appendToErrorFile(List<String> csvLines){

        String errorFileLines = getErrorFileLines(csvLines);

        if(String.isEmpty(errorFileLines) || errorFileLines.trim().length() == 0){
            return;
        }

		// Obtengo la carpeta donde almacenare el archivo de exitos y/o errores
		List<Folder> fs = [SELECT Id,DeveloperName FROM Folder WHERE DeveloperName = :FOLDER_DEVELOPER_NAME];

		if(fs.size() == 1){

			String fileName = timeStamp+'_errors';

		    List<Document> ds = [SELECT Id, Body FROM Document WHERE Name = :fileName AND Type = 'csv' AND FolderId = :fs.get(0).Id];

		    Document d = null;

		    if(ds.size() == 1){

		    	d = ds.get(0);

		    	String sCurrentBody = d.Body.toString();
		    	sCurrentBody += errorFileLines;
		    	d.Body = Blob.valueOf(sCurrentBody);
        		

		    }else{

		    	// Al crear el file tengo que agregarle el header

		    	d = new Document();
		        d.name = fileName;
		        d.body = Blob.valueOf(HEADER+', Errores'+'\n'+errorFileLines);
		        d.type = 'csv';
		        d.FolderId = fs.get(0).Id;
		        
		    }

		    upsert d;

		}    
	}

	/**
    * @author Maximo Martinez
    * @date 15/10/2014
    * @description Metodo que imprime el archivo de exitos que sale de la carga del CSV
    */ 
    private String getSuccessFileLines(List<String> csvLines){

        //Obtenemos las lineas del archivo csv
        //List<String> csvLines = CSVFileManager.getBody(Blob.valueOf(this.csvFile), true);

        //Lista que contendra las lineas del archivo
        String successLines = '';

        //Recorremos sus lineas
        for(Integer i = 0; i < csvLines.size() ; i++){

            String csvLine = csvLines.get(i);

            csvLine = csvLine.replace('\n', '').replace('\r', '');

            //La primer linea corresponde al header
            /*if(i == 0){

                //Agregamos el fin de linea
                csvLine += '\n';

                //Agregamos la linea
                successLines+=csvLine; 

            }else{ *///Las demas lineas corresponde a lineas de venta

                //Verificamos si la linea esta en el map de errores
                if(!ventasCSVErrores.containsKey(i)){

                    //Agregamos el fin de linea
                    csvLine += '\n';

                    //Agregamos la linea
                    successLines+=csvLine;    

                }
                


           // }

            

        }

        return successLines;

    }

    /**
    * @author Maximo Martinez
    * @date 24/09/2014
    * @description Metodo que imprime las lineas que estan duplicadas
    */ 
    private String getDuplicateLines(String csvLine, Integer currentLine){

        //Variable que imprime el error de lineas duplicadas
        String errorMsg = '';

        //Verificamos si esta la entrada en el map
        if(ventasDuplicadasError.containsKey(csvLine.trim())){

            //Obtenemos las lineas duplicadas
            List<Integer> lineasDuplicadas = ventasDuplicadasError.get(csvLine.trim());

            if(lineasDuplicadas.size() == 1) return errorMsg;

            //Hacemos un sort de la list
            lineasDuplicadas.sort();

            //Armamos el mensaje
            for(Integer i = 0 ; i < lineasDuplicadas.size() ; i++){

                //Obtengo la linea
                Integer linea = lineasDuplicadas.get(i);

                //Verifico si la linea por la que consulto es el primer elemento de la lista
                //en ese caso no marco el error pq no es la linea que duplica
                if(linea == currentLine && i == 0)
                    break;

                if(linea != currentLine){

                    if(errorMsg.length() != 0)
                        errorMsg += '-'+' ';

                    errorMsg += String.valueOf((linea+1));    

                }

            }

            if(errorMsg.length() != 0){
                if(lineasDuplicadas.size() == 2)
                    errorMsg = 'Linea duplicada con la linea '+errorMsg+' del archivo "'+fileName+'";';
                else
                    errorMsg = 'Linea duplicada con las lineas '+errorMsg+' del archivo "'+fileName+'";';
            }

        }

        return errorMsg;    

    }

    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que imprime el archivo de errores que sale de la carga del CSV
    */ 
    public String getErrorFileLines(List<String> csvLines){

        //Obtenemos las lineas del archivo csv
        //List<String> csvLines = CSVFileManager.getBody(Blob.valueOf(this.csvFile), true);

        //Lista que contendra las lineas del archivo
        String errorLines = '';

        //Recorremos sus lineas
        for(Integer i = 0; i < csvLines.size() ; i++){

            String csvLine = csvLines.get(i);

            csvLine = csvLine.replace('\n', '').replace('\r', '');

            //La primer linea corresponde al header
            /*if(i == 0){

                //Agregamos al header, una columna llamada errores
                csvLine+= ','+' '+'Errores'; 

                //Agregamos el fin de linea
                csvLine += '\n';

                //Agregamos la linea
                errorLines+=csvLine; 

            }else{ //Las demas lineas corresponde a lineas de venta*/

                //Obtengo las lineas duplicadas (si las hay)
                String lineasDuplicadas = getDuplicateLines(csvLine, i);

                String errores = lineasDuplicadas;

                //Verificamos si la linea esta en el map de errores
                if(ventasCSVErrores.containsKey(i)){

                    //Obtenemos la linea
                    errores += ventaCSVErrorToString(ventasCSVErrores.get(i));

                    csvLine +=',';

                    if(errores.length() > 0)
                        csvLine += '"'+errores+'"';

                    //Agregamos el fin de linea
                    csvLine += '\n';

                    //Agregamos la linea
                    errorLines+=csvLine;    

                }

            //}

            

        }

        return errorLines;

    }

        /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que convierte un objeto VentaCSVError en un String
    */
    private static String ventaCSVErrorToString(VentaCSVErrores ventaCSVErrores){

        String errores = '';

        if(ventaCSVErrores.errorCargaVenta != null && ventaCSVErrores.errorCargaVenta != '')
            errores += ERROR_VENTA_INSERTION_FAILURE +' '+ventaCSVErrores.errorCargaVenta;
        
        if(ventaCSVErrores.errorCargaOriginante != null && ventaCSVErrores.errorCargaOriginante != '')
            errores += ERROR_ORIGINANTE_INSERTION_FAILURE+' '+ventaCSVErrores.errorCargaOriginante;

        if(ventaCSVErrores.errorCargaDestinatario != null && ventaCSVErrores.errorCargaDestinatario != '')
            errores += ERROR_DESTINATARIO_INSERTION_FAILURE+' '+ventaCSVErrores.errorCargaDestinatario;
        
        if(ventaCSVErrores.productoNoEncontrado == true)
            errores += ERROR_PRODUCT_NOT_FOUND+';';
        
        if(ventaCSVErrores.campanaNoEncontrada == true)
            errores += ERROR_CAMPANA_NOT_FOUND+';';
        
        if(ventaCSVErrores.cultivoNoEncontrado == true)
            errores += ERROR_CULTIVO_NOT_FOUND+';';

        return errores;

    }

	/**
    * @author Maximo Martinez
    * @date 15/10/2014
    * @description Metodo que indica si hay ventas que se han cargado correctamente 
    */ 
    private Boolean getVentasCargadasCorrectamente(){

        //Obtenemos las lineas del archivo csv
        List<String> csvLines = CSVFileManager.getBody(Blob.valueOf(this.csvFile), true);

        return (csvLines.size()-1) > (ventasCSVErrores.size()+blankLineCounter);
    }

    /**
    * @author Maximo Martinez
    * @date 15/10/2014
    * @description Metodo que determina si una linea es vacia
    */
    private static Boolean isEmptyLine(String line, String separator){

        List<String> values = line.split(separator);

        Integer i = 0;

        while(i < values.size() && values.get(i).trim().length() == 0){
            i++;
        }

        return i == values.size();

    }

	/**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo a partir de una linea retorna una VentaCSV
    */ 
    private static VentaCSV getVentaCSVFromLine(String line){

        //Obtenemos los elementos de la linea
        List<String> lineElements = CSVFileManager.getLineElements(line, ',');

        //Instanciamos una nueva venta
        VentaCSV ventaCSV = new VentaCSV();

        //Recorremos los elementos de una linea del CSV
        for(Integer j = 0; j < lineElements.size() ; j++){

            String valor = lineElements[j];

            if(j == COL_RAZON_SOCIAL_ORIGINANTE){
                ventaCSV.originante.Name = valor;
            }else if(j == COL_CUIT_ORIGINANTE){    
                ventaCSV.originante.N_CUIT__c = valor;
            }else if(j == COL_CP_ORIGINANTE){
                ventaCSV.localidadOriginante.CP__c = valor;
            }else if(j == COL_CALLE_ORIGINANTE){
                ventaCSV.originante.Calle_Envio__c = valor;
            }else if(j == COL_NUMERO_ORIGINANTE){
                ventaCSV.originante.Numero_Depto_Piso_Envio__c = valor;
            }else if(j == COL_PROVINCIA_ORIGINANTE){
                ventaCSV.provinciaOriginante.Name = valor;
            }else if(j == COL_PARTIDO_ORIGINANTE){
                ventaCSV.partidoOriginante.Name = valor;
            }else if(j == COL_CAMPANA){
                ventaCSV.campana.Name = valor;
            }else if(j == COL_CULTIVO){
                ventaCSV.cultivo.Name = valor;
            }else if(j == COL_FECHA){
                ventaCSV.venta.Fecha__c = Utils.stringToDate(valor);
            }else if(j == COL_FECHA_FACTURACION){
                ventaCSV.venta.Fecha_Facturacion__c = Utils.stringToDate(valor);
            }else if(j == COL_CANAL){
                ventaCSV.venta.Canal__c = valor;
            }else if(j == COL_UM_PRODUCTO){
                ventaCSV.producto.Unidad_de_Medida__c = valor;
            }else if(j == COL_TIPO_PRODUCTO){
                ventaCSV.producto.Family = valor;
            }else if(j == COL_CATEGORIA_PRODUCTO){
                ventaCSV.producto.Categoria__c = valor;
            }else if(j == COL_VARIEDAD_PRODUCTO){
                ventaCSV.producto.Variedad__c = valor;
            }else if(j == COL_CANTIDAD_BOLSAS){
                ventaCSV.venta.Cantidad__c = Utils.stringToDouble(valor);
            }else if(j == COL_CAMPANA_VENTAS){
                ventaCSV.campanaVenta.Name = valor;
            }else if(j == COL_ROL_DESTINATARIO){
                ventaCSV.venta.Rol_Destinatario__c = valor;
                ventaCSV.rolDestinatario = valor;
            }else if(j == COL_ROL_ORIGINANTE){
                ventaCSV.venta.Rol_Originante__c = valor;
                ventaCSV.rolOriginante = valor;
            }else if(j == COL_CP_DESTINATARIO){
                ventaCSV.localidadDestinatario.CP__c = valor;
            }else if(j == COL_LOCALIDAD_DESTINATARIO){
                ventaCSV.localidadDestinatario.Name = valor;
            }else if(j == COL_PARTIDO_DESTINATARIO){
                ventaCSV.partidoDestinatario.Name = valor;
            }else if(j == COL_PROVINCIA_DESTINATARIO){
                ventaCSV.provinciaDestinatario.Name = valor;
            }else if(j == COL_NUMERO_DESTINATARIO){
                ventaCSV.destinatario.Numero_Depto_Piso_Envio__c = valor;
            }else if(j == COL_CALLE_DESTINATARIO){
                ventaCSV.destinatario.Calle_Envio__c = valor;
            }else if(j == COL_RAZON_SOCIAL_DESTINATARIO){
                ventaCSV.destinatario.Name = valor;
            }else if(j == COL_LOCALIDAD_ORIGINANTE){
                ventaCSV.localidadOriginante.Name = valor;
            }else if(j == COL_CUIT_DESTINATARIO){
                ventaCSV.destinatario.N_CUIT__c = valor;
            }else if(j == COL_NUMERO_COMPROBANTE){
                ventaCSV.venta.Nro_de_Comprobante__c = valor;
            }else if(j == COL_KILOS_POR_BOLSA){
                ventaCSV.kilosPorBolsa = valor;
            }else if(j == COL_ORIGEN_REGISTRO){
                ventaCSV.origenRegistro = valor;
            }else if(j == COL_GESTOR){
                ventaCSV.gestor = valor;
            }else if(j == COL_ZONA_VENTA){
                ventaCSV.zonaVenta = valor;
            }
        }  
        return ventaCSV;

    }

    /**
    * @author Maximo Martinez
    * @date 15/09/2014
    * @description Metodo que crea una cuenta
    */ 
    @TestVisible private static Account crearCuenta(Account cuenta, Localidad__c localidad , Provincia__c provincia, Partido__c partido,String rolCuenta, Map<String,RecordType> tiposDeProductos,MAP<String,MAP<String,MAP<String,MAP<String,Localidad__c>>>> localidades){
        
        //Buscamos el recortype de la cuenta
        if(tiposDeProductos.containsKey(rolCuenta)){
            cuenta.RecordTypeId = tiposDeProductos.get(rolCuenta).Id;
        }

        //Buscamos la localidad de la cuenta
        if(localidades.containsKey(provincia.Name)){
            if(localidades.get(provincia.Name).containsKey(partido.Name)){
                if(localidades.get(provincia.Name).get(partido.Name).containsKey(localidad.CP__c)){
                    if(localidades.get(provincia.Name).get(partido.Name).get(localidad.CP__c).containsKey(localidad.Name)){
                        cuenta.Localidad_Envio__c = localidades.get(provincia.Name).get(partido.Name).get(localidad.CP__c).get(localidad.Name).Id;
                    }
                }
            }
        }
    
        //Retornamos la cuenta con los datos que faltaban setear    
        return cuenta;            
    }

  	private static String obtenerErrorInsercionDeCuentas(Set<Account> cuentas, Account cuenta, List<Database.SaveResult> svrs){

        String error = '';

        Integer i = 0;

        for(Account a : cuentas){

            if(a == cuenta){

                //Verificamos si esta en el SaveResult
                if(i < svrs.size()){

                    //Obtenemos el save result
                    Database.SaveResult svr = svrs[i];

                    //Verificamos si ocurrio efectivamente un error
                    if(!svr.isSuccess()){

                        //Mostramos los error que ocurrieron               
                        for(Database.Error err : svr.getErrors()) {                   

                            error += err.getStatusCode() + ': ' + err.getMessage()+';';

                        }

                    }

                }

                //Salimos del FOR
                break;

            }

            i++;

        }

        return error;

    }

    /*
	* Clases Auxiliares
	*/

	/**
    * @author Maximo Martinez
    * @date 22/06/2014
    * @description Clase auxiliar que contiene los errores de una venta determinada
    */
    public class VentaCSVErrores{
        //Atributos
        public String errorCargaOriginante {get; set;}
        public String errorCargaDestinatario {get; set;}
        public String errorCargaVenta {get; set;}
        public Boolean productoNoEncontrado {get; set;}
        public Boolean cultivoNoEncontrado {get; set;}
        public Boolean campanaNoEncontrada {get; set;}
        public Boolean ventaDuplicada {get; set;}


        //Constructor
        public VentaCSVErrores(){
            this.errorCargaDestinatario = '';
            this.errorCargaOriginante = '';
            this.errorCargaVenta = '';
            this.productoNoEncontrado = false;
            this.cultivoNoEncontrado = false;
            this.campanaNoEncontrada = false;
            this.ventaDuplicada = false;
        }
    }

    /**
    * @author Maximo Martinez
    * @date 2/06/2014
    * @description Clase que representa una venta cargada en el archivo CSV
    */
    public class VentaCSV{

        //Atributos
        public Account originante {get; set;}
        public Account destinatario {get; set;}
        public Venta__c venta {get; set;}
        public Product2 producto {get; set;}
        public Localidad__c localidadOriginante {get; set;}
        public Localidad__c localidadDestinatario {get; set;}
        public Provincia__c provinciaOriginante {get; set;}
        public Partido__c partidoOriginante {get; set;}
        public Provincia__c provinciaDestinatario {get; set;}
        public Partido__c partidoDestinatario {get; set;}
        public Campana_Agricola__c campana {get; set;}
        public Campana_Agricola__c campanaVenta {get; set;}
        public Cultivo__c cultivo {get; set;}
        public String rolOriginante {get; set;}
        public String rolDestinatario {get; set;}
        public String kilosPorBolsa {get; set;}
        public String origenRegistro {get; set;}
        public String gestor {get; set;}
        public String zonaVenta {get; set;}
        public Integer linea {get; set;}

        //Constructor
        public VentaCSV(){

            //Instancio los atributos
            this.originante = new Account();
            this.destinatario = new Account();
            this.venta = new Venta__c();
            this.producto = new Product2();
            this.localidadOriginante = new Localidad__c();
            this.localidadDestinatario = new Localidad__c();
            this.provinciaOriginante = new Provincia__c();
            this.partidoOriginante = new Partido__c();
            this.provinciaDestinatario = new Provincia__c();
            this.partidoDestinatario = new Partido__c();
            this.campana = new Campana_Agricola__c();
            this.campanaVenta = new Campana_Agricola__c();
            this.cultivo = new Cultivo__c();

        }

    }

    /**
    * @author Maximo Martinez
    * @date 22/09/2014
    * @description Clase Auxiliar que contiene SET con datos referidos las ventas
    */
    public class DatosVentas{

        //Atributos
        public Set<String> numerosCUIT {get; set;}
        public Set<String> codigosPostales {get; set;}
        public Set<String> ciudades {get; set;}
        public Set<String> partidos {get; set;}
        public Set<String> provincias {get; set;}
        public Set<String> variedades {get; set;}
        public Set<String> tiposDeProductos {get; set;}
        public Set<String> unidadesDeMedida {get; set;}
        public Set<String> categorias {get; set;}
        public Set<String> campanasVentas {get; set;}
        public Set<String> cultivosVentas {get; set;}
        public Map<String,Map<String,Account>> cuentas {get; set;}
        public Map<String,Map<String,Map<String,Map<String,Product2>>>> productos {get; set;}
        public Map<String,Map<String, Map<String, Map<String, Localidad__c>>>> localidades {get; set;}
        public Map<String,Cultivo__c> cultivos {get; set;}
        public Map<String,Campana_Agricola__c> campanas {get; set;}
        public Set<String> roles {get; set;}
        public Map<String,RecordType> tiposDeRegistros {get; set;}

        //Constructor
        public DatosVentas(){
            this.numerosCUIT = new Set<String>();
            this.codigosPostales = new Set<String>();
            this.variedades = new Set<String>();
            this.tiposDeProductos = new Set<String>();
            this.unidadesDeMedida = new Set<String>();
            this.categorias = new Set<String>();
            this.campanasVentas = new Set<String>();
            this.cultivosVentas = new Set<String>();
            this.cuentas = new Map<String,Map<String,Account>>();
            this.productos = new Map<String,Map<String,Map<String,Map<String,Product2>>>>();
            this.localidades = new Map<String,Map<String, Map<String, Map<String, Localidad__c>>>>();
            this.cultivos = new Map<String,Cultivo__c>();
            this.campanas = new Map<String,Campana_Agricola__c>();
            this.roles = new Set<String>();
            this.tiposDeRegistros = new Map<String,RecordType>();
            this.provincias = new Set<String>();
            this.partidos = new Set<String>();
            this.ciudades = new Set<String>();
        }

    }
    
	
}