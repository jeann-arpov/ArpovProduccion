public without sharing class lwcVentasImportFromExcel {
    //Test_VImportExcel

    // Mapeo Tipo de Comprobante recibido en el Excel -> valor almacenable en SF.
    // Ticket 1874: se quita ND, se agregan Remito y Remito de Devolución.
    private static final Map<String, String> TIPO_COMPROBANTE_MAP = new Map<String, String>{
        'FC' => 'FC',
        'NC' => 'NC',
        'Remito' => 'FC',
        'REMITO' => 'FC',
        'Remito de Devolución' => 'NC',
        'Remito de Devolucion' => 'NC'
    };

    // Valores canónicos INASE (misma lista que picklist portal).
    @TestVisible private static final List<String> CATEGORIAS_VALIDAS = new List<String>{
        'Pre Básica',
        'Original o Fundadora',
        'Primera Multiplicación',
        'Segunda Multiplicación',
        'Tercera Multiplicación'
    };

    /** Alias solo en plantilla Excel: Original, Fundadora u Origina → Original o Fundadora. */
    @TestVisible private static final Set<String> CATEGORIA_ALIASES_PLANTILLA = new Set<String>{
        'original', 'fundadora', 'origina'
    };

    // Campos que reciben CUITs y deben ser normalizados (quitar guiones/puntos/espacios).
    private static final Set<String> CAMPOS_CUIT = new Set<String>{
        'CUIT_Destinatario__c', 'CUIT_Originante__c'
    };

    /** Clave temporal en el Map de fila (no es campo de SF); se usa antes del deserialize. */
    @TestVisible private static final String CAMPANA_AGRICOLA_NOMBRE_KEY = '_CampanaAgricolaNombre';

    // Alias de columnas: nombres idénticos al Pop Up "Nueva Venta" + API legacy.
    private static final Map<String, String> COLUMN_ALIASES = new Map<String, String>{
        'Campaña de Ventas' => 'Campana_de_Ventas__c',
        'Campana de Ventas' => 'Campana_de_Ventas__c',
        'Campana Agricola' => 'Campana_de_Ventas__c',
        'Campaña Agrícola' => 'Campana_de_Ventas__c',
        'Categoria' => 'Categoria__c',
        'Kilos Totales' => 'Cantidad_de_Bolsas__c',
        'Categoría' => 'Categoria__c',
        'CUIT Destinatario' => 'CUIT_Destinatario__c',
        'CUIT Originante' => 'CUIT_Originante__c',
        'Fecha Comprobante' => 'Fecha_de_Facturacion__c',
        'Fecha de Comprobante' => 'Fecha_de_Facturacion__c',
        'Fecha de Facturación' => 'Fecha_de_Facturacion__c',
        'Fecha de Facturacion' => 'Fecha_de_Facturacion__c',
        'Kilos por Bolsa' => 'Kilos_por_Bolsa__c',
        'Línea del Comprobante' => 'Linea_Facturacion__c',
        'Linea del Comprobante' => 'Linea_Facturacion__c',
        'Línea Facturación' => 'Linea_Facturacion__c',
        'Linea Facturacion' => 'Linea_Facturacion__c',
        'Nº de Comprobante' => 'N_de_Comprobante__c',
        'N° de Comprobante' => 'N_de_Comprobante__c',
        'N de Comprobante' => 'N_de_Comprobante__c',
        'N° Comprobante' => 'N_de_Comprobante__c',
        'Nº Comprobante' => 'N_de_Comprobante__c',
        'N Comprobante' => 'N_de_Comprobante__c',
        'Razón Social Destinatario' => 'Razon_Social_Destinatario__c',
        'Razon Social Destinatario' => 'Razon_Social_Destinatario__c',
        'Tipo de Comprobante' => 'Tipo_Comprobante_Externo__c',
        'Variedad' => 'Variedad__c'
    };

        @AuraEnabled
        public static Id saveFileExcel(List<Map<String,Object>> fileRows){
            return Database.executeBatch(
                new BatchApexVentasInformeFromExcel(filterFilasDatosVentas(fileRows)),
                BatchApexVentasInformeFromExcel.BATCH_SIZE
            );
        }

        @AuraEnabled
        public static String getContentDocument(id id ){
            return [ SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :id AND IsLatest = true].VersionData.toString();
        } 
        @AuraEnabled
        public static List<Map<String,Object>> inserRecodrsFromExcel(List<Map<String,Object>> fileRows ,  String base64Data, string fileTitle, Id originanteAccountId){
            String networkId = Network.getNetworkId();
            Boolean isCoreImport = networkId == null && originanteAccountId != null;
            Account userAccont;
            Account originanteCore;
            Id accountId;
            Boolean isPortalObtentor = false;

            if (networkId != null) {
                User u = [
                    SELECT AccountId, Contact.AccountId
                    FROM User
                    WHERE Id = :UserInfo.getUserId()
                    LIMIT 1
                ];
                accountId = u.AccountId != null ? u.AccountId : u.Contact?.AccountId;
                if (accountId != null) {
                    userAccont = [
                        SELECT Id, N_CUIT__c, RecordType.DeveloperName, Type, Name
                        FROM Account
                        WHERE Id = :accountId
                        LIMIT 1
                    ];
                }
                isPortalObtentor = Test.isRunningTest() == false && [SELECT Name FROM Network WHERE id =: networkId].Name == 'Sembrá Evolución Obtentor';

            if (Test.isRunningTest() == false && userAccont == null) throw new AuraHandledException('El usuario debe estar asociado a una cuenta');
            if (Test.isRunningTest() == false && isPortalObtentor && userAccont.RecordType.DeveloperName != 'Obtentor') throw new AuraHandledException('Sólo usuarios obtentores pueden importar ventas');
            if (Test.isRunningTest() == false && !isPortalObtentor && userAccont.RecordType.DeveloperName != 'Distribuidor' && userAccont.N_CUIT__c != '30500120882') throw new AuraHandledException('Sólo usuarios distribuidores pueden importar ventas');
            } else if (isCoreImport) {
                originanteCore = CrearVentaInformadaLWCController.resolveOriginanteAccount(originanteAccountId);
                accountId = originanteCore.Id;
            } else if (Test.isRunningTest()) {
                userAccont = null;
                accountId = null;
            } else {
                throw new AuraHandledException('Debe seleccionar la cuenta originante antes de importar.');
            }

            fileRows = filterFilasDatosVentas(fileRows);
            if (fileRows.isEmpty()) {
                throw new AuraHandledException('No hay filas de ventas para importar. Eliminá las filas de ayuda al final de la planilla o completá al menos una fila de datos.');
            }

            List<Ventas_Informadas__c> ventasInformadasAInsertar = new List<Ventas_Informadas__c>();
            List<Ventas_Informadas__c> todasVentas = new List<Ventas_Informadas__c>();
            Boolean hayError = false;
            
            Lote__c lote = crearLote();
            insert lote;

            List<Account> cuentas = isPortalObtentor ? [Select Id, N_CUIT__c, RecordType.DeveloperName, Type, Name FROM Account WHERE RecordType.DeveloperName in ('Distribuidor', 'Obtentor') and ((N_CUIT__c in ('30569723023', '30715468294') and Type = 'Obtentor') or parentId = null)] : new List<Account>();
            Map<String, List<Account>> cuentasPorCuit =
                VentasInformadasCuitResolver.agruparCuentasPorCuit(cuentas);

            // Pre-procesamos cada fila antes de los bulk query (solo cultivares/CUITs del archivo).
            for (Map<String,Object> fileRow : fileRows) {
                normalizeColumnAliases(fileRow);
                normalizeNComprobanteField(fileRow);
                normalizeCuitFields(fileRow);
                normalizeLineaFacturacionField(fileRow);
                normalizeCampanaAgricolaPreDeserialize(fileRow);
                normalizeCategoriaField(fileRow);
                normalizeTipoComprobanteField(fileRow);
                applyNComprobantePrefijoRemito(fileRow);
                normalizeVariedadField(fileRow);
                normalizeKilosTotalesField(fileRow);
                if (!isPortalObtentor) {
                    fileRow.remove('CUIT_Originante__c');
                }
            }

            Set<String> cultivaresEnArchivo = collectVariedadLabelsDesdeFilas(fileRows);
            Map<String, List<String>> mapValidacionVenta =
                buildMapValidacionVentaPorCultivares(cultivaresEnArchivo);
            Map<String, Variedad__c> variedadByName = getVariedadesPorNombre(fileRows, cultivaresEnArchivo);
            Map<String, Campana_Agricola__c> campanaByCultivoAno = getCampanasPorCultivoYAno(fileRows, variedadByName);
            VentasInformadasCuitResolver.CuitResolverCache cuitCache = VentasInformadasCuitResolver.buildCuitResolverCache(
                collectCuitsDesdeFilas(fileRows, isPortalObtentor),
                collectObtentorComercializaIds(variedadByName)
            );
            if (!cuentasPorCuit.isEmpty()) {
                cuitCache.mergeCuentasPorCuit(cuentasPorCuit);
            }

            for(Map<String,Object> fileRow : fileRows){
                fileRow.remove('Error'); 

                System.debug(fileRow.get('Fecha_de_Facturacion__c'));

                Date d;
                try {
                    Object fechaRaw = fileRow.get('Fecha_de_Facturacion__c');
                    d = parseFlexibleDate(fechaRaw);
                } catch (Exception e) {
                    
                } 
                Decimal cantidadBolsas = null;
                if (fileRow.containsKey('Cantidad_de_Bolsas__c') && fileRow.get('Cantidad_de_Bolsas__c') != null) {
                    cantidadBolsas = parseKilosTotales(fileRow.get('Cantidad_de_Bolsas__c'));
                }

                Object fecha  =fileRow.remove('Fecha_de_Facturacion__c');

                String cObjJsonDrunk = JSON.serialize(stripRowForDeserialize(fileRow));
                Ventas_Informadas__c venta  = null;
                try{
                    venta =(Ventas_Informadas__c)JSON.deserializeStrict(cObjJsonDrunk , Ventas_Informadas__c.class);
                }catch(Exception e){
                    throw new AuraHandledException('Nombre de columna inválida. NO cambiar el nombre de las columnas');
                }

                if (cantidadBolsas != null) venta.Cantidad_de_Bolsas__c = cantidadBolsas;

                boolean errorConDatos = false;
                if(d == null){
                    AddError(fileRow, 'Error con el formato del día'); errorConDatos = true;
                }

                fileRow.put('Fecha_de_Facturacion__c', fecha);

                if(venta != null){
                    if (isPortalObtentor) venta.obtentor__c = accountId;
                    venta.Fecha_de_Facturacion__c = d;

                    aplicarOriginanteEnImport(
                        venta,
                        fileRow,
                        isCoreImport,
                        isPortalObtentor,
                        accountId,
                        userAccont,
                        originanteCore,
                        cuentasPorCuit
                    );

                    if(venta.Cantidad_de_Bolsas__c == null) AddError(fileRow, 'Falta Kilos Totales');
                    if(venta.Categoria__c == null) AddError(fileRow, 'Falta Categoria__c'); 
                    if(venta.CUIT_Destinatario__c == null) AddError(fileRow, 'Falta CUIT_Destinatario__c');
                    venta.Kilos_por_Bolsa__c = 1;
                    if(venta.Linea_Facturacion__c == null) AddError(fileRow, 'Falta Línea del Comprobante');
                    if (!lwcVentasImportFromExcel.esTipoComprobanteExternoValido(venta.Tipo_Comprobante_Externo__c)) AddError(fileRow, 'El Tipo de Comprobante debe ser FC, NC, Remito o Remito de Devolución');
                    if(venta.Tipo_de_Comprobante__c == null || new List<String>{'FC', 'NC'}.contains(venta.Tipo_de_Comprobante__c) == false) AddError(fileRow, 'Error al mapear Tipo de Comprobante interno');
                    if(venta.Variedad__c == null) AddError(fileRow, 'Falta Variedad__c');
                    else {
                        Variedad__c vRef = variedadByName.get(variedadKey(venta.Variedad__c));
                        if (vRef == null) {
                            AddError(fileRow, 'La Variedad "' + venta.Variedad__c + '" no existe en Salesforce. Verificá el nombre exacto del cultivar INASE.');
                        } else {
                            String cultivarCanon = String.isNotBlank(vRef.Cultivar_Inase__c)
                                ? vRef.Cultivar_Inase__c
                                : venta.Variedad__c;
                            checkVenta(
                                mapValidacionVenta.get(variedadKey(cultivarCanon)),
                                fileRow,
                                venta,
                                cultivarCanon
                            );
                            venta.Variedad_INASE__c = vRef.Id;
                            if (vRef.Cultivo__c != null) venta.Cultivo__c = vRef.Cultivo__c;
                            // Canonizar el texto al nombre real del catálogo (ej. "DD32" -> "DD 32")
                            // para que el guardado y la detección de duplicados sean consistentes.
                            if (String.isNotBlank(vRef.Cultivar_Inase__c)) venta.Variedad__c = vRef.Cultivar_Inase__c;
                            VentasInformadasCuitResolver.aplicarOriginanteYDestinatario(
                                venta,
                                vRef.Obtentor_Comercializa__c,
                                cuitCache
                            );
                            VentasInformadasCuitResolver.aplicarVentaInterna(venta, cuitCache.accountsById);
                        }
                    }

                    if (String.isBlank(venta.Campana_de_Ventas__c)) {
                        AddError(fileRow, 'Falta Campaña Agrícola (año)');
                    } else if (venta.Variedad__c == null) {
                        AddError(fileRow, 'Indicá la Variedad para resolver la Campaña Agrícola');
                    } else {
                        Variedad__c vParaCamp = variedadByName.get(variedadKey(venta.Variedad__c));
                        applyCampanaAgricola(venta, campanaByCultivoAno, vParaCamp);
                        if (venta.Campana_Agricola__c == null) {
                            AddError(fileRow, 'No existe Campaña Agrícola para el cultivo de la variedad y el año ' + venta.Campana_de_Ventas__c);
                        }
                    }
                    if(venta.N_de_Comprobante__c == null) AddError(fileRow, 'Falta N_de_Comprobante__c');
                }  

                if(fileRow.containsKey('Error') == false){
                    ventasInformadasAInsertar.add(venta);
                    venta.Lote__c = lote.Id;
                }else {
                    hayError = true;
                }

                todasVentas.add(venta);
            }

            checkForDuplicates(ventasInformadasAInsertar);
            VentasInformadasExclusionUtil.marcarPendientesValidarSiCorresponde(
                ventasInformadasAInsertar,
                cuitCache.accountsById
            );
             
             List<Database.SaveResult> svrs = Utils.insertList(ventasInformadasAInsertar,false);
             integer offset = 0;
             for(Integer i=0;i<todasVentas.size();i++){
                 if(fileRows[i].containsKey('Error')){
                     offset ++;
                     continue;
                 }
                 if(svrs.size() <= (i - offset) ){
                     break;
                 }
                if(!svrs[i - offset].isSuccess()){
                    for (Database.Error err: svrs[i - offset].getErrors()) {
                        String error =  err.getMessage();
                        if (err.getFields().contains('CUIT_Destinatario__c')) {
                            error = 'Recuerde ingresar los CUIT sin guiones ni espacios, sólo números.';
                        }
                        AddError(fileRows[i], error);
                    }
                    hayError = true;
                }      
                
            }
            for(Map<String,Object> fileRow : fileRows){
            List<String> errores =   (List<String>)fileRow.get('Error');
                if(errores != null){
                    fileRow.put('Error', string.join(errores,', ') );
                }
            }


            system.debug(hayError);
             if(hayError){
                 delete lote;
                 List<Ventas_Informadas__c> ventasToDelete = new List<Ventas_Informadas__c>();
                 for(Ventas_Informadas__c venta : ventasInformadasAInsertar){
                     if(venta.id != null){
                        ventasToDelete.add(venta);
                    }
                }
                Utils.deleteList(ventasToDelete, false);
             }else {
                 
                base64Data = EncodingUtil.urlDecode(base64Data, 'UTF-8');
                ContentVersion conVer = new ContentVersion();
                conVer.ContentLocation = 'S'; // to use S specify this document is in Salesforce, to use E for external files
                conVer.PathOnClient = '/' + fileTitle; // The files name, extension is very important here which will help the file in preview.
                conVer.Title = fileTitle; // Display name of the files
                conVer.VersionData =EncodingUtil.base64Decode(base64Data); // converting your binary string to Blog
                conVer.IsMajorVersion = true;
                insert conVer;    //Insert ContentVersion
                // First get the Content Document Id from ContentVersion Object
                Id conDoc = [SELECT ContentDocumentId FROM ContentVersion WHERE Id =:conVer.Id].ContentDocumentId;
                //create ContentDocumentLink  record 
                ContentDocumentLink conDocLink = New ContentDocumentLink();
                conDocLink.LinkedEntityId = lote.id; // Specify RECORD ID here i.e Any Object ID (Standard Object/Custom Object)
                conDocLink.ContentDocumentId = conDoc;  //ContentDocumentId Id from ContentVersion
                conDocLink.shareType = 'I';
                insert conDocLink;

             }

             if(fileRows.size() > 0){
                 fileRows[0].put('isSucces' , !hayError);
             }

             return fileRows;
        }

        public static String key(Ventas_Informadas__c venta) {
            return venta.CUIT_Originante__c + '-' + venta.CUIT_Destinatario__c + '-' + venta.Variedad__c + '-' + venta.Cantidad_de_Bolsas__c.longValue() + '-' + venta.Campana_de_Ventas__c + '-' + venta.Categoria__c; 
        }

        @testVisible
        private static void checkForDuplicates(List<Ventas_Informadas__c> ventas) {
            Set<String> cuitsOriginante = new Set<String>();
            Set<String> cuitsDestinatarios = new Set<String>();
            Set<String> variedades = new Set<String>();
            Set<Decimal> cantidades = new Set<Decimal>();
            Set<String> campaigns = new Set<String>();
            Set<String> categorias = new Set<String>();

            for (Ventas_Informadas__c venta: ventas) {
                cuitsOriginante.add(venta.CUIT_Originante__c);
                cuitsDestinatarios.add(venta.CUIT_Destinatario__c);
                variedades.add(venta.Variedad__c);
                cantidades.add(venta.Cantidad_de_Bolsas__c);
                campaigns.add(venta.Campana_de_Ventas__c);
                categorias.add(venta.Categoria__c);
            }

            // Keys de registros YA existentes en la BD
            Set<String> existingKeys = new Set<String>();

            for (Ventas_Informadas__c venta: [
                SELECT CUIT_Originante__c, CUIT_Destinatario__c, Variedad__c, Cantidad_de_Bolsas__c, Campana_de_Ventas__c, Cultivo__c, Categoria__c 
                FROM Ventas_Informadas__c 
                WHERE CUIT_Originante__c IN :cuitsOriginante 
                    AND CUIT_Destinatario__c IN :cuitsDestinatarios 
                    AND Variedad__c IN :variedades 
                    AND Cantidad_de_Bolsas__c IN :cantidades 
                    AND Campana_de_Ventas__c IN :campaigns
                    AND Categoria__c IN :categorias
            ]) {
                existingKeys.add(key(venta));
            }

            // Keys procesadas en ESTE batch (para detectar duplicados dentro del mismo Excel)
            Set<String> processedKeys = new Set<String>();

            for (Ventas_Informadas__c venta: ventas) {
                String ventaKey = key(venta);
                
                // Si ya existe en BD O ya vimos esta key en el Excel actual, es duplicado
                if (existingKeys.contains(ventaKey) || processedKeys.contains(ventaKey)) {
                    venta.Resultado__c = 'Ya existe una venta con mismo cuit/variedad/cantidad/campaña';
                    venta.Estado__c = 'Preprocesado';
                } else {
                    // Primera vez que vemos esta key, la agregamos para marcar los siguientes
                    processedKeys.add(ventaKey);
                }
            }
        }

        @testVisible
        private static void checkVenta(
            List<String> categoriasProducto,
            Map<String,Object> fileRow,
            Ventas_Informadas__c venta
        ) {
            checkVenta(categoriasProducto, fileRow, venta, null);
        }

        @testVisible
        private static void checkVenta(
            List<String> categoriasProducto,
            Map<String,Object> fileRow,
            Ventas_Informadas__c venta,
            String cultivarDisplay
        ) {
            if (venta == null) {
                return;
            }

            String categoriaIngresada = normalizeCategoria(
                String.isNotBlank(venta.Categoria__c) ? venta.Categoria__c : venta.Categoria_Portal__c
            );
            if (String.isBlank(categoriaIngresada)) {
                return;
            }
            venta.Categoria__c = categoriaIngresada;
            venta.Categoria_Portal__c = categoriaIngresada;

            if (categoriasProducto == null || categoriasProducto.isEmpty()) {
                String sinProducto = 'No hay productos de Semilla Fiscalizada activos para la variedad';
                if (String.isNotBlank(cultivarDisplay)) {
                    sinProducto += ' "' + cultivarDisplay + '"';
                }
                AddError(fileRow, sinProducto + '.');
                return;
            }

            Set<String> keysPermitidas = new Set<String>();
            List<String> labelsPermitidas = new List<String>();
            String ingresadaKey = categoriaKey(categoriaIngresada);

            for (String canon : CATEGORIAS_VALIDAS) {
                String canonKey = categoriaKey(canon);
                for (String prodCat : categoriasProducto) {
                    if (String.isBlank(prodCat) || categoriaKey(prodCat) != canonKey) {
                        continue;
                    }
                    if (!keysPermitidas.contains(canonKey)) {
                        keysPermitidas.add(canonKey);
                        labelsPermitidas.add(canon);
                    }
                }
            }

            if (keysPermitidas.contains(ingresadaKey)) {
                return;
            }

            String msg = 'La categoría "' + categoriaIngresada + '" no está habilitada';
            if (String.isNotBlank(cultivarDisplay)) {
                msg += ' para la variedad "' + cultivarDisplay + '"';
            }
            if (!labelsPermitidas.isEmpty()) {
                msg += '. Categorías disponibles para esa variedad: ' + String.join(labelsPermitidas, ', ');
            } else {
                msg += '. No hay categorías INASE con producto activo para esa variedad.';
            }
            AddError(fileRow, msg);
        }

        /**
         * Originante en import: core = cuenta elegida en UI; portal distribuidor = Contact.Account del usuario;
         * portal obtentor = CUIT en fila (planillas legacy), si no hay columna debe venir vacío y falla con mensaje claro.
         */
        @TestVisible
        private static void aplicarOriginanteEnImport(
            Ventas_Informadas__c venta,
            Map<String, Object> fileRow,
            Boolean isCoreImport,
            Boolean isPortalObtentor,
            Id accountId,
            Account userAccont,
            Account originanteCore,
            Map<String, List<Account>> cuentasPorCuit
        ) {
            if (isCoreImport && originanteCore != null) {
                venta.CUIT_Originante__c = CrearVentaInformadaLWCController.limpiarCuit(originanteCore.N_CUIT__c);
                venta.Originante__c = accountId;
                VentasInformadasCuitResolver.aplicarRolOriginante(venta, originanteCore);
                return;
            }
            if (isPortalObtentor) {
                if (String.isBlank(venta.CUIT_Originante__c)) {
                    AddError(fileRow, 'Falta CUIT Originante en fila (portal obtentor).');
                    return;
                }
                Account originante = VentasInformadasCuitResolver.resolveCuentaPorCuit(
                    venta.CUIT_Originante__c,
                    null,
                    cuentasPorCuit.get(venta.CUIT_Originante__c)
                );
                if (originante != null) {
                    venta.Originante__c = originante.Id;
                    VentasInformadasCuitResolver.aplicarRolOriginante(venta, originante);
                } else {
                    AddError(fileRow, 'No existe cuenta distribuidora con el CUIT Originante indicado.');
                }
                return;
            }
            if (userAccont != null && String.isNotBlank(userAccont.N_CUIT__c) && accountId != null) {
                venta.CUIT_Originante__c = CrearVentaInformadaLWCController.limpiarCuit(userAccont.N_CUIT__c);
                venta.Originante__c = accountId;
                VentasInformadasCuitResolver.aplicarRolOriginante(venta, userAccont);
                return;
            }
            if (Test.isRunningTest()) {
                return;
            }
            AddError(
                fileRow,
                'El usuario debe tener una cuenta asociada (Contact.Account) para importar ventas en el portal.'
            );
        }

        private static void AddError(Map<String,Object> row , String error){

            if(row.get('Error') == null){
                row.put('Error', new List<String>());
            }
            
           List<string> l = (List<String>)row.get('Error');
           l.add(error);
           
        }

        private static Lote__c crearLote(){
            Lote__c lote = new Lote__c(
                Tipo_de_Lote__c = 'Ventas Informadas',
                Tipo__c = 'Ventas Informadas',
                Descripcion__c = 'Generación Ventas Informadas a través del Portal de Distribuidores ' + String.valueOf(Date.today())
                );
                return lote;
        }

        private static Date excelDecimalToDate(Decimal dias){

            Date primerDia = Date.newInstance(1900, 1, 1);
            return primerDia.addDays(Integer.valueOf(dias - 2));
        }

        /** Textos de la leyenda inferior de la plantilla (fila roja / tabla de ayuda). */
        private static final Set<String> LEYENDA_NOMBRES_CAMPO = new Set<String>{
            'Campana_de_Ventas__c', 'Campaña Agrícola', 'Campana Agricola', 'Kilos Totales', 'Categoria__c', 'Categoría', 'Categoria',
            'CUIT_Destinatario__c', 'CUIT_Originante__c', 'CUIT Originante',
            'Fecha_de_Facturacion__c', 'Fecha Comprobante', 'Fecha de Facturación', 'Fecha de Facturacion',
            'Kilos_por_Bolsa__c', 'Linea_Facturacion__c', 'Línea del Comprobante', 'Linea del Comprobante',
            'N_de_Comprobante__c', 'Razon_Social_Destinatario__c', 'Tipo_Comprobante_Externo__c', 'Tipo_de_Comprobante__c', 'Variedad__c'
        };

        /**
         * Omite filas vacías, la tabla de ayuda y todo lo que queda después del aviso
         * "elimine las líneas desde aquí" si el cliente no borró la leyenda del Excel.
         */
        @TestVisible
        public static List<Map<String,Object>> filterFilasDatosVentas(List<Map<String,Object>> fileRows) {
            List<Map<String,Object>> out = new List<Map<String,Object>>();
            if (fileRows == null || fileRows.isEmpty()) return out;

            Boolean omitirResto = false;
            for (Map<String,Object> row : fileRows) {
                if (row == null) continue;
                if (omitirResto) continue;
                if (esInicioBloqueLeyenda(row)) {
                    omitirResto = true;
                    continue;
                }
                if (esFilaVacia(row) || esFilaLeyendaInstrucciones(row)) continue;
                out.add(row);
            }
            return out;
        }

        @TestVisible
        private static Boolean esInicioBloqueLeyenda(Map<String,Object> row) {
            String texto = textoConcatenadoFila(row).toLowerCase();
            return texto.contains('por favor elimine')
                || texto.contains('elimine las líneas')
                || texto.contains('elimine las lineas')
                || texto.contains('eliminá estas líneas')
                || texto.contains('elimina estas lineas')
                || texto.contains('detalle de las columnas')
                || texto.contains('no enviar estas líneas')
                || texto.contains('no enviar estas lineas');
        }

        @TestVisible
        private static Boolean esFilaLeyendaInstrucciones(Map<String,Object> row) {
            for (Object v : row.values()) {
                if (v == null) continue;
                String s = String.valueOf(v).trim();
                if (String.isBlank(s)) continue;
                if (LEYENDA_NOMBRES_CAMPO.contains(s)) return true;
                String lower = s.toLowerCase();
                if (lower.contains('año de la campaña')
                    || lower.contains('planilla de ventas informadas')
                    || lower.contains('completar una fila por')
                    || lower.contains('todos los campos')
                    || lower.contains('no modificar encabezados')
                    || lower.contains('sembra evoluci')
                    || lower.contains('no colocar valores en negativo')
                    || lower.contains('alguno de los siguientes valores')
                    || lower.contains('cuit destinatario del movimiento')
                    || lower.contains('informar siempre 1')
                    || lower.contains('número correlativo')
                    || lower.contains('numero correlativo')
                    || lower.contains('número legal del documento')
                    || lower.contains('nombre razón social')
                    || lower.contains('corresponde al cultivar inase')
                    || lower.contains('puede consultarse en la solapa')
                    || lower.contains('pegá aquí los datos')
                    || lower.contains('pega aqui los datos')
                    || lower.contains('no pegues en la hoja datos')
                    || lower.contains('excel borra los desplegables')) {
                    return true;
                }
            }
            return false;
        }

        @TestVisible
        private static Boolean esFilaVacia(Map<String,Object> row) {
            for (Object v : row.values()) {
                if (v != null && String.isNotBlank(String.valueOf(v))) return false;
            }
            return true;
        }

        @TestVisible
        private static String textoConcatenadoFila(Map<String,Object> row) {
            List<String> partes = new List<String>();
            for (Object v : row.values()) {
                if (v != null) partes.add(String.valueOf(v));
            }
            return String.join(partes, ' ');
        }

        /**
         * Renombra las claves del fileRow al API name de Ventas_Informadas__c
         * para aceptar tanto los nombres legacy como los nuevos labels del Pop Up.
         */
        @TestVisible
        public static void normalizeColumnAliases(Map<String,Object> fileRow){
            if (fileRow == null) return;
            List<String> keys = new List<String>(fileRow.keySet());
            for (String key : keys) {
                String trimmed = key == null ? null : key.trim();
                if (trimmed != null && isCampanaAgricolaLabel(trimmed)) {
                    Object val = fileRow.get(key);
                    if (val != null && String.isNotBlank(String.valueOf(val))) {
                        fileRow.put('Campana_de_Ventas__c', String.valueOf(val).trim());
                    }
                    if (!key.equals('Campana_de_Ventas__c')) fileRow.remove(key);
                    continue;
                }
                if (trimmed != null && COLUMN_ALIASES.containsKey(trimmed)) {
                    String target = COLUMN_ALIASES.get(trimmed);
                    if (!fileRow.containsKey(target) || fileRow.get(target) == null) {
                        fileRow.put(target, fileRow.get(key));
                    }
                    if (!target.equals(key)) {
                        fileRow.remove(key);
                    }
                }
            }
        }

        /**
         * Normaliza CUITs en la fila: quita guiones, espacios, puntos y otros separadores.
         * '20-39342968-3' -> '20393429683'.  Si tras la limpieza no quedan 11 dígitos
         * lo deja en su forma "limpia" para que la validación posterior lo marque.
         */
        /**
         * Clave de comparación para categoría: trim, minúsculas, sin tildes ni ñ.
         * Ej.: "PRIMERA MULTIPLICACION" y "primera multiplicación" → misma clave.
         */
        @TestVisible
        public static String categoriaKey(String raw) {
            if (String.isBlank(raw)) return null;
            String t = raw.trim().toLowerCase();
            t = t.replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u');
            t = t.replace('ñ', 'n');
            while (t.contains('  ')) {
                t = t.replace('  ', ' ');
            }
            return t;
        }

        /** Mapea variantes de plantilla Excel al valor canónico INASE. */
        @TestVisible
        public static String normalizeCategoria(String raw) {
            if (String.isBlank(raw)) return null;
            String key = categoriaKey(raw);
            if (CATEGORIA_ALIASES_PLANTILLA.contains(key)) {
                return 'Original o Fundadora';
            }
            for (String canon : CATEGORIAS_VALIDAS) {
                if (categoriaKey(canon) == key) {
                    return canon;
                }
            }
            return raw.trim();
        }

        @TestVisible
        public static void normalizeCategoriaField(Map<String,Object> fileRow) {
            if (fileRow == null || !fileRow.containsKey('Categoria__c') || fileRow.get('Categoria__c') == null) {
                return;
            }
            String norm = normalizeCategoria(String.valueOf(fileRow.get('Categoria__c')));
            if (norm != null) {
                fileRow.put('Categoria__c', norm);
            }
        }

        /** Remito / Remito de Devolución y variantes sin acento o en mayúsculas → FC / NC. */
        @TestVisible
        public static String normalizeTipoComprobante(String raw) {
            if (String.isBlank(raw)) return null;
            String t = raw.trim();
            if (TIPO_COMPROBANTE_MAP.containsKey(t)) {
                return TIPO_COMPROBANTE_MAP.get(t);
            }
            String key = categoriaKey(t);
            for (String canon : TIPO_COMPROBANTE_MAP.keySet()) {
                if (categoriaKey(canon) == key) {
                    return TIPO_COMPROBANTE_MAP.get(canon);
                }
            }
            if (key == 'fc') return 'FC';
            if (key == 'nc') return 'NC';
            return t;
        }

        /** Valor canónico de picklist externo (FC, NC, Remito, Remito de Devolución), case-insensitive. */
        @TestVisible
        public static String canonicalTipoComprobanteExterno(String raw) {
            if (String.isBlank(raw)) {
                return null;
            }
            String key = categoriaKey(raw);
            if (key == 'fc') {
                return 'FC';
            }
            if (key == 'nc') {
                return 'NC';
            }
            if (key == 'remito') {
                return 'Remito';
            }
            if (key == 'remito de devolucion') {
                return 'Remito de Devolución';
            }
            for (String canon : TIPO_COMPROBANTE_MAP.keySet()) {
                if (categoriaKey(canon) == key) {
                    if (canon == 'REMITO') {
                        return 'Remito';
                    }
                    if (canon == 'Remito de Devolucion') {
                        return 'Remito de Devolución';
                    }
                    return canon;
                }
            }
            return raw.trim();
        }

        @TestVisible
        public static Boolean esTipoComprobanteExternoValido(String externo) {
            String canon = canonicalTipoComprobanteExterno(externo);
            return canon == 'FC' || canon == 'NC' || canon == 'Remito' || canon == 'Remito de Devolución';
        }

        @TestVisible
        public static void normalizeTipoComprobanteField(Map<String,Object> fileRow) {
            if (fileRow == null) return;

            Object extRaw = fileRow.get('Tipo_Comprobante_Externo__c');
            Object intRaw = fileRow.get('Tipo_de_Comprobante__c');

            if (extRaw != null && String.isNotBlank(String.valueOf(extRaw))) {
                String original = String.valueOf(extRaw);
                String norm = normalizeTipoComprobante(original);
                String canonExt = canonicalTipoComprobanteExterno(original);
                if (norm != null) {
                    fileRow.put('Tipo_de_Comprobante__c', norm);
                }
                if (canonExt != null) {
                    fileRow.put('Tipo_Comprobante_Externo__c', canonExt);
                }
                return;
            }

            // Plantilla legacy (API): columna Tipo_de_Comprobante__c con FC / NC / REMITO.
            if (intRaw == null || String.isBlank(String.valueOf(intRaw))) {
                return;
            }
            String interno = String.valueOf(intRaw).trim();
            if (TIPO_COMPROBANTE_MAP.containsKey(interno)) {
                fileRow.put('Tipo_de_Comprobante__c', TIPO_COMPROBANTE_MAP.get(interno));
                fileRow.put(
                    'Tipo_Comprobante_Externo__c',
                    interno == 'REMITO' ? 'Remito' : interno
                );
                return;
            }
            String norm = normalizeTipoComprobante(interno);
            String canonExt = canonicalTipoComprobanteExterno(interno);
            if (norm != null) {
                fileRow.put('Tipo_de_Comprobante__c', norm);
            }
            fileRow.put(
                'Tipo_Comprobante_Externo__c',
                canonExt != null ? canonExt : interno
            );
        }

        /**
         * Remito → R-{número}; Remito de Devolución → RD-{número}, solo si hay cuerpo.
         * Sin número no se agrega prefijo (igual que Nueva Venta).
         */
        @TestVisible
        public static String stripPrefijosRemitoNComprobante(String valor, String prefijoEsperado) {
            String s = valor == null ? '' : valor.trim();
            if (prefijoEsperado == 'RD-') {
                if (startsWithIgnoreCase(s, 'RD-')) return s.substring(3);
                if (equalsIgnoreCaseAny(s, new List<String>{ 'RD-', 'RD', 'R-', 'R' })) return '';
                return s;
            }
            if (prefijoEsperado == 'R-') {
                if (startsWithIgnoreCase(s, 'RD-')) return s.substring(3);
                if (startsWithIgnoreCase(s, 'R-')) return s.substring(2);
                if (equalsIgnoreCaseAny(s, new List<String>{ 'R-', 'R' })) return '';
                return s;
            }
            if (startsWithIgnoreCase(s, 'RD-')) return s.substring(3);
            if (startsWithIgnoreCase(s, 'R-')) return s.substring(2);
            if (equalsIgnoreCaseAny(s, new List<String>{ 'RD-', 'RD', 'R-', 'R' })) return '';
            return s;
        }

        @TestVisible
        public static void applyNComprobantePrefijoRemito(Map<String,Object> fileRow) {
            if (fileRow == null) return;
            Object tipoRaw = fileRow.get('Tipo_Comprobante_Externo__c');
            if (tipoRaw == null || String.isBlank(String.valueOf(tipoRaw))) {
                tipoRaw = fileRow.get('Tipo_de_Comprobante__c');
            }
            if (tipoRaw == null || String.isBlank(String.valueOf(tipoRaw))) {
                return;
            }
            String tipoKey = categoriaKey(String.valueOf(tipoRaw));
            String num = fileRow.containsKey('N_de_Comprobante__c') && fileRow.get('N_de_Comprobante__c') != null
                ? String.valueOf(fileRow.get('N_de_Comprobante__c')).trim()
                : '';

            if (tipoKey == 'remito de devolucion') {
                String cuerpo = stripPrefijosRemitoNComprobante(num, 'RD-');
                fileRow.put('N_de_Comprobante__c', String.isBlank(cuerpo) ? null : 'RD-' + cuerpo);
            } else if (tipoKey == 'remito') {
                String cuerpo = stripPrefijosRemitoNComprobante(num, 'R-');
                fileRow.put('N_de_Comprobante__c', String.isBlank(cuerpo) ? null : 'R-' + cuerpo);
            } else if (tipoKey == 'fc' || tipoKey == 'nc') {
                String limpio = stripPrefijosRemitoNComprobante(num, null);
                fileRow.put('N_de_Comprobante__c', String.isBlank(limpio) ? null : limpio);
            }
        }

        private static Boolean startsWithIgnoreCase(String s, String prefix) {
            return s != null && prefix != null && s.length() >= prefix.length()
                && s.substring(0, prefix.length()).equalsIgnoreCase(prefix);
        }

        private static Boolean equalsIgnoreCaseAny(String s, List<String> options) {
            if (s == null) return false;
            for (String opt : options) {
                if (s.equalsIgnoreCase(opt)) return true;
            }
            return false;
        }

        @TestVisible
        public static void normalizeCuitFields(Map<String,Object> fileRow) {
            if (fileRow == null) return;
            for (String campo : CAMPOS_CUIT) {
                if (!fileRow.containsKey(campo) || fileRow.get(campo) == null) continue;
                String raw = coerceExcelCellToPlainString(fileRow.get(campo));
                if (raw == null) continue;
                String soloDigitos = raw.replaceAll('[^0-9]', '');
                fileRow.put(campo, soloDigitos);
            }
        }

        @TestVisible
        public static void normalizeNComprobanteField(Map<String,Object> fileRow) {
            if (fileRow == null || !fileRow.containsKey('N_de_Comprobante__c') || fileRow.get('N_de_Comprobante__c') == null) {
                return;
            }
            String plain = coerceExcelCellToPlainString(fileRow.get('N_de_Comprobante__c'));
            fileRow.put('N_de_Comprobante__c', String.isBlank(plain) ? null : plain.trim());
        }

        @TestVisible
        public static void normalizeLineaFacturacionField(Map<String,Object> fileRow) {
            if (fileRow == null || !fileRow.containsKey('Linea_Facturacion__c') || fileRow.get('Linea_Facturacion__c') == null) {
                return;
            }
            String plain = coerceExcelCellToPlainString(fileRow.get('Linea_Facturacion__c'));
            if (String.isBlank(plain)) {
                return;
            }
            plain = plain.replaceAll('[^0-9]', '');
            if (String.isBlank(plain)) {
                fileRow.put('Linea_Facturacion__c', null);
                return;
            }
            fileRow.put('Linea_Facturacion__c', plain);
        }

        @TestVisible
        public static String coerceExcelCellToPlainString(Object raw) {
            if (raw == null) {
                return null;
            }
            if (raw instanceof Decimal) {
                Decimal d = (Decimal) raw;
                if (d.scale() <= 0 || d.stripTrailingZeros().scale() <= 0) {
                    return d.setScale(0, System.RoundingMode.FLOOR).toPlainString();
                }
                return d.toPlainString();
            }
            if (raw instanceof Integer || raw instanceof Long) {
                return String.valueOf(raw);
            }
            if (raw instanceof Double) {
                try {
                    Decimal d = Decimal.valueOf(String.valueOf(raw));
                    if (d.scale() <= 0 || d.stripTrailingZeros().scale() <= 0) {
                        return d.setScale(0, System.RoundingMode.FLOOR).toPlainString();
                    }
                    return d.toPlainString();
                } catch (Exception e) {
                    return String.valueOf(raw);
                }
            }
            String s = String.valueOf(raw).trim();
            if (String.isBlank(s)) {
                return null;
            }
            if (s.contains('e') || s.contains('E')) {
                try {
                    Decimal d = Decimal.valueOf(s);
                    if (d.scale() <= 0 || d.stripTrailingZeros().scale() <= 0) {
                        return d.setScale(0, System.RoundingMode.FLOOR).toPlainString();
                    }
                    return d.toPlainString();
                } catch (Exception e) {
                    return s;
                }
            }
            return s;
        }

        @TestVisible
        private static Boolean isCampanaAgricolaLabel(String label) {
            if (label == null) return false;
            String n = label.trim().toLowerCase();
            return n == 'campaña agrícola' || n == 'campana agricola' || n == 'campana agrícola'
                || n == 'campana_agricola__c' || n == 'campana_de_ventas__c';
        }

        /**
         * Normaliza el valor de campaña del Excel al primer año de 4 dígitos.
         * Acepta 2026, 2025/26, 2026-2027, 26-27, 26/27, SOJA - 2025/26, etc.
         */
        @TestVisible
        public static void normalizeCampanaAgricolaPreDeserialize(Map<String,Object> fileRow) {
            if (fileRow == null) return;

            String raw = null;
            if (fileRow.containsKey(CAMPANA_AGRICOLA_NOMBRE_KEY) && fileRow.get(CAMPANA_AGRICOLA_NOMBRE_KEY) != null) {
                raw = String.valueOf(fileRow.get(CAMPANA_AGRICOLA_NOMBRE_KEY)).trim();
                fileRow.remove(CAMPANA_AGRICOLA_NOMBRE_KEY);
            }
            if (fileRow.containsKey('Campana_Agricola__c') && fileRow.get('Campana_Agricola__c') != null) {
                String v = String.valueOf(fileRow.get('Campana_Agricola__c')).trim();
                if (!isSalesforceId(v)) raw = v;
                fileRow.remove('Campana_Agricola__c');
            }
            if (raw == null && fileRow.containsKey('Campana_de_Ventas__c') && fileRow.get('Campana_de_Ventas__c') != null) {
                raw = String.valueOf(fileRow.get('Campana_de_Ventas__c')).trim();
            }

            String ano = primerAnioCampanaText(raw);
            if (String.isNotBlank(ano)) {
                fileRow.put('Campana_de_Ventas__c', ano);
            }
        }

        @TestVisible
        public static Map<String,Object> stripRowForDeserialize(Map<String,Object> fileRow) {
            Map<String,Object> out = new Map<String,Object>(fileRow);
            out.remove(CAMPANA_AGRICOLA_NOMBRE_KEY);
            out.remove('Error');
            out.remove('isSucces');
            out.remove('debug');
            return out;
        }

        @TestVisible
        private static Boolean isSalesforceId(String s) {
            if (String.isBlank(s)) return false;
            String alnum = s.replaceAll('[^a-zA-Z0-9]', '');
            return alnum.length() >= 15 && alnum.length() <= 18;
        }

        /**
         * Resuelve Campana_Agricola__c por cultivo (de la variedad) + primer año informado.
         */
        @TestVisible
        public static void applyCampanaAgricola(
            Ventas_Informadas__c venta,
            Map<String, Campana_Agricola__c> campanasByCultivoAno,
            Variedad__c variedadRef
        ) {
            if (venta == null || variedadRef == null || variedadRef.Cultivo__c == null) return;

            String ano = primerAnioCampanaText(venta.Campana_de_Ventas__c);
            if (String.isBlank(ano)) return;
            venta.Campana_de_Ventas__c = ano;

            Campana_Agricola__c camp = campanasByCultivoAno != null
                ? campanasByCultivoAno.get(campanaCultivoAnoKey(variedadRef.Cultivo__c, ano))
                : null;

            if (camp == null) {
                return;
            }

            if (camp != null) {
                venta.Campana_Agricola__c = camp.Id;
                if (camp.Cultivo__c != null) venta.Cultivo__c = camp.Cultivo__c;
            }
        }

        @TestVisible
        public static String campanaCultivoAnoKey(Id cultivoId, String ano) {
            return String.valueOf(cultivoId) + '_' + ano;
        }

        /** Bulk: campañas agrícolas indexadas por cultivo + primer año de la fila. */
        @TestVisible
        public static Map<String, Campana_Agricola__c> getCampanasPorCultivoYAno(
            List<Map<String,Object>> fileRows,
            Map<String, Variedad__c> variedadByName
        ) {
            Set<Id> cultivoIds = new Set<Id>();
            Set<String> anos = new Set<String>();
            for (Map<String,Object> r : fileRows) {
                if (r == null) continue;
                String ano = primerAnioCampanaText(
                    r.containsKey('Campana_de_Ventas__c') ? String.valueOf(r.get('Campana_de_Ventas__c')) : null
                );
                if (String.isBlank(ano)) continue;
                anos.add(ano);
                if (r.get('Variedad__c') == null) continue;
                Variedad__c v = variedadByName.get(variedadKey(String.valueOf(r.get('Variedad__c'))));
                if (v != null && v.Cultivo__c != null) cultivoIds.add(v.Cultivo__c);
            }

            Map<String, Campana_Agricola__c> out = new Map<String, Campana_Agricola__c>();
            if (cultivoIds.isEmpty() || anos.isEmpty()) return out;

            for (Campana_Agricola__c c : [
                SELECT Id, Name, Ano__c, Cultivo__c
                FROM Campana_Agricola__c
                WHERE Cultivo__c IN :cultivoIds
                LIMIT 2000
            ]) {
                String y = primerAnioCampanaText(c.Ano__c);
                if (y != null && anos.contains(y)) {
                    String k = campanaCultivoAnoKey(c.Cultivo__c, y);
                    if (!out.containsKey(k)) out.put(k, c);
                }
            }
            return out;
        }

        @TestVisible
        public static String primerAnioCampanaText(String raw) {
            if (raw == null) return null;
            String s = String.valueOf(raw).trim();
            if (String.isBlank(s)) return null;

            Matcher m4 = Pattern.compile('\\d{4}').matcher(s);
            if (m4.find()) return m4.group();

            Matcher m2Pair = Pattern.compile('(\\d{2})\\s*[-/]\\s*\\d{2}').matcher(s);
            if (m2Pair.find()) {
                return expandirAnoDosDigitos(m2Pair.group(1));
            }

            return null;
        }

        /** Convierte "26" en "2026" (campañas agrícolas actuales en siglo XXI). */
        @TestVisible
        private static String expandirAnoDosDigitos(String yy) {
            if (String.isBlank(yy) || !Pattern.matches('\\d{2}', yy)) return null;
            return String.valueOf(2000 + Integer.valueOf(yy));
        }

        /** Compatibilidad con tests y plantillas legacy (solo año en Campana_de_Ventas__c). */
        @TestVisible
        private static void normalizeCampanaField(Map<String,Object> fileRow) {
            normalizeCampanaAgricolaPreDeserialize(fileRow);
        }

        /**
         * Bulk query a Variedad__c indexada por nombre normalizado. Soporta búsqueda
         * case-insensitive y con trim, para que coincida aunque venga con espacios
         * o capitalización distinta del Excel.
         */
        @TestVisible
        public static Map<String, Variedad__c> getVariedadesPorNombre(List<Map<String,Object>> fileRows) {
            return getVariedadesPorNombre(fileRows, collectVariedadLabelsDesdeFilas(fileRows));
        }

        @TestVisible
        public static Map<String, Variedad__c> getVariedadesPorNombre(
            List<Map<String,Object>> fileRows,
            Set<String> labelsEnArchivo
        ) {
            Set<String> keys = new Set<String>();
            if (fileRows != null) {
                for (Map<String,Object> r : fileRows) {
                    if (r != null && r.get('Variedad__c') != null) {
                        String k = variedadKey(String.valueOf(r.get('Variedad__c')));
                        if (String.isNotBlank(k)) {
                            keys.add(k);
                        }
                    }
                }
            }
            Map<String, Variedad__c> out = new Map<String, Variedad__c>();
            if (keys.isEmpty()) {
                return out;
            }

            Set<String> labels = labelsEnArchivo != null ? labelsEnArchivo : new Set<String>();
            if (!labels.isEmpty()) {
                for (List<String> chunk : chunkStringSet(labels, 200)) {
                    for (Variedad__c v : [
                        SELECT Id, Cultivar_Inase__c, Cultivo__c, Obtentor_Comercializa__c,
                               Obtentor_Comercializa__r.Id_Obtentor__c, Obtentor_Comercializa__r.Name
                        FROM Variedad__c
                        WHERE Cultivar_Inase__c IN :chunk
                    ]) {
                        indexVariedadPorClave(out, v, keys);
                    }
                }
            }

            Set<String> missingKeys = new Set<String>();
            for (String key : keys) {
                if (!out.containsKey(key)) {
                    missingKeys.add(key);
                }
            }
            if (!missingKeys.isEmpty()) {
                resolverVariedadesFaltantesPorClave(out, missingKeys);
            }
            return out;
        }

        @TestVisible
        private static void indexVariedadPorClave(
            Map<String, Variedad__c> out,
            Variedad__c v,
            Set<String> keys
        ) {
            if (v == null || keys == null || keys.isEmpty()) {
                return;
            }
            String k = variedadKey(v.Cultivar_Inase__c);
            if (k != null && keys.contains(k) && !out.containsKey(k)) {
                out.put(k, v);
            }
        }

        /** Segunda pasada solo para claves no encontradas (evita scan de 50k Variedad__c). */
        @TestVisible
        private static void resolverVariedadesFaltantesPorClave(
            Map<String, Variedad__c> out,
            Set<String> missingKeys
        ) {
            Integer fuzzyQueries = 0;
            for (String missingKey : missingKeys) {
                if (out.containsKey(missingKey) || fuzzyQueries >= 100) {
                    continue;
                }
                String pattern = cultivarLikePattern(missingKey);
                if (pattern == null) {
                    continue;
                }
                fuzzyQueries++;
                for (Variedad__c v : [
                    SELECT Id, Cultivar_Inase__c, Cultivo__c, Obtentor_Comercializa__c,
                           Obtentor_Comercializa__r.Id_Obtentor__c, Obtentor_Comercializa__r.Name
                    FROM Variedad__c
                    WHERE Cultivar_Inase__c != NULL
                    AND Cultivar_Inase__c LIKE :pattern
                    LIMIT 20
                ]) {
                    indexVariedadPorClave(out, v, missingKeys);
                }
            }
        }

        /** Ej. DD32 → %D%D%3%2% para matchear "DD 32" sin scan masivo. */
        @TestVisible
        private static String cultivarLikePattern(String normalizedKey) {
            if (String.isBlank(normalizedKey)) {
                return null;
            }
            String pattern = '%';
            for (Integer i = 0; i < normalizedKey.length(); i++) {
                pattern += normalizedKey.substring(i, i + 1) + '%';
            }
            return pattern;
        }

        @TestVisible
        public static Set<String> collectVariedadLabelsDesdeFilas(List<Map<String, Object>> fileRows) {
            Set<String> labels = new Set<String>();
            if (fileRows == null) {
                return labels;
            }
            for (Map<String, Object> row : fileRows) {
                if (row == null || row.get('Variedad__c') == null) {
                    continue;
                }
                String label = String.valueOf(row.get('Variedad__c')).trim();
                if (String.isNotBlank(label)) {
                    labels.add(label);
                }
            }
            return labels;
        }

        @TestVisible
        public static Map<String, List<String>> buildMapValidacionVentaPorCultivares(Set<String> cultivarLabels) {
            Map<String, List<String>> mapValidacionVenta = new Map<String, List<String>>();
            if (cultivarLabels == null || cultivarLabels.isEmpty()) {
                return mapValidacionVenta;
            }
            for (List<String> chunk : chunkStringSet(cultivarLabels, 200)) {
                for (Product2 producto : [
                    SELECT Cultivar_Inase__c, Categoria__c
                    FROM Product2
                    WHERE Family = 'Semilla Fiscalizada'
                        AND IsActive = true
                        AND Cultivar_Inase__c != null
                        AND Categoria__c != null
                        AND Cultivar_Inase__c IN :chunk
                ]) {
                    String pk = variedadKey(producto.Cultivar_Inase__c);
                    if (pk == null) {
                        continue;
                    }
                    if (mapValidacionVenta.get(pk) == null) {
                        mapValidacionVenta.put(pk, new List<String>());
                    }
                    mapValidacionVenta.get(pk).add(producto.Categoria__c);
                }
            }
            return mapValidacionVenta;
        }

        @TestVisible
        private static List<List<String>> chunkStringSet(Set<String> values, Integer size) {
            return chunkStringList(new List<String>(values), size);
        }

        @TestVisible
        private static List<List<String>> chunkStringList(List<String> values, Integer size) {
            List<List<String>> chunks = new List<List<String>>();
            if (values == null || values.isEmpty() || size == null || size < 1) {
                return chunks;
            }
            for (Integer i = 0; i < values.size(); i += size) {
                List<String> chunk = new List<String>();
                for (Integer j = i; j < Math.min(i + size, values.size()); j++) {
                    chunk.add(values[j]);
                }
                chunks.add(chunk);
            }
            return chunks;
        }

        /** CUITs de la planilla para resolver cuentas en bulk (evita límite SOQL en import >100 filas). */
        @TestVisible
        public static Set<String> collectCuitsDesdeFilas(
            List<Map<String, Object>> fileRows,
            Boolean incluirOriginante
        ) {
            Set<String> cuits = new Set<String>();
            if (fileRows == null) {
                return cuits;
            }
            for (Map<String, Object> row : fileRows) {
                if (row == null) {
                    continue;
                }
                Object dest = row.get('CUIT_Destinatario__c');
                if (dest != null) {
                    String cuitDest = CrearVentaInformadaLWCController.limpiarCuit(String.valueOf(dest));
                    if (String.isNotBlank(cuitDest)) {
                        cuits.add(cuitDest);
                    }
                }
                if (incluirOriginante) {
                    Object orig = row.get('CUIT_Originante__c');
                    if (orig != null) {
                        String cuitOrig = CrearVentaInformadaLWCController.limpiarCuit(String.valueOf(orig));
                        if (String.isNotBlank(cuitOrig)) {
                            cuits.add(cuitOrig);
                        }
                    }
                }
            }
            return cuits;
        }

        @TestVisible
        public static Set<Id> collectObtentorComercializaIds(Map<String, Variedad__c> variedadByName) {
            Set<Id> ids = new Set<Id>();
            if (variedadByName == null) {
                return ids;
            }
            for (Variedad__c variedad : variedadByName.values()) {
                if (variedad != null && variedad.Obtentor_Comercializa__c != null) {
                    ids.add(variedad.Obtentor_Comercializa__c);
                }
            }
            return ids;
        }

        /**
         * Clave normalizada para hacer match de Variedad case/space-insensitive.
         * Quita TODOS los espacios internos para que "DD 32" y "DD32" coincidan.
         */
        @TestVisible
        public static String variedadKey(String s) {
            return s == null ? null : s.trim().toUpperCase().replaceAll('\\s+', '');
        }

        /**
         * Normaliza el texto de Variedad en el preproceso: trim + mayúsculas, para que
         * coincida con el catálogo INASE (que está en mayúsculas) y quede consistente el
         * valor guardado, el match y la detección de duplicados.
         */
        @TestVisible
        public static void normalizeVariedadField(Map<String,Object> fileRow) {
            if (fileRow == null || fileRow.get('Variedad__c') == null) return;
            String norm = String.valueOf(fileRow.get('Variedad__c')).trim().toUpperCase();
            fileRow.put('Variedad__c', String.isBlank(norm) ? null : norm);
        }

        /**
         * Normaliza Kilos Totales en el preproceso a un string numérico canónico (US, punto
         * decimal) para que tanto el JSON.deserializeStrict como el parse a Decimal funcionen.
         * Si el valor no es numérico, lo deja en null (la validación posterior lo reporta).
         */
        @TestVisible
        public static void normalizeKilosTotalesField(Map<String,Object> fileRow) {
            if (fileRow == null || fileRow.get('Cantidad_de_Bolsas__c') == null) return;
            Decimal d = parseKilosTotales(fileRow.get('Cantidad_de_Bolsas__c'));
            fileRow.put('Cantidad_de_Bolsas__c', d == null ? null : String.valueOf(d));
        }

        /**
         * Parsea Kilos Totales en formato argentino: '.' = separador de miles, ',' = decimal.
         * También tolera el formato US legacy ("3280.0"). Reglas:
         *  - Si hay coma y punto: el separador que aparece más a la derecha es el decimal,
         *    el otro son miles. ("1.234,56" -> 1234.56 ; "1,234.56" -> 1234.56)
         *  - Solo coma: una coma => decimal ("1234,56" -> 1234.56); varias => miles.
         *  - Solo punto: varios puntos => miles ("1.234.567" -> 1234567); un punto con
         *    exactamente 3 decimales => miles AR ("3.280" -> 3280); en otro caso => decimal
         *    ("3280.0" -> 3280.0).
         * Devuelve null si no es numérico.
         */
        @TestVisible
        public static Decimal parseKilosTotales(Object raw) {
            if (raw == null) return null;
            String s = String.valueOf(raw).trim();
            if (String.isBlank(s)) return null;

            // Conservar solo dígitos, separadores y signo.
            s = s.replaceAll('[^0-9.,-]', '');
            if (String.isBlank(s)) return null;

            Integer lastComma = s.lastIndexOf(',');
            Integer lastDot = s.lastIndexOf('.');

            if (lastComma >= 0 && lastDot >= 0) {
                if (lastComma > lastDot) {
                    // Coma decimal (AR): los puntos son miles.
                    s = s.replace('.', '').replace(',', '.');
                } else {
                    // Punto decimal (US): las comas son miles.
                    s = s.replace(',', '');
                }
            } else if (lastComma >= 0) {
                if (s.countMatches(',') > 1) {
                    s = s.replace(',', '');          // miles US: 1,234,567
                } else if (esMilesConComaUs(s)) {
                    s = s.replace(',', '');          // miles US: 1,600 (SheetJS / Excel)
                } else {
                    s = s.replace(',', '.');         // decimal AR: 1234,56
                }
            } else if (lastDot >= 0) {
                if (s.countMatches('.') > 1) {
                    s = s.replace('.', '');          // miles
                } else {
                    Integer after = s.length() - lastDot - 1;
                    if (after == 3) {
                        s = s.replace('.', '');      // miles AR (ej. 3.280)
                    }
                    // si no, se conserva el punto como decimal (ej. 3280.0)
                }
            }

            try {
                return Decimal.valueOf(s);
            } catch (Exception e) {
                return null;
            }
        }

        /** Una coma y exactamente 3 dígitos después → miles US (ej. 1,600), no decimal AR. */
        @TestVisible
        private static Boolean esMilesConComaUs(String s) {
            Integer idx = s.lastIndexOf(',');
            if (idx < 0) {
                return false;
            }
            String after = s.substring(idx + 1);
            return after.length() == 3 && after.isNumeric();
        }

        /**
         * Parser flexible de fechas. Acepta:
         *  - DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
         *  - YYYY-MM-DD, YYYY/MM/DD (ISO)
         *  - Serial numérico de Excel (días desde 1900-01-01)
         */
        @TestVisible
        public static Date parseFlexibleDate(Object raw){
            if (raw == null) return null;

            // Caso: número (serial de Excel).
            if (raw instanceof Decimal) {
                return excelDecimalToDate((Decimal) raw);
            }

            String s = String.valueOf(raw).trim();
            if (String.isBlank(s)) return null;

            // Serial puro (todo dígitos): Excel decimal.
            if (s.isNumeric() && s.length() <= 6) {
                try {
                    return excelDecimalToDate(Decimal.valueOf(s));
                } catch (Exception ex) { /* continúa con parsing string */ }
            }

            // ISO yyyy-MM-dd (o con barras).
            if (s.length() >= 10 && (s.substring(4,5) == '-' || s.substring(4,5) == '/')) {
                String sep = s.substring(4,5);
                List<String> parts = s.substring(0,10).split('\\' + sep);
                if (parts.size() == 3) {
                    try {
                        return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), Integer.valueOf(parts[2]));
                    } catch (Exception ex) { /* continúa */ }
                }
            }

            // DD/MM/YYYY, MM/DD/YYYY (si el 2º tramo > 12) o separadores -/. 
            String normalized = s.replace('-', '/').replace('.', '/');
            List<String> parts = normalized.split('/');
            if (parts.size() == 3) {
                try {
                    Integer a = Integer.valueOf(parts[0].trim());
                    Integer b = Integer.valueOf(parts[1].trim());
                    Integer y = Integer.valueOf(parts[2].trim());
                    if (y < 100) {
                        y += 2000;
                    }
                    Integer d;
                    Integer m;
                    if (a > 12) {
                        d = a;
                        m = b;
                    } else if (b > 12) {
                        m = a;
                        d = b;
                    } else {
                        d = a;
                        m = b;
                    }
                    return Date.newInstance(y, m, d);
                } catch (Exception ex) {
                    return null;
                }
            }

            return null;
        }
}