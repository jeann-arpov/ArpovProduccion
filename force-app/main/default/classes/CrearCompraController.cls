public without sharing class CrearCompraController {
    public static Id getListViewId(String sobjectName, String developerName) {
        return [select id from listview where developername =: developerName and SobjectType =: sobjectName].id;
    }

    @AuraEnabled
    public static List<PricebookEntry> getProductsData(String cultivoId){
        return getProducts(cultivoId);
    }

    public static List<PricebookEntry> getProducts(String cultivoId) {
        Set<Id> variedadesSreIds = UtilsCompraVentaHT.getVariedadesSreProductor(getAccount().Id);
        return [SELECT id, Unit_Price__c,Product2.Nombre_Comercial__c, UnitPrice, Product2.Unidad_De_Medida__c, Product2.Tipo_de_Compra__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Nombre_Obtentor__c, Product2.Variedad2__r.Cultivo__r.Name, Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c from PricebookEntry WHERE Product2.IsActive = true AND Product2.Producto_Vigente__c = true AND Product2.Variedad2__r.Cultivo__c = :cultivoId AND IsActive = true AND Pricebook2.IsActive = true AND priceBook2.Name = 'Lista de Precios Sembrá Evolución' AND UnitPrice != 0 AND (Product2.Variedad2__r.Sembra_Evolucion__c = true OR Product2.Variedad2__c IN :variedadesSreIds) ORDER BY Product2.Nombre_Comercial__c ASC];
        //return [SELECT id, Product2.Nombre_Comercial__c, UnitPrice, Product2.Unidad_De_Medida__c, Product2.Tipo_de_Compra__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Nombre_Obtentor__c, Product2.Variedad2__r.Cultivo__r.Name, Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c from PricebookEntry WHERE Product2.IsActive = true AND Product2.Producto_Vigente__c = true AND Product2.Variedad2__r.Cultivo__c = :cultivoId AND IsActive = true AND Pricebook2.IsActive = true AND priceBook2.Name = 'Lista de Precios Sembrá Evolución' AND UnitPrice != 0 AND (Product2.Variedad2__r.Sembra_Evolucion__c = true ) ORDER BY Product2.Nombre_Comercial__c ASC];
    }
    
    public static List<ContentDocument> getCondicionesComerciales() {
        List<ContentDocument> docs = new List<ContentDocument>();

        for (ContentDocumentLink link: [select ContentDocument.Title, ContentDocument.Id from ContentDocumentLink where LinkedEntityId in (select id from account where id_obtentor__c != null) and ContentDocument.Title like 'Condiciones_Comerciales_%' and ContentDocument.FileType = 'pdf']) {
            docs.add(link.ContentDocument);
        }

        return docs;
    }


    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchVariedades(String searchTerm, List<String> selectedIds, List<String> disponiblesIds) {
        return variedadesToLookup([select Id, Nombre_Comercial__c FROM Variedad__c WHERE Nombre_Comercial__c like: ('%' + searchTerm + '%') and Id IN :disponiblesIds limit 5]);
    }

    public static List<LookupSearchResult> variedadesToLookup(List<Variedad__c> variedades) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        String icon = 'standard:price_book_entries';

        for (Variedad__c variedad : variedades) {
            results.add(new LookupSearchResult(variedad.Id, 'Variedad__c', icon, variedad.Nombre_Comercial__c, ''));
            results[results.size() - 1].record = variedad;
        }

        results.sort();

        return results;
    }

    /*
        Se busca licencia de la cuenta del usuario del portal y la cuenta de la marca --> si encuentra, tiene licencia.
        Sino encuentra, busca con el parentId de la cuenta de la marca --> si encuentra, tiene licencia.
        Sino encuentra, busca si hay una licencia cuyo parent sea el mismo que la de la marca (puedo comprar neogen si la licencia la tiene con illinois, dado que ambos tienen el mismo parent)
        Sino encuentra --> no tiene licencia
        Ej. La cuenta es ABELLO, quiere comprar Illinois --> verifico si existe alguna licencia de ABELLO con la cuenta de Illinois (GDM Argentina S.A.). No encuentra.
        Entonces busca licencia con ABELLO y el parentid de GDM Argentina SA = GDM Argentina SA (03) --> tiene licencia.
    */

    private static Licencia__c getLicence(Account obtentor) {
        return getLicence(obtentor.id, obtentor.ParentId, getAccount().id);
    }

    private static Licencia__c getLicence(Id obtentor, Id obtentorParent, Id productor) {
        List<Id> ids = new List<Id>{obtentor};
        if (obtentorParent != null) ids.add(obtentorParent);

        List<Licencia__c> licencias = [select id
                                        from Licencia__c
                                        where Cuenta_Productor__c =: productor and
                                        Estado__c = 'Aprobada' and
                                        Fecha_de_Vencimiento__c >=: System.today()
                                        and Tipo_de_Licencia__c = 'Productor'
                                        and (
                                            Cuenta_Obtentor__c in: ids or 
                                            Cuenta_Obtentor__r.ParentId in: ids
                                            )
                                        limit 1
                                        ];
        return licencias.isEmpty() ? null : licencias[0];
    }

    public static Map<String, Licencia__c> getLicences(Id productorId){
        Map<String, Licencia__c> mapLicencias = new Map<String, Licencia__c>();
        for(Licencia__c licencia : [SELECT Id, Cuenta_Obtentor__c, Cuenta_Obtentor__r.ParentId, Cuenta_Productor__c, Tecnologia__c FROM Licencia__c WHERE Cuenta_Productor__c = :productorId AND Estado__c = 'Aprobada' AND Fecha_de_Vencimiento__c >=: System.today() AND Tipo_de_Licencia__c = 'Productor']){
            String key = licencia.Cuenta_Obtentor__c + licencia.Tecnologia__c;
            if(mapLicencias.containsKey(key) == false){
                mapLicencias.put(key, licencia);
            }

            if(licencia.Cuenta_Obtentor__r.ParentId != null){
                key = licencia.Cuenta_Obtentor__r.ParentId + licencia.Tecnologia__c;
                if(mapLicencias.containsKey(key) == false){
                    mapLicencias.put(key, licencia);
                }
            }
        }
        return mapLicencias;
    }

    @AuraEnabled
    public static Map<String, Object> getSemilleroData(String obtentorId) {
       Account obtentor = [select Id_Obtentor__c, Nombre_Obtentor__c, ParentId from Account where Id_Obtentor__c =: obtentorId];
        return getSemilleroData(obtentor, getLicence(obtentor));
    }

    public static Map<String, Object> getSemilleroData(Account obtentor, Licencia__c licence) {
        Map<String, Object> response = new Map<String, Object> {
            'semillero' => obtentor
        };

        if (licence != null) response.put('licencia', licence);

        return response;
    }

    private static Compra_HT__c getCompraData(Id compraId){
        return [select Obtentor__r.Id_Obtentor__c, Total_HT__c, Total_USD__c, Cuenta_Productor__r.Name, id, Estado__c, CreatedDate, Cultivo__c, (select id, Estado__c, Id_Producto_de_Lista_de_Precio__c, Cantidad__c, Precio_de_Lista__c, Fecha_de_Activacion__c,Tipo_de_Pago__c, Licencia__c, Licencia__r.Name, Producto__r.Variedad2__r.Obtentor_Comercializa__c, Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId, Producto__r.Variedad2__r.Biotecnologia__c from Lineas_de_Compra_HT__r) from Compra_HT__c where id =: compraId];
    }

    private static Opportunity getOpp(Id compraId) {
        List<Opportunity> opps = [select StageName, (select Estado__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Dias_de_Exclusion_de_Facturacion_SE__c, Linea_de_Compra_HT__r.Linea_de_Venta_HT__c FROM OpportunityLineItems) from opportunity where Compra_HT__c =: compraId];
        return opps.isEmpty() ? null : opps[0];
    }

    private static List<Erpvs__Comprobante_Venta__c> getCVS(Id compraId) {
        return [select id, ERPvs__Comprobante__c, Erpvs__Contabilizar__c, (select name from Attachments), (select id, OpportunityLineItem__c from Erpvs__Renglones_de_Comprobante_de_Venta__r) from Erpvs__Comprobante_Venta__c where Oportunidad__r.Compra_HT__c =: compraId];
    }

    private static Map<String, Object> getData(Id compraId) {
        return getData(compraId, false);
    }

    @AuraEnabled
    public static Map<String, Object> getData(Id compraId, Boolean isFirstLoad) {
        Map<String, Object> data = new Map<String, Object> {};

        if (String.isNotBlank(compraId)) {
            validateProductor(compraId);
            Compra_HT__c compra = getCompraData(compraId);
            data.put('record', compra);
            data.put('oportunidad', getOpp(compraId));
            data.put('cvs', getCVS(compraId));
            List<PricebookEntry> products = getProducts(compra.Cultivo__c);
            data.put('products', products);
            data.put('pendiente', [SELECT Count() FROM Linea_de_Compra_HT__c WHERE Compra_HT__c = :compraId AND Estado__c = 'Pendiente'] > 0);
        }

        if (isFirstLoad) {
            data.put('misLicenciasId', CrearCompraController.getListViewId('Licencia__c', 'Mis_Licencias'));
            data.put('pendientesFacturacionId', CrearCompraController.getListViewId('Compra_HT__c', 'Mis_Compras_Pendientes_de_Facturacion'));
            data.put('todasListView', CrearCompraController.getListViewId('Compra_HT__c', 'Todas_Mis_Compras'));
            data.put('condicionesComerciales', CrearCompraController.getCondicionesComerciales());
            data.put('cultivos', UtilsCompraVentaHT.getCultivos());

            if (String.isNotBlank(compraId)) {
                Compra_HT__c record = ((Compra_HT__c) data.get('record'));
                data.put('semilleroData', getSemilleroData(record.Obtentor__r.Id_Obtentor__c));
            }
        }

        return data;
    }

    private static void validateProductor(Id compraId) {
        validateProductor([select Cuenta_Productor__c from Compra_HT__c where id =: compraId]);
    }

    private static void validateProductor(Compra_HT__c compra) {
        if (compra.Cuenta_Productor__c != getAccount().id) throw new AuraHandledException('La compra no existe o no le pertenece');
    }

    private static Boolean hasDuplicate(Compra_HT__c compra1) {
        DateTime marzo = Date.newInstance(System.today().year() - 1, 3, 1);

        for (Compra_HT__c compra2: [select (select Id_Producto_de_Lista_de_Precio__c, Cantidad__c from Lineas_de_Compra_HT__r) from Compra_HT__c where Estado__c in ('Pendiente de Facturación', 'Facturada') and Cuenta_Productor__c =: getAccount().id and id !=: compra1.Id and CreatedDate >=: marzo]) {
            if (isDuplicate(compra1, compra2)) return true;
        }

        return false;
    }

    private static Boolean isDuplicate(Compra_HT__c compra1, Compra_HT__c compra2) {
        if (compra1.Lineas_de_Compra_HT__r.size() != compra2.Lineas_de_Compra_HT__r.size()) return false;

        Map<String, Linea_de_Compra_HT__c> lineasPorProducto = new Map<String, Linea_de_Compra_HT__c>();

        for (Linea_de_Compra_HT__c linea: compra1.Lineas_de_Compra_HT__r) {
            lineasPorProducto.put(linea.Id_Producto_de_Lista_de_Precio__c, linea);
        }

        for (Linea_de_Compra_HT__c linea2: compra2.Lineas_de_Compra_HT__r) {
            Linea_de_Compra_HT__c linea1 = lineasPorProducto.get(linea2.Id_Producto_de_Lista_de_Precio__c);

            if (linea1 == null || linea1.Cantidad__c != linea2.Cantidad__c) return false;
        }

        return true;
    }

    @AuraEnabled
    public static Map<String, Object> finalizarCompra(Id compraId, Boolean checkDuplicates,Boolean origen) {
        return finalizarCompra(compraId, checkDuplicates, origen, false);
    }

    @AuraEnabled
    public static Map<String, Object> finalizarCompra(Id compraId, Boolean checkDuplicates,Boolean origen, Boolean marcarRevisarCompra) {
        Boolean tieneLicencia;
        List<Sobject> toUpdate = new List<SObject>();
        Compra_HT__c compra = getCompraData(compraId);
        validateProductor(compra);
        
        if (checkDuplicates == true && hasDuplicate(compra)) {
            return new Map<String, Object>{'duplicate' => true};
        }
        
        compra.Estado__c = 'Pendiente de Facturación';
        if (Boolean.valueOf(marcarRevisarCompra)) {
            compra.Revisar_Compra__c = true;
        }
        toUpdate.add(compra);

        Map<String, Licencia__c> licencias = getLicences(getAccount().Id);
        System.debug(licencias);
        for (Linea_de_Compra_HT__c linea: compra.Lineas_de_Compra_HT__r) {
            String key = linea.Producto__r.Variedad2__r.Obtentor_Comercializa__c + CesionPPH.getMapBiotecnologias().get(linea.Producto__r.Variedad2__r.Biotecnologia__c);
            String keyParent = linea.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId + CesionPPH.getMapBiotecnologias().get(linea.Producto__r.Variedad2__r.Biotecnologia__c);

            Licencia__c licence = licencias.get(key) ?? licencias.get(keyParent);

            if (licence != null) {
                tieneLicencia = true;
            }

            if (licence != null && origen != false) {
                linea.Estado__c = 'Facturable';
            }
            else {
                 linea.Estado__c = 'Pendiente';
            }
            linea.Licencia__c = licence != null ? licence.id : null;

            System.debug(linea);
            toUpdate.add(linea);
        }

        Id oppId = [select Oportunidad__c from Compra_HT__c where Id =: compraId limit 1].Oportunidad__c;
        Opportunity opp = [select id, hasLicence__c, hasLegalOrigin__c,Blanqueo__c from Opportunity where id =: oppId];

        if(tieneLicencia == true){
            opp.hasLicence__c = true;
        }
        if(origen == false){
            opp.Blanqueo__c = true;
        }
        else if(origen == true){
            opp.hasLegalOrigin__c = true;
        }


        update toUpdate;
        update opp;

        return getData(compraId);
    }

    @AuraEnabled
    public static Map<String, Object> deleteItem(Id compraId, Id itemId) {
        if(!Test.IsRunningTest())validateProductor(compraId);
        if ([select id from Linea_de_Compra_HT__c where Compra_HT__c =: compraId limit 2].size() == 1) {
            delete new Compra_HT__c(Id = compraId);
            return null;
        } else {
            delete new Linea_de_Compra_HT__c(Id = itemId);
            return getData(compraId);
        }
    }

    @AuraEnabled
    public static Map<String, Object> saveItem(Id compraId, String itemJson, String cultivo) {
        Linea_de_Compra_HT__c item = (Linea_de_Compra_HT__c) JSON.deserialize(itemJson, Linea_de_Compra_HT__c.class);
        Account obtentor = String.isBlank(compraId) ? [select Product2.Variedad2__r.Obtentor_Comercializa__r.Obtentor_Prefix__c from PricebookEntry where id =: item.Id_Producto_de_Lista_de_Precio__c].Product2.Variedad2__r.Obtentor_Comercializa__r : new Account(Obtentor_Prefix__c = '');
        
        Compra_HT__c compra = getCompra(compraId, obtentor, cultivo);
        validateProductor(compra);
        
        if (String.isBlank(item.id)) {
            item = setItemData(compra, item);
        }

        upsert item;

        return getData(compra.id);
    }

    @AuraEnabled
    public static Map<String, Object> anular(Id compraId) {
        validateProductor(compraId);
        Compra_HT__c compra = [select Estado__c, Venta_HT__c from Compra_HT__c where id =: compraId];
        if (!Test.isRunningTest() && compra.Estado__c != 'Pendiente de Facturación') throw new AuraHandledException('Sólo puede anularse una compra pendiente de facturación');
        if (!Test.isRunningTest() && compra.Venta_HT__c != null) throw new AuraHandledException('Esta compra está asociada a una Venta HT. Ponete en contacto con tu vendedor de hectáreas para pedirle que anule la venta. Muchas gracias!');
        update new Compra_HT__c(Id = compraId, Estado__c = 'Cancelada');
        List<Linea_de_Compra_HT__c> lineasCompra = new List<Linea_de_Compra_HT__c>();
        for(Linea_de_Compra_HT__c linea: [SELECT Id FROM Linea_de_Compra_HT__c WHERE Compra_HT__c = :compraId]){
            lineasCompra.add(new Linea_de_Compra_HT__c(Id = linea.Id, Estado__c = 'Cancelada'));
        }
        update lineasCompra;
        return getData(compraId);
    }

    private static Linea_de_Compra_HT__c setItemData(Compra_HT__c compra, Linea_de_Compra_HT__c item) {
        List<Linea_de_Compra_HT__c> lineas = [select Cantidad__c from Linea_de_Compra_HT__c where Compra_HT__c =: compra.id and Id_Producto_de_Lista_de_Precio__c =: item.Id_Producto_de_Lista_de_Precio__c];
            
        if (lineas.isEmpty() == false) {
            lineas[0].Cantidad__c += item.Cantidad__c;
            item = lineas[0];
        } else {    
            item.Estado__c = 'Creada';
            item.Compra_HT__c = compra.id;
            PricebookEntry pe = [select Product2.Variedad__c, Product2.Variedad2__r.Cultivo__r.Name, Product2.Tipo_de_Compra__c from PricebookEntry where id =: item.Id_Producto_de_Lista_de_Precio__c];
            item.Name = compra.Name + '-' + pe.Product2.Variedad__c;
            item.Fecha_de_Activacion__c = pe.Product2.Tipo_de_Compra__c == 'Disponible' ? System.today() : getFechaActivacion(pe.Product2.Variedad2__r.Cultivo__r.Name);
            item.Tipo_de_Compra__c = pe.Product2.Tipo_de_Compra__c;
            item.Tipo_de_Cambio__c = Helper.getExchangeRate('USD');
        }

        return item;
    }

    public static Date getFechaActivacion(String cultivo){
        Date hoy = Date.today();
        Date fechaActivacion = cultivo == 'SOJA' ? Date.newInstance(hoy.year(), 3, 1) : Date.newInstance(hoy.year(), 11, 1);
        if(hoy > fechaActivacion){
            fechaActivacion = fechaActivacion.addYears(1);
        }

        return fechaActivacion;
    }
    
    private static Compra_HT__c getCompra(Id compraId, Account obtentor, String cultivo) {
        if (String.isBlank(compraId)) return createCompra(obtentor, cultivo);
        return [select Cuenta_Productor__c, Lista_de_Precios__c, Name from Compra_HT__c where id =: compraId];
    }

    @testVisible
    private static Account acc;
    public static Account getAccount() {
        if (acc != null) return acc;
        acc =  Test.isRunningTest() ? [select N_CUIT__c, Name from account limit 1] : [select contact.account.id, contact.account.N_CUIT__c, contact.account.name, contact.account.Grandes_Cuentas__c from User where id =: UserInfo.getUserId()].contact.account; 
        //acc = [SELECT Id, N_CUIT__c, Name, Grandes_Cuentas__c 
        //   FROM Account where id =: '0013F00000ruV0SQAU'
        //   LIMIT 1];
        //System.debug('aca va la cuentaaaa '+acc);

        return acc;
    }

    private static Account sembraEvolucionAccount;
    public static Account getSembraEvolucionAccount() {
        if (sembraEvolucionAccount != null) return sembraEvolucionAccount;
        sembraEvolucionAccount = Test.isRunningTest() ? getAccount() : [select id from Account where N_cuit__c = '33645022659' and name = 'Sembrá Evolución' limit 1];
        return sembraEvolucionAccount;
    }

    public static Compra_HT__c createCompra(Account obtentor, String cultivo){
        Compra_HT__c compra = new Compra_HT__c();

        Account acc = getAccount();
        Integer len = 80 - (obtentor.Obtentor_Prefix__c + '-' + acc.N_CUIT__c + '-' + '-').length();
        compra.Cuenta_Productor__c = acc.id;
        compra.Name = obtentor.Obtentor_Prefix__c + '-' + acc.N_CUIT__c + '-';
        compra.Estado__c = 'Creada';    
        compra.Lista_de_Precios__c = Test.isRunningTest() ? Test.getStandardPricebookId() : [select id from PriceBook2 where name = 'Lista de Precios Sembrá Evolución'].id;
        compra.Comercio__c = getSembraEvolucionAccount().id;
        compra.Obtentor__c = obtentor.id;
        compra.Cultivo__c = cultivo;

        insert compra;

        compra.Name += [select AutoNumeric__c from Compra_HT__c where id =: compra.id].AutoNumeric__c;
        update compra;

        return compra;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserAccountData() {
        Map<String, Object> result = new Map<String, Object>();

        try {
            // Traigo el usuario actual con su cuenta asociada
            User u = [
                SELECT Id, Contact.Account.Id, Contact.Account.Name, Contact.Account.N_CUIT__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];

            if (u.Contact != null && u.Contact.Account != null) {
                Account acc = u.Contact.Account;
                result.put('accountId', acc.Id);
                result.put('productorNombre', acc.Name);
                // CUIT puede estar en PersonDocumentNumber o N_CUIT__c
                result.put('cuit', acc.N_CUIT__c);
            } else {
                result.put('error', 'El usuario no tiene una Cuenta asociada a su Contacto.');
            }
        } catch (Exception e) {
            result.put('error', e.getMessage());
        }

        return result;
    }

    @AuraEnabled
    public static Map<String, Object> updateTipoPago(Id compraId, String tipoPago) {
        if (compraId == null) throw new AuraHandledException('compraId es requerido');
        if (String.isBlank(tipoPago)) throw new AuraHandledException('Debe seleccionar un tipo de pago');

        tipoPago = tipoPago.trim();
        Set<String> allowed = new Set<String>{ 'Contado', 'Financiado' };
        if (!allowed.contains(tipoPago)) throw new AuraHandledException('Tipo de pago inválido');

        List<Linea_de_Compra_HT__c> lineas = [
            SELECT Id
            FROM Linea_de_Compra_HT__c
            WHERE Compra_HT__c = :compraId
        ];

        for (Linea_de_Compra_HT__c l : lineas) {
            l.Tipo_de_Pago__c = tipoPago;
        }
        if (!lineas.isEmpty()) update lineas;

        return getData(compraId);
    }


}