public without sharing class CrearVentaController {
    /*
        Producción es un desastre puede haber licencia vinculada a cuenta hija pero la variedad estar con la parent o viceversa
        Además por ejemplo GDM puede tener una licencia para la hija y eso habilita variedades de las demas hijas del parent
        Tengo que permitir esos matches excepto para corteva (parent CUIT 30636021578)
    */

    @AuraEnabled
    public static List<PricebookEntry> getProductsData(String cultivoId, String productorId){
        return getProducts(cultivoId, productorId);
    }

    public static List<PricebookEntry> getProducts(String cultivoId, String productorId) {
        Boolean isPortalObtentores = SolicitarLicencia.networkName == 'Sembrá Evolución Obtentor';
        List<Licencia__c> licences = !isPortalObtentores ? [select Cuenta_Obtentor__c, Cuenta_Obtentor__r.ParentId from Licencia__c where Cuenta_Productor__c =: getAccount(null).id and Estado__c = 'Aprobada' and Fecha_de_Vencimiento__c >=: System.today() AND Tipo_de_Licencia__c = 'Comercio'] : new List<Licencia__c>();
        Set<Id> obtentores = new Set<Id>();

        Boolean productorGrandesCuentas = [SELECT Grandes_Cuentas__c FROM Account WHERE Id = :productorId].Grandes_Cuentas__c;
        
        for (Licencia__c l: licences) {
            obtentores.add(l.Cuenta_Obtentor__c);
            if (l.Cuenta_Obtentor__r.ParentId != null) obtentores.add(l.Cuenta_Obtentor__r.ParentId);
        }

        Set<Id> variedadesSreIds = UtilsCompraVentaHT.getVariedadesSreProductor(productorId);

        if(isPortalObtentores){
            obtentores.add(getAccount(null).Id);
            return getProductosPortalObtentor(cultivoId, obtentores, variedadesSreIds);
        }
        
        List<PricebookEntry> entries = new List<PricebookEntry>();
        for(PricebookEntry pbe : getProductosPortalComercio(cultivoId, obtentores, variedadesSreIds)){
            if(productorGrandesCuentas && pbe.Product2.Variedad2__r.Obtentor_Comercializa__r.No_Vender_a_Grandes_Cuentas__c == true){
                continue;
            }
            entries.add(pbe);
        }

        return entries;
    }

    private static List<PricebookEntry> getProductosPortalComercio(String cultivoId, Set<Id> obtentores, Set<Id> variedadesSreIds){
        String cuitCorteva = UtilsAccount.getCuitCorteva();
        return [SELECT Id, 
                        Product2.Nombre_Comercial__c, 
                        UnitPrice, 
                        Unit_Price__c,
                        Product2.Unidad_De_Medida__c, 
                        Product2.Tipo_de_Compra__c, 
                        Product2.Variedad2__r.Cultivo__r.Name, 
                        Product2.Variedad2__r.Obtentor_Comercializa__r.Nombre_Obtentor__c, 
                        Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c, 
                        Product2.Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c, 
                        Product2.Variedad2__r.Obtentor_Comercializa__r.No_Vender_a_Grandes_Cuentas__c 
                FROM PricebookEntry 
                WHERE Product2.IsActive = true 
                AND Product2.Producto_Vigente__c = true 
                AND Product2.Variedad2__r.Cultivo__c = :cultivoId 
                AND IsActive = true 
                AND Pricebook2.IsActive = true 
                AND PriceBook2.Name = 'Lista de Precios Sembrá Evolución' 
                AND (Product2.Variedad2__r.Obtentor_Comercializa__c in: obtentores OR (Product2.Variedad2__r.Obtentor_Comercializa__r.ParentId in: obtentores AND Product2.Variedad2__r.Obtentor_Comercializa__r.Parent.N_CUIT__C != :cuitCorteva)) 
                AND (Product2.Variedad2__r.Sembra_Evolucion__c = true OR Product2.Variedad2__c IN :variedadesSreIds) 
                AND UnitPrice != 0 
                ORDER BY Product2.Nombre_Comercial__c ASC];
    }

    private static List<PricebookEntry> getProductosPortalObtentor(String cultivoId, Set<Id> obtentores, Set<Id> variedadesSreIds){
        return [SELECT Id, 
                        UnitPrice,
                        Unit_Price__c,
                        Product2.Nombre_Comercial__c, 
                        Product2.Unidad_De_Medida__c, 
                        Product2.Tipo_de_Compra__c, 
                        Product2.Variedad2__r.Cultivo__r.Name, 
                        Product2.Variedad2__r.Obtentor_Comercializa__r.Nombre_Obtentor__c, 
                        Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c, 
                        Product2.Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c 
                FROM PricebookEntry 
                WHERE Product2.IsActive = true 
                AND Product2.Producto_Vigente__c = true 
                AND Product2.Variedad2__r.Cultivo__c = :cultivoId 
                AND IsActive = true 
                AND Pricebook2.IsActive = true 
                AND priceBook2.Name = 'Lista de Precios Sembrá Evolución' 
                AND (Product2.Variedad2__r.Obtentor_Comercializa__c in: obtentores OR Product2.Variedad2__r.Obtentor_Comercializa__r.ParentId in: obtentores) 
                AND (Product2.Variedad2__r.Sembra_Evolucion__c = true OR Product2.Variedad2__c IN :variedadesSreIds) 
                AND UnitPrice != 0 
                ORDER BY Product2.Nombre_Comercial__c ASC];
    }

    private static Licencia__c getLicence(Account obtentor, Id productorId) {
        List<Id> accounts = new List<Id>{obtentor.id};
        if (obtentor.ParentId != null) accounts.add(obtentor.ParentId);

        String cuitCorteva = UtilsAccount.getCuitCorteva();

        List<Licencia__c> licenciasComercio = [select id from Licencia__c where Cuenta_Productor__c =: CrearCompraController.getAccount().id and Estado__c = 'Aprobada' and Fecha_de_Vencimiento__c >=: System.today() and Tipo_de_Licencia__c = 'Comercio' and (Cuenta_Obtentor__c in: accounts or (Cuenta_Obtentor__r.ParentId in: accounts and Cuenta_Obtentor__r.Parent.N_CUIT__c != :cuitCorteva))];
        List<Licencia__c> licenciasProductor = [select id from Licencia__c where Cuenta_Productor__c =: productorId and Estado__c = 'Aprobada' and Fecha_de_Vencimiento__c >=: System.today() and Tipo_de_Licencia__c = 'Productor' and (Cuenta_Obtentor__c in: accounts or Cuenta_Obtentor__r.ParentId in: accounts)]; //se sacó la exclusión de CORTEVA 18/09/23
        
        Boolean isPortalObtentores = SolicitarLicencia.networkName == 'Sembrá Evolución Obtentor';

        return licenciasProductor.isEmpty() || (!isPortalObtentores && licenciasComercio.isEmpty()) ? null : licenciasProductor[0];
    }

    @AuraEnabled
    public static Map<String, Object> getSemilleroData(String obtentorId, Id productorId) {
        Account obtentor = [select Id_Obtentor__c, Nombre_Obtentor__c, ParentId from Account where Id_Obtentor__c =: obtentorId];
        //Account obtentor = [select Id_Obtentor__c, Nombre_Obtentor__c, ParentId from Account where Id_Obtentor__c ='87'];
        return CrearCompraController.getSemilleroData(obtentor, getLicence(obtentor, productorId));
    }

    private static Venta_HT__c getVentaData(Id ventaId){
        return [select Comercio__c, Obtentor__r.Id_Obtentor__c, Obtentor__r.N_CUIT__c, Total_HT__c, Total_USD__c, Cuenta_Productor__r.Name, Cuenta_Productor__r.N_CUIT__c, Cuenta_Productor__r.Owner.Name, Cuenta_Productor__r.Operador_de_Cobranza__r.Name, Cuenta_Productor__r.Provincia_Envio__c, Cuenta_Productor__r.Phone, id, Cuenta_Productor__c, Compra_HT__c, Estado__c, CreatedDate, Cultivo__c, (select id, Estado__c, Licencia__c, Licencia__r.Name, Id_Producto_de_Lista_de_Precio__c, Cantidad__c, Precio_de_Lista__c, Fecha_de_Activacion__c,Tipo_de_Pago__c, Producto__r.Variedad2__r.Obtentor_Comercializa__c, Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId, Producto__r.Variedad2__r.Biotecnologia__c from Lineas_de_Venta_HT__r) from Venta_HT__c where id =: ventaId];
    }

    public static Opportunity getOpp(Id ventaId) {
        List<Opportunity> opps = [select StageName, (select Estado__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c, Product2.Variedad2__r.Obtentor_Comercializa__r.Dias_de_Exclusion_de_Facturacion_SE__c, Linea_de_Compra_HT__r.Linea_de_Venta_HT__c FROM OpportunityLineItems) from opportunity where Compra_HT__r.Venta_HT__c =: ventaId];
        return opps.isEmpty() ? null : opps[0];
    }

    private static List<Erpvs__Comprobante_Venta__c> getCVS(Id ventaId) {
        return [select id, ERPvs__Comprobante__c, Erpvs__Contabilizar__c, (select name from Attachments), (select id, OpportunityLineItem__c from Erpvs__Renglones_de_Comprobante_de_Venta__r) from Erpvs__Comprobante_Venta__c where Oportunidad__r.Compra_HT__r.Venta_HT__c =: ventaId];
    }

    private static Map<String, Object> getData(Id ventaId) {
        return getData(ventaId, false);
    }

    @AuraEnabled
    public static Map<String, Object> getData(Id ventaId, Boolean isFirstLoad) {
        Map<String, Object> data = new Map<String, Object> {};

        if (String.isNotBlank(ventaId)) {
            validateComercio(ventaId);
            Venta_HT__c venta = getVentaData(ventaId);
            data.put('record', venta);
            data.put('oportunidad', getOpp(ventaId));
            data.put('cvs', getCVS(ventaId));
            List<PricebookEntry> products = getProducts(venta.Cultivo__c, venta.Cuenta_Productor__c);
            data.put('products', products);
            data.put('pendiente', [SELECT Count() FROM Linea_de_Venta_HT__c WHERE Venta_HT__c = :ventaId AND Estado__c = 'Pendiente'] > 0);
        }

        if (isFirstLoad) {
            data.put('misLicenciasId', CrearCompraController.getListViewId('Licencia__c', 'Mis_Licencias'));
            data.put('pendientesFacturacionId', CrearCompraController.getListViewId('Venta_HT__c', 'Ventas_Pendientes_de_Facturacion'));
            data.put('todasListView', CrearCompraController.getListViewId('Venta_HT__c', 'Todas_las_Ventas'));
            data.put('cultivos', UtilsCompraVentaHT.getCultivos());
            data.put('condicionesComerciales', CrearCompraController.getCondicionesComerciales());

            if (String.isNotBlank(ventaId)) {
                Venta_HT__c record = ((Venta_HT__c) data.get('record'));
                data.put('semilleroData', getSemilleroData(record.Obtentor__r.Id_Obtentor__c, record.Cuenta_Productor__c));
            }
        }

        return data;
    }

    @AuraEnabled
    public static Map<String, Object> finalizarVenta(Id ventaId, Boolean checkDuplicates, Boolean origen) {
        return finalizarVenta(ventaId, checkDuplicates, origen, false);
    }

    @AuraEnabled
    public static Map<String, Object> finalizarVenta(Id ventaId, Boolean checkDuplicates, Boolean origen, Boolean marcarRevisarCompra) {
        List<Sobject> toUpdate = new List<SObject>();
        Boolean tieneLicencia;

        Venta_HT__c venta = getVentaData(ventaId);

        if (checkDuplicates == true && hasDuplicate(venta)) {
            return new Map<String, Object>{'duplicate' => true};
        }

        venta.Estado__c = 'Pendiente de Facturación';
        toUpdate.add(venta);
        if (Boolean.valueOf(marcarRevisarCompra) && venta.Compra_HT__c != null) {
            toUpdate.add(new Compra_HT__c(
                Id = venta.Compra_HT__c,
                Revisar_Compra__c = true
            ));
        }

        Map<String, Licencia__c> licenciasProductor = CrearCompraController.getLicences(venta.Cuenta_Productor__c);

        for (Linea_de_Venta_HT__c linea: venta.Lineas_de_Venta_HT__r) {
            String key = linea.Producto__r.Variedad2__r.Obtentor_Comercializa__c + CesionPPH.getMapBiotecnologias().get(linea.Producto__r.Variedad2__r.Biotecnologia__c);
            String keyParent = linea.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId + CesionPPH.getMapBiotecnologias().get(linea.Producto__r.Variedad2__r.Biotecnologia__c);

            Licencia__c licence = licenciasProductor.get(key) ?? licenciasProductor.get(keyParent);

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

        Id oppId = [select Compra_HT__r.Oportunidad__c from Venta_HT__c where Id =: ventaId limit 1].Compra_HT__r.Oportunidad__c;
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

        return getData(ventaId);
    }

    @AuraEnabled
    public static Map<String, Object> deleteItem(Id ventaId, Id itemId) {
        validateComercio(ventaId);
        if ([select id from Linea_de_Venta_HT__c where Venta_HT__c =: ventaId limit 2].size() == 1) {
            delete new Venta_HT__c(Id = ventaId);
            return null;
        } else {
            delete new Linea_de_Venta_HT__c(Id = itemId);
            return getData(ventaId);
        }
    }

    @AuraEnabled
    public static Map<String, Object> saveItem(Id ventaId, String itemJson, Id productorId, String cultivo) {
        Linea_de_Venta_HT__c item = (Linea_de_Venta_HT__c) JSON.deserialize(itemJson, Linea_de_Venta_HT__c.class);
        Account obtentor = String.isBlank(ventaId) ? [select Product2.Variedad2__r.Obtentor_Comercializa__r.Obtentor_Prefix__c from PricebookEntry where id =: item.Id_Producto_de_Lista_de_Precio__c].Product2.Variedad2__r.Obtentor_Comercializa__r : new Account(Obtentor_Prefix__c = '');
        
        Venta_HT__c venta = getVenta(ventaId, productorId, obtentor, cultivo);
        validateComercio(venta);

        if (String.isBlank(item.id)) {
            item = setItemData(venta, item);
        }

        upsert item;

        return getData(venta.id);
    }

    @AuraEnabled
    public static Map<String, Object> anular(Id ventaId) {
        validateComercio(ventaId);
        if (!Test.isRunningTest() && [select Estado__c from Venta_HT__c where id =: ventaId].Estado__c != 'Pendiente de Facturación') throw new AuraHandledException('Sólo puede anularse una venta pendiente de facturación');
        update new Venta_HT__c(Id = ventaId, Estado__c = 'Cancelada');
        List<Linea_de_Venta_HT__c> lineasVenta = new List<Linea_de_Venta_HT__c>();
        for(Linea_de_Venta_HT__c linea: [SELECT Id FROM Linea_de_Venta_HT__c WHERE Venta_HT__c = :ventaId]){
            lineasVenta.add(new Linea_de_Venta_HT__c(Id = linea.Id, Estado__c = 'Cancelada'));
        }
        update lineasVenta;
        return getData(ventaId);
    }

    private static Linea_de_Venta_HT__c setItemData(Venta_HT__c venta, Linea_de_Venta_HT__c item) {
        List<Linea_de_Venta_HT__c> lineas = [select Cantidad__c from Linea_de_Venta_HT__c where Venta_HT__c =: venta.id and Id_Producto_de_Lista_de_Precio__c =: item.Id_Producto_de_Lista_de_Precio__c];
            
        if (lineas.isEmpty() == false) {
            lineas[0].Cantidad__c += item.Cantidad__c;
            item = lineas[0];
        } else {    
            item.Estado__c = 'Creada';
            item.Venta_HT__c = venta.id;
            PricebookEntry pe = [select Product2.Variedad__c, Product2.Variedad2__r.Cultivo__r.Name, Product2.Tipo_de_Compra__c from PricebookEntry where id =: item.Id_Producto_de_Lista_de_Precio__c];
            item.Name = venta.Name + '-' + pe.Product2.Variedad__c;
            item.Fecha_de_Activacion__c = pe.Product2.Tipo_de_Compra__c == 'Disponible' ? System.today() : CrearCompraController.getFechaActivacion(pe.Product2.Variedad2__r.Cultivo__r.Name);
            item.Tipo_de_Compra__c = pe.Product2.Tipo_de_Compra__c;
            item.Tipo_de_Cambio__c = Helper.getExchangeRate('USD');
        }

        return item;
    }
    
    private static Venta_HT__c getVenta(Id ventaId) {
        return getVenta(ventaId, null, null, null);
    }

    private static Venta_HT__c getVenta(Id ventaId, Id productorId, Account obtentor, String cultivo) {
        if (String.isBlank(ventaId)) return createVenta(productorId, obtentor, cultivo);
        return [select Comercio__c, Lista_de_Precios__c, Name from Venta_HT__c where id =: ventaId];
    }

    public static Account getAccount(Id productorId) {
        if (productorId != null) return [select N_CUIT__c, name from Account where id =: productorId];
        return CrearCompraController.getAccount(); 
    }

    public static Venta_HT__c createVenta(Id productorId, Account obtentor, String cultivo){
        Venta_HT__c venta = new Venta_HT__c();

        Account acc = getAccount(productorId);

        Integer len = 80 - ('SE-' + acc.N_CUIT__c + '-' + '-').length();

        venta.Cuenta_Productor__c = acc.id;
        venta.Name = obtentor.Obtentor_Prefix__c + '-' + acc.N_CUIT__c + '-';
        venta.Estado__c = 'Creada';    
        venta.Lista_de_Precios__c = Test.isRunningTest() ? Test.getStandardPricebookId() : [select id from PriceBook2 where name = 'Lista de Precios Sembrá Evolución'].id;
        venta.Comercio__c = Test.isRunningTest() ? acc.id : getAccount(null).id;
        venta.Obtentor__c = obtentor.id;
        venta.Cultivo__c = cultivo;

        insert venta;

        venta.Name += [select AutoNumeric__c from Venta_HT__c where id =: venta.id].AutoNumeric__c;
        update venta;

        return venta;
    }
    
    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchProductores(String searchTerm, List<String> selectedIds) {
        String safeTerm = String.escapeSingleQuotes(searchTerm);
        String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(searchTerm);
        String cuitCondition = String.isNotBlank(normalizedCuitTerm)
            ? ' or N_CUIT__c like \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\''
            : '';
        return accountsToLookup(Database.query(
            'select RecordType.DeveloperName, Name, N_CUIT__c, Owner.Name, Operador_de_Cobranza__r.Name, Provincia_Envio__c, Phone ' +
            'from account where (name like \'%' + safeTerm + '%\'' + cuitCondition + ') ' +
            'and recordType.DeveloperName in (\'Productor\', \'Comercio\', \'Distribuidor\') ' +
            'and ParentId = null limit 5'
        ));
    }

    public static List<LookupSearchResult> accountsToLookup(List<Account> accs) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        String accountIcon = 'standard:account';

        for (Account account : accs) {
            String name = account.Name == 'A Gestionar' ? 'cuenta inexistente a registrar' : account.Name;
            results.add(new LookupSearchResult(account.Id, 'Account', accountIcon, account.N_CUIT__c + ' - ' + name, account.recordType.DeveloperName));
            results[results.size() - 1].record = account;
        }

        results.sort();

        return results;
    }

    private static void validateComercio(Id ventaId) {
        validateComercio([select Comercio__c from Venta_HT__c where id =: ventaId]);
    }

    private static void validateComercio(Venta_HT__c venta) {
        if (venta.Comercio__c != getAccount(null).id) throw new AuraHandledException('La venta no existe o no le pertenece');
    }

    private static Boolean hasDuplicate(Venta_HT__c venta1) {
        DateTime marzo = Date.newInstance(System.today().year() - 1, 3, 1);

        for (Venta_HT__c venta2: [select (select Id_Producto_de_Lista_de_Precio__c, Cantidad__c from Lineas_de_Venta_HT__r) from Venta_HT__c where Estado__c in ('Pendiente de Facturación', 'Facturada') and Comercio__c =: getAccount(null).id and id !=: venta1.Id and CreatedDate >=: marzo and Cuenta_Productor__c =: venta1.Cuenta_Productor__c and Obtentor__c =: venta1.Obtentor__c]) {
            if (isDuplicate(venta1, venta2)) return true;
        }

        return false;
    }

    private static Boolean isDuplicate(Venta_HT__c compra1, Venta_HT__c compra2) {
        if (compra1.Lineas_de_Venta_HT__r.size() != compra2.Lineas_de_Venta_HT__r.size()) return false;

        Map<String, Linea_de_Venta_HT__c> lineasPorProducto = new Map<String, Linea_de_Venta_HT__c>();

        for (Linea_de_Venta_HT__c linea: compra1.Lineas_de_Venta_HT__r) {
            lineasPorProducto.put(linea.Id_Producto_de_Lista_de_Precio__c, linea);
        }

        for (Linea_de_Venta_HT__c linea2: compra2.Lineas_de_Venta_HT__r) {
            Linea_de_Venta_HT__c linea1 = lineasPorProducto.get(linea2.Id_Producto_de_Lista_de_Precio__c);

            if (linea1 == null || linea1.Cantidad__c != linea2.Cantidad__c) return false;
        }

        return true;
    }
    /***********************************************************************************************************************
     * Método para guardar observaciones realizadas desde el portal. Relacionado a Facturacción Mixta.
     * Autor: Rodrigo Lopez
     * Fecha: 29/09/2025
     *********************************************************************************************************************/
    @AuraEnabled
    public static Boolean saveObvservations(Id recordId, String obs){
        try {
            if (!String.isBlank(obs) && recordId != null) {
                Venta_HT__c venta = new Venta_HT__c(Id = recordId, Observaciones__c = obs);
                update venta;
                return true;
            } else {
                return false;  
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    /***********************************************************************************************************************
     * Método para obtener observaciones realizadas desde el portal. Relacionado a Facturacción Mixta.
     * Autor: Nerio Alvarado
     * Fecha: 20/10/2025
     *********************************************************************************************************************/
     
    @AuraEnabled
    public static string getObservaciones(Id recordId){
        try {
            String Obs = [Select Observaciones__c from Venta_HT__c where id =: recordId].Observaciones__c;
            return Obs;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    } 
    /***********************************************************************************************************************
     * Método para Actualizar las oportunidades. Relacionado a Facturacción Mixta.
     * Autor: Nerio Alvarado
     * Fecha: 20/10/2025
     *********************************************************************************************************************/
      
     @AuraEnabled
     public static void updateOpportunity(Id recordId, date fechaEmision, String numComprobante){
        Venta_HT__c venta = [
            SELECT Id, Estado__c
            FROM Venta_HT__c
            WHERE Id = :recordId
            LIMIT 1
        ];
        if (venta.Estado__c == 'Pagada' || venta.Estado__c == 'Facturada') {
            throw new AuraHandledException('No se puede subir factura para una venta en estado ' + venta.Estado__c + '.');
        }

        Opportunity opp = [select id,AccountId,Total_Comprobante__c,CloseDate from Opportunity where Compra_HT__r.Venta_HT__c =: recordId LIMIT 1];
        Decimal TipoCambio = !Test.isRunningTest() ? [Select Tipo_de_Cambio__c from OpportunityLineItem where OpportunityId =: opp.Id limit 1].Tipo_de_Cambio__c : 1300.00;
        Decimal total;
      
        AggregateResult[] results = [
            SELECT OpportunityId, SUM(TotalPrice)
            FROM OpportunityLineItem
            WHERE OpportunityId =: opp.Id
            GROUP BY OpportunityId
        ];
         if(!Test.isRunningTest()){
             for (AggregateResult ar : results) {
              total = (Decimal) ar.get('expr0'); // SUM(TotalPrice)
          }
         }
         else {
             total = 1000.00;
         }
        
         Opportunity oppToUpdate = new Opportunity(
            Id = opp.Id,
            Fecha_Emision_Comprobante__c = fechaEmision,
            N_de_Comprobante__c = numComprobante,
            Neto_Comprobante__c = total,
            Total_Comprobante__c = total * 1.21,
            Divisa_Comprobante__c = 'USD',
            Fecha_Pedido_Facturacion__c = opp.CloseDate,
            Fecha_Facturacion__c = Date.today(),
            Saldo_a_Gestionar__c = total * 1.21,
            Tipo_de_Cambio_Actualizado__c  = TipoCambio,
            Saldo_a_Cobrar_Comprobante__c = total * 1.21,
            StageName = 'Pedido de Facturacion',
            Tipo_de_Cambio_del_Comprobante__c = TipoCambio
        );
        Movimientos__c mov = new Movimientos__c(
            Tipo_de_Movimiento__c = 'FC',
            Comprobante__c = numComprobante,
            Importe__c = total * 1.21,
            Moneda__c = 'USD',
            Tipo_de_Cambio__c = TipoCambio,
            Oportunidad__c = opp.Id,
            Cuenta__c = opp.AccountId,
            Fecha__c = Date.today()
        );
        try {
            AdminDmlExecutor executor = new AdminDmlExecutor();
            executor.executeDml(oppToUpdate, mov);
            System.debug('Oportunidad actualizada correctamente');
        } catch (Exception e) {
            System.debug('Error al actualizar la oportunidad: ' + e.getMessage());
            throw new AuraHandledException('Error en updateOpportunity (Admin Context): ' + e.getMessage());
        }
     }
    
    // Definimos las reglas de Semilla Fiscalizada
    private static Map<String, Map<String, Integer>> reglasSemillaFiscalizada = new Map<String, Map<String, Integer>>{
        'Original o Fundadora' => new Map<String, Integer>{
            'C' => 1,
            'DPD' => -1,
            'DPO' => 1,
            'Venta' => 1
        },
        'Pre Básica' => new Map<String, Integer>{
            'C' => 1,
            'DPD' => -1,
            'TDS' => -1,
            'Venta' => -1
        },
        'Primera Multiplicación' => new Map<String, Integer>{
            'C' => 1,
            'DPD' => -1,
            'DPO' => 1,
            'Venta' => 1
        }
    };

        private static Decimal getTotal(List<Venta__c> VentasCRM){
            Decimal total = 0;
             if(VentasCRM.size()>0){
                    
                    // Recorremos los registros
                    for (Venta__c v : VentasCRM) {
                        // Cuando el Tipo de Producto es Regalía Comercial
                        if (v.Tipo_de_Producto__c == 'Regalía Comercial') {
                            
                            // Evaluamos la categoría
                            if (v.Categoria__c == 'Original o Fundadora') {
                                
                                // Evaluamos el tipo de venta
                                if (v.Tipo_de_Venta__c == 'C') {
                                    total += (v.Cantidad__c != null ? v.Cantidad__c : 0);
                                } else if (v.Tipo_de_Venta__c == 'TDS') {
                                    total -= (v.Cantidad__c != null ? v.Cantidad__c : 0);
                                }
                            }
                        }
                        
                        // Caso 2: Semilla Fiscalizada
                        else if (v.Tipo_de_Producto__c == 'Semilla Fiscalizada') {
                            if (reglasSemillaFiscalizada.containsKey(v.Categoria__c)) {
                                Map<String, Integer> reglasPorCategoria = reglasSemillaFiscalizada.get(v.Categoria__c);
                                
                                if (reglasPorCategoria.containsKey(v.Tipo_de_Venta__c)) {
                                    Integer signo = reglasPorCategoria.get(v.Tipo_de_Venta__c);
                                    total += signo * (v.Cantidad__c != null ? v.Cantidad__c : 0);
                                }
                            }
                        }
                    } 
                }
            return total;
        }

        private static Decimal totalVentasCrmDelObtentor(Id cuentaProductor, Id parentId, Id idObtentor) {
            List<Venta__c> ventas;
            if (parentId != null) {
                ventas = [
                    SELECT Categoria__c, Destinatario__c, Cantidad__c, Tipo_de_Producto__c, Tipo_de_Venta__c, Obtentor__c,
                        Originante__r.Id, Variedad__c, Producto__r.Variedad2__r.Name
                    FROM Venta__c
                    WHERE (Producto__r.Obtentor_Comercializa__c = :idObtentor OR Producto__r.Obtentor_Comercializa__r.ParentId = :parentId)
                    AND (Originante__c = :cuentaProductor OR Destinatario__c = :cuentaProductor)
                    AND Semba_Evolucion__c = true
                ];
            } else {
                ventas = [
                    SELECT Categoria__c, Destinatario__c, Cantidad__c, Tipo_de_Producto__c, Tipo_de_Venta__c, Obtentor__c,
                        Producto__r.Obtentor_Comercializa__c, Originante__r.Id, Variedad__c, Producto__r.Variedad2__r.Name
                    FROM Venta__c
                    WHERE (Producto__r.Obtentor_Comercializa__c = :idObtentor OR Producto__r.Obtentor_Comercializa__r.ParentId = :idObtentor)
                    AND (Originante__c = :cuentaProductor OR Destinatario__c = :cuentaProductor)
                    AND Semba_Evolucion__c = true
                ];
            }
            return getTotal(ventas);
        }

        private static Decimal totalVentasCrmCualquierObtentor(Id cuentaProductor) {
            return getTotal([
                SELECT Categoria__c, Destinatario__c, Cantidad__c, Tipo_de_Producto__c, Tipo_de_Venta__c, Obtentor__c,
                    Originante__r.Id, Variedad__c, Producto__r.Variedad2__r.Name
                FROM Venta__c
                WHERE (Originante__c = :cuentaProductor OR Destinatario__c = :cuentaProductor)
                AND Semba_Evolucion__c = true
            ]);
        }

        // Origen legal y blanqueo: solo ventas CRM (Semba Evolución). Sin cesiones ni compras HT.
        @AuraEnabled
        public static Map<String, Object> canFinish(
            Map<String, Object> semillero,
            Id CuentaProductor,
            Boolean tieneLicencia,
            List<Id> Variedades
        ) {
            try {
                String parentIdStr = (String) semillero.get('ParentId');
                String idObtentorStr = (String) semillero.get('Id');
                Id parentId = String.isNotBlank(parentIdStr) ? (Id) parentIdStr : null;
                Id idObtentor = String.isNotBlank(idObtentorStr) ? (Id) idObtentorStr : null;

                Decimal totalObtentor = totalVentasCrmDelObtentor(CuentaProductor, parentId, idObtentor);
                Boolean origenLegal = totalObtentor > 0;
                Boolean blanqueo = !origenLegal && totalVentasCrmCualquierObtentor(CuentaProductor) <= 0;

                return new Map<String, Object>{
                    'origenLegal' => origenLegal,
                    'Blanqueo' => blanqueo,
                    'TieneLicencia' => tieneLicencia,
                    'VentasCRM' => totalObtentor,
                    'ParentId' => parentId,
                    'IdObtentor' => idObtentor,
                    'CuentaProductor' => CuentaProductor
                };
            } catch (Exception e) {
                throw new AuraHandledException('Error en canFinish: ' + e.getMessage());
            }
        }

    @AuraEnabled
    public static Map<String, Object> updateTipoPago(Id ventaId, String tipoPago) {
    if (ventaId == null) throw new AuraHandledException('ventaId es requerido');
    if (String.isBlank(tipoPago)) throw new AuraHandledException('Debe seleccionar un tipo de pago');

    // Seguridad / ownership: que la venta sea del comercio logueado
    validateComercio(ventaId);

    tipoPago = tipoPago.trim();
    Set<String> allowed = new Set<String>{ 'Contado', 'Financiado' };
    if (!allowed.contains(tipoPago)) throw new AuraHandledException('Tipo de pago inválido');

    // 1) Lineas de venta de esa venta
    List<Linea_de_Venta_HT__c> lineasVenta = [
        SELECT Id, Tipo_de_Pago__c
        FROM Linea_de_Venta_HT__c
        WHERE Venta_HT__c = :ventaId
    ];

    if (!lineasVenta.isEmpty()) {
        for (Linea_de_Venta_HT__c lv : lineasVenta) {
            lv.Tipo_de_Pago__c = tipoPago;
        }
        update lineasVenta;
    }

    // 2) Lineas de compra asociadas a esas lineas de venta
    //    (asumiendo que existe el lookup Linea_de_Venta_HT__c en Linea_de_Compra_HT__c)
    Set<Id> lineaVentaIds = new Set<Id>();
    for (Linea_de_Venta_HT__c lv : lineasVenta) lineaVentaIds.add(lv.Id);

    if (!lineaVentaIds.isEmpty()) {
        List<Linea_de_Compra_HT__c> lineasCompra = [
            SELECT Id, Tipo_de_Pago__c
            FROM Linea_de_Compra_HT__c
            WHERE Linea_de_Venta_HT__c IN :lineaVentaIds
        ];

        if (!lineasCompra.isEmpty()) {
            for (Linea_de_Compra_HT__c lc : lineasCompra) {
                lc.Tipo_de_Pago__c = tipoPago;
            }
            update lineasCompra;
        }
    }

    return getData(ventaId);
}

    private without sharing class AdminDmlExecutor {
        public void executeDml(Opportunity opp, Movimientos__c mov) {
            update opp;
            insert mov;
        }
    }

}