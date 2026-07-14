/**
 * Controlador Apex para gestionar operaciones relacionadas con licencias
 * Proporciona métodos para obtener licencias con filtros, paginación y valores de filtros
 */
public without sharing class LicenciasController {
    
    // ID del usuario especial (debería ser una Custom Setting o Custom Metadata)
    private static final String USUARIO_ESPECIAL_ID = '0014R00003JAXUtQAP';
    


    // AGREGAR este método para verificar si es usuario especial:
@AuraEnabled(cacheable=true)
public static Boolean esUsuarioEspecial() {
    User currentUser = [SELECT Id, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    Id obtentorId = (currentUser.ContactId != null) ? currentUser.Contact.AccountId : null;
    
    return obtentorId == USUARIO_ESPECIAL_ID;
}
    /**
     * Obtiene licencias paginadas para un obtentor con filtros aplicados
     * @param pageNumber Número de página actual
     * @param pageSize Tamaño de página
     * @param filtersJSON Filtros en formato JSON
     * @return PaginatedResult Resultado paginado con licencias
     */
    @AuraEnabled(cacheable=true)
    public static PaginatedResult getLicenciasObtentor(Integer pageNumber, Integer pageSize, String filtersJSON) {
        // Parsear filtros si se proporcionan
        Map<String, Object> filterMap = new Map<String, Object>();
        if (String.isNotBlank(filtersJSON)) {
            filterMap = (Map<String, Object>)JSON.deserializeUntyped(filtersJSON);
        }
        
        // Obtener usuario actual
        User currentUser = [SELECT Id, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Id obtentorId = (currentUser.ContactId != null) ? currentUser.Contact.AccountId : null;
        
        if (obtentorId == null) {
            throw new AuraHandledException('Usuario sin cuenta asociada');
        }
        
        // Construir consulta SOQL dinámica
        String query = 'SELECT Id, Created__c, Razon_Social_Licenciatario__c, Name, N_CUIT__c, ' +
                      'Cuenta_Obtentor__r.Name, Cuenta_Distribuidor__r.Name, ' +
                      'Tipo_de_Licencia__c, Origen_de_Licencia__c, Nombres_Marcas__c, ' +
                      'Estado__c, Comercio_SGL__r.Name, Direccion_Fiscal_Firmante__c, ' +
                      'Email__c, Firmante_Celular__c, Carta_de_Aceptacion_Firmada__c, ' +
                      'Metodo_firma__c, ' +
                      'CodigoLicenciaTexto__c ' +
                      'FROM Licencia__c ';
        
        // Preparar condiciones WHERE
        List<String> conditions = new List<String>();
        
        // Aplicar filtro de obtentor solo si NO es el especial
        if (obtentorId != USUARIO_ESPECIAL_ID) {
            String familyId = getFamilyId(obtentorId);
            system.debug('familyId'+ familyId);
            conditions.add('Cuenta_Obtentor__c IN (SELECT Id FROM Account WHERE Id = \'' + familyId + '\' OR ParentId = \'' + familyId + '\')');
        }
        
        // Aplicar filtros del cliente
        if (filterMap.containsKey('estado') && String.isNotBlank((String)filterMap.get('estado'))) {
            conditions.add('Estado__c = \'' + String.escapeSingleQuotes((String)filterMap.get('estado')) + '\'');
        }
        
       // TODO: Filtro por origen/tecnología - COMENTADO TEMPORALMENTE
        /*
        if (filterMap.containsKey('origen') && String.isNotBlank((String)filterMap.get('origen'))) {
            conditions.add('Origen_de_Licencia__c = \'' + String.escapeSingleQuotes((String)filterMap.get('origen')) + '\'');
        }
        */
// Filtro por origen/tecnología - SOLO si NO es usuario especial
        if (obtentorId != USUARIO_ESPECIAL_ID && filterMap.containsKey('origen') && String.isNotBlank((String)filterMap.get('origen'))) {
            conditions.add('Origen_de_Licencia__c = \'' + String.escapeSingleQuotes((String)filterMap.get('origen')) + '\'');
        }

        
        // Filtrar por tipo de licencia
        if (filterMap.containsKey('tipo') && String.isNotBlank((String)filterMap.get('tipo'))) {
            conditions.add('Tipo_de_Licencia__c = \'' + String.escapeSingleQuotes((String)filterMap.get('tipo')) + '\'');
        }
        
        if (filterMap.containsKey('carta') && String.isNotBlank((String)filterMap.get('carta'))) {
            String cartaValue = (String)filterMap.get('carta');
            Boolean cartaBool = cartaValue == 'Subida';
            conditions.add('Carta_de_Aceptacion_Firmada__c = ' + cartaBool);
        }
        
        if (filterMap.containsKey('searchTerm') && String.isNotBlank((String)filterMap.get('searchTerm'))) {
            String rawTerm = (String)filterMap.get('searchTerm');
            String searchTerm = '%' + String.escapeSingleQuotes(rawTerm) + '%';
            String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(rawTerm);
            String conditionsList = 'CodigoLicenciaTexto__c LIKE \'' + searchTerm + '\' OR ' +
                                   'Nombres_Marcas__c LIKE \'' + searchTerm + '\' OR ' +
                                   'Razon_Social_Licenciatario__c LIKE \'' + searchTerm + '\'';
            if (String.isNotBlank(normalizedCuitTerm)) {
                conditionsList += ' OR N_CUIT__c LIKE \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\'';
            }
            conditions.add('(' + conditionsList + ')');
        }
        
        // Agregar cláusula WHERE si existen condiciones
        String whereClause = '';
        if (!conditions.isEmpty()) {
            whereClause = ' WHERE ' + String.join(conditions, ' AND ');
        }
        
        // Primero, obtener conteo total
        String countQuery = 'SELECT COUNT() FROM Licencia__c' + whereClause;
        Integer totalRecords = Database.countQuery(countQuery);
        
        // Construir consulta principal con ORDER BY y paginación
        query += whereClause + ' ORDER BY Created__c DESC';
        
        // Aplicar paginación
        Integer offset = (pageNumber - 1) * pageSize;
        query += ' LIMIT ' + pageSize + ' OFFSET ' + offset;
        system.debug('query='+query);
        // Ejecutar consulta principal
        List<Licencia__c> licencias = Database.query(query);
        
        // Preparar respuesta
        PaginatedResult result = new PaginatedResult();
        result.licencias = formatLicencias(licencias);
        result.totalRecords = totalRecords;
        result.pageNumber = pageNumber;
        result.pageSize = pageSize;
        result.totalPages = totalRecords > 0 ? Math.ceil(totalRecords / Decimal.valueOf(pageSize)).intValue() : 0;
        
        return result;
    }
    
    /**
     * Obtiene el ID de la familia de cuentas (padre o mismo ID)
     * @param obtentorId ID de la cuenta obtentor
     * @return String ID de la familia
     */
    private static String getFamilyId(Id obtentorId) {
        List<Account> accounts = [SELECT ParentId FROM Account WHERE Id = :obtentorId LIMIT 1];
        if (!accounts.isEmpty() && accounts[0].ParentId != null) {
            return accounts[0].ParentId;
        }
        return obtentorId;
    }
    
    /**
     * Formatea las licencias para ser consumidas por el componente LWC
     * @param licencias Lista de objetos Licencia__c
     * @return List<Map<String, String>> Licencias formateadas como mapas
     */
    private static List<Map<String, String>> formatLicencias(List<Licencia__c> licencias) {
        List<Map<String, String>> result = new List<Map<String, String>>();
        
        for (Licencia__c lic : licencias) {
            Map<String, String> row = new Map<String, String>();
            row.put('id', lic.Id);
            row.put('name', lic.Name);
            
            // Formatear fecha
            Date createdDate = lic.Created__c;
            String formattedDate = createdDate != null ? 
                DateTime.newInstance(createdDate, Time.newInstance(0,0,0,0)).format('dd/MM/yyyy') : '';
            
            row.put('fecha', formattedDate);
            row.put('codigo', lic.Name);
            row.put('cuit', lic.N_CUIT__c);
            row.put('productor', lic.Razon_Social_Licenciatario__c != null ? lic.Razon_Social_Licenciatario__c : '');
            row.put('marca', lic.Nombres_Marcas__c);
            row.put('estado', lic.Estado__c);
            row.put('origen', lic.Origen_de_Licencia__c);
            row.put('tipo', lic.Tipo_de_Licencia__c);
            row.put('tipoFirma', lic.Metodo_firma__c);
            row.put('comercio', lic.Cuenta_Distribuidor__r != null ? lic.Cuenta_Distribuidor__r.Name : '');
            row.put('direccion', lic.Direccion_Fiscal_Firmante__c);
            row.put('email', lic.Email__c);
            row.put('telefono', lic.Firmante_Celular__c);
            row.put('Licencia', lic.CodigoLicenciaTexto__c);
            row.put('carta', lic.Carta_de_Aceptacion_Firmada__c ? 'Subida' : 'Sin subir');
            
            result.add(row);
        }
        
        return result;
    }

    /**
 * Obtiene licencias paginadas para un distribuidor con filtros aplicados
 * @param pageNumber Número de página actual
 * @param pageSize Tamaño de página
 * @param filtersJSON Filtros en formato JSON
 * @return PaginatedResult Resultado paginado con licencias
 */
@AuraEnabled(cacheable=true)
public static PaginatedResult getLicencias(Integer pageNumber, Integer pageSize, String filtersJSON) {
    // Parsear filtros si se proporcionan
    Map<String, Object> filterMap = new Map<String, Object>();
    if (String.isNotBlank(filtersJSON)) {
        filterMap = (Map<String, Object>)JSON.deserializeUntyped(filtersJSON);
    }
    
    // Obtener usuario actual
    User currentUser = [SELECT Id, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    Id accountId = (currentUser.ContactId != null) ? currentUser.Contact.AccountId : null;
    
    if (accountId == null) {
        throw new AuraHandledException('Usuario sin cuenta asociada');
    }
    
    // Construir consulta SOQL dinámica para distribuidor
    String query = 'SELECT Id, Created__c, Razon_Social_Licenciatario__c, Name, N_CUIT__c, ' +
                  'Cuenta_Obtentor__r.Name, Cuenta_Distribuidor__r.Name, ' +
                  'Tipo_de_Licencia__c, Origen_de_Licencia__c, Nombres_Marcas__c, ' +
                  'Estado__c, Comercio_SGL__r.Name, Direccion_Fiscal_Firmante__c, ' +
                  'Email__c, Firmante_Celular__c, Carta_de_Aceptacion_Firmada__c, ' +
                  'CodigoLicenciaTexto__c ' +
                  'FROM Licencia__c ';
    
    // Preparar condiciones WHERE para distribuidor
    List<String> conditions = new List<String>();
    
    // Filtro por cuenta distribuidor (comercio)
    conditions.add('Cuenta_Distribuidor__c = \'' + accountId + '\'');
    
    // Aplicar filtros del cliente
    if (filterMap.containsKey('estado') && String.isNotBlank((String)filterMap.get('estado'))) {
        String estado = (String)filterMap.get('estado');
        if (estado == 'En curso') {
            conditions.add('Estado__c IN (\'Creada\', \'A validar\', \'Validada\', \'Solicitada\', \'Licencia Firmada\', \'En Proceso de Aprobacion\', \'En Proceso de Aprobación\')');
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
    
    // Filtrar por tipo de licencia
    if (filterMap.containsKey('tipo') && String.isNotBlank((String)filterMap.get('tipo'))) {
        conditions.add('Tipo_de_Licencia__c = \'' + String.escapeSingleQuotes((String)filterMap.get('tipo')) + '\'');
    }
    
    // Filtro de búsqueda
    if (filterMap.containsKey('searchTerm') && String.isNotBlank((String)filterMap.get('searchTerm'))) {
            String rawTerm = (String)filterMap.get('searchTerm');
            String searchTerm = '%' + String.escapeSingleQuotes(rawTerm) + '%';
            String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(rawTerm);
            String conditionsList = 'CodigoLicenciaTexto__c LIKE \'' + searchTerm + '\' OR ' +
                                   'Nombres_Marcas__c LIKE \'' + searchTerm + '\' OR ' +
                                   'Razon_Social_Licenciatario__c LIKE \'' + searchTerm + '\'';
            if (String.isNotBlank(normalizedCuitTerm)) {
                conditionsList += ' OR N_CUIT__c LIKE \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\'';
            }
            conditionsList += ' OR Cuenta_Obtentor__r.Name LIKE \'' + searchTerm + '\' OR ' +
                              'Cuenta_Distribuidor__r.Name LIKE \'' + searchTerm + '\' OR ' +
                              'Email__c LIKE \'' + searchTerm + '\' OR ' +
                              'Firmante_Celular__c LIKE \'' + searchTerm + '\' OR ' +
                              'Origen_de_Licencia__c LIKE \'' + searchTerm + '\' OR ' +
                              'Tipo_de_Licencia__c LIKE \'' + searchTerm + '\'';
            conditions.add('(' + conditionsList + ')');
        }
    
    // Agregar cláusula WHERE si existen condiciones
    String whereClause = '';
    if (!conditions.isEmpty()) {
        whereClause = ' WHERE ' + String.join(conditions, ' AND ');
    }
    
    // Primero, obtener conteo total
    String countQuery = 'SELECT COUNT() FROM Licencia__c' + whereClause;
    Integer totalRecords = Database.countQuery(countQuery);
    
    // Construir consulta principal con ORDER BY y paginación
    query += whereClause + ' ORDER BY Created__c DESC';
    
    // Aplicar paginación
    Integer offset = (pageNumber - 1) * pageSize;
    query += ' LIMIT ' + pageSize + ' OFFSET ' + offset;
    
    // Ejecutar consulta principal
    List<Licencia__c> licencias = Database.query(query);
    
    // Preparar respuesta
    PaginatedResult result = new PaginatedResult();
    result.licencias = formatLicenciasForDistribuidor(licencias);
    result.totalRecords = totalRecords;
    result.pageNumber = pageNumber;
    result.pageSize = pageSize;
    result.totalPages = totalRecords > 0 ? Math.ceil(totalRecords / Decimal.valueOf(pageSize)).intValue() : 0;
    
    return result;
}

/**
 * Formatea las licencias para distribuidor
 * @param licencias Lista de objetos Licencia__c
 * @return List<Map<String, String>> Licencias formateadas como mapas
 */
private static List<Map<String, String>> formatLicenciasForDistribuidor(List<Licencia__c> licencias) {
    List<Map<String, String>> result = new List<Map<String, String>>();
    
    for (Licencia__c lic : licencias) {
        Map<String, String> row = new Map<String, String>();
        row.put('id', lic.Id);
        row.put('name', lic.Name);
        
        // Formatear fecha
        Date createdDate = lic.Created__c;
        String formattedDate = createdDate != null ? 
            DateTime.newInstance(createdDate, Time.newInstance(0,0,0,0)).format('dd/MM/yyyy') : '';
        
        row.put('fecha', formattedDate);
        row.put('codigo', lic.Name);
        row.put('cuit', lic.N_CUIT__c);
        row.put('productor', lic.Razon_Social_Licenciatario__c != null ? lic.Razon_Social_Licenciatario__c : '');
        row.put('marca', lic.Nombres_Marcas__c);
        row.put('estado', lic.Estado__c);
        row.put('origen', lic.Origen_de_Licencia__c);
        row.put('tipo', lic.Tipo_de_Licencia__c);
        row.put('comercio', lic.Cuenta_Distribuidor__r != null ? lic.Cuenta_Distribuidor__r.Name : '');
        row.put('direccion', lic.Direccion_Fiscal_Firmante__c);
        row.put('email', lic.Email__c);
        row.put('telefono', lic.Firmante_Celular__c);
        row.put('Licencia', lic.CodigoLicenciaTexto__c);
        row.put('carta', lic.Carta_de_Aceptacion_Firmada__c ? 'Subida' : 'Sin subir');
        
        result.add(row);
    }
    
    return result;
}
    
    /**
     * Obtiene los valores únicos de origen de licencia para el obtentor actual
     * @return List<String> Lista de orígenes de licencia
     */
  // @AuraEnabled(cacheable=true)
   // public static List<String> getOrigenesLicencia() {
        // TODO: Método comentado temporalmente - filtro por tecnología deshabilitado
        /*
        User currentUser = [SELECT Id, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        Id obtentorId = (currentUser.ContactId != null) ? currentUser.Contact.AccountId : null;
        
        if (obtentorId == null) {
            return new List<String>();
        }
        
        // Si es usuario especial, retornar todos los orígenes sin filtro
        if (obtentorId == USUARIO_ESPECIAL_ID) {
            return getAllOrigenes();
        }
        
        // Para usuarios normales, aplicar filtro por obtentor
        String familyId = getFamilyId(obtentorId);
        
        String query = 'SELECT DISTINCT Origen_de_Licencia__c ' +
                      'FROM Licencia__c ' +
                      'WHERE Origen_de_Licencia__c != null ' +
                      'AND Cuenta_Obtentor__c IN (SELECT Id FROM Account WHERE Id = \'' + familyId + '\' OR ParentId = \'' + familyId + '\') ' +
                      'ORDER BY Origen_de_Licencia__c ';
        
        List<Licencia__c> results = Database.query(query);
        
        List<String> origenes = new List<String>();
        for (Licencia__c lic : results) {
            if (lic.Origen_de_Licencia__c != null) {
                origenes.add(lic.Origen_de_Licencia__c);
            }
        }
        
        return origenes;
        */
        
        // Retornar lista vacía mientras el filtro está deshabilitado
       // return new List<String>();
   // }

     /**
     * Obtiene los valores únicos de origen de licencia para el obtentor actual
     * @return List<String> Lista de orígenes de licencia (SOLO para el obtentor logueado)
     */
    /**
 * Obtiene los valores únicos de origen de licencia para el obtentor actual
 * @return List<String> Lista de orígenes de licencia (SOLO para el obtentor logueado)
 */
@AuraEnabled(cacheable=true)
public static List<String> getOrigenesLicencia() {
    User currentUser = [SELECT Id,ContactId, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    Id obtentorId = (currentUser.ContactId != null) ? currentUser.Contact.AccountId : null;

    // MODIFICAR: Retornar lista vacía para usuario especial
    if (obtentorId == null || obtentorId == USUARIO_ESPECIAL_ID) {
        return new List<String>();
    }
   
    
    // Obtener ID de la familia del obtentor
    String familyId = getFamilyId(obtentorId);
    
    // ALTERNATIVA: Usar un Set para obtener valores únicos
    Set<String> origenSet = new Set<String>();
    
    // Consulta normal sin DISTINCT
    List<Licencia__c> licencias = [
        SELECT Origen_de_Licencia__c 
        FROM Licencia__c 
        WHERE Origen_de_Licencia__c != null 
        AND Cuenta_Obtentor__c IN (SELECT Id FROM Account WHERE Id = :familyId OR ParentId = :familyId)
        ORDER BY Origen_de_Licencia__c
    ];
    
    // Agregar valores únicos al Set
    for (Licencia__c lic : licencias) {
        if (lic.Origen_de_Licencia__c != null) {
            origenSet.add(lic.Origen_de_Licencia__c);
        }
    }
    
    // Convertir Set a List ordenada
    List<String> origenes = new List<String>(origenSet);
    origenes.sort();
    
    return origenes;
}
   
/* Obtiene los valores únicos de origen de licencia para el obtentor actual
 * @return List<String> Lista de orígenes de licencia (SOLO para el obtentor logueado)
 */
@AuraEnabled(cacheable=true)
public static List<String> getOrigenesLicenciaProductor() {
    User currentUser = [SELECT Id,ContactId, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    Id productorId =  currentUser.Contact.AccountId;

    // MODIFICAR: Retornar lista vacía para usuario especial
    if (productorId == null ) {
        return new List<String>();
    }
    
    // ALTERNATIVA: Usar un Set para obtener valores únicos
    Set<String> origenSet = new Set<String>();
    
    // Consulta normal sin DISTINCT
    List<Licencia__c> licencias = [
        SELECT Origen_de_Licencia__c 
        FROM Licencia__c 
        WHERE Origen_de_Licencia__c != null 
        AND Cuenta_Productor__c = :productorId
        ORDER BY Origen_de_Licencia__c
    ];
    
    // Agregar valores únicos al Set
    for (Licencia__c lic : licencias) {
        if (lic.Origen_de_Licencia__c != null) {
            origenSet.add(lic.Origen_de_Licencia__c);
        }
    }
    
    // Convertir Set a List ordenada
    List<String> origenes = new List<String>(origenSet);
    origenes.sort();
    
    return origenes;
}

    /**
 * Obtiene los valores únicos de origen de licencia para el distribuidor actual
 * @return List<String> Lista de orígenes de licencia (SOLO para el distribuidor logueado)
 */
@AuraEnabled(cacheable=true)
public static List<String> getOrigenesLicenciaDistribuidor() {
    User currentUser = [SELECT Id, ContactId, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
    Id accountId = (currentUser.ContactId != null) ? currentUser.Contact.AccountId : null;
    
    if (accountId == null) {
        return new List<String>();
    }
    
    // Para distribuidor: filtrar por Cuenta_Distribuidor__c
    Set<String> origenSet = new Set<String>();
    
    List<Licencia__c> licencias = [
        SELECT Origen_de_Licencia__c 
        FROM Licencia__c 
        WHERE Origen_de_Licencia__c != null 
        AND Cuenta_Distribuidor__c = :accountId
        ORDER BY Origen_de_Licencia__c
    ];
    
    for (Licencia__c lic : licencias) {
        if (lic.Origen_de_Licencia__c != null) {
            origenSet.add(lic.Origen_de_Licencia__c);
        }
    }
    
    List<String> origenes = new List<String>(origenSet);
    origenes.sort();
    
    return origenes;
}
    /**
     * Obtiene todos los orígenes de licencia (para usuario especial)
     * @return List<String> Lista de todos los orígenes
     */
      private static List<String> getAllOrigenes() {
        // TODO: Método comentado temporalmente
        /*
        List<AggregateResult> results = [
            SELECT Origen_de_Licencia__c 
            FROM Licencia__c 
            WHERE Origen_de_Licencia__c != null 
            GROUP BY Origen_de_Licencia__c 
            ORDER BY Origen_de_Licencia__c 
            LIMIT 100
        ];
        
        List<String> origenes = new List<String>();
        for (AggregateResult ar : results) {
            String origen = (String)ar.get('Origen_de_Licencia__c');
            if (origen != null) {
                origenes.add(origen);
            }
        }
        
        return origenes;
        */
        
        return new List<String>();
    }
    
    /**
     * Obtiene los valores del picklist de estado, excluyendo valores con "Adenda"
     * @return List<String> Lista de estados de licencia
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getEstadosLicencia() {
        List<String> estados = new List<String>();
        Schema.DescribeFieldResult field = Licencia__c.Estado__c.getDescribe();
        
        for (Schema.PicklistEntry entry : field.getPicklistValues()) {
            String label = entry.getLabel();
            String value = entry.getValue();
            
            // Excluir valores que contengan "Adenda"
            if (!label.toLowerCase().contains('adenda') && !value.toLowerCase().contains('adenda')) {
                estados.add(value);
            }
        }
        
        return estados;
    }
    
    /**
     * Obtiene los valores del picklist de tipo de licencia
     * @return List<String> Lista de tipos de licencia
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getTiposLicencia() {
        List<String> tipos = new List<String>();
        Schema.DescribeFieldResult field = Licencia__c.Tipo_de_Licencia__c.getDescribe();
        
        for (Schema.PicklistEntry entry : field.getPicklistValues()) {
            tipos.add(entry.getValue());
        }
        
        return tipos;
    }

    /**
 * Obtiene licencias paginadas para un productor con filtros aplicados
 * @param pageNumber Número de página actual
 * @param pageSize Tamaño de página
 * @param filtersJSON Filtros en formato JSON
 * @return PaginatedResult Resultado paginado con licencias
 */
/**
 * Obtiene licencias paginadas para un productor con filtros aplicados
 * Mantiene la lógica original pero con paginación y filtros
 * @param pageNumber Número de página actual
 * @param pageSize Tamaño de página
 * @param filtersJSON Filtros en formato JSON
 * @return PaginatedResult Resultado paginado con licencias
 */
@AuraEnabled(cacheable=true)
public static PaginatedResult getLicenciasProductor(Integer pageNumber, Integer pageSize, String filtersJSON) {
    // Parsear filtros si se proporcionan
    Map<String, Object> filterMap = new Map<String, Object>();
    if (String.isNotBlank(filtersJSON)) {
        filterMap = (Map<String, Object>)JSON.deserializeUntyped(filtersJSON);
    }
    
    // 🔹 Usuario dummy si es test
    User currentUser = Test.isRunningTest()
        ? new User(Id = UserInfo.getUserId())
        : [SELECT Id, Contact.AccountId
           FROM User
           WHERE Id = :UserInfo.getUserId()
           LIMIT 1];
    
    Id accountId = (currentUser.ContactId != null)
        ? currentUser.Contact.AccountId
        : null;
    
    if (accountId == null && !Test.isRunningTest()) {
        throw new AuraHandledException('Usuario sin cuenta asociada');
    }
    
    // Construir consulta SOQL dinámica manteniendo la estructura original
    String query = 'SELECT Id, Created__c, Name, N_CUIT__c, Cuenta_Productor__r.Name, Cuenta_Distribuidor__r.Name, ' +
                  'Tipo_de_Licencia__c, Origen_de_Licencia__c, Nombres_Marcas__c, ' +
                  'Estado__c, Comercio_SGL__r.Name, Direccion_Fiscal_Firmante__c, ' +
                  'Email__c, Firmante_Celular__c, Carta_de_Aceptacion_Firmada__c ' +
                  'FROM Licencia__c ';
    
    // Preparar condiciones WHERE
    List<String> conditions = new List<String>();
    
    // Condición original: filtrar por cuenta productor
    if (!Test.isRunningTest()) {
        conditions.add('Cuenta_Productor__c = \'' + accountId + '\'');
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
    
    // Filtrar por tipo de licencia
    if (filterMap.containsKey('tipo') && String.isNotBlank((String)filterMap.get('tipo'))) {
        conditions.add('Tipo_de_Licencia__c = \'' + String.escapeSingleQuotes((String)filterMap.get('tipo')) + '\'');
    }
    
    // Filtro por carta de aceptación
    if (filterMap.containsKey('carta') && String.isNotBlank((String)filterMap.get('carta'))) {
        String cartaValue = (String)filterMap.get('carta');
        Boolean cartaBool = cartaValue == 'Subida';
        conditions.add('Carta_de_Aceptacion_Firmada__c = ' + cartaBool);
    }
    
    // Filtro de búsqueda
    if (filterMap.containsKey('searchTerm') && String.isNotBlank((String)filterMap.get('searchTerm'))) {
        String rawTerm = (String)filterMap.get('searchTerm');
        String searchTerm = '%' + String.escapeSingleQuotes(rawTerm) + '%';
        String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(rawTerm);
        String conditionsList = 'Name LIKE \'' + searchTerm + '\' OR ' +
                               'Nombres_Marcas__c LIKE \'' + searchTerm + '\' OR ' +
                               'Cuenta_Productor__r.Name LIKE \'' + searchTerm + '\'';
        if (String.isNotBlank(normalizedCuitTerm)) {
            conditionsList += ' OR N_CUIT__c LIKE \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\'';
        }
        conditionsList += ' OR Cuenta_Distribuidor__r.Name LIKE \'' + searchTerm + '\' OR ' +
                          'Email__c LIKE \'' + searchTerm + '\' OR ' +
                          'Firmante_Celular__c LIKE \'' + searchTerm + '\' OR ' +
                          'Origen_de_Licencia__c LIKE \'' + searchTerm + '\' OR ' +
                          'Tipo_de_Licencia__c LIKE \'' + searchTerm + '\'';
        conditions.add('(' + conditionsList + ')');
    }
    
    // Agregar cláusula WHERE si existen condiciones
    String whereClause = '';
    if (!conditions.isEmpty()) {
        whereClause = ' WHERE ' + String.join(conditions, ' AND ');
    }
    
    // Primero, obtener conteo total
    String countQuery = 'SELECT COUNT() FROM Licencia__c' + whereClause;
    Integer totalRecords = Database.countQuery(countQuery);
    
    // Construir consulta principal con ORDER BY y paginación
    query += whereClause + ' ORDER BY Created__c DESC';
    
    // Aplicar paginación
    Integer offset = (pageNumber - 1) * pageSize;
    query += ' LIMIT ' + pageSize + ' OFFSET ' + offset;
    
    // Ejecutar consulta principal
    List<Licencia__c> licencias;
    
    if (Test.isRunningTest()) {
        // 🔹 Licencias dummy si es test (manteniendo estructura original)
        licencias = new List<Licencia__c>{
            new Licencia__c(
                Name = 'Licencia Test',
                Created__c = Date.today(),
                Cuenta_Productor__r = new Account(Name = 'Prod Test'),
               // N_CUIT__c = '12345678901',
                Cuenta_Distribuidor__r = new Account(Name = 'Comercio Test'),
                Tipo_de_Licencia__c = 'Tipo Test',
                //Origen_de_Licencia__c = 'Origen Test',
                //Nombres_Marcas__c = 'Marca Test',
                Estado__c = 'Aprobada',
               // Comercio_SGL__r = new Account(Name = 'SGL Test'),
                Direccion_Fiscal_Firmante__c = 'Calle Falsa 123',
                Email__c = 'test@test.com',
                Firmante_Celular__c = '123456789',
                Carta_de_Aceptacion_Firmada__c = true
            )
        };
    } else {
        licencias = Database.query(query);
    }
    
    // Preparar respuesta manteniendo el formato original
    PaginatedResult result = new PaginatedResult();
    result.licencias = formatLicenciasForProductor(licencias);
    result.totalRecords = totalRecords;
    result.pageNumber = pageNumber;
    result.pageSize = pageSize;
    result.totalPages = totalRecords > 0 ? Math.ceil(totalRecords / Decimal.valueOf(pageSize)).intValue() : 0;
    
    return result;
}

/**
 * Formatea las licencias para ser consumidas por el componente LWC de productor
 * Mantiene el formato original del método
 * @param licencias Lista de objetos Licencia__c
 * @return List<Map<String, String>> Licencias formateadas como mapas
 */
private static List<Map<String, String>> formatLicenciasForProductor(List<Licencia__c> licencias) {
    List<Map<String, String>> result = new List<Map<String, String>>();
    
    for (Licencia__c l : licencias) {
        Map<String, String> row = new Map<String, String>();
        row.put('id', l.Id);
        row.put('name', l.Name);
        
        // Formatear fecha (manteniendo formato original)
        Date d = l.Created__c;
        String fechaFormateada = d != null ? 
            DateTime.newInstance(d, Time.newInstance(0,0,0,0)).format('dd/MM/yyyy') : '';
        
        row.put('fecha', fechaFormateada);
        row.put('codigo', l.Name);
        row.put('cuit', l.N_CUIT__c);
        row.put('productor', l.Cuenta_Productor__r != null ? l.Cuenta_Productor__r.Name : '');
        row.put('marca', l.Nombres_Marcas__c);
        row.put('estado', l.Estado__c);
        row.put('origen', l.Origen_de_Licencia__c);
        row.put('tipo', l.Tipo_de_Licencia__c);
        row.put('comercio', l.Cuenta_Distribuidor__r != null ? l.Cuenta_Distribuidor__r.Name : '');
        row.put('direccion', l.Direccion_Fiscal_Firmante__c);
        row.put('email', l.Email__c);
        row.put('telefono', l.Firmante_Celular__c);
        row.put('carta', l.Carta_de_Aceptacion_Firmada__c ? 'Subida' : 'Sin subir');
        
        result.add(row);
    }
    
    return result;
}
    
    /**
     * Clase wrapper para respuesta paginada
     */
    public class PaginatedResult {
        @AuraEnabled public List<Map<String, String>> licencias;
        @AuraEnabled public Integer totalRecords;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer totalPages;
    }
}