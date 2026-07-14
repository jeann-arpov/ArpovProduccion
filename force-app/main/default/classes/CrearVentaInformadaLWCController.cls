public without sharing class CrearVentaInformadaLWCController {

    // Mínimo de Kg para permitir guardar (ticket 1916).
    // Mapeo Tipo de Comprobante (ticket 1874).
    // Remito -> FC, Remito de Devolución -> NC al momento de reprocesar/guardar.
    // El API value de "Remito" en la picklist es "REMITO" (legacy).
    private static final Map<String, String> TIPO_COMPROBANTE_MAP = new Map<String, String>{
        'FC' => 'FC',
        'NC' => 'NC',
        'Remito' => 'FC',
        'REMITO' => 'FC',
        'Remito de Devolución' => 'NC',
        'Remito de Devolucion' => 'NC'
    };

    @AuraEnabled
    public static Account getCuenta(String recordId) {
        List<Account> accs = [SELECT Id, Name, Type, N_CUIT__c FROM Account WHERE Id = :recordId];
        if(accs.size() > 0){
            return accs[0];
        } else {
            return null;
        }
    }

    /**
     * Devuelve la Razón Social asociada a un CUIT.
     * 1) Intenta en Salesforce (Account.ParentId = null).
     * 2) Si no existe, hace fallback al WS de ARCA (pendiente de implementación).
     */
    @AuraEnabled
    public static String getRazonSocialPorCuit(String cuit, Id variedadId) {
        if (String.isBlank(cuit)) return null;
        String cuitClean = limpiarCuit(cuit);
        if (String.isBlank(cuitClean)) {
            return null;
        }

        Id obtComId = obtenerObtentorComercializaId(variedadId);
        Map<String, List<Account>> porCuit =
            VentasInformadasCuitResolver.queryCuentasPorCuitsNormalizados(new Set<String>{ cuitClean });
        List<Account> candidatos = porCuit.get(cuitClean);
        Account acc = VentasInformadasCuitResolver.resolveCuentaPorCuit(cuitClean, obtComId, candidatos);
        return acc != null ? acc.Name : null;
    }

    /** Resuelve cuenta destinatario por CUIT (lookup + rol) para el formulario modal. */
    @AuraEnabled
    public static Map<String, String> getCuentaDestinatarioPorCuit(String cuit, Id variedadId) {
        Map<String, String> out = new Map<String, String>();
        if (String.isBlank(cuit)) {
            return out;
        }
        String cuitClean = limpiarCuit(cuit);
        Id obtComId = obtenerObtentorComercializaId(variedadId);
        Map<String, List<Account>> porCuit =
            VentasInformadasCuitResolver.queryCuentasPorCuitsNormalizados(new Set<String>{ cuitClean });
        Account acc = VentasInformadasCuitResolver.resolveCuentaPorCuit(cuitClean, obtComId, porCuit.get(cuitClean));
        if (acc == null) {
            return out;
        }
        out.put('id', acc.Id);
        out.put('name', acc.Name);
        String rol = acc.Type;
        if (String.isBlank(rol) && acc.RecordType != null && acc.RecordType.DeveloperName != 'Proveedor') {
            rol = acc.RecordType.DeveloperName;
        }
        if (rol == 'Productor') {
            out.put('rol', 'Productor');
        } else if (rol == 'Distribuidor') {
            out.put('rol', 'Distribuidor');
        }
        return out;
    }

    /**
     * Campañas agrícolas para lookup con búsqueda en Nueva Venta.
     * Rango: 2 años atrás y 1 adelante del actual (4 años por cultivo, ej. 2024–2027 si hoy es 2026).
     * Orden: SOJA, TRIGO, demás cultivos; dentro de cada cultivo año descendente (ej. 2026, 2025).
     */
    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> getCampanasAgricolasParaLookup(String searchTerm) {
        String searchLower = String.isBlank(searchTerm) ? '' : searchTerm.trim().toLowerCase();
        List<Campana_Agricola__c> campanas;
        if (String.isBlank(searchLower)) {
            campanas = [
                SELECT Id, Name, Ano__c, Cultivo__r.Name
                FROM Campana_Agricola__c
                WHERE Cultivo__c != null
                ORDER BY Name
                LIMIT 500
            ];
        } else {
            String likeTerm = '%' + searchTerm.trim() + '%';
            campanas = [
                SELECT Id, Name, Ano__c, Cultivo__r.Name
                FROM Campana_Agricola__c
                WHERE Cultivo__c != null AND Name LIKE :likeTerm
                ORDER BY Name
                LIMIT 200
            ];
        }

        List<CampanaSortable> ordenadas = new List<CampanaSortable>();
        for (Campana_Agricola__c c : campanas) {
            if (campanaAnoEnRangoPicklist(c.Ano__c)) {
                ordenadas.add(new CampanaSortable(c));
            }
        }
        ordenadas.sort();

        List<LookupSearchResult> resultados = new List<LookupSearchResult>();
        String icon = 'standard:data_streams';

        for (CampanaSortable cs : ordenadas) {
            if (String.isBlank(searchLower) || cs.label.toLowerCase().contains(searchLower)) {
                LookupSearchResult resultado = new LookupSearchResult(
                    cs.rec.Id,
                    'Campana_Agricola__c',
                    icon,
                    cs.label,
                    ''
                );
                resultado.record = cs.rec;
                resultados.add(resultado);
            }
        }

        return resultados;
    }

    @TestVisible
    private class CampanaSortable implements Comparable {
        public Campana_Agricola__c rec;
        public Integer grupoCultivo;
        public String cultivoNombre;
        public Integer anoClave;
        public String label;

        CampanaSortable(Campana_Agricola__c c) {
            rec = c;
            cultivoNombre = c.Cultivo__r != null ? c.Cultivo__r.Name : '';
            grupoCultivo = cultivoGrupoOrden(cultivoNombre);
            anoClave = anoClaveOrden(c.Ano__c);
            label = etiquetaCampanaPicklist(c);
        }

        public Integer compareTo(Object other) {
            CampanaSortable o = (CampanaSortable) other;
            if (grupoCultivo != o.grupoCultivo) {
                return grupoCultivo - o.grupoCultivo;
            }
            if (grupoCultivo >= 2) {
                Integer cmpCultivo = cultivoNombre.toUpperCase().compareTo(o.cultivoNombre.toUpperCase());
                if (cmpCultivo != 0) {
                    return cmpCultivo;
                }
            }
            if (anoClave != o.anoClave) {
                return o.anoClave - anoClave;
            }
            return label.compareTo(o.label);
        }
    }

    @TestVisible
    private static Integer cultivoGrupoOrden(String cultivoName) {
        if (String.isBlank(cultivoName)) {
            return 3;
        }
        String upper = cultivoName.trim().toUpperCase();
        if (upper.startsWith('SOJA')) {
            return 0;
        }
        if (upper.startsWith('TRIGO')) {
            return 1;
        }
        return 2;
    }

    @TestVisible
    private static Integer anoClaveOrden(String ano) {
        String primer = primerAnio(ano);
        if (String.isBlank(primer)) {
            return 9999;
        }
        try {
            return Integer.valueOf(primer);
        } catch (Exception e) {
            return 9999;
        }
    }

    /** Escapa % y _ para LIKE en SOQL (el guión bajo es comodín de un carácter). */
    @TestVisible
    private static String escapeSoqlLike(String term) {
        if (String.isBlank(term)) {
            return term;
        }
        return term.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
    }

    /** Año mínimo del rango del picklist (actual − 2). */
    @TestVisible
    private static Integer anoMinimoCampanaPicklist() {
        return Date.today().year() - 2;
    }

    /** Año máximo del rango del picklist (actual + 1). */
    @TestVisible
    private static Integer anoMaximoCampanaPicklist() {
        return Date.today().year() + 1;
    }

    @TestVisible
    private static Boolean campanaAnoEnRangoPicklist(String ano) {
        Integer clave = anoClaveOrden(ano);
        if (clave == 9999) {
            return false;
        }
        return clave >= anoMinimoCampanaPicklist() && clave <= anoMaximoCampanaPicklist();
    }

    @TestVisible
    private static String etiquetaCampanaPicklist(Campana_Agricola__c c) {
        if (String.isNotBlank(c.Name)) {
            return c.Name;
        }
        String cultivo = c.Cultivo__r != null ? c.Cultivo__r.Name : '';
        if (String.isNotBlank(c.Ano__c) && String.isNotBlank(cultivo)) {
            return c.Ano__c + ' ' + cultivo;
        }
        return String.isNotBlank(c.Ano__c) ? c.Ano__c : cultivo;
    }

    /** Nombre del cultivo de la campaña — para filtro Variedad en alta LWC (antes de guardar). */
    @AuraEnabled(Cacheable=true)
    public static String getNombreCultivoPorCampana(Id campanaAgricolaId) {
        if (campanaAgricolaId == null) {
            return null;
        }
        List<Campana_Agricola__c> campanas = [
            SELECT Cultivo__r.Name
            FROM Campana_Agricola__c
            WHERE Id = :campanaAgricolaId
            LIMIT 1
        ];
        return (campanas.isEmpty() || campanas[0].Cultivo__r == null)
            ? null
            : campanas[0].Cultivo__r.Name;
    }

    /** Tope de variedades por consulta (listado inicial o búsqueda LIKE). */
    @TestVisible
    private static final Integer VARIEDADES_MAX_LIMIT = 1200;

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> getVariedadesParaLookup(Id campanaAgricolaId) {
        Id cultivoId = getCultivoIdPorCampana(campanaAgricolaId);
        if (cultivoId == null) {
            return new List<LookupSearchResult>();
        }
        return VariedadToLookup(queryVariedadesPorCultivo(cultivoId, null));
    }

    /**
     * Variedades por cultivo de la campaña: listado inicial o búsqueda por nombre (LIKE).
     * Sin tope bajo artificial; máximo VARIEDADES_MAX_LIMIT por respuesta.
     */
    @AuraEnabled
    public static List<LookupSearchResult> getVariedad(String searchTerm, List<String> selectedIds, Id campanaAgricolaId) {
        Id cultivoId = getCultivoIdPorCampana(campanaAgricolaId);
        if (cultivoId == null) {
            return new List<LookupSearchResult>();
        }

        String normalizedSearchTerm = String.isBlank(searchTerm) ? null : searchTerm.trim();
        List<Variedad__c> variedades = queryVariedadesPorCultivo(cultivoId, normalizedSearchTerm);
        appendVariedadesSeleccionadas(variedades, selectedIds, cultivoId);

        return CrearVentaInformadaLWCController.VariedadToLookup(variedades);
    }

    @TestVisible
    private static Id getCultivoIdPorCampana(Id campanaAgricolaId) {
        if (campanaAgricolaId == null) {
            return null;
        }
        List<Campana_Agricola__c> campanas = [
            SELECT Cultivo__c
            FROM Campana_Agricola__c
            WHERE Id = :campanaAgricolaId
            LIMIT 1
        ];
        return campanas.isEmpty() ? null : campanas[0].Cultivo__c;
    }

    @TestVisible
    private static List<Variedad__c> queryVariedadesPorCultivo(Id cultivoId, String searchTerm) {
        if (cultivoId == null) {
            return new List<Variedad__c>();
        }
        if (String.isBlank(searchTerm)) {
            return [
                SELECT Id, Name
                FROM Variedad__c
                WHERE Cultivo__c = :cultivoId
                ORDER BY Name
                LIMIT :VARIEDADES_MAX_LIMIT
            ];
        }
        String likeTerm = '%' + escapeSoqlLike(searchTerm) + '%';
        return [
            SELECT Id, Name
            FROM Variedad__c
            WHERE Cultivo__c = :cultivoId
            AND Name LIKE :likeTerm
            ORDER BY Name
            LIMIT :VARIEDADES_MAX_LIMIT
        ];
    }

    @TestVisible
    private static void appendVariedadesSeleccionadas(
        List<Variedad__c> variedades,
        List<String> selectedIds,
        Id cultivoId
    ) {
        if (selectedIds == null || selectedIds.isEmpty() || cultivoId == null) {
            return;
        }
        Set<Id> foundIds = new Set<Id>();
        for (Variedad__c v : variedades) {
            foundIds.add(v.Id);
        }
        for (String selectedId : selectedIds) {
            if (String.isBlank(selectedId) || foundIds.contains((Id) selectedId)) {
                continue;
            }
            List<Variedad__c> selected = [
                SELECT Id, Name
                FROM Variedad__c
                WHERE Id = :selectedId
                AND Cultivo__c = :cultivoId
                LIMIT 1
            ];
            if (!selected.isEmpty()) {
                variedades.add(selected[0]);
                foundIds.add(selected[0].Id);
            }
        }
    }

     public static List<LookupSearchResult> VariedadToLookup(List<Variedad__c> variedades) {
        List<LookupSearchResult> results = new List<LookupSearchResult>();

        String accountIcon = 'custom:custom24';

        for (Variedad__c variedad : variedades) {
            String name = variedad.Name;
            results.add(new LookupSearchResult(variedad.Id, 'Variedad__c', accountIcon,  ' - ' + name, ''));
            results[results.size() - 1].record = variedad;
        }

        results.sort();

        return results;
    }

    /**
     * Diccionarios para la plantilla Excel de Importar Ventas.
     * Devuelve listas para dropdowns: variedades (Cultivar_Inase__c distinct),
     * categorías, tipos de comprobante y campañas agrícolas.
     */
    @AuraEnabled(Cacheable=true)
    public static Map<String, List<String>> getDiccionariosPlantilla() {
        Map<String, List<String>> dicc = new Map<String, List<String>>();

        // Variedades únicas por Cultivar INASE (lo que se valida al importar).
        Set<String> variedadesSet = new Set<String>();
        for (Variedad__c v : [
            SELECT Cultivar_Inase__c
            FROM Variedad__c
            WHERE Cultivar_Inase__c != null
            ORDER BY Cultivar_Inase__c
        ]) {
            variedadesSet.add(v.Cultivar_Inase__c);
        }
        List<String> variedades = new List<String>(variedadesSet);
        variedades.sort();
        dicc.put('variedades', variedades);

        // Categorías INASE.
        dicc.put('categorias', new List<String>{
            'Pre Básica',
            'Original o Fundadora',
            'Primera Multiplicación',
            'Segunda Multiplicación',
            'Tercera Multiplicación'
        });

        // Tipos de Comprobante (ticket 1874).
        dicc.put('tiposComprobante', new List<String>{
            'FC',
            'NC',
            'Remito',
            'Remito de Devolución'
        });

        // Campañas agrícolas activas (formato Name: ej. "SOJA - 25/26").
        Set<String> campanasSet = new Set<String>();
        for (Campana_Agricola__c c : [
            SELECT Name
            FROM Campana_Agricola__c
            WHERE Name != null
            ORDER BY Name DESC
            LIMIT 200
        ]) {
            campanasSet.add(c.Name);
        }
        List<String> campanas = new List<String>(campanasSet);
        campanas.sort();
        dicc.put('campanasAgricolas', campanas);

        return dicc;
    }

    @AuraEnabled
    public static Account getCuentaOriginante() {
        Id accountId = [SELECT Id, Contact.AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1].Contact.AccountId;
        List<Account> accs = [SELECT Id, Name, Type, N_CUIT__c FROM Account WHERE Id = :accountId];
        if(accs.size() > 0){
            return accs[0];
        } else {
            return null;
        }    
    }

    /**
     * Busca cuenta Distribuidor/Obtentor por CUIT (Salesforce core: selector de originante).
     */
    @AuraEnabled(Cacheable=true)
    public static Account buscarCuentaOriginantePorCuit(String cuit) {
        String cuitClean = limpiarCuit(cuit);
        if (String.isBlank(cuitClean)) {
            return null;
        }
        List<Account> accs = [
            SELECT Id, Name, Type, N_CUIT__c, RecordType.DeveloperName
            FROM Account
            WHERE N_CUIT__c = :cuitClean
                AND RecordType.DeveloperName IN ('Distribuidor', 'Obtentor')
                AND ParentId = null
            LIMIT 1
        ];
        return accs.isEmpty() ? null : accs[0];
    }

    public static Account resolveOriginanteAccount(Id originanteAccountId) {
        if (originanteAccountId == null) {
            throw new AuraHandledException('Debe seleccionar la cuenta originante.');
        }
        List<Account> accs = [
            SELECT Id, Name, Type, N_CUIT__c, RecordType.DeveloperName
            FROM Account
            WHERE Id = :originanteAccountId
            LIMIT 1
        ];
        if (accs.isEmpty()) {
            throw new AuraHandledException('Cuenta originante no encontrada.');
        }
        Account acc = accs[0];
        if (
            !Test.isRunningTest()
            && acc.RecordType.DeveloperName != 'Distribuidor'
            && acc.RecordType.DeveloperName != 'Obtentor'
        ) {
            throw new AuraHandledException('La cuenta originante debe ser Distribuidor u Obtentor.');
        }
        if (String.isBlank(acc.N_CUIT__c)) {
            throw new AuraHandledException('La cuenta originante no tiene CUIT cargado.');
        }
        return acc;
    }

    @TestVisible
    private static void aplicarOriginanteCore(Ventas_Informadas__c venta, Id originanteAccountId) {
        Account originante = resolveOriginanteAccount(originanteAccountId);
        venta.CUIT_Originante__c = limpiarCuit(originante.N_CUIT__c);
        venta.Originante__c = originante.Id;
        VentasInformadasCuitResolver.aplicarRolOriginante(venta, originante);
    }

    @AuraEnabled
    public static String saveVentaInformada(Ventas_Informadas__c venta, String variedadId, Id originanteAccountId){
        aplicarTipoComprobante(venta);

        // Ticket 2444: Kilos Totales obligatorio; sin mínimo de 20 kg al guardar.
        if (venta.Cantidad_de_Bolsas__c == null) {
            throw new AuraHandledException('Falta Kilos Totales.');
        }
        // if (venta.Cantidad_de_Bolsas__c < 0) {
        //     throw new AuraHandledException('Kilos Totales no puede ser negativo.');
        // }

        String networkId = Network.getNetworkId();
        if (networkId != null) {
            Account userAccont = [SELECT Account.N_CUIT__c, Account.RecordType.DeveloperName, Account.Type FROM User WHERE id =: UserInfo.getUserId()].Account;
            Id accountId;
            
            if(userAccont == null) throw new AuraHandledException('El usuario no posee una cuenta asociada');
            accountId = userAccont.Id;

            Boolean isPortalObtentor = [SELECT Name FROM Network WHERE id =:networkId].Name == 'Sembrá Evolución Obtentor';

            if (isPortalObtentor && userAccont.RecordType.DeveloperName != 'Obtentor') throw new AuraHandledException('Sólo usuarios obtentores pueden importar ventas');

            if (!isPortalObtentor && userAccont.RecordType.DeveloperName != 'Distribuidor' && userAccont.N_CUIT__c != '30500120882') throw new AuraHandledException('Sólo usuarios distribuidores pueden importar ventas');

            List<Account> cuentas = isPortalObtentor ? 
                [
                    SELECT Id, N_CUIT__c, RecordType.DeveloperName, Type, Name
                    FROM Account 
                    WHERE 
                        RecordType.DeveloperName IN ('Distribuidor', 'Obtentor') 
                        AND ((N_CUIT__c IN ('30569723023', '30715468294') 
                        AND Type = 'Obtentor') OR parentId = null)
                ] : new List<Account>();

            Map<String, List<Account>> cuentasPorCuit =
                VentasInformadasCuitResolver.agruparCuentasPorCuit(cuentas);
        
            if (isPortalObtentor) {
                if (String.isBlank(venta.CUIT_Originante__c)) {
                    throw new AuraHandledException('Falta CUIT Originante.');
                }
                Account originante = VentasInformadasCuitResolver.resolveCuentaPorCuit(
                    venta.CUIT_Originante__c,
                    null,
                    cuentasPorCuit.get(venta.CUIT_Originante__c)
                );
                if (originante == null) {
                    throw new AuraHandledException('No existe cuenta distribuidora con el CUIT_Originante__c');
                }
                venta.Originante__c = originante.Id;
                VentasInformadasCuitResolver.aplicarRolOriginante(venta, originante);
            } else {
                venta.CUIT_Originante__c = limpiarCuit(userAccont.N_CUIT__c);
                if (venta.CUIT_Originante__c == userAccont.N_CUIT__c) {
                    venta.Originante__c = accountId;
                    VentasInformadasCuitResolver.aplicarRolOriginante(venta, userAccont);
                } else throw new AuraHandledException('El cuit originante debe ser igual al propio');
            }
        } else if (originanteAccountId != null) {
            aplicarOriginanteCore(venta, originanteAccountId);
        } else if (Test.isRunningTest()) {
            // Tests unitarios sin comunidad ni cuenta originante explícita.
        } else {
            throw new AuraHandledException('Debe seleccionar la cuenta originante antes de guardar.');
        }

        // Venta Interna: respeta el checkbox del formulario; si no vino marcado, infiere por CUITs iguales.
        if (venta.Venta_Interna__c != true) {
            venta.Venta_Interna__c = venta.CUIT_Destinatario__c == venta.CUIT_Originante__c
                && String.isNotBlank(venta.CUIT_Originante__c);
        }

        if (String.isBlank(variedadId)) {
            throw new AuraHandledException('Debes seleccionar una Variedad existente en Salesforce.');
        }
        Variedad__c variedad = [
            SELECT Id, Cultivar_INASE__c, Cultivo__c, Obtentor_Comercializa__c
            FROM Variedad__c WHERE Id = :variedadId LIMIT 1
        ];
        venta.Variedad__c = variedad.Cultivar_INASE__c;
        venta.Variedad_INASE__c = variedad.Id;
        if (venta.Cultivo__c == null && variedad.Cultivo__c != null) {
            venta.Cultivo__c = variedad.Cultivo__c;
        }

        aplicarCuentasObtentorPorVariedad(venta, variedad.Obtentor_Comercializa__c);
        VentasInformadasCuitResolver.aplicarVentaInterna(venta);

        venta.Kilos_por_Bolsa__c = 1;

        // Defensivo: si el CUIT llega con guiones/puntos/espacios desde el cliente,
        // lo limpiamos. Lo mismo para la Campaña (que viene en formato AAAA).
        venta.CUIT_Destinatario__c = limpiarCuit(venta.CUIT_Destinatario__c);
        venta.CUIT_Originante__c   = limpiarCuit(venta.CUIT_Originante__c);
        venta.Campana_de_Ventas__c = primerAnio(venta.Campana_de_Ventas__c);

        for(Product2 product : [
            SELECT Id, Cultivo__r.Unidad_de_Medida_Por_Defecto__c, Unidad_de_Medida__c
            FROM Product2 
            WHERE Cultivar_Inase__c = :venta.Variedad__c 
                AND Categoria__c = :venta.Categoria__c 
                AND Family = 'Semilla Fiscalizada' 
                AND isActive = true

        ]) {
            if(product.Cultivo__r.Unidad_de_Medida_Por_Defecto__c == product.Unidad_de_Medida__c) {
                venta.Producto__c = product.Id;
            }
        }


        List<Campana_Agricola__c> campana = [SELECT Id, Ano__c, Cultivo__c FROM Campana_Agricola__c WHERE Id = :venta.Campana_Agricola__c];
        if(!campana.isEmpty()) {
            venta.Campana_de_Ventas__c = campana[0].Ano__c;
            venta.Cultivo__c = campana[0].Cultivo__c;
        }

        List<Ventas_Informadas__c> ventas = [
            SELECT CUIT_Originante__c, CUIT_Destinatario__c, Variedad__c, Cantidad_de_Bolsas__c, Campana_Agricola__c from Ventas_Informadas__c 
            WHERE CUIT_Originante__c = :venta.CUIT_Originante__c 
                AND CUIT_Destinatario__c = :venta.CUIT_Destinatario__c 
                AND Variedad__c = :venta.Variedad__c 
                AND Categoria__c = :venta.Categoria__c
                AND Cantidad_de_Bolsas__c = :venta.Cantidad_de_Bolsas__c 
                AND Campana_de_Ventas__c = :venta.Campana_de_Ventas__c
        ];

        if(ventas.size() > 0) {
            venta.Resultado__c = 'Ya existe una venta con mismo cuit/variedad/cantidad/campaña';
            venta.Estado__c = 'Preprocesado';
        }
        
        insert venta;

        return venta.Id;
    }

    @TestVisible
    private static void aplicarCuentasObtentorPorVariedad(
        Ventas_Informadas__c venta,
        Id obtentorComercializaId
    ) {
        VentasInformadasCuitResolver.aplicarOriginanteYDestinatario(venta, obtentorComercializaId);
    }

    @TestVisible
    private static void aplicarTipoComprobante(Ventas_Informadas__c venta) {
        if (venta == null) {
            return;
        }

        if (String.isNotBlank(venta.Tipo_Comprobante_Externo__c)) {
            String ext = venta.Tipo_Comprobante_Externo__c;
            if (TIPO_COMPROBANTE_MAP.containsKey(ext)) {
                venta.Tipo_de_Comprobante__c = TIPO_COMPROBANTE_MAP.get(ext);
            } else {
                venta.Tipo_de_Comprobante__c = ext;
            }
            return;
        }

        if (venta.Tipo_de_Comprobante__c == null) {
            return;
        }

        String interno = venta.Tipo_de_Comprobante__c;
        if (TIPO_COMPROBANTE_MAP.containsKey(interno)) {
            venta.Tipo_Comprobante_Externo__c = interno == 'REMITO' ? 'Remito' : interno;
            venta.Tipo_de_Comprobante__c = TIPO_COMPROBANTE_MAP.get(interno);
        } else {
            venta.Tipo_Comprobante_Externo__c = interno;
        }
    }

    /** Quita guiones, puntos, espacios y otros separadores de un CUIT. */
    public static String limpiarCuit(String cuit) {
        if (cuit == null) return null;
        return cuit.replaceAll('[^0-9]', '');
    }

    @TestVisible
    private static Id obtenerObtentorComercializaId(Id variedadId) {
        if (variedadId == null) {
            return null;
        }
        List<Variedad__c> variedades = [
            SELECT Obtentor_Comercializa__c
            FROM Variedad__c
            WHERE Id = :variedadId
            LIMIT 1
        ];
        return variedades.isEmpty() ? null : variedades[0].Obtentor_Comercializa__c;
    }

    /** Extrae el primer año de 4 dígitos de '2025/26', '2026-2027', '26/27', '2026', etc. */
    @TestVisible
    private static String primerAnio(String camp) {
        if (camp == null) return null;
        String normalized = lwcVentasImportFromExcel.primerAnioCampanaText(camp);
        return normalized != null ? normalized : camp;
    }
}