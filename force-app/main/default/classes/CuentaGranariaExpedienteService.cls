public without sharing class CuentaGranariaExpedienteService {

    public class ExpedienteCgException extends Exception {}

    public static Id generarExpedientePorNombre(String cuentaGranariaName) {
        if (String.isBlank(cuentaGranariaName)) {
            throw new ExpedienteCgException('Debe indicar el Name de la Cuenta Granaria.');
        }

        List<Cuenta_Granaria__c> cuentas = [
            SELECT Id, Name, Productor__c, Campania__c, Es_Carga_Manual__c, Saldo_Cuenta__c
            FROM Cuenta_Granaria__c
            WHERE Name = :cuentaGranariaName.trim()
            LIMIT 2
        ];

        if (cuentas.isEmpty()) {
            throw new ExpedienteCgException(
                'No se encontró Cuenta Granaria con Name: ' + cuentaGranariaName
            );
        }
        if (cuentas.size() > 1) {
            throw new ExpedienteCgException(
                'Hay más de una Cuenta Granaria con Name: ' + cuentaGranariaName
            );
        }

        return crearOActualizarExpediente(cuentas[0]);
    }

    private static Id crearOActualizarExpediente(Cuenta_Granaria__c cg) {
        if (cg.Es_Carga_Manual__c != true) {
            throw new ExpedienteCgException(
                'La Cuenta Granaria ' + cg.Name + ' no es de carga manual.'
            );
        }
        if (cg.Saldo_Cuenta__c == null || cg.Saldo_Cuenta__c >= -3) {
            throw new ExpedienteCgException(
                'La Cuenta Granaria ' + cg.Name + ' debe tener saldo menor a -3.'
            );
        }

        Decimal saldoNegativo = cg.Saldo_Cuenta__c;
        List<Expediente_de_Negativos__c> expedientesActivos = [
            SELECT Id, Saldo_Expediente__c
            FROM Expediente_de_Negativos__c
            WHERE Cuenta_Granaria__c = :cg.Id
                AND Estado_de_la_Etapa__c != 'Finalizado'
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!expedientesActivos.isEmpty()) {
            Expediente_de_Negativos__c expedienteActivo = expedientesActivos[0];
            expedienteActivo.Saldo_Expediente__c = saldoNegativo;
            update expedienteActivo;
            vincularExpedienteEnCg(cg.Id, expedienteActivo.Id);
            return expedienteActivo.Id;
        }

        Sembra_Evolucion__c config = Sembra_Evolucion__c.getInstance();
        Id obtentorId = (config != null && config.Corteva_30_Id__c != null)
            ? Id.valueOf(config.Corteva_30_Id__c)
            : null;

        Expediente_de_Negativos__c nuevoExpediente = new Expediente_de_Negativos__c(
            Campania__c = cg.Campania__c,
            Cuenta__c = cg.Productor__c,
            Cuenta_Granaria__c = cg.Id,
            Saldo_Previo_al_Expediente__c = saldoNegativo,
            Saldo_Expediente__c = saldoNegativo,
            Tipo_expendiente__c = 'EXP',
            Estado_de_la_Etapa__c = 'No empezado',
            Etapa__c = 'Llamar',
            Fecha_Cambio_Etapa__c = Date.today(),
            Gestionar__c = true,
            Obtentor__c = obtentorId
        );
        insert nuevoExpediente;
        vincularExpedienteEnCg(cg.Id, nuevoExpediente.Id);
        return nuevoExpediente.Id;
    }

    private static void vincularExpedienteEnCg(Id cgId, Id expedienteId) {
        if (cgId == null || expedienteId == null) {
            return;
        }
        vincularToneladasYMovimientosPorCg(new Map<Id, Id>{ cgId => expedienteId });
    }

    /**
     * Vincula toneladas y MBT a partir de un mapa CG → expediente.
     * Si la tonelada ya tiene otro expediente (p. ej. legacy sin CG), lo conserva en Expediente_de_Origen__c.
     * No modifica TN ni MBT que ya tengan expediente PRI o SEC.
     */
    public static VinculacionExpedienteResult vincularToneladasYMovimientosPorCg(Map<Id, Id> expedientePorCg) {
        return vincularPorMapaExpedientePorCg(expedientePorCg);
    }

    /**
     * Vincula toneladas y MBT para todos los expedientes no finalizados con Cuenta Granaria.
     * Si hay más de un expediente activo por CG, usa el más reciente.
     */
    public static VinculacionExpedienteResult vincularToneladasYMovimientosExpedientesNoFinalizados() {
        Map<Id, Id> expedientePorCg = new Map<Id, Id>();
        for (Expediente_de_Negativos__c exp : [
            SELECT Id, Cuenta_Granaria__c, CreatedDate
            FROM Expediente_de_Negativos__c
            WHERE Estado_de_la_Etapa__c != 'Finalizado'
                AND Cuenta_Granaria__c != null
            ORDER BY CreatedDate DESC
        ]) {
            if (!expedientePorCg.containsKey(exp.Cuenta_Granaria__c)) {
                expedientePorCg.put(exp.Cuenta_Granaria__c, exp.Id);
            }
        }

        return vincularPorMapaExpedientePorCg(expedientePorCg);
    }

    /**
     * Vincula toneladas de la cuenta granaria del expediente y su Movimiento BolsaTech.
     * Completa Expediente_de_Negativos__c cuando está null.
     * No sobrescribe TN ni MBT que ya tengan expediente PRI o SEC.
     */
    public static VinculacionExpedienteResult vincularToneladasYMovimientosPorNombresExpediente(
        Set<String> nombresExpediente
    ) {
        if (nombresExpediente == null || nombresExpediente.isEmpty()) {
            throw new ExpedienteCgException('Debe indicar al menos un Name de expediente.');
        }

        Map<Id, Id> expedientePorCg = new Map<Id, Id>();
        for (Expediente_de_Negativos__c exp : [
            SELECT Id, Name, Cuenta_Granaria__c
            FROM Expediente_de_Negativos__c
            WHERE Name IN :nombresExpediente
                AND Cuenta_Granaria__c != null
        ]) {
            expedientePorCg.put(exp.Cuenta_Granaria__c, exp.Id);
        }

        return vincularPorMapaExpedientePorCg(expedientePorCg);
    }

    /**
     * Completa Expediente_de_Negativos__c en MBT tomando el valor de su tonelada
     * (vía Mov_BolsaTech__c en la TN o vía TN_Id__c en el MBT) cuando el movimiento no tiene expediente.
     */
    public static VinculacionExpedienteResult completarExpedienteMbtDesdeTonelada() {
        VinculacionExpedienteResult resultado = completarExpedienteMbtDesdeToneladasEnCgs(null);
        VinculacionExpedienteResult desdeTnId = completarExpedienteMbtDesdeTnIdEnCgs(null, null);
        resultado.expedientesEncontrados += desdeTnId.expedientesEncontrados;
        resultado.movimientosActualizados += desdeTnId.movimientosActualizados;
        resultado.errores += desdeTnId.errores;
        return resultado;
    }

    /**
     * Completa expediente en MBT sin expediente que tengan TN_Id__c apuntando a una tonelada con expediente.
     */
    public static VinculacionExpedienteResult completarExpedienteMbtDesdeTnId() {
        return completarExpedienteMbtDesdeTnId(null);
    }

    /**
     * @param limite Máximo de MBT a procesar (null = sin límite).
     */
    public static VinculacionExpedienteResult completarExpedienteMbtDesdeTnId(Integer limite) {
        return completarExpedienteMbtDesdeTnIdEnCgs(null, limite);
    }

    /**
     * Copia Expediente_de_Negativos__c de toneladas concretas a su MBT (Mov_BolsaTech__c o TN_Id__c).
     * No sobrescribe MBT con expediente PRI o SEC.
     */
    public static VinculacionExpedienteResult sincronizarMbtDesdeToneladas(Set<Id> toneladaIds) {
        VinculacionExpedienteResult resultado = new VinculacionExpedienteResult();
        if (toneladaIds == null || toneladaIds.isEmpty()) {
            return resultado;
        }

        Map<Id, Id> expedientePorMbt = new Map<Id, Id>();
        for (Tonelada__c tn : [
            SELECT Id, Mov_BolsaTech__c, Expediente_de_Negativos__c,
                   Expediente_de_Negativos__r.Tipo_expendiente__c
            FROM Tonelada__c
            WHERE Id IN :toneladaIds
                AND Expediente_de_Negativos__c != null
        ]) {
            Boolean tnTienePriOSec = tn.Expediente_de_Negativos__c != null
                && esExpedientePriOSec(tn.Expediente_de_Negativos__r.Tipo_expendiente__c);
            if (tn.Mov_BolsaTech__c != null && !tnTienePriOSec) {
                expedientePorMbt.put(tn.Mov_BolsaTech__c, tn.Expediente_de_Negativos__c);
            }
        }

        List<Movimiento_BolsaTech__c> movimientosAActualizar = new List<Movimiento_BolsaTech__c>();
        if (!expedientePorMbt.isEmpty()) {
            for (Movimiento_BolsaTech__c mbt : [
                SELECT Id, Expediente_de_Negativos__c, Expediente_de_Negativos__r.Tipo_expendiente__c
                FROM Movimiento_BolsaTech__c
                WHERE Id IN :expedientePorMbt.keySet()
            ]) {
                Movimiento_BolsaTech__c mbtActualizado = prepararMovimientoConExpediente(
                    mbt,
                    expedientePorMbt.get(mbt.Id)
                );
                if (mbtActualizado != null) {
                    movimientosAActualizar.add(mbtActualizado);
                }
            }
        }

        for (Movimiento_BolsaTech__c mbt : [
            SELECT Id, Expediente_de_Negativos__c, Expediente_de_Negativos__r.Tipo_expendiente__c,
                   TN_Id__c, TN_Id__r.Expediente_de_Negativos__c,
                   TN_Id__r.Expediente_de_Negativos__r.Tipo_expendiente__c
            FROM Movimiento_BolsaTech__c
            WHERE TN_Id__c IN :toneladaIds
                AND Expediente_de_Negativos__c = null
                AND TN_Id__r.Expediente_de_Negativos__c != null
        ]) {
            Movimiento_BolsaTech__c mbtActualizado = prepararMovimientoConExpediente(
                mbt,
                mbt.TN_Id__r.Expediente_de_Negativos__c
            );
            if (mbtActualizado != null) {
                movimientosAActualizar.add(mbtActualizado);
            }
        }

        resultado.expedientesEncontrados = movimientosAActualizar.size();
        if (movimientosAActualizar.isEmpty()) {
            return resultado;
        }

        Database.SaveResult[] mbtResults = Database.update(movimientosAActualizar, false);
        for (Database.SaveResult sr : mbtResults) {
            if (sr.isSuccess()) {
                resultado.movimientosActualizados++;
            } else {
                resultado.errores++;
            }
        }
        return resultado;
    }

    /**
     * Encola sincronización MBT post-commit (evita pisado por flows en la misma transacción).
     */
    public static void programarSincronizacionMbtDesdeToneladas(Set<Id> toneladaIds) {
        if (toneladaIds == null || toneladaIds.isEmpty()) {
            return;
        }
        if (Test.isRunningTest()) {
            sincronizarMbtDesdeToneladas(toneladaIds);
            return;
        }
        System.enqueueJob(new SincronizarMbtExpedienteQueueable(toneladaIds));
    }

    private static VinculacionExpedienteResult completarExpedienteMbtDesdeToneladasEnCgs(Set<Id> cuentaGranariaIds) {
        VinculacionExpedienteResult resultado = new VinculacionExpedienteResult();
        Map<Id, Id> expedientePorMbt = new Map<Id, Id>();

        String tnQuery = 'SELECT Mov_BolsaTech__c, Expediente_de_Negativos__c ' +
            'FROM Tonelada__c ' +
            'WHERE Mov_BolsaTech__c != null ' +
            'AND Expediente_de_Negativos__c != null ' +
            'AND Mov_BolsaTech__r.Expediente_de_Negativos__c = null';
        if (cuentaGranariaIds != null && !cuentaGranariaIds.isEmpty()) {
            tnQuery += ' AND Cuenta_Granaria__c IN :cuentaGranariaIds';
        }
        for (Tonelada__c tn : Database.query(tnQuery)) {
            expedientePorMbt.put(tn.Mov_BolsaTech__c, tn.Expediente_de_Negativos__c);
        }

        resultado.expedientesEncontrados = expedientePorMbt.size();
        if (expedientePorMbt.isEmpty()) {
            return resultado;
        }

        List<Movimiento_BolsaTech__c> movimientosAActualizar = new List<Movimiento_BolsaTech__c>();
        for (Id mbtId : expedientePorMbt.keySet()) {
            movimientosAActualizar.add(new Movimiento_BolsaTech__c(
                Id = mbtId,
                Expediente_de_Negativos__c = expedientePorMbt.get(mbtId)
            ));
        }

        Database.SaveResult[] mbtResults = Database.update(movimientosAActualizar, false);
        for (Database.SaveResult sr : mbtResults) {
            if (sr.isSuccess()) {
                resultado.movimientosActualizados++;
            } else {
                resultado.errores++;
            }
        }

        return resultado;
    }

    /**
     * MBT sin expediente → copia Expediente_de_Negativos__c desde Tonelada__c referenciada en TN_Id__c.
     */
    private static VinculacionExpedienteResult completarExpedienteMbtDesdeTnIdEnCgs(
        Set<Id> cuentaGranariaIds,
        Integer limite
    ) {
        VinculacionExpedienteResult resultado = new VinculacionExpedienteResult();
        List<Movimiento_BolsaTech__c> movimientosAActualizar = new List<Movimiento_BolsaTech__c>();

        String mbtQuery = 'SELECT Id, Expediente_de_Negativos__c, Expediente_de_Negativos__r.Tipo_expendiente__c, ' +
            'TN_Id__c, TN_Id__r.Expediente_de_Negativos__c, TN_Id__r.Expediente_de_Negativos__r.Tipo_expendiente__c ' +
            'FROM Movimiento_BolsaTech__c ' +
            'WHERE Expediente_de_Negativos__c = null ' +
            'AND TN_Id__c != null ' +
            'AND TN_Id__r.Expediente_de_Negativos__c != null';
        if (cuentaGranariaIds != null && !cuentaGranariaIds.isEmpty()) {
            mbtQuery += ' AND TN_Id__r.Cuenta_Granaria__c IN :cuentaGranariaIds';
        }
        mbtQuery += ' ORDER BY CreatedDate ASC';
        if (limite != null && limite > 0) {
            mbtQuery += ' LIMIT ' + limite;
        }

        for (Movimiento_BolsaTech__c mbt : Database.query(mbtQuery)) {
            Id expedienteId = mbt.TN_Id__r.Expediente_de_Negativos__c;
            Movimiento_BolsaTech__c mbtActualizado = prepararMovimientoConExpediente(mbt, expedienteId);
            if (mbtActualizado != null) {
                movimientosAActualizar.add(mbtActualizado);
            }
        }

        resultado.expedientesEncontrados = movimientosAActualizar.size();
        if (movimientosAActualizar.isEmpty()) {
            return resultado;
        }

        Database.SaveResult[] mbtResults = Database.update(movimientosAActualizar, false);
        for (Database.SaveResult sr : mbtResults) {
            if (sr.isSuccess()) {
                resultado.movimientosActualizados++;
            } else {
                resultado.errores++;
            }
        }

        return resultado;
    }

    private static VinculacionExpedienteResult vincularPorMapaExpedientePorCg(Map<Id, Id> expedientePorCg) {
        VinculacionExpedienteResult resultado = new VinculacionExpedienteResult();
        resultado.expedientesEncontrados = expedientePorCg.size();

        if (expedientePorCg.isEmpty()) {
            return resultado;
        }

        List<Tonelada__c> toneladasAActualizar = new List<Tonelada__c>();
        Map<Id, Id> expedientePorMovBolsaTech = new Map<Id, Id>();
        for (Tonelada__c tn : [
            SELECT Id, Cuenta_Granaria__c, Mov_BolsaTech__c, Expediente_de_Negativos__c,
                   Expediente_de_Origen__c, Expediente_de_Negativos__r.Name,
                   Expediente_de_Negativos__r.Tipo_expendiente__c
            FROM Tonelada__c
            WHERE Cuenta_Granaria__c IN :expedientePorCg.keySet()
        ]) {
            Id expedienteId = expedientePorCg.get(tn.Cuenta_Granaria__c);
            if (expedienteId == null) {
                continue;
            }

            Boolean tnTienePriOSec = tn.Expediente_de_Negativos__c != null
                && esExpedientePriOSec(tn.Expediente_de_Negativos__r.Tipo_expendiente__c);

            Tonelada__c tnActualizada = prepararToneladaConExpediente(tn, expedienteId);
            if (tnActualizada != null) {
                toneladasAActualizar.add(tnActualizada);
            }

            if (tn.Mov_BolsaTech__c != null && !tnTienePriOSec) {
                expedientePorMovBolsaTech.put(tn.Mov_BolsaTech__c, expedienteId);
            }
        }

        if (!toneladasAActualizar.isEmpty()) {
            Database.SaveResult[] tnResults = Database.update(toneladasAActualizar, false);
            for (Database.SaveResult sr : tnResults) {
                if (sr.isSuccess()) {
                    resultado.toneladasActualizadas++;
                } else {
                    resultado.errores++;
                }
            }
        }

        if (!expedientePorMovBolsaTech.isEmpty()) {
            List<Movimiento_BolsaTech__c> movimientosAActualizar = new List<Movimiento_BolsaTech__c>();
            for (Movimiento_BolsaTech__c mbt : [
                SELECT Id, Expediente_de_Negativos__c, Expediente_de_Negativos__r.Name,
                       Expediente_de_Negativos__r.Tipo_expendiente__c
                FROM Movimiento_BolsaTech__c
                WHERE Id IN :expedientePorMovBolsaTech.keySet()
            ]) {
                Id expedienteId = expedientePorMovBolsaTech.get(mbt.Id);
                Movimiento_BolsaTech__c mbtActualizado = prepararMovimientoConExpediente(mbt, expedienteId);
                if (mbtActualizado != null) {
                    movimientosAActualizar.add(mbtActualizado);
                }
            }

            if (!movimientosAActualizar.isEmpty()) {
                Database.SaveResult[] mbtResults = Database.update(movimientosAActualizar, false);
                for (Database.SaveResult sr : mbtResults) {
                    if (sr.isSuccess()) {
                        resultado.movimientosActualizados++;
                    } else {
                        resultado.errores++;
                    }
                }
            }
        }

        VinculacionExpedienteResult mbtDesdeTn = completarExpedienteMbtDesdeToneladasEnCgs(expedientePorCg.keySet());
        resultado.movimientosActualizados += mbtDesdeTn.movimientosActualizados;
        resultado.errores += mbtDesdeTn.errores;

        VinculacionExpedienteResult mbtDesdeTnId = completarExpedienteMbtDesdeTnIdEnCgs(expedientePorCg.keySet(), null);
        resultado.movimientosActualizados += mbtDesdeTnId.movimientosActualizados;
        resultado.errores += mbtDesdeTnId.errores;

        return resultado;
    }

    private static Boolean esExpedientePriOSec(String tipoExpediente) {
        return tipoExpediente == 'PRI' || tipoExpediente == 'SEC';
    }

    private static Tonelada__c prepararToneladaConExpediente(Tonelada__c tn, Id expedienteId) {
        if (tn.Expediente_de_Negativos__c == expedienteId) {
            return null;
        }

        if (tn.Expediente_de_Negativos__c != null
            && esExpedientePriOSec(tn.Expediente_de_Negativos__r.Tipo_expendiente__c)) {
            return null;
        }

        if (tn.Expediente_de_Negativos__c == null) {
            return new Tonelada__c(
                Id = tn.Id,
                Expediente_de_Negativos__c = expedienteId
            );
        }

        return new Tonelada__c(
            Id = tn.Id,
            Expediente_de_Origen__c = tn.Expediente_de_Negativos__c,
            Expediente_de_Negativos__c = expedienteId
        );
    }

    private static Movimiento_BolsaTech__c prepararMovimientoConExpediente(
        Movimiento_BolsaTech__c mbt,
        Id expedienteId
    ) {
        if (mbt.Expediente_de_Negativos__c == expedienteId) {
            return null;
        }

        if (mbt.Expediente_de_Negativos__c != null
            && esExpedientePriOSec(mbt.Expediente_de_Negativos__r.Tipo_expendiente__c)) {
            return null;
        }

        return new Movimiento_BolsaTech__c(
            Id = mbt.Id,
            Expediente_de_Negativos__c = expedienteId
        );
    }

    public class VinculacionExpedienteResult {
        public Integer expedientesEncontrados = 0;
        public Integer toneladasActualizadas = 0;
        public Integer movimientosActualizados = 0;
        public Integer errores = 0;
    }
}