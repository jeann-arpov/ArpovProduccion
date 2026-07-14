public without sharing class ConfiguracionFacturacion {

    @AuraEnabled
    public static Map<String, Object> getData(Boolean isFirstLoad){
        Map<String, Object> data = new Map<String, Object>();

        Account account = CrearCompraController.getAccount();

        if(isFirstLoad){
            data.put('marcas', getMarcasOptions());
            data.put('cuenta', account);
        }
        
        data.put('cuentasPv', [SELECT Id, Cuenta__c, Cuenta__r.Name, Cuenta__r.N_CUIT__c, Cuenta__r.RecordType.Developername, Marca__c, Marca__r.Nombre_Obtentor__c, Punto_de_Venta__c, LastModifiedDate FROM Punto_de_Venta__c WHERE Punto_de_Venta__c = true AND (Obtentor_Comercializa__c = :account.Id OR Obtentor_Comercializa__r.ParentId = :account.Id)]);

        return data;
    }

    @AuraEnabled
    public static void doSave(String cuentaId, String marcaId){
        Punto_de_Venta__c config = createPuntoDeVenta(cuentaId, marcaId);
        insert config;
    }

    @AuraEnabled
    public static void doDelete(String pvConfigId){
        delete [SELECT Id FROM Punto_de_Venta__c WHERE Id = :pvConfigId];
    }
    
    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchAccounts(String searchTerm, List<String> selectedIds) {
        String safeTerm = String.escapeSingleQuotes(searchTerm);
        String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(searchTerm);
        String cuitCondition = String.isNotBlank(normalizedCuitTerm)
            ? ' or N_CUIT__c like \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\''
            : '';
        return CrearVentaController.accountsToLookup(Database.query(
            'select RecordType.DeveloperName, Name, N_CUIT__c, Owner.Name, Operador_de_Cobranza__r.Name, Provincia_Envio__c, Phone ' +
            'from account where (name like \'%' + safeTerm + '%\'' + cuitCondition + ') ' +
            'and recordType.DeveloperName in (\'Productor\', \'Distribuidor\') and ParentId = null limit 5'
        ));
    }

    public static Punto_de_Venta__c createPuntoDeVenta(String cuentaId, String marcaId){
        Punto_de_Venta__c pv = new Punto_de_Venta__c();
        pv.Cuenta__c = cuentaId;
        pv.Marca__c = marcaId;

        return pv;
    }

    private static List<Map<String, String>> getMarcasOptions(){
        List<Map<String,String>> options = new List<Map<String,String>>();
        Account cuenta = CrearCompraController.getAccount();

        String cuitCorteva = UtilsAccount.getCuitCorteva();
        for(Account marca : [SELECT Id, Nombre_Obtentor__c, N_CUIT__c, ParentId FROM Account WHERE Id = :cuenta.Id OR ParentId = :cuenta.Id]){
            if(marca.N_CUIT__c != cuitCorteva || marca.ParentId != null){
                options.add(new Map<String, String>{'value' => marca.Id, 'label' => marca.Nombre_Obtentor__c});
            }
        }

        return options;
    }
}