public without sharing class misEstablecimientosController {
    public class EstRow {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public Decimal lat;
        @AuraEnabled public Decimal lng;
        @AuraEnabled public Boolean vigente;
        @AuraEnabled public String cultivo;
        @AuraEnabled public String origen;
        @AuraEnabled public String localidad;
        @AuraEnabled public String provincia;
        @AuraEnabled public Decimal superficie;
        @AuraEnabled public Decimal superficieSinSembrar;
        @AuraEnabled public Boolean hasHt;
        @AuraEnabled public Boolean adheridoPph;
    }

    @AuraEnabled
    public static List<EstRow> getEstablecimientos() {
        Id userId = UserInfo.getUserId();
        Id accId = [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1][0].AccountId;

        List<Establecimiento__c> establecimientos = [
            SELECT
                Id,
                Name,
                Origen__c,
                Localidad__r.Name,
                Provincia__c,
                Coordenadas__Latitude__s,
                Coordenadas__Longitude__s,
                Vigente__c,
                Cultivo__r.Name
            FROM Establecimiento__c
            WHERE Productor__c = :accId
            ORDER BY Name ASC
            LIMIT 200
        ];

        Set<Id> withHt = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Establecimiento_PPH__r.Establecimiento__c estId
            FROM Linea_PPH__c
            WHERE
                Establecimiento_PPH__r.Establecimiento__r.Productor__c = :accId
                AND Cantidad_Declarada__c > 0
            GROUP BY Establecimiento_PPH__r.Establecimiento__c
        ]) {
            Id estId = (Id) ar.get('estId');
            if (estId != null) {
                withHt.add(estId);
            }
        }

        Set<Id> adheridos = new Set<Id>();
        Map<Id, Decimal> superficieByEst = new Map<Id, Decimal>();
        Map<Id, Decimal> sinSembrarByEst = new Map<Id, Decimal>();
        Map<Id, Set<String>> cultivosByEst = new Map<Id, Set<String>>();

        for (Establecimiento_PPH__c ep : [
            SELECT
                Establecimiento__c,
                Total_a_Entregar__c,
                Cantidad_Variedad_No_SE__c,
                Plan_de_Siembra__r.Estado__c,
                Plan_de_Siembra__r.Parametro_PPH__r.Cultivo__r.Name
            FROM Establecimiento_PPH__c
            WHERE
                Establecimiento__r.Productor__c = :accId
                AND Plan_de_Siembra__r.Estado__c IN (
                    'Adherido',
                    'Certificado',
                    'En Preparación',
                    'Rectificado',
                    'Vencido'
                )
        ]) {
            if (ep.Establecimiento__c == null) {
                continue;
            }

            String estado = ep.Plan_de_Siembra__r?.Estado__c;
            if (estado == 'Adherido' || estado == 'Certificado') {
                adheridos.add(ep.Establecimiento__c);
            }

            Decimal se = ep.Total_a_Entregar__c != null ? ep.Total_a_Entregar__c : 0;
            Decimal noSe = ep.Cantidad_Variedad_No_SE__c != null ? ep.Cantidad_Variedad_No_SE__c : 0;

            Decimal currentSup = superficieByEst.containsKey(ep.Establecimiento__c)
                ? superficieByEst.get(ep.Establecimiento__c)
                : 0;
            Decimal currentSin = sinSembrarByEst.containsKey(ep.Establecimiento__c)
                ? sinSembrarByEst.get(ep.Establecimiento__c)
                : 0;
            superficieByEst.put(ep.Establecimiento__c, currentSup + se + noSe);
            sinSembrarByEst.put(ep.Establecimiento__c, currentSin + noSe);

            String cultivoName = ep.Plan_de_Siembra__r?.Parametro_PPH__r?.Cultivo__r?.Name;
            if (String.isNotBlank(cultivoName)) {
                if (!cultivosByEst.containsKey(ep.Establecimiento__c)) {
                    cultivosByEst.put(ep.Establecimiento__c, new Set<String>());
                }
                cultivosByEst.get(ep.Establecimiento__c).add(cultivoName);
            }
        }

        List<EstRow> rows = new List<EstRow>();
        for (Establecimiento__c est : establecimientos) {
            EstRow row = new EstRow();
            row.id = est.Id;
            row.name = est.Name;
            row.origen = est.Origen__c;
            row.localidad = est.Localidad__r != null ? est.Localidad__r.Name : null;
            row.provincia = est.Provincia__c;
            row.lat = est.Coordenadas__Latitude__s;
            row.lng = est.Coordenadas__Longitude__s;
            row.vigente = est.Vigente__c;
            row.hasHt = withHt.contains(est.Id);
            row.adheridoPph = adheridos.contains(est.Id);
            row.superficie = superficieByEst.get(est.Id);
            row.superficieSinSembrar = sinSembrarByEst.get(est.Id);

            Set<String> cultivos = cultivosByEst.get(est.Id);
            if (cultivos != null && !cultivos.isEmpty()) {
                List<String> sorted = new List<String>(cultivos);
                sorted.sort();
                row.cultivo = String.join(sorted, ' · ');
            } else if (est.Cultivo__r != null) {
                row.cultivo = est.Cultivo__r.Name;
            }

            rows.add(row);
        }
        return rows;
    }
}
