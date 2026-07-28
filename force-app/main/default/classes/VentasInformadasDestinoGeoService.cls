/**
 * Provincia/Localidad destino en Ventas Informadas (opcionales).
 * Si se informan, se valida que la localidad pertenezca a la provincia.
 */
public without sharing class VentasInformadasDestinoGeoService {

    @TestVisible
    private static final String STINE_ID_OBTENTOR = '24';

    public class GeoOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public GeoOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    @TestVisible
    private static Boolean forceRequiereDestinoStineForTests;

    @AuraEnabled
    public static Boolean requiereDestinoStineActivo() {
        if (Test.isRunningTest() && forceRequiereDestinoStineForTests != null) {
            return forceRequiereDestinoStineForTests;
        }
        Ventas_Informadas_Settings__c cfg = Ventas_Informadas_Settings__c.getOrgDefaults();
        return cfg != null && cfg.Requiere_Destino_Stine__c == true;
    }

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> getProvinciasDestinoParaLookup(String searchTerm) {
        String searchLower = String.isBlank(searchTerm) ? '' : searchTerm.trim().toLowerCase();
        List<LookupSearchResult> out = new List<LookupSearchResult>();
        Set<String> namesVistos = new Set<String>();
        for (Provincia__c p : [
            SELECT Id, Name
            FROM Provincia__c
            WHERE NAME != 'OTROS PAISES'
            ORDER BY Name ASC
            LIMIT 100
        ]) {
            String key = String.isNotBlank(p.Name) ? p.Name.trim().toLowerCase() : String.valueOf(p.Id);
            if (namesVistos.contains(key)) {
                continue;
            }
            if (String.isBlank(searchLower) || p.Name.toLowerCase().contains(searchLower)) {
                namesVistos.add(key);
                out.add(new LookupSearchResult(
                    p.Id,
                    'Provincia__c',
                    'standard:location',
                    p.Name,
                    ''
                ));
            }
        }
        return out;
    }

    @AuraEnabled
    public static List<LookupSearchResult> getLocalidadesDestinoParaLookup(
        Id provinciaId,
        String searchTerm
    ) {
        if (provinciaId == null) {
            return new List<LookupSearchResult>();
        }
        String term = String.isBlank(searchTerm) ? null : searchTerm.trim();
        List<Localidad__c> rows;
        if (term == null) {
            rows = [
                SELECT Id, Name
                FROM Localidad__c
                WHERE Provincia__c = :provinciaId
                ORDER BY Name ASC
                LIMIT 200
            ];
        } else {
            String likeTerm = '%' + term + '%';
            rows = [
                SELECT Id, Name
                FROM Localidad__c
                WHERE Provincia__c = :provinciaId AND Name LIKE :likeTerm
                ORDER BY Name ASC
                LIMIT 200
            ];
        }
        List<LookupSearchResult> out = new List<LookupSearchResult>();
        Set<String> namesVistos = new Set<String>();
        for (Localidad__c l : rows) {
            String key = String.isNotBlank(l.Name) ? l.Name.trim().toLowerCase() : String.valueOf(l.Id);
            if (namesVistos.contains(key)) {
                continue;
            }
            namesVistos.add(key);
            out.add(new LookupSearchResult(
                l.Id,
                'Localidad__c',
                'standard:location',
                l.Name,
                ''
            ));
        }
        return out;
    }

    @AuraEnabled(Cacheable=true)
    public static List<GeoOption> getProvinciasDestino() {
        List<GeoOption> out = new List<GeoOption>();
        for (Provincia__c p : [SELECT Id, Name FROM Provincia__c ORDER BY Name ASC LIMIT 100]) {
            out.add(new GeoOption(p.Name, p.Id));
        }
        return out;
    }

    @AuraEnabled(Cacheable=true)
    public static List<GeoOption> getLocalidadesDestinoPorProvincia(Id provinciaId) {
        List<GeoOption> out = new List<GeoOption>();
        if (provinciaId == null) {
            return out;
        }
        for (Localidad__c l : [
            SELECT Id, Name
            FROM Localidad__c
            WHERE Provincia__c = :provinciaId
            ORDER BY Name ASC
            LIMIT 10000
        ]) {
            out.add(new GeoOption(l.Name, l.Id));
        }
        return out;
    }

    @AuraEnabled
    public static Boolean esVariedadStine(Id variedadId) {
        return esVariedadStinePorId(variedadId);
    }

    public static Boolean requiereDestinoParaVariedad(Id variedadId) {
        return false;
    }

    public static Boolean requiereDestinoParaVariedad(Variedad__c variedad) {
        return false;
    }

    public static Boolean esVariedadStine(Variedad__c variedad) {
        if (variedad == null) {
            return false;
        }
        if (variedad.Obtentor_Comercializa__r != null) {
            return esObtentorStine(
                variedad.Obtentor_Comercializa__r.Id_Obtentor__c,
                variedad.Obtentor_Comercializa__r.Name
            );
        }
        return esVariedadStinePorId(variedad.Id);
    }

    public static void validarDestinoObligatorio(Ventas_Informadas__c venta, Id variedadId) {
        validarDestinoConsistencia(venta, false);
    }

    public static void validarDestinoObligatorio(
        Ventas_Informadas__c venta,
        Id variedadInaseId,
        Boolean strict
    ) {
        validarDestinoConsistencia(venta, strict);
    }

    @TestVisible
    private static void validarDestinoConsistencia(Ventas_Informadas__c venta, Boolean strict) {
        if (venta == null) {
            return;
        }
        String msg = null;
        if (venta.Localidad_Destino__c != null && venta.Provincia_Destino__c == null) {
            msg = 'Si informa Localidad Destino debe indicar Provincia Destino.';
        } else if (venta.Localidad_Destino__c != null && venta.Provincia_Destino__c != null) {
            try {
                validarLocalidadPerteneceProvincia(
                    venta.Provincia_Destino__c,
                    venta.Localidad_Destino__c
                );
            } catch (AuraHandledException ex) {
                msg = ex.getMessage();
            }
        }
        if (msg == null) {
            return;
        }
        if (strict == true) {
            venta.addError(msg);
        } else {
            throw new AuraHandledException(msg);
        }
    }

    public static void aplicarDestinoDesdeFilas(
        Ventas_Informadas__c venta,
        Map<String, Object> fileRow,
        Map<String, Id> provinciasByKey
    ) {
        aplicarDestinoDesdeFilas(venta, fileRow, provinciasByKey, null);
    }

    public static void aplicarDestinoDesdeFilas(
        Ventas_Informadas__c venta,
        Map<String, Object> fileRow,
        Map<String, Id> provinciasByKey,
        Map<Id, Map<String, Id>> localidadesByProvinciaId
    ) {
        if (venta == null || fileRow == null) {
            return;
        }
        Object provRaw = firstNonBlank(
            fileRow.get('Provincia_Destino__c'),
            fileRow.get('Provincia Destino'),
            null
        );
        Object locRaw = firstNonBlank(
            fileRow.get('Localidad_Destino__c'),
            fileRow.get('Localidad Destino'),
            null
        );
        if (provRaw != null && String.isNotBlank(String.valueOf(provRaw))) {
            venta.Provincia_Destino__c = resolveProvinciaId(
                String.valueOf(provRaw),
                provinciasByKey
            );
        }
        if (locRaw != null && String.isNotBlank(String.valueOf(locRaw))
            && venta.Provincia_Destino__c != null) {
            Map<String, Id> localidadesByKey = resolveLocalidadesByKey(
                venta.Provincia_Destino__c,
                localidadesByProvinciaId
            );
            venta.Localidad_Destino__c = resolveLocalidadId(
                String.valueOf(locRaw),
                venta.Provincia_Destino__c,
                localidadesByKey
            );
        }
    }

    public static Set<Id> collectProvinciaIdsDesdeFilas(
        List<Map<String, Object>> fileRows,
        Map<String, Id> provinciasByKey
    ) {
        Set<Id> out = new Set<Id>();
        if (fileRows == null || fileRows.isEmpty() || provinciasByKey == null) {
            return out;
        }
        for (Map<String, Object> row : fileRows) {
            if (row == null) {
                continue;
            }
            Object provRaw = firstNonBlank(
                row.get('Provincia_Destino__c'),
                row.get('Provincia Destino'),
                null
            );
            if (provRaw == null || String.isBlank(String.valueOf(provRaw))) {
                continue;
            }
            Id provinciaId = resolveProvinciaId(String.valueOf(provRaw), provinciasByKey);
            if (provinciaId != null) {
                out.add(provinciaId);
            }
        }
        return out;
    }

    public static Map<Id, Map<String, Id>> buildLocalidadesCacheForProvinciaIds(Set<Id> provinciaIds) {
        Map<Id, Map<String, Id>> out = new Map<Id, Map<String, Id>>();
        if (provinciaIds == null || provinciaIds.isEmpty()) {
            return out;
        }
        for (Id provinciaId : provinciaIds) {
            out.put(provinciaId, new Map<String, Id>());
        }
        for (Localidad__c l : [
            SELECT Id, Name, Provincia__c
            FROM Localidad__c
            WHERE Provincia__c IN :provinciaIds
        ]) {
            if (!out.containsKey(l.Provincia__c)) {
                out.put(l.Provincia__c, new Map<String, Id>());
            }
            out.get(l.Provincia__c).put(normalizeGeoKey(l.Name), l.Id);
        }
        return out;
    }

    public static Map<String, Id> loadProvinciasByKey() {
        Map<String, Id> out = new Map<String, Id>();
        for (Provincia__c p : [SELECT Id, Name FROM Provincia__c]) {
            out.put(normalizeGeoKey(p.Name), p.Id);
        }
        return out;
    }

    @TestVisible
    private static Map<Id, Map<String, Id>> localidadesByProvinciaCache;

    public static Map<String, Id> loadLocalidadesByKey(Id provinciaId) {
        if (provinciaId == null) {
            return new Map<String, Id>();
        }
        if (localidadesByProvinciaCache == null) {
            localidadesByProvinciaCache = new Map<Id, Map<String, Id>>();
        }
        if (!localidadesByProvinciaCache.containsKey(provinciaId)) {
            localidadesByProvinciaCache.put(
                provinciaId,
                loadLocalidadesByKeyUncached(provinciaId)
            );
        }
        return localidadesByProvinciaCache.get(provinciaId);
    }

    @TestVisible
    private static Map<String, Id> loadLocalidadesByKeyUncached(Id provinciaId) {
        Map<String, Id> out = new Map<String, Id>();
        if (provinciaId == null) {
            return out;
        }
        for (Localidad__c l : [
            SELECT Id, Name
            FROM Localidad__c
            WHERE Provincia__c = :provinciaId
        ]) {
            out.put(normalizeGeoKey(l.Name), l.Id);
        }
        return out;
    }

    @TestVisible
    private static Map<String, Id> resolveLocalidadesByKey(
        Id provinciaId,
        Map<Id, Map<String, Id>> localidadesByProvinciaId
    ) {
        if (provinciaId == null) {
            return new Map<String, Id>();
        }
        if (localidadesByProvinciaId != null && localidadesByProvinciaId.containsKey(provinciaId)) {
            return localidadesByProvinciaId.get(provinciaId);
        }
        return loadLocalidadesByKey(provinciaId);
    }

    @TestVisible
    static void resetCachesForTests() {
        localidadesByProvinciaCache = null;
        forceRequiereDestinoStineForTests = null;
    }

    @TestVisible
    private static Boolean esVariedadStinePorId(Id variedadId) {
        if (variedadId == null) {
            return false;
        }
        List<Variedad__c> rows = [
            SELECT Obtentor_Comercializa__r.Id_Obtentor__c,
                   Obtentor_Comercializa__r.Name
            FROM Variedad__c
            WHERE Id = :variedadId
            LIMIT 1
        ];
        if (rows.isEmpty() || rows[0].Obtentor_Comercializa__r == null) {
            return false;
        }
        return esObtentorStine(
            rows[0].Obtentor_Comercializa__r.Id_Obtentor__c,
            rows[0].Obtentor_Comercializa__r.Name
        );
    }

    @TestVisible
    private static Boolean esObtentorStine(String idObtentor, String nombre) {
        if (String.isNotBlank(idObtentor) && idObtentor.contains(STINE_ID_OBTENTOR)) {
            return true;
        }
        return String.isNotBlank(nombre)
            && (nombre.toUpperCase().contains('STINE')
                || nombre.toUpperCase().contains('M.S. TECHNOLOGIES'));
    }

    @TestVisible
    private static void validarLocalidadPerteneceProvincia(Id provinciaId, Id localidadId) {
        List<Localidad__c> locs = [
            SELECT Provincia__c
            FROM Localidad__c
            WHERE Id = :localidadId
            LIMIT 1
        ];
        if (locs.isEmpty() || locs[0].Provincia__c != provinciaId) {
            throw new AuraHandledException(
                'La Localidad Destino no corresponde a la Provincia Destino seleccionada.'
            );
        }
    }

    @TestVisible
    private static Id resolveProvinciaId(String raw, Map<String, Id> provinciasByKey) {
        if (String.isBlank(raw) || provinciasByKey == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (isSalesforceId(trimmed)) {
            return (Id) trimmed;
        }
        return provinciasByKey.get(normalizeGeoKey(trimmed));
    }

    @TestVisible
    private static Id resolveLocalidadId(
        String raw,
        Id provinciaId,
        Map<String, Id> localidadesByKey
    ) {
        if (String.isBlank(raw) || localidadesByKey == null) {
            return null;
        }
        String trimmed = raw.trim();
        if (isSalesforceId(trimmed)) {
            return (Id) trimmed;
        }
        return localidadesByKey.get(normalizeGeoKey(trimmed));
    }

    @TestVisible
    private static String normalizeGeoKey(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String t = value.trim().toLowerCase();
        t = t.replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u');
        t = t.replace('ñ', 'n');
        while (t.contains('  ')) {
            t = t.replace('  ', ' ');
        }
        return t;
    }

    private static Object firstNonBlank(Object a, Object b, Object c) {
        if (a != null && String.isNotBlank(String.valueOf(a))) {
            return a;
        }
        if (b != null && String.isNotBlank(String.valueOf(b))) {
            return b;
        }
        if (c != null && String.isNotBlank(String.valueOf(c))) {
            return c;
        }
        return null;
    }

    private static Boolean isSalesforceId(String s) {
        if (String.isBlank(s)) {
            return false;
        }
        String trimmed = s.trim();
        if (trimmed.length() != 15 && trimmed.length() != 18) {
            return false;
        }
        return Pattern.matches('[a-zA-Z0-9]{15}|[a-zA-Z0-9]{18}', trimmed);
    }
}