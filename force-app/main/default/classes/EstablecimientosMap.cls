public without sharing class EstablecimientosMap {

    private class GeoAddress {
        public String countryCode;
        public String state;
        public String partido;
        public String town;
        public String suburb;
        public String village;
        public String city;
        public String municipality;
    }

    @AuraEnabled
    public static List<Establecimiento__c> getEstablecimientos() {
        return [
            SELECT Name, Coordenadas__Latitude__s, Coordenadas__Longitude__s
            FROM Establecimiento__c
            WHERE
                Productor__c = :CrearCompraController.getAccount().Id
                AND Origen__c = 'Propio'
                AND Coordenadas__Latitude__s != null
                AND Coordenadas__Longitude__s != null
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled
    public static string getAccountId() {
        Id userId = UserInfo.getUserId();
        Id accId = [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1][0].AccountId;
        return accId;
    }

    @AuraEnabled
    public static String insertEstablecimiento(Map<String, Object> fieldMap) {
        try {
            Establecimiento__c establecimiento = new Establecimiento__c();

            for (String key : fieldMap.keySet()) {
                establecimiento.put(key, fieldMap.get(key));
            }

            if (
                establecimiento.Localidad__c == null &&
                establecimiento.Coordenadas__Latitude__s != null &&
                establecimiento.Coordenadas__Longitude__s != null
            ) {
                Id localidadId = resolveLocalidadId(
                    establecimiento.Coordenadas__Latitude__s,
                    establecimiento.Coordenadas__Longitude__s
                );
                if (localidadId != null) {
                    establecimiento.Localidad__c = localidadId;
                }
            }

            insert establecimiento;
            return 'Nuevo Establecimiento creado con exito';
        } catch (DmlException e) {
            return 'Error al crear el establecimiento: ' + e.getDmlMessage(0);
        } catch (Exception e) {
            return 'Error al crear el establecimiento: ' + e.getMessage();
        }
    }

    /**
     * Resuelve Localidad__c por lat/lng via Nominatim (solo Argentina).
     * Expuesto para pruebas / backfill.
     */
    @AuraEnabled
    public static Id resolveLocalidadId(Decimal latitude, Decimal longitude) {
        if (latitude == null || longitude == null) {
            return null;
        }

        GeoAddress geo = reverseGeocode(latitude, longitude);
        if (geo == null || geo.countryCode != 'ar') {
            return null;
        }

        List<String> nameCandidates = new List<String>();
        addCandidate(nameCandidates, geo.town);
        addCandidate(nameCandidates, geo.suburb);
        addCandidate(nameCandidates, geo.village);
        addCandidate(nameCandidates, geo.municipality);
        addCandidate(nameCandidates, geo.city);

        if (nameCandidates.isEmpty()) {
            return null;
        }

        Set<String> queryNames = new Set<String>();
        for (String cand : nameCandidates) {
            queryNames.add(cand);
            queryNames.add(cand.toUpperCase());
            queryNames.add(normalize(cand));
        }

        List<Localidad__c> matches = [
            SELECT Id, Name, Provincia__r.Name, Partido__r.Name
            FROM Localidad__c
            WHERE Name IN :queryNames
            LIMIT 50
        ];

        if (matches.isEmpty()) {
            // Fallback: buscar por Name normalizado en memoria (pocos candidatos SOQL LIKE)
            String likeKey = '%' + normalize(nameCandidates[0]).left(4) + '%';
            matches = [
                SELECT Id, Name, Provincia__r.Name, Partido__r.Name
                FROM Localidad__c
                WHERE Name LIKE :likeKey
                LIMIT 100
            ];
        }

        String provNorm = normalize(geo.state);
        String partidoNorm = normalizePartido(geo.partido);

        // 1) Match fuerte: Nombre + Provincia + Partido
        // 2) Match medio: Nombre + Provincia
        // No devolver solo por nombre si hay provincia y no coincide.
        Id matchNombreProvincia;
        for (String cand : nameCandidates) {
            String candNorm = normalize(cand);
            for (Localidad__c loc : matches) {
                if (normalize(loc.Name) != candNorm) {
                    continue;
                }

                String locProv = normalize(loc.Provincia__r?.Name);
                String locPartido = normalizePartido(loc.Partido__r?.Name);

                Boolean okProvincia =
                    String.isBlank(provNorm) || provinceMatches(provNorm, locProv);
                if (!okProvincia) {
                    continue;
                }

                Boolean okPartido =
                    String.isBlank(partidoNorm) ||
                    String.isBlank(locPartido) ||
                    partidoMatches(partidoNorm, locPartido);

                if (okPartido && String.isNotBlank(partidoNorm) && String.isNotBlank(locPartido)) {
                    return loc.Id; // Nombre + Provincia + Partido
                }
                if (matchNombreProvincia == null) {
                    matchNombreProvincia = loc.Id; // Nombre + Provincia
                }
            }
        }
        return matchNombreProvincia;
    }

    private static void addCandidate(List<String> candidates, String value) {
        if (String.isBlank(value)) {
            return;
        }
        for (String existing : candidates) {
            if (normalize(existing) == normalize(value)) {
                return;
            }
        }
        candidates.add(value.trim());
    }

    private static String normalizePartido(String value) {
        String s = normalize(value);
        if (String.isBlank(s)) {
            return '';
        }
        if (s.startsWith('PARTIDO DE ')) {
            s = s.substring('PARTIDO DE '.length());
        }
        if (s.startsWith('PARTIDO ')) {
            s = s.substring('PARTIDO '.length());
        }
        return s.trim();
    }

    private static Boolean partidoMatches(String geoPartido, String sfPartido) {
        if (String.isBlank(geoPartido) || String.isBlank(sfPartido)) {
            return false;
        }
        return geoPartido == sfPartido ||
            geoPartido.contains(sfPartido) ||
            sfPartido.contains(geoPartido);
    }

    private static Boolean provinceMatches(String geoProv, String sfProv) {
        if (String.isBlank(geoProv) || String.isBlank(sfProv)) {
            return false;
        }
        if (geoProv == sfProv || geoProv.contains(sfProv) || sfProv.contains(geoProv)) {
            return true;
        }
        // CABA variants
        Boolean geoCaba =
            geoProv.contains('AUTONOMOUS CITY') ||
            geoProv.contains('CIUDAD AUTONOMA') ||
            geoProv == 'CABA' ||
            geoProv.contains('CAPITAL FEDERAL');
        Boolean sfCaba =
            sfProv.contains('CIUDAD AUTONOMA') ||
            sfProv.contains('CAPITAL FEDERAL') ||
            sfProv == 'CABA';
        return geoCaba && sfCaba;
    }

    private static String normalize(String value) {
        if (value == null) {
            return '';
        }
        String s = value.trim().toUpperCase();
        s = s.replace('Á', 'A').replace('É', 'E').replace('Í', 'I').replace('Ó', 'O').replace('Ú', 'U');
        s = s.replace('Ä', 'A').replace('Ë', 'E').replace('Ï', 'I').replace('Ö', 'O').replace('Ü', 'U');
        s = s.replace('Ñ', 'N').replace('À', 'A').replace('È', 'E').replace('Ì', 'I').replace('Ò', 'O').replace('Ù', 'U');
        return s;
    }

    private static GeoAddress reverseGeocode(Decimal latitude, Decimal longitude) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        req.setEndpoint(
            'https://nominatim.openstreetmap.org/reverse?format=json&addressdetails=1&zoom=14' +
                '&lat=' +
                String.valueOf(latitude) +
                '&lon=' +
                String.valueOf(longitude)
        );
        req.setHeader('User-Agent', 'SembraEvolucion-Salesforce/1.0 (establecimientos; contacto portal)');
        req.setHeader('Accept-Language', 'es');
        req.setTimeout(10000);

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() < 200 || res.getStatusCode() >= 300) {
            return null;
        }

        Map<String, Object> root = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (root == null || !root.containsKey('address')) {
            return null;
        }

        Map<String, Object> address = (Map<String, Object>) root.get('address');
        GeoAddress geo = new GeoAddress();
        geo.countryCode = str(address.get('country_code'));
        if (String.isNotBlank(geo.countryCode)) {
            geo.countryCode = geo.countryCode.toLowerCase();
        }
        geo.state = str(address.get('state'));
        // Partido suele venir como state_district ("Partido de San Isidro") o county
        geo.partido = str(address.get('state_district'));
        if (String.isBlank(geo.partido)) {
            geo.partido = str(address.get('county'));
        }
        geo.town = str(address.get('town'));
        geo.suburb = str(address.get('suburb'));
        geo.village = str(address.get('village'));
        geo.city = str(address.get('city'));
        geo.municipality = str(address.get('municipality'));
        if (String.isBlank(geo.suburb) && address.containsKey('quarter')) {
            geo.suburb = str(address.get('quarter'));
        }
        return geo;
    }

    private static String str(Object value) {
        return value == null ? null : String.valueOf(value);
    }
}
