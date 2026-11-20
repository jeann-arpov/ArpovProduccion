public with sharing class ReporteVarietalController {

    private static final String CULTIVO = 'TRIGO';
    private static final String SIN_VARIEDAD = 'Sin variedad';
    private static final String SIN_SEMILLERO = 'Sin semillero';

    @AuraEnabled
    public static Opciones getOpciones(Id productorId) {
        validarProductor(productorId);

        Opciones opciones = new Opciones();
        opciones.campanas = new List<Opcion>();
        Set<Id> campaniaIds = new Set<Id>();
        for (AggregateResult fila : [
            SELECT Cuenta_Granaria__r.Campania__c campaniaId
            FROM Tonelada__c
            WHERE Cuenta_Granaria__r.Productor__c = :productorId
                AND Cuenta_Granaria__r.Cultivo__r.Name = :CULTIVO
                AND Cuenta_Granaria__r.Campania__c != null
                AND Variedad__c != null
                AND Fecha_Inicio__c <= TODAY
                AND Etapa__c != 'Pendiente'
                AND Origen__c != 'Balance Anual'
            GROUP BY Cuenta_Granaria__r.Campania__c
        ]) {
            campaniaIds.add((Id) fila.get('campaniaId'));
        }

        Map<Id, Campana_Agricola__c> campanas = campaniaIds.isEmpty()
            ? new Map<Id, Campana_Agricola__c>()
            : new Map<Id, Campana_Agricola__c>([
                SELECT Id, Name, Ano__c, Cultivo__c
                FROM Campana_Agricola__c
                WHERE Id IN :campaniaIds
            ]);
        Set<Id> cultivoIds = new Set<Id>();
        for (Campana_Agricola__c campania : campanas.values()) {
            if (campania.Cultivo__c != null) {
                cultivoIds.add(campania.Cultivo__c);
            }
        }

        Campana_Agricola__c actual = campaniaActual(cultivoIds);

        List<Campana_Agricola__c> ordenadas = campanas.values();
        ordenadas.sort(new CampaniaPorAnoDesc());
        for (Campana_Agricola__c campania : ordenadas) {
            opciones.campanas.add(new Opcion(campania.Id, periodo(campania)));
        }
        if (actual != null && campanas.containsKey(actual.Id)) {
            opciones.campaniaActual = actual.Id;
        } else if (!opciones.campanas.isEmpty()) {
            opciones.campaniaActual = opciones.campanas[0].id;
        }

        Set<String> marcas = new Set<String>();
        Set<Id> variedadIds = new Set<Id>();
        for (AggregateResult fila : [
            SELECT Variedad__c variedadId
            FROM Tonelada__c
            WHERE Cuenta_Granaria__r.Productor__c = :productorId
                AND Cuenta_Granaria__r.Cultivo__r.Name = :CULTIVO
                AND Variedad__c != null
                AND Fecha_Inicio__c <= TODAY
                AND Etapa__c != 'Pendiente'
                AND Origen__c != 'Balance Anual'
            GROUP BY Variedad__c
        ]) {
            variedadIds.add((Id) fila.get('variedadId'));
        }
        for (Variedad__c variedad : consultarVariedades(variedadIds).values()) {
            marcas.add(marca(variedad));
        }
        opciones.semilleros = new List<Opcion>();
        for (String nombre : marcas) {
            opciones.semilleros.add(new Opcion(nombre, nombre));
        }
        opciones.semilleros.sort();
        return opciones;
    }

    @AuraEnabled
    public static Reporte getReporte(Id productorId, Id campaniaId, String semillero, String estado) {
        validarProductor(productorId);
        if (campaniaId == null) {
            Campana_Agricola__c actual = campaniaActual(cultivosDelProductor(productorId));
            campaniaId = actual == null ? null : actual.Id;
        }

        Map<String, Fila> porVariedad = new Map<String, Fila>();
        if (campaniaId != null) {
            String base = 'SELECT Variedad__c variedadId, Origen__c origen, SUM(Cantidad_con_Signo__c) toneladas '
                + 'FROM Tonelada__c '
                + 'WHERE Cuenta_Granaria__r.Productor__c = :productorId '
                + 'AND Cuenta_Granaria__r.Cultivo__r.Name = :CULTIVO '
                + 'AND Cuenta_Granaria__r.Campania__c = :campaniaId '
                + 'AND Fecha_Inicio__c <= TODAY '
                + 'AND Etapa__c != \'Pendiente\' '
                + 'AND Origen__c != \'Balance Anual\' ';
            // Dos consultas: un solo GROUP BY Variedad+Origen netea Compra SF +/−. No unificar. SE-157.
            acumular(porVariedad, Database.query(base + 'AND Cantidad_con_Signo__c >= 0 GROUP BY Variedad__c, Origen__c'));
            acumular(porVariedad, Database.query(base + 'AND Cantidad_con_Signo__c < 0 GROUP BY Variedad__c, Origen__c'));
        }

        Set<Id> variedadIds = new Set<Id>();
        for (Fila fila : porVariedad.values()) {
            if (fila.variedadId != null) {
                variedadIds.add(fila.variedadId);
            }
        }
        Map<Id, Variedad__c> variedades = consultarVariedades(variedadIds);

        Reporte reporte = new Reporte();
        reporte.filas = new List<Fila>();
        reporte.credito = 0;
        reporte.debito = 0;
        for (Fila fila : porVariedad.values()) {
            Variedad__c variedad = fila.variedadId == null ? null : variedades.get(fila.variedadId);
            fila.variedad = variedad == null || String.isBlank(variedad.Name) ? SIN_VARIEDAD : variedad.Name;
            fila.semillero = variedad == null ? SIN_SEMILLERO : marca(variedad);
            fila.saldo = fila.credito + fila.debito;
            fila.estado = EstadoVarietal.calcular(fila.saldo, fila.entregas);

            if (String.isNotBlank(semillero) && fila.semillero != semillero) {
                continue;
            }
            if (String.isNotBlank(estado) && fila.estado != estado) {
                continue;
            }
            reporte.filas.add(fila);
            reporte.credito += fila.credito;
            reporte.debito += fila.debito;
        }
        reporte.filas.sort();
        reporte.saldo = reporte.credito + reporte.debito;
        reporte.expedientesAbiertos = contarExpedientes(productorId, campaniaId, semillero);
        return reporte;
    }

    private static void acumular(Map<String, Fila> porVariedad, List<AggregateResult> filas) {
        for (AggregateResult ar : filas) {
            Id variedadId = (Id) ar.get('variedadId');
            String clave = variedadId == null ? SIN_VARIEDAD : String.valueOf(variedadId);
            Fila fila = porVariedad.get(clave);
            if (fila == null) {
                fila = new Fila();
                fila.variedadId = variedadId;
                porVariedad.put(clave, fila);
            }
            Decimal toneladas = ar.get('toneladas') == null ? 0 : (Decimal) ar.get('toneladas');
            String origen = (String) ar.get('origen');
            if (toneladas >= 0) {
                fila.credito += toneladas;
            } else {
                fila.debito += toneladas;
            }
            if (origen == 'Compra SF') {
                // Compra SF + y − por separado. No hacer compraSf += toneladas con ambos
                // signos: el neto esconde las anulaciones (CG-9595: tarjeta 2440 vs columna 1892). SE-157.
                if (toneladas >= 0) {
                    fila.compraSf += toneladas;
                } else {
                    fila.compraSfDebito += toneladas;
                }
            } else if (origen == 'Compra HT') {
                fila.compraHt += toneladas;
            } else if (origen == 'Cesión HT') {
                fila.cesion += toneladas;
            } else if (EstadoVarietal.esEntrega(origen)) {
                fila.entregas += toneladas;
            } else {
                fila.otros += toneladas;
            }
        }
    }

    private static Campana_Agricola__c campaniaActual(Set<Id> cultivoIds) {
        if (cultivoIds.isEmpty()) {
            for (Cultivo__c cultivo : [SELECT Id FROM Cultivo__c WHERE Name = :CULTIVO]) {
                cultivoIds.add(cultivo.Id);
            }
        }
        if (cultivoIds.isEmpty()) {
            return null;
        }
        Campana_Agricola__c actual;
        for (List<Campana_Agricola__c> visibles : CuentaGranaria.getCampanasVisiblesPorCultivo(cultivoIds).values()) {
            if (visibles.isEmpty()) {
                continue;
            }
            Campana_Agricola__c candidata = visibles[0];
            if (actual == null || anio(candidata) > anio(actual)) {
                actual = candidata;
            }
        }
        return actual;
    }

    private static Set<Id> cultivosDelProductor(Id productorId) {
        Set<Id> cultivoIds = new Set<Id>();
        for (Cuenta_Granaria__c cg : [
            SELECT Cultivo__c
            FROM Cuenta_Granaria__c
            WHERE Productor__c = :productorId AND Cultivo__r.Name = :CULTIVO
            LIMIT 50
        ]) {
            cultivoIds.add(cg.Cultivo__c);
        }
        return cultivoIds;
    }

    private static Map<Id, Variedad__c> consultarVariedades(Set<Id> variedadIds) {
        if (variedadIds.isEmpty()) {
            return new Map<Id, Variedad__c>();
        }
        return new Map<Id, Variedad__c>([
            SELECT Name, Nombre_Obtentor__c, Obtentor_Comercializa__r.Nombre_Obtentor__c
            FROM Variedad__c
            WHERE Id IN :variedadIds
        ]);
    }

    private static String marca(Variedad__c variedad) {
        String comercial = variedad.Obtentor_Comercializa__r?.Nombre_Obtentor__c;
        if (String.isNotBlank(comercial)) {
            return comercial;
        }
        return String.isBlank(variedad.Nombre_Obtentor__c) ? SIN_SEMILLERO : variedad.Nombre_Obtentor__c;
    }

    private static String periodo(Campana_Agricola__c campania) {
        String ano = campania.Ano__c;
        if (String.isBlank(ano) || !ano.isNumeric() || ano.length() != 4) {
            return campania.Name;
        }
        Integer valor = Integer.valueOf(ano);
        return String.valueOf(valor).right(2) + '/' + String.valueOf(valor + 1).right(2);
    }

    private static Integer anio(Campana_Agricola__c campania) {
        return String.isNotBlank(campania.Ano__c) && campania.Ano__c.isNumeric() ? Integer.valueOf(campania.Ano__c) : 0;
    }

    private static void validarProductor(Id productorId) {
        if (productorId == null || productorId.getSobjectType() != Account.SObjectType) {
            throw error('El reporte varietal se abre desde la cuenta del productor.');
        }
    }

    private static Integer contarExpedientes(Id productorId, Id campaniaId, String semillero) {
        String consulta = 'SELECT COUNT() FROM Expediente_de_Negativos__c '
            + 'WHERE Cuenta__c = :productorId '
            + 'AND Estado_de_la_Etapa__c != \'Finalizado\' '
            + 'AND (Cuenta_Granaria__r.Cultivo__r.Name = :CULTIVO OR Campania__r.Cultivo__r.Name = :CULTIVO) ';
        if (campaniaId != null) {
            consulta += 'AND (Campania__c = :campaniaId OR Cuenta_Granaria__r.Campania__c = :campaniaId) ';
        }
        if (String.isBlank(semillero)) {
            return Database.countQuery(consulta);
        }
        try {
            return Database.countQuery(consulta
                + 'AND (Detalle_Variedad_CG__r.Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c = :semillero '
                + 'OR Cuenta_Granaria__r.Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c = :semillero)');
        } catch (QueryException e) {
            return Database.countQuery(consulta
                + 'AND Cuenta_Granaria__r.Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c = :semillero');
        }
    }

    private static AuraHandledException error(String mensaje) {
        AuraHandledException ex = new AuraHandledException(mensaje);
        ex.setMessage(mensaje);
        return ex;
    }

    private class CampaniaPorAnoDesc implements Comparator<Campana_Agricola__c> {
        public Integer compare(Campana_Agricola__c a, Campana_Agricola__c b) {
            return anio(b) - anio(a);
        }
    }

    public class Opciones {
        @AuraEnabled public List<Opcion> campanas;
        @AuraEnabled public List<Opcion> semilleros;
        @AuraEnabled public String campaniaActual;
    }

    public class Opcion implements Comparable {
        @AuraEnabled public String id;
        @AuraEnabled public String nombre;

        public Opcion(String id, String nombre) {
            this.id = id;
            this.nombre = nombre;
        }

        public Integer compareTo(Object otro) {
            Opcion opcion = (Opcion) otro;
            String a = this.nombre == null ? '' : this.nombre;
            String b = opcion.nombre == null ? '' : opcion.nombre;
            return a.compareTo(b);
        }
    }

    public class Reporte {
        @AuraEnabled public Decimal credito;
        @AuraEnabled public Decimal debito;
        @AuraEnabled public Decimal saldo;
        @AuraEnabled public Integer expedientesAbiertos;
        @AuraEnabled public List<Fila> filas;
    }

    public class Fila implements Comparable {
        @AuraEnabled public String variedadId;
        @AuraEnabled public String variedad;
        @AuraEnabled public String semillero;
        @AuraEnabled public Decimal compraSf = 0;
        @AuraEnabled public Decimal compraSfDebito = 0;
        @AuraEnabled public Decimal compraHt = 0;
        @AuraEnabled public Decimal cesion = 0;
        @AuraEnabled public Decimal entregas = 0;
        @AuraEnabled public Decimal otros = 0;
        @AuraEnabled public Decimal credito = 0;
        @AuraEnabled public Decimal debito = 0;
        @AuraEnabled public Decimal saldo = 0;
        @AuraEnabled public String estado;

        public Integer compareTo(Object otro) {
            Fila fila = (Fila) otro;
            Integer grupo = grupo(this.estado) - grupo(fila.estado);
            if (grupo != 0) {
                return grupo;
            }
            if (this.estado == EstadoVarietal.DEBE_REGULARIZAR && this.saldo != fila.saldo) {
                return this.saldo < fila.saldo ? -1 : 1;
            }
            String a = this.variedad == null ? '' : this.variedad;
            String b = fila.variedad == null ? '' : fila.variedad;
            return a.compareTo(b);
        }
    }

    private static Integer grupo(String estado) {
        if (estado == EstadoVarietal.DEBE_REGULARIZAR) return 0;
        if (estado == EstadoVarietal.EN_REGLA) return 1;
        return 2;
    }
}
