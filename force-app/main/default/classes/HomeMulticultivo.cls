public without sharing class HomeMulticultivo {

    private static final Integer URGENCIA_DIAS = 15;

    public class HomeData {
        @AuraEnabled public String firstName;
        @AuraEnabled public List<Tarjeta> cultivos;
    }

    public class Tarjeta {
        @AuraEnabled public Cultivo__c cultivo;
        @AuraEnabled public String paramId;
        @AuraEnabled public Decimal saldoHTs;
        @AuraEnabled public Decimal htSinConsumir;
        @AuraEnabled public Decimal htFuturas;
        @AuraEnabled public Decimal htAdquirida;
        @AuraEnabled public String version;
        @AuraEnabled public String pphEstado;
        @AuraEnabled public Boolean cgNeedsRegularizar;
        @AuraEnabled public String faseLabel;
        @AuraEnabled public String faseHito;
        @AuraEnabled public Integer faseDias;
        @AuraEnabled public Boolean faseUrgent;
        @AuraEnabled public Boolean hasFase;
        @AuraEnabled public Decimal pphHectareas;
        @AuraEnabled public Integer pphEstablecimientos;
        @AuraEnabled public String pphPeriod;
        @AuraEnabled public String pphInicioAdhesion;
        @AuraEnabled public String pphFinAdhesion;
        @AuraEnabled public Boolean pphAdhesionProxima;
    }

    @AuraEnabled
    public static HomeData getLoadData() {
        HomeData payload = new HomeData();
        payload.firstName = UserInfo.getFirstName();
        payload.cultivos = new List<Tarjeta>();

        Map<Id, Cultivo__c> mapCultivos = new Map<Id, Cultivo__c>([
            SELECT Id, Name
            FROM Cultivo__c
            WHERE Sembra_Evolucion__c = true
        ]);

        Id productorId = CrearCompraController.getAccount().Id;

        Map<Id, List<Parametro_PPH__c>> paramsPorCultivo = new Map<Id, List<Parametro_PPH__c>>();
        for (Parametro_PPH__c param : [
            SELECT Id, Name, Cultivo__c, CreatedDate,
                   Fecha_Inicio_Adhesion_PPH__c, Fecha_Fin_Adhesion_PPH__c, Fecha_Fin_Rectificacion_2__c
            FROM Parametro_PPH__c
            WHERE Cultivo__c IN :mapCultivos.keySet()
            ORDER BY Fecha_Inicio_Adhesion_PPH__c DESC NULLS LAST, CreatedDate DESC
        ]) {
            if (!paramsPorCultivo.containsKey(param.Cultivo__c)) {
                paramsPorCultivo.put(param.Cultivo__c, new List<Parametro_PPH__c>());
            }
            paramsPorCultivo.get(param.Cultivo__c).add(param);
        }

        Map<Id, Plan_de_Siembra__c> mapPlanesSiembra = new Map<Id, Plan_de_Siembra__c>();
        for (Plan_de_Siembra__c plan : [
            SELECT Id, Parametro_PPH__c, Estado__c
            FROM Plan_de_Siembra__c
            WHERE Parametro_PPH__r.Cultivo__c IN :mapCultivos.keySet()
            AND Estado__c != 'Cancelado'
            AND Productor__c = :productorId
            ORDER BY CreatedDate ASC
        ]) {
            mapPlanesSiembra.put(plan.Parametro_PPH__c, plan);
        }

        Map<Id, Parametro_PPH__c> mapCultivoParametro = new Map<Id, Parametro_PPH__c>();
        for (Id cultivoId : paramsPorCultivo.keySet()) {
            Parametro_PPH__c elegido = pickParametroVigente(
                paramsPorCultivo.get(cultivoId),
                mapPlanesSiembra
            );
            if (elegido != null) {
                mapCultivoParametro.put(cultivoId, elegido);
            }
        }

        Map<Id, Decimal> mapSaldos = new Map<Id, Decimal>();
        for (AggregateResult saldoCultivo : [
            SELECT Cultivo__c cultivo, SUM(Cantidad_con_Signo__c) saldo
            FROM Hectareas_Tecnologicas__c
            WHERE Cultivo__c IN :mapCultivos.keySet()
            AND Productor__c = :productorId
            AND HT_Vigente__c = true
            GROUP BY Cultivo__c
        ]) {
            mapSaldos.put((Id) saldoCultivo.get('cultivo'), (Decimal) saldoCultivo.get('saldo'));
        }

        Set<Id> planesAdheridos = new Map<Id, Plan_de_Siembra__c>(mapPlanesSiembra.values()).keySet();
        Map<Id, Decimal> mapSaldosAdheridos = new Map<Id, Decimal>();
        for (AggregateResult saldoAdherido : [
            SELECT Plan_de_Siembra__c plan, SUM(Cantidad_con_Signo__c) saldo
            FROM Hectareas_Tecnologicas__c
            WHERE Plan_de_Siembra__c IN :planesAdheridos
            AND Productor__c = :productorId
            GROUP BY Plan_de_Siembra__c
        ]) {
            mapSaldosAdheridos.put((Id) saldoAdherido.get('plan'), (Decimal) saldoAdherido.get('saldo'));
        }

        Map<Id, Decimal> mapHaPorPlan = new Map<Id, Decimal>();
        Map<Id, Integer> mapEstPorPlan = new Map<Id, Integer>();
        if (!planesAdheridos.isEmpty()) {
            for (AggregateResult ar : [
                SELECT Establecimiento_PPH__r.Plan_de_Siembra__c planId,
                       SUM(Cantidad_Declarada__c) ha
                FROM Linea_PPH__c
                WHERE Establecimiento_PPH__r.Plan_de_Siembra__c IN :planesAdheridos
                AND Cantidad_Declarada__c > 0
                GROUP BY Establecimiento_PPH__r.Plan_de_Siembra__c
            ]) {
                mapHaPorPlan.put((Id) ar.get('planId'), (Decimal) ar.get('ha'));
            }
            for (AggregateResult ar : [
                SELECT Plan_de_Siembra__c planId, COUNT(Id) cnt
                FROM Establecimiento_PPH__c
                WHERE Plan_de_Siembra__c IN :planesAdheridos
                GROUP BY Plan_de_Siembra__c
            ]) {
                mapEstPorPlan.put((Id) ar.get('planId'), Integer.valueOf(ar.get('cnt')));
            }
        }

        // Mismo criterio que el total de Movimientos HT (ComprasHTController.getResumenBiotecnologiaPorCultivo)
        Map<Id, Decimal> mapHtAdquirida = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Cultivo__c cultivo, SUM(Cantidad_con_Signo__c) saldo
            FROM Hectareas_Tecnologicas__c
            WHERE Cultivo__c IN :mapCultivos.keySet()
            AND Productor__c = :productorId
            AND Origen__c NOT IN ('Semilla Original', 'Semilla Pre Básica', 'PPH')
            AND HT_Vigente__c = true
            GROUP BY Cultivo__c
        ]) {
            Decimal total = (Decimal) ar.get('saldo');
            mapHtAdquirida.put((Id) ar.get('cultivo'), total != null ? total : 0);
        }

        Map<Id, Decimal> mapHtSinConsumir = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Cultivo__c cultivoId, SUM(Saldo_Cuenta__c) total
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productorId
            AND Cultivo__c IN :mapCultivos.keySet()
            AND Campania__c = null
            GROUP BY Cultivo__c
        ]) {
            Decimal total = (Decimal) ar.get('total');
            mapHtSinConsumir.put((Id) ar.get('cultivoId'), total != null ? total : 0);
        }

        Set<Id> cultivosConDeuda = getCultivosConDeuda(mapCultivos.keySet(), productorId);

        Map<Id, Campana_Agricola__c> campanaPorCultivo = getCampanaVigentePorCultivo(mapCultivos.keySet());

        for (Id cultivoId : mapCultivoParametro.keySet()) {
            Parametro_PPH__c param = mapCultivoParametro.get(cultivoId);
            Plan_de_Siembra__c plan = mapPlanesSiembra.get(param.Id);
            String version = resolveVersion(param, plan, Date.today());
            Decimal saldo;
            if (version == 'adherido' || version == 'revision') {
                saldo = mapSaldosAdheridos.get(plan.Id);
                if (saldo == null) saldo = 0;
            } else {
                saldo = mapSaldos.containsKey(cultivoId) ? mapSaldos.get(cultivoId) : 0;
            }

            Decimal htSinConsumir = mapHtSinConsumir.containsKey(cultivoId)
                ? mapHtSinConsumir.get(cultivoId)
                : 0;
            if (htSinConsumir == 0 && version == 'adherido') {
                htSinConsumir = saldo;
            }

            Decimal htFuturas = mapSaldos.containsKey(cultivoId) ? mapSaldos.get(cultivoId) : 0;
            if (htFuturas == null) htFuturas = 0;

            Decimal htAdquirida = mapHtAdquirida.containsKey(cultivoId) ? mapHtAdquirida.get(cultivoId) : 0;

            Tarjeta t = new Tarjeta();
            t.cultivo = mapCultivos.get(cultivoId);
            t.paramId = param.Id;
            t.saldoHTs = saldo;
            t.htSinConsumir = htSinConsumir;
            t.htFuturas = htFuturas;
            t.htAdquirida = htAdquirida;
            t.version = version;
            t.pphEstado = plan != null && version != 'comprar' ? plan.Estado__c : null;
            t.cgNeedsRegularizar = cultivosConDeuda.contains(cultivoId);

            Campana_Agricola__c camp = campanaPorCultivo.get(cultivoId);
            applyFase(t, camp);
            applyUrgenciaPph(t, param, version);

            String period = camp != null ? formatPeriod(camp.Ano__c) : null;
            t.pphPeriod = period;
            t.pphInicioAdhesion = formatDate(param.Fecha_Inicio_Adhesion_PPH__c);
            t.pphAdhesionProxima = param.Fecha_Inicio_Adhesion_PPH__c != null
                && Date.today() < param.Fecha_Inicio_Adhesion_PPH__c;
            t.pphFinAdhesion = formatDate(getFinAdhesion(param));

            if (version == 'adherido' && mapPlanesSiembra.containsKey(param.Id)) {
                Id planId = mapPlanesSiembra.get(param.Id).Id;
                t.pphHectareas = mapHaPorPlan.containsKey(planId) ? mapHaPorPlan.get(planId) : 0;
                t.pphEstablecimientos = mapEstPorPlan.containsKey(planId) ? mapEstPorPlan.get(planId) : 0;
            }

            payload.cultivos.add(t);
        }

        return payload;
    }

    /**
     * Elige el Parametro_PPH de la tarjeta Home por cultivo.
     * Prioridad: Adherido + ventana abierta > ventana abierta > Adherido cerrado >
     * adhesión futura > resto. En empate, evita Name "TEST%" y prefiere inicio más reciente.
     */
    @TestVisible
    private static Parametro_PPH__c pickParametroVigente(
        List<Parametro_PPH__c> params,
        Map<Id, Plan_de_Siembra__c> planesAdheridosPorParam
    ) {
        if (params == null || params.isEmpty()) return null;

        Parametro_PPH__c best = null;
        Integer bestScore = -1;
        Date today = Date.today();

        for (Parametro_PPH__c param : params) {
            Boolean hasAdherido = planesAdheridosPorParam != null
                && planesAdheridosPorParam.containsKey(param.Id);
            Boolean inWindow = isInPphLifecycle(param, today);
            Boolean upcoming = param.Fecha_Inicio_Adhesion_PPH__c != null
                && today < param.Fecha_Inicio_Adhesion_PPH__c;

            Integer score;
            if (hasAdherido && inWindow) {
                score = 400;
            } else if (inWindow) {
                score = 200;
            } else if (hasAdherido) {
                score = 150;
            } else if (upcoming) {
                score = 100;
            } else {
                score = 10;
            }

            if (best == null || score > bestScore || (score == bestScore && isBetterTieBreak(param, best))) {
                best = param;
                bestScore = score;
            }
        }
        return best;
    }

    @TestVisible
    private static Boolean isInPphLifecycle(Parametro_PPH__c param, Date today) {
        if (param == null || param.Fecha_Inicio_Adhesion_PPH__c == null) return false;
        if (today < param.Fecha_Inicio_Adhesion_PPH__c) return false;
        Date finCiclo = getFinCiclo(param);
        if (finCiclo != null && today > finCiclo) {
            return false;
        }
        return true;
    }

    /**
     * Sin plan: se puede adherir entre el inicio y el fin de adhesión (mismo criterio que AdhesionPPH).
     * Con plan (cualquier estado salvo Cancelado, igual que Mis PPH): se muestra hasta el fin del ciclo
     * (adhesión o rectificación 2, la que sea posterior). 'enCurso' = En Preparación, Rectificado, Rechazado, etc.
     */
    @TestVisible
    private static String resolveVersion(Parametro_PPH__c param, Plan_de_Siembra__c plan, Date today) {
        Boolean empezo = param.Fecha_Inicio_Adhesion_PPH__c == null || today >= param.Fecha_Inicio_Adhesion_PPH__c;
        if (!empezo) return 'comprar';

        if (plan != null) {
            Date finCiclo = getFinCiclo(param);
            if (finCiclo != null && today > finCiclo) return 'comprar';
            if (plan.Estado__c == 'Adherido') return 'adherido';
            if (plan.Estado__c == 'En Revisión') return 'revision';
            return 'enCurso';
        }

        Date finAdhesion = getFinAdhesion(param);
        if (finAdhesion != null && today > finAdhesion) return 'comprar';
        return 'adherir';
    }

    private static Date getFinAdhesion(Parametro_PPH__c param) {
        return param.Fecha_Fin_Adhesion_PPH__c != null
            ? param.Fecha_Fin_Adhesion_PPH__c
            : param.Fecha_Fin_Rectificacion_2__c;
    }

    private static Date getFinCiclo(Parametro_PPH__c param) {
        Date finAdhesion = param.Fecha_Fin_Adhesion_PPH__c;
        Date finRect2 = param.Fecha_Fin_Rectificacion_2__c;
        if (finAdhesion == null) return finRect2;
        if (finRect2 == null) return finAdhesion;
        return finAdhesion > finRect2 ? finAdhesion : finRect2;
    }

    private static Boolean isBetterTieBreak(Parametro_PPH__c candidate, Parametro_PPH__c current) {
        Boolean candTest = isTestParam(candidate);
        Boolean currTest = isTestParam(current);
        if (candTest != currTest) return !candTest;

        Date candIni = candidate.Fecha_Inicio_Adhesion_PPH__c;
        Date currIni = current.Fecha_Inicio_Adhesion_PPH__c;
        if (candIni != currIni) {
            if (candIni == null) return false;
            if (currIni == null) return true;
            return candIni > currIni;
        }

        Datetime candCreated = candidate.CreatedDate;
        Datetime currCreated = current.CreatedDate;
        if (candCreated == null || currCreated == null) return false;
        return candCreated > currCreated;
    }

    private static Boolean isTestParam(Parametro_PPH__c param) {
        return param != null
            && String.isNotBlank(param.Name)
            && param.Name.toUpperCase().startsWith('TEST');
    }

    /**
     * Adhesión PPH pendiente que cierra en 15 días o menos: marca la franja como urgente,
     * salvo que el cierre de la ventana de HT sea igual o más próximo.
     */
    @TestVisible
    private static void applyUrgenciaPph(Tarjeta t, Parametro_PPH__c param, String version) {
        if (version != 'adherir' || param == null || param.Fecha_Fin_Adhesion_PPH__c == null) return;
        Integer dias = Date.today().daysBetween(param.Fecha_Fin_Adhesion_PPH__c);
        if (dias < 0 || dias > URGENCIA_DIAS) return;
        if (t.faseUrgent == true && t.faseDias != null && t.faseDias <= dias) return;

        if (t.hasFase != true) {
            t.hasFase = true;
            t.faseLabel = 'Adhesión PPH';
        }
        t.faseUrgent = true;
        t.faseDias = dias;
        t.faseHito = 'Cierra la adhesión PPH el ' + formatDate(param.Fecha_Fin_Adhesion_PPH__c);
    }

    private static void applyFase(Tarjeta t, Campana_Agricola__c camp) {
        t.hasFase = false;
        t.faseUrgent = false;
        t.faseDias = null;
        if (camp == null) return;

        String period = formatPeriod(camp.Ano__c);

        if (camp.Estado__c == 'En Preparación' && camp.Fecha_de_Inicio__c != null) {
            t.hasFase = true;
            t.faseLabel = 'Precampaña ' + period;
        } else if (camp.Estado__c == 'Activa') {
            t.hasFase = true;
            t.faseLabel = 'Campaña ' + period;
        }
    }

    /** Más reciente ya iniciada (Activa o En Preparación); si no hay, la próxima en preparación. */
    public static Map<Id, Campana_Agricola__c> getCampanaVigentePorCultivo(Set<Id> cultivoIds) {
        Map<Id, Campana_Agricola__c> iniciadas = new Map<Id, Campana_Agricola__c>();
        Map<Id, Campana_Agricola__c> proximas = new Map<Id, Campana_Agricola__c>();
        Date hoy = Date.today();
        for (Campana_Agricola__c camp : [
            SELECT Id, Cultivo__c, Name, Ano__c, Estado__c, Fecha_de_Inicio__c, Fecha_de_Fin__c
            FROM Campana_Agricola__c
            WHERE Cultivo__c IN :cultivoIds
            AND (Estado__c = 'Activa' OR Estado__c = 'En Preparación')
            ORDER BY Fecha_de_Inicio__c DESC NULLS LAST
        ]) {
            Boolean iniciada = camp.Fecha_de_Inicio__c == null || camp.Fecha_de_Inicio__c <= hoy;
            if (iniciada) {
                if (!iniciadas.containsKey(camp.Cultivo__c)) iniciadas.put(camp.Cultivo__c, camp);
            } else {
                proximas.put(camp.Cultivo__c, camp);
            }
        }
        Map<Id, Campana_Agricola__c> result = new Map<Id, Campana_Agricola__c>(proximas);
        result.putAll(iniciadas);
        return result;
    }

    /**
     * Cultivos con alguna campaña en negativo, con el mismo alcance que muestra Cuenta Granaria
     * (CuentaGranaria.getCampanasVisiblesPorCultivo: actual + 2 anteriores) y sin las campañas en PPH.
     */
    @TestVisible
    private static Set<Id> getCultivosConDeuda(Set<Id> cultivoIds, Id productorId) {
        Set<Id> result = new Set<Id>();
        if (cultivoIds == null || cultivoIds.isEmpty() || productorId == null) return result;

        Set<Id> campanasVisibles = new Set<Id>();
        Map<Id, Id> cultivoPorCampana = new Map<Id, Id>();
        for (List<Campana_Agricola__c> campanas : CuentaGranaria.getCampanasVisiblesPorCultivo(cultivoIds).values()) {
            for (Campana_Agricola__c c : campanas) {
                campanasVisibles.add(c.Id);
                cultivoPorCampana.put(c.Id, c.Cultivo__c);
            }
        }
        if (campanasVisibles.isEmpty()) return result;

        Set<Id> campanasConPph = new Set<Id>();
        for (Plan_de_Siembra__c plan : [
            SELECT Parametro_PPH__r.Campana__c
            FROM Plan_de_Siembra__c
            WHERE Productor__c = :productorId
            AND Estado__c = 'Adherido'
            AND Parametro_PPH__r.Campana__c IN :campanasVisibles
        ]) {
            campanasConPph.add(plan.Parametro_PPH__r.Campana__c);
        }

        for (AggregateResult ar : [
            SELECT Cultivo__c cultivoId
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productorId
            AND Cultivo__c IN :cultivoIds
            AND Campania__c IN :campanasVisibles
            AND Campania__c NOT IN :campanasConPph
            AND Saldo_Cuenta__c < 0
            AND PPH_Adherida__c = false
            GROUP BY Cultivo__c
        ]) {
            result.add((Id) ar.get('cultivoId'));
        }

        // La tarjeta de campaña de CG muestra la suma de toneladas por plataforma, que puede ser
        // negativa aunque no exista (o no esté al día) el registro de Cuenta Granaria.
        Set<Id> campanasSinPph = campanasVisibles.clone();
        campanasSinPph.removeAll(campanasConPph);
        Set<String> plataformasConPph = new Set<String>();
        for (Cuenta_Granaria__c cg : [
            SELECT Campania__c, Tecnologia__c
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productorId
            AND Campania__c IN :campanasSinPph
            AND PPH_Adherida__c = true
        ]) {
            plataformasConPph.add(cg.Campania__c + '|' + cg.Tecnologia__c);
        }
        Map<String, Decimal> totales = CuentaGranaria.getTotalesPorCampanaYPlataforma(productorId, campanasSinPph);
        for (String key : totales.keySet()) {
            if (totales.get(key) >= 0 || plataformasConPph.contains(key)) continue;
            Id cultivoId = cultivoPorCampana.get((Id) key.substringBefore('|'));
            if (cultivoId != null) result.add(cultivoId);
        }
        return result;
    }

    public static String formatPeriod(String ano) {
        if (String.isBlank(ano) || !ano.isNumeric()) return ano;
        Integer y = Integer.valueOf(ano);
        String a = String.valueOf(Math.mod(y, 100)).leftPad(2, '0');
        String b = String.valueOf(Math.mod(y + 1, 100)).leftPad(2, '0');
        return a + '/' + b;
    }

    private static String formatDate(Date d) {
        if (d == null) return '';
        String dd = String.valueOf(d.day()).leftPad(2, '0');
        String mm = String.valueOf(d.month()).leftPad(2, '0');
        String yy = String.valueOf(Math.mod(d.year(), 100)).leftPad(2, '0');
        return dd + '/' + mm + '/' + yy;
    }
}
