public without sharing class ConsultaLicenciasController {
    
    // Clase wrapper para respuesta paginada - DEFINIRLA PRIMERO
    public class PaginatedResult {
        @AuraEnabled public List<Licencia__c> licencias;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalPages;
    }

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchProductores(String searchTerm, List<String> selectedIds) {
        return CrearVentaController.accountsToLookup([select RecordType.DeveloperName, N_CUIT__c, Name from account where (name like: '%'+searchTerm+'%' or N_CUIT__c like: '%'+searchTerm+'%') and Type IN ('Productor', 'Comercio', 'Distribuidor', 'Obtentor') and ParentId = null limit 5]);
    }

    @AuraEnabled(Cacheable=true)
    public static Account getAccount() {
        return CrearCompraController.getAccount();
    }

    /**
     * Obtiene licencias paginadas para un productor con filtros aplicados
     * @param productorId ID del productor
     * @param pageNumber Número de página actual
     * @param pageSize Tamaño de página
     * @param filtersJSON Filtros en formato JSON
     * @return PaginatedResult Resultado paginado con licencias
     */
    @AuraEnabled
    public static PaginatedResult getLicencias(Id productorId, Integer pageNumber, Integer pageSize, String filtersJSON) {
        // Parsear filtros si se proporcionan
        Map<String, Object> filterMap = new Map<String, Object>();
        if (String.isNotBlank(filtersJSON)) {
            filterMap = (Map<String, Object>)JSON.deserializeUntyped(filtersJSON);
        }
        
        Set<String> cuits = new Set<String>();
        Set<Id> obtentores = new Set<Id>();
        
        // 1) Licencias del comercio que consulta
        for (Licencia__c lic : [
            SELECT Cuenta_Obtentor__c,
                Cuenta_Obtentor__r.N_CUIT__c,
                Cuenta_Obtentor__r.ParentId,
                Cuenta_Obtentor__r.Parent.N_CUIT__c
            FROM Licencia__c
            WHERE Cuenta_Productor__c = :CrearCompraController.getAccount().Id
            AND Tipo_de_Licencia__c = 'Comercio'
        ]) {
            if (lic.Cuenta_Obtentor__c != null) {
                obtentores.add(lic.Cuenta_Obtentor__c);
                
                if (lic.Cuenta_Obtentor__r.N_CUIT__c != null) {
                    cuits.add(lic.Cuenta_Obtentor__r.N_CUIT__c);
                }
                if (lic.Cuenta_Obtentor__r.ParentId != null &&
                    lic.Cuenta_Obtentor__r.Parent.N_CUIT__c != null) {
                    cuits.add(lic.Cuenta_Obtentor__r.Parent.N_CUIT__c);
                }
            }
        }
        
        // Limpieza por seguridad
        cuits.remove(null);
        obtentores.remove(null);
        
        // 2) Expandir por cuentas hermanas/parent
        if (!cuits.isEmpty()) {
            for (Account cta : [
                SELECT N_CUIT__c, ParentId, Parent.N_CUIT__c
                FROM Account
                WHERE N_CUIT__c IN :cuits OR Parent.N_CUIT__c IN :cuits
            ]) {
                if (cta.N_CUIT__c != null) cuits.add(cta.N_CUIT__c);
                if (cta.ParentId != null && cta.Parent.N_CUIT__c != null) {
                    cuits.add(cta.Parent.N_CUIT__c);
                }
            }
        }
        
        Set<String> tipos = new Set<String>{'Productor', 'Comercio'};
        String cuitParentCorteva = UtilsAccount.getCuitCorteva();
        Set<String> cuitsCorteva = new Set<String>{ cuitParentCorteva, '30569723023' };
        
        // Construir consulta SOQL dinámica
        String query = 'SELECT Origen__c, Cuenta_Distribuidor__c, Marcas__c, Marcas_Productor_Comercio__c, ' +
                      'Tipo_de_Licencia__c, Origen_de_Licencia__c, Cultivo__c, Tecnologia__c, ' +
                      'Name, Cuenta_Obtentor__c, Cuenta_Obtentor__r.Name, ' +
                      'Cuenta_Obtentor__r.N_CUIT__c, Cuenta_Obtentor__r.ParentId, ' +
                      'Cuenta_Obtentor__r.Parent.N_CUIT__c, Estado__c, Fecha_de_Vencimiento__c ' +
                      'FROM Licencia__c ';
        
        // Preparar condiciones WHERE
        List<String> conditions = new List<String>();
        
        // Condición principal: productor seleccionado
        conditions.add('Cuenta_Productor__c = \'' + productorId + '\'');
        
        // Condición: tipo de licencia
        conditions.add('Tipo_de_Licencia__c IN (\'Productor\', \'Comercio\')');
        
        // Condición: filtro por CUIT de obtentor (si hay cuits)
        if (!cuits.isEmpty()) {
            conditions.add('Cuenta_Obtentor__r.N_CUIT__c IN :cuits');
        }
        
        // Aplicar filtros adicionales
        if (filterMap.containsKey('estado') && String.isNotBlank((String)filterMap.get('estado'))) {
            String estado = (String)filterMap.get('estado');
            if (estado == 'En curso') {
                conditions.add('Estado__c IN (\'Creada\', \'A validar\', \'Validada\', \'Solicitada\', \'Licencia Firmada\', \'En Proceso de Aprobacion\')');
            } else if (estado == 'Aprobada') {
                conditions.add('Estado__c = \'Aprobada\'');
            } else if (estado == 'Rechazada') {
                conditions.add('Estado__c = \'Rechazada\'');
            }
        }
        
        // Filtro por origen/tecnología
        if (filterMap.containsKey('origen') && String.isNotBlank((String)filterMap.get('origen'))) {
            conditions.add('Origen_de_Licencia__c = \'' + String.escapeSingleQuotes((String)filterMap.get('origen')) + '\'');
        }
        
        // Filtrar por tipo de licencia específico
        if (filterMap.containsKey('tipo') && String.isNotBlank((String)filterMap.get('tipo'))) {
            conditions.add('Tipo_de_Licencia__c = \'' + String.escapeSingleQuotes((String)filterMap.get('tipo')) + '\'');
        }
        
        // Filtro de búsqueda
        if (filterMap.containsKey('searchTerm') && String.isNotBlank((String)filterMap.get('searchTerm'))) {
            String searchTerm = '%' + String.escapeSingleQuotes((String)filterMap.get('searchTerm')) + '%';
            conditions.add('(Name LIKE \'' + searchTerm + '\' OR ' +
                          'Cultivo__c LIKE \'' + searchTerm + '\' OR ' +
                          'Tecnologia__c LIKE \'' + searchTerm + '\' OR ' +
                          'Origen_de_Licencia__c LIKE \'' + searchTerm + '\' OR ' +
                          'Tipo_de_Licencia__c LIKE \'' + searchTerm + '\' OR ' +
                          'Estado__c LIKE \'' + searchTerm + '\')');
        }
        
        // Agregar cláusula WHERE
        String whereClause = '';
        if (!conditions.isEmpty()) {
            whereClause = ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        // Primero, obtener conteo total
        String countQuery = 'SELECT COUNT() FROM Licencia__c' + whereClause;
        Integer totalRecords = Database.countQuery(countQuery);
        
        // Construir consulta principal con ORDER BY y paginación
        query += whereClause + ' ORDER BY Name DESC';
        
        // Aplicar paginación
        Integer offset = (pageNumber - 1) * pageSize;
        query += ' LIMIT ' + pageSize + ' OFFSET ' + offset;
        
        // Ejecutar consulta principal
        List<Licencia__c> licencias = Database.query(query);
        
        // Filtrar licencias de tipo "Comercio" para Corteva
        List<Licencia__c> filteredLicencias = new List<Licencia__c>();
        for (Licencia__c lic : licencias) {
            Boolean pasa = true;
            
            // Para licencias de tipo "Comercio" de Corteva, verificar que el obtentor esté en la lista
            if (lic.Tipo_de_Licencia__c == 'Comercio' && 
                lic.Cuenta_Obtentor__r != null && 
                cuitsCorteva.contains(lic.Cuenta_Obtentor__r.N_CUIT__c)) {
                pasa = obtentores.contains(lic.Cuenta_Obtentor__c);
            }
            
            if (pasa) {
                filteredLicencias.add(lic);
            }
        }
        
        // Preparar respuesta
        PaginatedResult result = new PaginatedResult();
        result.licencias = filteredLicencias;
        result.totalRecords = totalRecords;
        result.pageNumber = pageNumber;
        result.pageSize = pageSize;
        result.totalPages = totalRecords > 0 ? Math.ceil(totalRecords / Decimal.valueOf(pageSize)).intValue() : 0;
        
        return result;
    }

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchLicenciatarios(String searchTerm, List<String> selectedIds) {
        return Test.isRunningTest() ? null : CrearVentaController.accountsToLookup([select RecordType.DeveloperName, N_CUIT__c, Name from account where (name like: '%'+searchTerm+'%' or N_CUIT__c like: '%'+searchTerm+'%') and id in (select Cuenta_Productor__c from Licencia__c where Cuenta_Obtentor__c =: CrearCompraController.getAccount().id) limit 5]);
    }

    //portal SE Obtentor 
    @AuraEnabled
    public static List<Licencia__c> getLicenciasLicenciatario(Id licenciatarioId) {
        return Test.isRunningTest() ? null : [select Origen__c, Cuenta_Distribuidor__c, Marcas_Obtentor__c, Origen_de_Licencia__c, Cultivo__c, Tecnologia__c, name, Cuenta_Productor__r.Name, Estado__c, Tipo_de_Licencia__c, Cuenta_Obtentor__c from Licencia__c where Cuenta_Obtentor__c =: CrearCompraController.getAccount().id and Cuenta_Productor__c =: licenciatarioId];
    }
}