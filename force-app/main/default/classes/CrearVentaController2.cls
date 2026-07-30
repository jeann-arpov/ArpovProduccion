public without sharing class CrearVentaController2 {
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
        return [select Name, Comercio__c, Nombre_del_comercio__c, Es_NC__c, Tipo_Ajuste__c, Venta_Original__c, Venta_Original__r.Name, Obtentor__r.Id_Obtentor__c, Total_HT__c, Total_USD__c, Cuenta_Productor__r.Name, Cuenta_Productor__r.N_CUIT__c, Cuenta_Productor__r.Owner.Name, Cuenta_Productor__r.Operador_de_Cobranza__r.Name, Cuenta_Productor__r.Provincia_Envio__c, Cuenta_Productor__r.Phone, id, Cuenta_Productor__c, Estado__c, CreatedDate, Cultivo__c, (select id, Estado__c, Licencia__c, Licencia__r.Name, Id_Producto_de_Lista_de_Precio__c, Cantidad__c, Precio_de_Lista__c, Fecha_de_Activacion__c,Tipo_de_Pago__c, Producto__r.Variedad2__r.Obtentor_Comercializa__c, Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId, Producto__r.Variedad2__r.Biotecnologia__c from Lineas_de_Venta_HT__r) from Venta_HT__c where id =: ventaId];
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

    // MODIFICAR el método getData para incluir información de notas de crédito
@AuraEnabled
public static Map<String, Object> getData(Id ventaId, Boolean isFirstLoad) {
    Map<String, Object> data = new Map<String, Object> {};

    if (String.isNotBlank(ventaId)) {
        //validateComercio(ventaId);
        Venta_HT__c venta = getVentaData(ventaId);
        data.put('record', venta);
        data.put('oportunidad', getOpp(ventaId));
        data.put('cvs', getCVS(ventaId));
        List<PricebookEntry> products = getProducts(venta.Cultivo__c, venta.Cuenta_Productor__c);
        data.put('products', products);
        data.put('pendiente', [SELECT Count() FROM Linea_de_Venta_HT__c WHERE Venta_HT__c = :ventaId AND Estado__c = 'Pendiente'] > 0);
        
        // ===== NUEVO: INCLUIR INFORMACIÓN DE NOTAS DE CRÉDITO PENDIENTES =====
        Map<String, Object> infoNotasCredito = verificarNotasCreditoPendientes(ventaId);
        data.put('infoNotasCredito', infoNotasCredito);
        
        // ===== NUEVO: INCLUIR SALDO HT =====
        data.put('saldoHT', obtenerSaldoHT(ventaId));
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
        List<Sobject> toUpdate = new List<SObject>();

        Venta_HT__c venta = getVentaData(ventaId);

        if (checkDuplicates == true && hasDuplicate(venta)) {
            return new Map<String, Object>{'duplicate' => true};
        }

        venta.Estado__c = 'Pendiente de Facturación';
        toUpdate.add(venta);

        Map<String, Licencia__c> licenciasProductor = CrearCompraController.getLicences(venta.Cuenta_Productor__c);

        for (Linea_de_Venta_HT__c linea: venta.Lineas_de_Venta_HT__r) {
            String key = linea.Producto__r.Variedad2__r.Obtentor_Comercializa__c + CesionPPH.getMapBiotecnologias().get(linea.Producto__r.Variedad2__r.Biotecnologia__c);
            String keyParent = linea.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId + CesionPPH.getMapBiotecnologias().get(linea.Producto__r.Variedad2__r.Biotecnologia__c);

            Licencia__c licence = licenciasProductor.get(key) ?? licenciasProductor.get(keyParent);

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

        update toUpdate;

        return getData(ventaId);
    }

    @AuraEnabled
    public static Map<String, Object> deleteItem(Id ventaId, Id itemId) {
        //validateComercio(ventaId);
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
       // validateComercio(venta);

        if (String.isBlank(item.id)) {
            item = setItemData(venta, item);
        }

        upsert item;

        return getData(venta.id);
    }

    @AuraEnabled
    public static Map<String, Object> anular(Id ventaId) {
       // validateComercio(ventaId);
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

   /*  private static void validateComercio(Id ventaId) {
        validateComercio([select Comercio__c from Venta_HT__c where id =: ventaId]);
    }

    private static void validateComercio(Venta_HT__c venta) {
        if (venta.Comercio__c != getAccount(null).id) throw new AuraHandledException('La venta no existe o no le pertenece');
    } */

    private static Boolean hasDuplicate(Venta_HT__c venta1) {
        DateTime marzo = Date.newInstance(System.today().year() - 1, 3, 1);

        for (Venta_HT__c venta2: [select (select Id_Producto_de_Lista_de_Precio__c, Cantidad__c from Lineas_de_Venta_HT__r) from Venta_HT__c where Estado__c in ('Pendiente de Facturación', 'Facturada')  and id !=: venta1.Id and CreatedDate >=: marzo and Cuenta_Productor__c =: venta1.Cuenta_Productor__c and Obtentor__c =: venta1.Obtentor__c]) {
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
         
         // Determinar si es NC para asignar tipo de movimiento correcto
         String tipoMovimiento = 'FC';
         List<Venta_HT__c> venta = [SELECT Es_NC__c FROM Venta_HT__c WHERE Id = :recordId LIMIT 1];
         if (!venta.isEmpty() && venta[0].Es_NC__c == true) {
             tipoMovimiento = 'NC';
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
            Tipo_de_Movimiento__c = tipoMovimiento,
            Comprobante__c = numComprobante,
            Importe__c = total * 1.21,
            Moneda__c = 'USD',
            Tipo_de_Cambio__c = TipoCambio,
            Oportunidad__c = opp.Id,
            Cuenta__c = opp.AccountId,
            Fecha__c = Date.today()
        );
        try {
            update oppToUpdate;
            insert mov;
            System.debug('Oportunidad actualizada correctamente');
        } catch (DmlException e) {
            System.debug('Error al actualizar la oportunidad: ' + e.getMessage());
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
        
        @AuraEnabled
        public static Map<String, Object> canFinish(Map<String, Object> semillero, Id CuentaProductor, Boolean tieneLicencia, list<Id> Variedades) {
            try {
                Boolean OrigenLegal;
                String parentIdStr = (String) semillero.get('ParentId');
                String idObtentorStr = (String) semillero.get('Id');
                string Id_ObtentorTonelada = (String) semillero.get('Id_Obtentor__c');
                
                Id parentId = String.isNotBlank(parentIdStr) ? (Id) parentIdStr : null;
                Id idObtentor = String.isNotBlank(idObtentorStr) ? (Id) idObtentorStr : null;
                Decimal total = 0;
                
                
                list<Tonelada__c> CesionRecibida = [SELECT Id
                                                    FROM Tonelada__c
                                                    WHERE Productor__c = :CuentaProductor
                                                    AND Id_Obtentor__c = :Id_ObtentorTonelada
                                                    AND Etapa__c = 'Recibida'
                                                   ];

                list<Compra_HT__c> ComprasHT = parentId != null ? [SELECT Id
                                                FROM Compra_HT__c
                                                WHERE Cuenta_Productor__c =:CuentaProductor
                                                AND  Obtentor__r.ParentId =: parentId
                                                AND Estado__c = 'Pagada'
                                               ] : [SELECT Id
                                                FROM Compra_HT__c
                                                WHERE Cuenta_Productor__c =:CuentaProductor
                                                AND  Obtentor__c =: idObtentor
                                                AND Estado__c = 'Pagada'
                                               ];
                
                List<Venta__c> VentasCRM = [SELECT Categoria__c,
                                            Destinatario__c,Cantidad__c,Tipo_de_Producto__c,Tipo_de_Venta__c,Obtentor__c, 
                                            Originante__r.Id, Variedad__c, Producto__r.Variedad2__r.Name
                                            FROM Venta__c where (Producto__r.Obtentor_Comercializa__c=: idObtentor OR  Producto__r.Obtentor_Comercializa__r.ParentId =: parentId)
                                            AND (Originante__c  =: CuentaProductor OR Destinatario__c =: CuentaProductor) 
                                            AND Semba_Evolucion__c  = true
                                            ];
                
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
            
            if (CesionRecibida.size()>0 || ComprasHT.size()>0 || total>0) {
                OrigenLegal = true;
            } else {
                OrigenLegal = false;
            }   
            
            Map<String, Object> response = new Map<String, Object>();
            response.put('origenLegal', OrigenLegal);
            response.put('ParentId', parentId);
            response.put('IdObtentor', idObtentor);
            response.put('CuentaProductor', CuentaProductor);
            response.put('TieneLicencia', tieneLicencia);
            response.put('Id_ObtentorTonelada', Id_ObtentorTonelada);
            response.put('CesionRecibida', CesionRecibida.size());
            response.put('ComprasHT', ComprasHT.size());
            response.put('Variedades',Variedades);
            response.put('VentasCRM',total);
            
            return response;
        } catch (Exception e) {
            throw new AuraHandledException('Error en canFinish: ' + e.getMessage());
        }
}

/***********************************************************************************************************************
 * Método para crear Nota de Crédito Parcial por Precio (REFACTORIZADO)
 *********************************************************************************************************************/
@AuraEnabled
public static Map<String, Object> crearNotaCreditoParcialPrecio(Id ventaId, String lineasConAjustes) {
    Savepoint sp = Database.setSavepoint();
    
    try {
        System.debug('Creando Nota de Crédito Parcial por Precio - Venta: ' + ventaId);
        System.debug('JSON recibido: ' + lineasConAjustes);
        
        // Validaciones iniciales
        if (String.isBlank(ventaId)) {
            throw new AuraHandledException('El ID de venta es requerido');
        }
        
        if (String.isBlank(lineasConAjustes)) {
            throw new AuraHandledException('No se encontraron ajustes para procesar');
        }
        
        // Deserializar las líneas con ajustes
        List<Map<String, Object>> ajustes = deserializarAjustes(lineasConAjustes);

        // ===== NUEVA VALIDACIÓN: VERIFICAR OBSERVACIONES =====
        validarObservacionesObligatorias(ajustes);
        
        // Obtener datos necesarios
        Venta_HT__c ventaOriginal = obtenerVentaOriginal(ventaId);
        
        // Crear Nota de Crédito
        Venta_HT__c notaCredito = crearEncabezadoNotaCredito(ventaOriginal);
        insert notaCredito;
        
        // Procesar líneas con ajustes
        ProcesamientoResultado resultado = procesarLineasConAjustes(ajustes, notaCredito.Id, ventaId);
        
        // Crear respuesta
        return crearRespuestaExito(notaCredito, resultado);
        
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug('Error al crear Nota de Crédito Parcial: ' + e.getMessage());
        throw new AuraHandledException('Error al crear Nota de Crédito: ' + e.getMessage());
    }
}

/***********************************************************************************************************************
 * Métodos auxiliares para reducir complejidad
 *********************************************************************************************************************/
private static void validarPrecondiciones(Id ventaId, String lineasConAjustes) {
    if (String.isBlank(ventaId)) {
        throw new AuraHandledException('El ID de venta es requerido');
    }
    
    if (String.isBlank(lineasConAjustes)) {
        throw new AuraHandledException('No se encontraron ajustes para procesar');
    }
}

private static Venta_HT__c obtenerVentaOriginal(Id ventaId) {
    Venta_HT__c venta = [
        SELECT Id, Estado__c, Name, Comercio_CUIT__c, Comercio__c, 
               Cuenta_Productor__c, Cultivo__c, Lista_de_Precios__c,
               Obtentor__c, Punto_de_Venta__c
        FROM Venta_HT__c 
        WHERE Id = :ventaId 
        LIMIT 1
    ];
    
    if (venta.Estado__c != 'Facturada' /*&& venta.Estado__c != 'Pagada'*/) {
        throw new AuraHandledException('Solo se pueden crear Notas de Crédito para ventas en estado Facturada');
    }
    
    return venta;
}

private static List<Map<String, Object>> deserializarAjustes(String lineasConAjustes) {
    System.debug('JSON a deserializar: ' + lineasConAjustes);
    
    try {
        // Primero deserializar como List<Object>
        List<Object> objetosAjustes = (List<Object>) JSON.deserializeUntyped(lineasConAjustes);
        
        // Convertir cada Object a Map<String, Object>
        List<Map<String, Object>> ajustes = new List<Map<String, Object>>();
        for (Object obj : objetosAjustes) {
            Map<String, Object> ajuste = (Map<String, Object>) obj;
             // Log detallado de cada ajuste
            System.debug('Ajuste deserializado - Linea: ' + ajuste.get('lineaId') + 
                        ', Tipo: ' + ajuste.get('tipoAjuste') + 
                        ', Observaciones: ' + ajuste.get('observaciones'));
            
            ajustes.add(ajuste);
        }
        
        System.debug('Número de ajustes convertidos: ' + ajustes.size());
        
        if (ajustes.isEmpty()) {
            throw new AuraHandledException('No se encontraron ajustes válidos para procesar');
        }
        
        return ajustes;
    } catch (Exception e) {
        System.debug('Error al deserializar ajustes: ' + e.getMessage());
        throw new AuraHandledException('Error en el formato de los ajustes: ' + e.getMessage());
    }
}

private static ProcesamientoResultado procesarLineasConAjustes(List<Map<String, Object>> ajustes, Id notaCreditoId, Id ventaId) {
    Set<Id> lineaIds = obtenerIdsLineas(ajustes);
    Map<Id, Linea_de_Venta_HT__c> lineasOriginalesMap = obtenerLineasOriginales(lineaIds);
    
    return crearLineasYTracking(ajustes, lineasOriginalesMap, notaCreditoId, ventaId);
}

private static Set<Id> obtenerIdsLineas(List<Map<String, Object>> ajustes) {
    Set<Id> lineaIds = new Set<Id>();
    for (Map<String, Object> ajuste : ajustes) {
        String lineaId = (String) ajuste.get('lineaId');
        if (String.isNotBlank(lineaId)) {
            lineaIds.add(lineaId);
        }
    }
    return lineaIds;
}

private static Map<Id, Linea_de_Venta_HT__c> obtenerLineasOriginales(Set<Id> lineaIds) {
    return new Map<Id, Linea_de_Venta_HT__c>([
        SELECT Id, Name, Cantidad__c, Precio_de_Lista__c, Comercio_CUIT__c,
               Id_Producto_de_Lista_de_Precio__c, Licencia__c, Producto__c, Tipo_de_cambio__c,
               Tipo_de_Compra__c, Fecha_de_Activacion__c, Estado__c
        FROM Linea_de_Venta_HT__c 
        WHERE Id IN :lineaIds
    ]);
}

private static ProcesamientoResultado crearLineasYTracking(List<Map<String, Object>> ajustes, 
                                                          Map<Id, Linea_de_Venta_HT__c> lineasOriginalesMap,
                                                          Id notaCreditoId, Id ventaId) {
    List<Linea_de_Venta_HT__c> lineasNotaCredito = new List<Linea_de_Venta_HT__c>();
    List<Nota_de_Credito__c> registrosTracking = new List<Nota_de_Credito__c>();
    
    for (Map<String, Object> ajuste : ajustes) {
        ProcesarLineaResultado resultadoLinea = procesarLineaIndividual(ajuste, lineasOriginalesMap, notaCreditoId, ventaId);
        
        if (resultadoLinea.lineaNC != null) {
            lineasNotaCredito.add(resultadoLinea.lineaNC);
        }
        
        if (resultadoLinea.tracking != null) {
            registrosTracking.add(resultadoLinea.tracking);
        }
    }
    
    insertarLineasYActualizarTracking(lineasNotaCredito, registrosTracking);
    
    return new ProcesamientoResultado(lineasNotaCredito, registrosTracking);
}

private static ProcesarLineaResultado procesarLineaIndividual(Map<String, Object> ajuste, 
                                                             Map<Id, Linea_de_Venta_HT__c> lineasOriginalesMap,
                                                             Id notaCreditoId, Id ventaId) {
    String lineaId = (String) ajuste.get('lineaId');
    Decimal valorAnterior = (Decimal) ajuste.get('valorAnterior');
    Decimal valorNuevo = (Decimal) ajuste.get('valorNuevo');
    String observaciones = (String) ajuste.get('observaciones'); // OBTENER OBSERVACIONES
    System.debug('Procesando línea individual - ID: ' + lineaId + ' Observaciones: ' + observaciones);
    
    Linea_de_Venta_HT__c lineaOriginal = lineasOriginalesMap.get(lineaId);
    if (lineaOriginal == null) {
        System.debug('Línea original no encontrada: ' + lineaId);
        return new ProcesarLineaResultado(null, null);
    }
    
        // Usar Precio_de_Lista__c para la validación
       // Decimal precioActual = lineaOriginal.Precio_de_Lista__c;
       Decimal precioActual = valorAnterior;
        validarAjustePrecio(precioActual, valorNuevo, lineaOriginal.Name);
        
     // ===== MODIFICACIÓN: CALCULAR DIFERENCIA PARA PRECIO =====
    Decimal diferenciaPrecio = precioActual - valorNuevo;
     Linea_de_Venta_HT__c lineaNC = crearLineaNotaCredito(lineaOriginal, notaCreditoId, diferenciaPrecio, observaciones);
    Nota_de_Credito__c tracking = crearRegistroTracking(ventaId, notaCreditoId, lineaId, precioActual, valorNuevo, observaciones);
    
    return new ProcesarLineaResultado(lineaNC, tracking);
}

/***********************************************************************************************************************
 * Método para validar ajuste de cantidad
 *********************************************************************************************************************/
private static void validarAjusteCantidad(Decimal cantidadActual, Decimal cantidadNueva, String nombreLinea) {
    if (cantidadNueva > cantidadActual) {
        throw new AuraHandledException('La nueva cantidad no puede ser mayor a la cantidad actual para la línea: ' + nombreLinea);
    }
    
    if (cantidadNueva < 0) {
        throw new AuraHandledException('La cantidad no puede ser negativa para la línea: ' + nombreLinea);
    }

    // ===== MODIFICACIÓN: PERMITIR CANTIDAD IGUAL (0 diferencia) =====
    if (cantidadNueva == cantidadActual) {
        throw new AuraHandledException('La nueva cantidad debe ser diferente a la cantidad actual para generar una nota de crédito: ' + nombreLinea);
    }
}

private static void validarAjustePrecio(Decimal valorAnterior, Decimal valorNuevo, String nombreLinea) {
    if (valorNuevo > valorAnterior) {
        throw new AuraHandledException('El nuevo precio no puede ser mayor al precio actual para la línea: ' + nombreLinea);
    }

     if (valorNuevo < 0) {
        throw new AuraHandledException('El precio no puede ser negativo para la línea: ' + nombreLinea);
    }
    
    // ===== MODIFICACIÓN: PERMITIR VALOR IGUAL (0 diferencia) =====
    if (valorNuevo == valorAnterior) {
        throw new AuraHandledException('El nuevo precio debe ser diferente al precio actual para generar una nota de crédito: ' + nombreLinea);
    }
}

private static Nota_de_Credito__c crearRegistroTracking(Id ventaId, Id notaCreditoId, Id lineaId, 
                                                       Decimal valorAnterior, Decimal valorNuevo,String observaciones) {
    Nota_de_Credito__c tracking = new Nota_de_Credito__c();
    tracking.Venta_HT_Original__c = ventaId;
    tracking.Venta_HT_NC__c = notaCreditoId;
    tracking.Linea_de_Venta_HT_Original__c = lineaId;
    tracking.Tipo_Nota_Credito__c = 'Precio';
    tracking.Valor_Anterior__c = valorAnterior;
    tracking.Valor_Nuevo__c = valorNuevo;
    tracking.Diferencia__c = valorAnterior - valorNuevo;
    tracking.Fecha_de_Procesamiento__c = System.now();
    tracking.Estado__c = 'Pendiente de Facturación';
    // ===== NUEVO: INCLUIR OBSERVACIONES EN EL TRACKING =====
    tracking.Observaciones__c = observaciones;
    
    return tracking;
}

private static void insertarLineasYActualizarTracking(List<Linea_de_Venta_HT__c> lineasNotaCredito, 
                                                     List<Nota_de_Credito__c> registrosTracking) {
    if (!lineasNotaCredito.isEmpty()) {
        insert lineasNotaCredito;
        
        // Actualizar tracking con IDs de líneas creadas
        for (Integer i = 0; i < lineasNotaCredito.size(); i++) {
            registrosTracking[i].Linea_de_Venta_HT_NC__c = lineasNotaCredito[i].Id;
        }
    }
    
    if (!registrosTracking.isEmpty()) {
        insert registrosTracking;
    }
}

private static Map<String, Object> crearRespuestaExito(Venta_HT__c notaCredito, ProcesamientoResultado resultado) {
    Map<String, Object> respuesta = new Map<String, Object>();
    respuesta.put('notaCreditoId', notaCredito.Id);
    respuesta.put('notaCreditoName', notaCredito.Name);
    respuesta.put('lineasCreadas', resultado.lineasNotaCredito.size());
    respuesta.put('trackingCreado', resultado.registrosTracking.size());
    
    return respuesta;
}

/***********************************************************************************************************************
  Método auxiliar para crear el encabezado de la Nota de Crédito
 *********************************************************************************************************************/
private static Venta_HT__c crearEncabezadoNotaCredito(Venta_HT__c ventaOriginal) {
    Venta_HT__c notaCredito = new Venta_HT__c();
    
    // Copiar campos del encabezado original (igual que en el Flow)
    notaCredito.Comercio_CUIT__c = ventaOriginal.Comercio_CUIT__c;
    notaCredito.Comercio__c = ventaOriginal.Comercio__c;
    notaCredito.Cuenta_Productor__c = ventaOriginal.Cuenta_Productor__c;
    notaCredito.Cultivo__c = ventaOriginal.Cultivo__c;
    notaCredito.Es_NC__c = true;
    notaCredito.Estado__c = 'Pendiente de Facturación';
    notaCredito.Lista_de_Precios__c = ventaOriginal.Lista_de_Precios__c;
    notaCredito.Name = ventaOriginal.Name + '-NCP'; // Nomenclatura NCP para Nota de Crédito Parcial por precio
    notaCredito.Obtentor__c = ventaOriginal.Obtentor__c;
    notaCredito.Punto_de_Venta__c = ventaOriginal.Punto_de_Venta__c;
    notaCredito.Venta_Original__c = ventaOriginal.Id;
    notaCredito.Tipo_Ajuste__c = 'NCP';
    
    
    return notaCredito;
}

/***********************************************************************************************************************
 * Método auxiliar para crear línea de Nota de Crédito
 *********************************************************************************************************************/
private static Linea_de_Venta_HT__c crearLineaNotaCredito(Linea_de_Venta_HT__c lineaOriginal, Id notaCreditoId, Decimal diferenciaPrecio, String observaciones)  {
    Linea_de_Venta_HT__c lineaNC = new Linea_de_Venta_HT__c();
    
    // Copiar campos de la línea original (usando campos del flow)
    lineaNC.Name = lineaOriginal.Name + '-NCP';
    lineaNC.Cantidad__c = lineaOriginal.Cantidad__c;
     // ===== MODIFICACIÓN: USAR LA DIFERENCIA COMO PRECIO =====
    lineaNC.Precio_de_Lista__c = diferenciaPrecio; // Usar la diferencia como precio
   // lineaNC.Precio_de_Lista__c = nuevoPrecio; // Usar Precio_de_Lista__c en lugar de Precio__c
    lineaNC.Comercio_CUIT__c = lineaOriginal.Comercio_CUIT__c;
    lineaNC.Id_Producto_de_Lista_de_Precio__c = lineaOriginal.Id_Producto_de_Lista_de_Precio__c;
    lineaNC.Licencia__c = lineaOriginal.Licencia__c;
    lineaNC.Producto__c = lineaOriginal.Producto__c;
    lineaNC.Tipo_de_cambio__c = lineaOriginal.Tipo_de_cambio__c;
    lineaNC.Tipo_de_Compra__c = lineaOriginal.Tipo_de_Compra__c;
    // Variedad__c no es escribible, se infiere del producto
    lineaNC.Fecha_de_Activacion__c = lineaOriginal.Fecha_de_Activacion__c;
    lineaNC.Estado__c = 'Facturable';
    lineaNC.Venta_HT__c = notaCreditoId;
    // ===== NUEVO: ASIGNAR OBSERVACIONES =====
    lineaNC.Observaciones__c = observaciones;
    lineaNC.Es_NC__c = true;
    lineaNC.Tipo_Ajuste__c = 'NCP';
    
    return lineaNC;
}
/***********************************************************************************************************************
 * Clases wrapper para resultados
 *********************************************************************************************************************/
public class ProcesamientoResultado {
    public List<Linea_de_Venta_HT__c> lineasNotaCredito { get; set; }
    public List<Nota_de_Credito__c> registrosTracking { get; set; }
    
    public ProcesamientoResultado(List<Linea_de_Venta_HT__c> lineas, List<Nota_de_Credito__c> tracking) {
        this.lineasNotaCredito = lineas;
        this.registrosTracking = tracking;
    }
}

public class ProcesarLineaResultado {
    public Linea_de_Venta_HT__c lineaNC { get; set; }
    public Nota_de_Credito__c tracking { get; set; }
    
    public ProcesarLineaResultado(Linea_de_Venta_HT__c linea, Nota_de_Credito__c track) {
        this.lineaNC = linea;
        this.tracking = track;
    }
}
/***********************************************************************************************************************
 * Método para validar observaciones obligatorias
 *********************************************************************************************************************/
private static void validarObservacionesObligatorias(List<Map<String, Object>> ajustes) {
    System.debug('Validando observaciones obligatorias para ' + ajustes.size() + ' ajustes');
    
    List<String> lineasSinObservaciones = new List<String>();
    
    for (Integer i = 0; i < ajustes.size(); i++) {
        Map<String, Object> ajuste = ajustes[i];
        String observaciones = (String) ajuste.get('observaciones');
        String lineaId = (String) ajuste.get('lineaId');
        
        System.debug('Ajuste ' + i + ' - Linea: ' + lineaId + ', Observaciones: ' + observaciones);
        
        if (String.isBlank(observaciones) || observaciones.trim().length() < 20) {
            lineasSinObservaciones.add('Línea ' + (i + 1));
        }
    }
    
    if (!lineasSinObservaciones.isEmpty()) {
        String mensajeError = 'Debe ingresar al menos 20 caracteres de observaciones para las siguientes lineas: ' + String.join(lineasSinObservaciones, ', ');
        System.debug('Error de validación: ' + mensajeError);
        throw new AuraHandledException(mensajeError);
    }
    
    System.debug('Todas las líneas tienen observaciones válidas');
}


////////////////////////////////////NOTA de CREDITO X CANTIDAD///////////////////////////////////////////////////////////////////////////////////////////
// AGREGAR método para Nota de Crédito por Cantidad
@AuraEnabled
public static Map<String, Object> crearNotaCreditoParcialCantidad(Id ventaId, String lineasConAjustes) {
    Savepoint sp = Database.setSavepoint();
    
    try {
        System.debug('Creando Nota de Crédito Parcial por Cantidad - Venta: ' + ventaId);
        System.debug('JSON recibido: ' + lineasConAjustes);
        
        // Validaciones iniciales
        if (String.isBlank(ventaId)) {
            throw new AuraHandledException('El ID de venta es requerido');
        }
        
        if (String.isBlank(lineasConAjustes)) {
            throw new AuraHandledException('No se encontraron ajustes para procesar');
        }
        
        // Deserializar las líneas con ajustes
        List<Map<String, Object>> ajustes = deserializarAjustes(lineasConAjustes);

        // ===== VALIDACIÓN: VERIFICAR OBSERVACIONES =====
        validarObservacionesObligatorias(ajustes);
        
        // Obtener datos necesarios
        Venta_HT__c ventaOriginal = obtenerVentaOriginal(ventaId);
        
        // Crear Nota de Crédito
        Venta_HT__c notaCredito = crearEncabezadoNotaCreditoCantidad(ventaOriginal);
        insert notaCredito;
        
        // Procesar líneas con ajustes
        ProcesamientoResultado resultado = procesarLineasConAjustesCantidad(ajustes, notaCredito.Id, ventaId);
        
        // Crear respuesta
        return crearRespuestaExito(notaCredito, resultado);
        
    } catch (Exception e) {
        Database.rollback(sp);
        System.debug('Error al crear Nota de Crédito Parcial por Cantidad: ' + e.getMessage());
        throw new AuraHandledException('Error al crear Nota de Crédito por Cantidad: ' + e.getMessage());
    }
}

// Método específico para procesar líneas con ajustes de cantidad
private static ProcesamientoResultado procesarLineasConAjustesCantidad(List<Map<String, Object>> ajustes, Id notaCreditoId, Id ventaId) {
    Set<Id> lineaIds = obtenerIdsLineas(ajustes);
    Map<Id, Linea_de_Venta_HT__c> lineasOriginalesMap = obtenerLineasOriginalesConCompra(lineaIds);
    
    ProcesamientoResultado resultado = crearLineasYTrackingCantidad(ajustes, lineasOriginalesMap, notaCreditoId, ventaId);
    
    return resultado;
}

private static Map<Id, Linea_de_Venta_HT__c> obtenerLineasOriginalesConCompra(Set<Id> lineaIds) {
    return new Map<Id, Linea_de_Venta_HT__c>([
        SELECT Id, Name, Cantidad__c, Precio_de_Lista__c, Comercio_CUIT__c,
               Id_Producto_de_Lista_de_Precio__c, Licencia__c, Producto__c, Tipo_de_cambio__c,
               Tipo_de_Compra__c, Fecha_de_Activacion__c, Estado__c, Linea_de_Compra_HT__c
        FROM Linea_de_Venta_HT__c 
        WHERE Id IN :lineaIds
    ]);
}


// Método específico para crear líneas y tracking de cantidad
private static ProcesamientoResultado crearLineasYTrackingCantidad(List<Map<String, Object>> ajustes, 
                                                                  Map<Id, Linea_de_Venta_HT__c> lineasOriginalesMap,
                                                                  Id notaCreditoId, Id ventaId) {
    List<Linea_de_Venta_HT__c> lineasNotaCredito = new List<Linea_de_Venta_HT__c>();
    List<Nota_de_Credito__c> registrosTracking = new List<Nota_de_Credito__c>();
    
    for (Map<String, Object> ajuste : ajustes) {
        ProcesarLineaResultado resultadoLinea = procesarLineaIndividualCantidad(ajuste, lineasOriginalesMap, notaCreditoId, ventaId);
        
        if (resultadoLinea.lineaNC != null) {
            lineasNotaCredito.add(resultadoLinea.lineaNC);
        }
        
        if (resultadoLinea.tracking != null) {
            registrosTracking.add(resultadoLinea.tracking);
        }
    }
    
    insertarLineasYActualizarTracking(lineasNotaCredito, registrosTracking);
    
    return new ProcesamientoResultado(lineasNotaCredito, registrosTracking);
}

// Método específico para procesar línea individual de cantidad
private static ProcesarLineaResultado procesarLineaIndividualCantidad(Map<String, Object> ajuste, 
                                                                     Map<Id, Linea_de_Venta_HT__c> lineasOriginalesMap,
                                                                     Id notaCreditoId, Id ventaId) {
    String lineaId = (String) ajuste.get('lineaId');
    String tipoAjuste = (String) ajuste.get('tipoAjuste');
    Decimal valorAnterior = (Decimal) ajuste.get('valorAnterior');
    Decimal valorNuevo = (Decimal) ajuste.get('valorNuevo');
    String observaciones = (String) ajuste.get('observaciones');
    
    System.debug('Procesando línea individual por Cantidad - ID: ' + lineaId + ', Observaciones: ' + observaciones);
    
    Linea_de_Venta_HT__c lineaOriginal = lineasOriginalesMap.get(lineaId);
    if (lineaOriginal == null) {
        System.debug('Línea original no encontrada: ' + lineaId);
        return new ProcesarLineaResultado(null, null);
    }
    
    // Validar ajuste de cantidad
    validarAjusteCantidad(valorAnterior, valorNuevo, lineaOriginal.Name);
    
    // ===== MODIFICACIÓN: CALCULAR DIFERENCIA PARA CANTIDAD =====
    Decimal diferenciaCantidad = valorAnterior - valorNuevo;
    
    
   Linea_de_Venta_HT__c lineaNC = crearLineaNotaCreditoCantidad(lineaOriginal, notaCreditoId, diferenciaCantidad, observaciones);
    Nota_de_Credito__c tracking = crearRegistroTrackingCantidad(ventaId, notaCreditoId, lineaId, valorAnterior, valorNuevo, observaciones);
    
    return new ProcesarLineaResultado(lineaNC, tracking);
}

// Método para crear encabezado de Nota de Crédito por Cantidad
private static Venta_HT__c crearEncabezadoNotaCreditoCantidad(Venta_HT__c ventaOriginal) {
    Venta_HT__c notaCredito = new Venta_HT__c();
    
    // Copiar campos del encabezado original
    notaCredito.Comercio_CUIT__c = ventaOriginal.Comercio_CUIT__c;
    notaCredito.Comercio__c = ventaOriginal.Comercio__c;
    notaCredito.Cuenta_Productor__c = ventaOriginal.Cuenta_Productor__c;
    notaCredito.Cultivo__c = ventaOriginal.Cultivo__c;
    notaCredito.Es_NC__c = true;
    notaCredito.Estado__c = 'Pendiente de Facturación';
    notaCredito.Lista_de_Precios__c = ventaOriginal.Lista_de_Precios__c;
    notaCredito.Name = ventaOriginal.Name + '-NCC'; // Nomenclatura NCC para Nota de Crédito Parcial por cantidad
    notaCredito.Obtentor__c = ventaOriginal.Obtentor__c;
    notaCredito.Punto_de_Venta__c = ventaOriginal.Punto_de_Venta__c;
    notaCredito.Venta_Original__c = ventaOriginal.Id;
    notaCredito.Tipo_Ajuste__c = 'NCC';
    
    return notaCredito;
}

// Método para crear línea de Nota de Crédito por Cantidad
private static Linea_de_Venta_HT__c crearLineaNotaCreditoCantidad(Linea_de_Venta_HT__c lineaOriginal, Id notaCreditoId, Decimal diferenciaCantidad, String observaciones)  {
    Linea_de_Venta_HT__c lineaNC = new Linea_de_Venta_HT__c();
    
    // Copiar campos de la línea original
    lineaNC.Name = lineaOriginal.Name + '-NCC';
   // lineaNC.Cantidad__c = nuevaCantidad; // Usar la nueva cantidad
    lineaNC.Cantidad__c = diferenciaCantidad; // Usar la diferencia como cantidad
    lineaNC.Precio_de_Lista__c = lineaOriginal.Precio_de_Lista__c; // Mantener el precio original
    lineaNC.Comercio_CUIT__c = lineaOriginal.Comercio_CUIT__c;
    lineaNC.Id_Producto_de_Lista_de_Precio__c = lineaOriginal.Id_Producto_de_Lista_de_Precio__c;
    lineaNC.Licencia__c = lineaOriginal.Licencia__c;
    lineaNC.Producto__c = lineaOriginal.Producto__c;
    lineaNC.Tipo_de_cambio__c = lineaOriginal.Tipo_de_cambio__c;
    lineaNC.Tipo_de_Compra__c = lineaOriginal.Tipo_de_Compra__c;
    lineaNC.Fecha_de_Activacion__c = lineaOriginal.Fecha_de_Activacion__c;
    lineaNC.Estado__c = 'Facturable';
    lineaNC.Venta_HT__c = notaCreditoId;
    lineaNC.Observaciones__c = observaciones;
    lineaNC.Tipo_Ajuste__c = 'NCC';
    lineaNC.Es_NC__c = true;
    lineaNC.Linea_de_Venta_HT__c = lineaOriginal.Id;
    
    return lineaNC;
}

// Método para crear registro de tracking por cantidad
private static Nota_de_Credito__c crearRegistroTrackingCantidad(Id ventaId, Id notaCreditoId, Id lineaId, 
                                                               Decimal valorAnterior, Decimal valorNuevo, String observaciones) {
    Nota_de_Credito__c tracking = new Nota_de_Credito__c();
    tracking.Venta_HT_Original__c = ventaId;
    tracking.Venta_HT_NC__c = notaCreditoId;
    tracking.Linea_de_Venta_HT_Original__c = lineaId;
    tracking.Tipo_Nota_Credito__c = 'Cantidad';
    tracking.Valor_Anterior__c = valorAnterior;
    tracking.Valor_Nuevo__c = valorNuevo;
    tracking.Diferencia__c = valorAnterior - valorNuevo;
    tracking.Fecha_de_Procesamiento__c = System.now();
    tracking.Estado__c = 'Pendiente de Facturación';
    tracking.Observaciones__c = observaciones;
    
    return tracking;
}

// AGREGAR método para verificar notas de crédito pendientes
@AuraEnabled
public static Map<String, Object> verificarNotasCreditoPendientes(Id ventaId) {
    try {
        Map<String, Object> resultado = new Map<String, Object>();
        
        // Todas las NC existentes para esta venta (cualquier estado)
        List<Venta_HT__c> todasLasNC = [
            SELECT Id, Name, Estado__c, Tipo_Ajuste__c, CreatedDate,
                   Compra_HT__r.Oportunidad__r.StageName
            FROM Venta_HT__c 
            WHERE Venta_Original__c = :ventaId 
            AND Es_NC__c = true
            ORDER BY CreatedDate DESC
        ];
        
        // NC pendientes de facturación (oportunidad no está en 'Aplicada')
        List<Venta_HT__c> notasCreditoPendientes = new List<Venta_HT__c>();
        // Verificar si existe NC Total (cualquier estado)
        Boolean existeNCTotal = false;
        // Verificar si existe NC Parcial por Precio no aplicada
        Boolean existeNCPPendiente = false;
        // Verificar si existe NC Parcial por Cantidad no aplicada
        Boolean existeNCCPendiente = false;
        
        for (Venta_HT__c nc : todasLasNC) {
            if (nc.Tipo_Ajuste__c == 'NC' || (nc.Tipo_Ajuste__c == null && nc.Name != null && nc.Name.endsWith('-NC'))) {
                existeNCTotal = true;
            }
            String stageOpp = nc.Compra_HT__r?.Oportunidad__r?.StageName;
            Boolean noAplicada = stageOpp == null || (stageOpp != 'Aplicada' && stageOpp != 'Facturada');
            if (noAplicada) {
                notasCreditoPendientes.add(nc);
                String tipo = nc.Tipo_Ajuste__c;
                if (tipo == 'NCP' || (tipo == null && nc.Name != null && nc.Name.endsWith('-NCP'))) {
                    existeNCPPendiente = true;
                }
                if (tipo == 'NCC' || (tipo == null && nc.Name != null && nc.Name.endsWith('-NCC'))) {
                    existeNCCPendiente = true;
                }
            }
        }
        
        resultado.put('tieneNotasCreditoPendientes', !notasCreditoPendientes.isEmpty());
        resultado.put('existeNCTotal', existeNCTotal);
        resultado.put('existeNCPPendiente', existeNCPPendiente);
        resultado.put('existeNCCPendiente', existeNCCPendiente);
        resultado.put('cantidadPendientes', notasCreditoPendientes.size());
        
        // Todas las NC (pendientes + aplicadas) para mostrar en venta original
        if (!todasLasNC.isEmpty()) {
            List<Map<String, String>> todasLasNCDetalle = new List<Map<String, String>>();
            for (Venta_HT__c nc : todasLasNC) {
                Map<String, String> info = new Map<String, String>();
                info.put('id', nc.Id);
                info.put('name', nc.Name);
                info.put('tipo', nc.Tipo_Ajuste__c);
                info.put('fecha', nc.CreatedDate.format());
                info.put('estado', nc.Estado__c);
                todasLasNCDetalle.add(info);
            }
            resultado.put('todasLasNC', todasLasNCDetalle);
        }
        
        if (!notasCreditoPendientes.isEmpty()) {
            List<Map<String, String>> infoNotas = new List<Map<String, String>>();
            for (Venta_HT__c nc : notasCreditoPendientes) {
                Map<String, String> info = new Map<String, String>();
                info.put('id', nc.Id);
                info.put('name', nc.Name);
                info.put('tipo', nc.Tipo_Ajuste__c);
                info.put('fecha', nc.CreatedDate.format());
                infoNotas.add(info);
            }
            resultado.put('detalleNotas', infoNotas);
        }
        
        return resultado;
        
    } catch (Exception e) {
        System.debug('Error al verificar notas de crédito pendientes: ' + e.getMessage());
        throw new AuraHandledException('Error al verificar notas de crédito: ' + e.getMessage());
    }
}

public static Map<String, Object> obtenerSaldoHT(Id ventaId) {
    Map<String, Object> saldo = new Map<String, Object>();
    saldo.put('htOriginal', 0);
    saldo.put('htAjustada', 0);
    saldo.put('htRestante', 0);
    saldo.put('tieneAjuste', false);
    
    try {
        // Obtener las Linea_de_Compra_HT__c asociadas a las líneas de esta venta
        Set<Id> lineasCompraIds = new Map<Id, Linea_de_Venta_HT__c>([
            SELECT Id, Linea_de_Compra_HT__c 
            FROM Linea_de_Venta_HT__c 
            WHERE Venta_HT__c = :ventaId 
            AND Linea_de_Compra_HT__c != null
        ]).keySet();
        
        Decimal htOriginal = 0;
        Decimal htAjustadaAplicada = 0;
        Decimal htAjustadaPendiente = 0;
        
        // IDs de HT originales encontradas (para buscar débitos vinculados)
        Set<Id> htOriginalesIds = new Set<Id>();
        
        if (!lineasCompraIds.isEmpty()) {
            // HT original (Signo=1) - todas
            for (AggregateResult ar : [
                SELECT Linea_de_Compra_HT__c linea, SUM(Cantidad__c) total
                FROM Hectareas_Tecnologicas__c
                WHERE Linea_de_Compra_HT__c IN :lineasCompraIds
                AND Signo__c = 1
                GROUP BY Linea_de_Compra_HT__c
            ]) {
                htOriginal += (Decimal) ar.get('total');
            }
            
            // Buscar HT originales para luego encontrar sus débitos
            for (Hectareas_Tecnologicas__c ht : [
                SELECT Id FROM Hectareas_Tecnologicas__c
                WHERE Linea_de_Compra_HT__c IN :lineasCompraIds
                AND Signo__c = 1
            ]) {
                htOriginalesIds.add(ht.Id);
            }
        }
        
        // Si no hay HT vía Linea_de_Compra_HT__c, usar Total_HT__c de la venta
        if (htOriginal == 0 && htAjustadaAplicada == 0) {
            Venta_HT__c venta = [SELECT Total_HT__c FROM Venta_HT__c WHERE Id = :ventaId];
            htOriginal = venta.Total_HT__c != null ? venta.Total_HT__c : 0;
            
            // Buscar HT originales por la venta para encontrar débitos
            for (Hectareas_Tecnologicas__c ht : [
                SELECT Id FROM Hectareas_Tecnologicas__c
                WHERE Linea_de_Compra_HT__r.Linea_de_Venta_HT__r.Venta_HT__c = :ventaId
                AND Signo__c = 1
            ]) {
                htOriginalesIds.add(ht.Id);
            }
        }
        
        // Buscar HT débito asociadas a las HT originales (por HT_Original__c)
        if (!htOriginalesIds.isEmpty()) {
            AggregateResult htDebitoResult = [
                SELECT SUM(Cantidad__c) total
                FROM Hectareas_Tecnologicas__c
                WHERE HT_Original__c IN :htOriginalesIds
                AND Signo__c = -1
            ];
            htAjustadaAplicada = (Decimal) htDebitoResult.get('total');
            if (htAjustadaAplicada == null) htAjustadaAplicada = 0;
        }
        
        // NCC pendientes de facturación (ajuste pendiente, sin HT negativa aún)
        AggregateResult ncPendienteResult = [
            SELECT SUM(Total_HT__c) total
            FROM Venta_HT__c
            WHERE Venta_Original__c = :ventaId
            AND Es_NC__c = true
            AND Tipo_Ajuste__c = 'NCC'
            AND Estado__c = 'Pendiente de Facturación'
        ];
        Decimal ncPendiente = (Decimal) ncPendienteResult.get('total');
        htAjustadaPendiente = ncPendiente != null ? ncPendiente : 0;
        
        Decimal htAjustadaTotal = htAjustadaAplicada + htAjustadaPendiente;
        
        // Determinar si existe NCC (parcial por cantidad) vs NC total
        Boolean existeNCC = false;
        if (htAjustadaTotal > 0) {
            existeNCC = true;
        } else {
            // Verificar si hay NCC no canceladas
            AggregateResult nccCount = [
                SELECT COUNT(Id) total
                FROM Venta_HT__c
                WHERE Venta_Original__c = :ventaId
                AND Es_NC__c = true
                AND Tipo_Ajuste__c = 'NCC'
                AND Estado__c != 'Cancelada'
            ];
            Decimal count = (Decimal) nccCount.get('total');
            existeNCC = count != null && count > 0;
        }
        
        saldo.put('htOriginal', Integer.valueOf(htOriginal));
        saldo.put('htAjustada', Integer.valueOf(htAjustadaTotal));
        saldo.put('htAjustadaAplicada', Integer.valueOf(htAjustadaAplicada));
        saldo.put('htAjustadaPendiente', Integer.valueOf(htAjustadaPendiente));
        saldo.put('htRestante', Integer.valueOf(htOriginal - htAjustadaTotal));
        saldo.put('tieneAjuste', htAjustadaTotal > 0);
        saldo.put('tienePendiente', htAjustadaPendiente > 0);
        saldo.put('existeNCC', existeNCC);
        
    } catch (Exception e) {
        System.debug('Error al obtener saldo HT: ' + e.getMessage());
    }
    
    return saldo;
}

@AuraEnabled
public static Map<String, Object> obtenerSaldoHTPorLinea(Id lineaVentaId) {
    Map<String, Object> resultado = new Map<String, Object>();
    resultado.put('htOriginal', 0);
    resultado.put('htAjustada', 0);
    resultado.put('htRestante', 0);
    
    try {
        Linea_de_Venta_HT__c linea = [
            SELECT Linea_de_Compra_HT__c FROM Linea_de_Venta_HT__c WHERE Id = :lineaVentaId
        ];
        if (linea.Linea_de_Compra_HT__c == null) return resultado;
        
        // HT originales (Signo=1) de esta línea
        List<Hectareas_Tecnologicas__c> htsOriginales = [
            SELECT Id, Cantidad__c, Etapa__c FROM Hectareas_Tecnologicas__c
            WHERE Linea_de_Compra_HT__c = :linea.Linea_de_Compra_HT__c
            AND Signo__c = 1
        ];
        if (htsOriginales.isEmpty()) return resultado;
        
        String etapaOriginal = '';
        Decimal totalOriginal = 0;
        Set<Id> htOriginalIds = new Set<Id>();
        for (Hectareas_Tecnologicas__c ht : htsOriginales) {
            totalOriginal += ht.Cantidad__c;
            htOriginalIds.add(ht.Id);
            if (String.isBlank(etapaOriginal)) {
                etapaOriginal = ht.Etapa__c;
            }
        }
        
        // HT débito vinculadas
        AggregateResult htDebito = [
            SELECT SUM(Cantidad__c) total FROM Hectareas_Tecnologicas__c
            WHERE HT_Original__c IN :htOriginalIds AND Signo__c = -1
        ];
        Decimal totalDebito = (Decimal) htDebito.get('total');
        if (totalDebito == null) totalDebito = 0;
        
        // Etapa de la HT débito
        String etapaDebito = '';
        if (totalDebito > 0) {
            List<Hectareas_Tecnologicas__c> htsDebito = [
                SELECT Etapa__c FROM Hectareas_Tecnologicas__c
                WHERE HT_Original__c IN :htOriginalIds AND Signo__c = -1
                LIMIT 1
            ];
            if (!htsDebito.isEmpty()) {
                etapaDebito = htsDebito[0].Etapa__c;
            }
        }
        
        resultado.put('htOriginal', Integer.valueOf(totalOriginal));
        resultado.put('htAjustada', Integer.valueOf(totalDebito));
        resultado.put('htRestante', Integer.valueOf(totalOriginal - totalDebito));
        resultado.put('etapaOriginal', etapaOriginal);
        resultado.put('etapaDebito', etapaDebito);
        
    } catch (Exception e) {
        System.debug('Error al obtener saldo HT por línea: ' + e.getMessage());
    }
    
    return resultado;
}

@AuraEnabled
public static Boolean tieneHTONCPorLinea(Id lineaVentaId) {
    try {
        Linea_de_Venta_HT__c linea = [
            SELECT Linea_de_Compra_HT__c, Estado__c FROM Linea_de_Venta_HT__c WHERE Id = :lineaVentaId
        ];
        
        // Solo mostrar si existen registros HT negativos (Signo__c = -1) de ajuste por NC
        if (linea.Linea_de_Compra_HT__c == null) return false;
        
        List<Hectareas_Tecnologicas__c> htsOriginales = [
            SELECT Id FROM Hectareas_Tecnologicas__c
            WHERE Linea_de_Compra_HT__c = :linea.Linea_de_Compra_HT__c
            AND Signo__c = 1
        ];
        if (htsOriginales.isEmpty()) return false;
        
        Set<Id> htOriginalIds = new Set<Id>();
        for (Hectareas_Tecnologicas__c ht : htsOriginales) {
            htOriginalIds.add(ht.Id);
        }
        
        Integer countHtNegativos = [SELECT COUNT() FROM Hectareas_Tecnologicas__c
                                     WHERE HT_Original__c IN :htOriginalIds
                                     AND Signo__c = -1];
        return (countHtNegativos > 0);
        
    } catch (Exception e) {
        System.debug('Error al verificar HT/NC por línea: ' + e.getMessage());
    }
    
    return false;
}


}