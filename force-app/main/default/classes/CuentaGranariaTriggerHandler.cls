public with sharing class CuentaGranariaTriggerHandler extends TriggerHandler {

    @TestVisible
    private static Boolean HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS = true;

    public override void afterInsert() {
        gestionarExpedientesNegativos((List<Cuenta_Granaria__c>) Trigger.new, null);
    }

    public override void afterUpdate() {
        gestionarExpedientesNegativos(
            (List<Cuenta_Granaria__c>) Trigger.new,
            (Map<Id, Cuenta_Granaria__c>) Trigger.oldMap
        );
    }

    private static void gestionarExpedientesNegativos(
        List<Cuenta_Granaria__c> nuevasCuentas,
        Map<Id, Cuenta_Granaria__c> oldMap
    ) {
        if (nuevasCuentas == null || nuevasCuentas.isEmpty()) {
            return;
        }

        Set<Id> cuentaIdsObjetivo = new Set<Id>();
        Map<Id, Cuenta_Granaria__c> cuentaPorId = new Map<Id, Cuenta_Granaria__c>();

        for (Cuenta_Granaria__c cg : nuevasCuentas) {
            if (cg == null || cg.Id == null || cg.Saldo_Cuenta__c == null) {
                continue;
            }

            if (cg.Es_Carga_Manual__c != true || cg.Saldo_Cuenta__c >= -3) {
                continue;
            }

            Boolean debeProcesar = (oldMap == null);
            if (!debeProcesar && oldMap.containsKey(cg.Id)) {
                Cuenta_Granaria__c oldCg = oldMap.get(cg.Id);
                debeProcesar =
                    oldCg == null ||
                    oldCg.Saldo_Cuenta__c != cg.Saldo_Cuenta__c ||
                    oldCg.Es_Carga_Manual__c != cg.Es_Carga_Manual__c;
            }

            if (debeProcesar) {
                cuentaIdsObjetivo.add(cg.Id);
                cuentaPorId.put(cg.Id, cg);
            }
        }

        if (cuentaIdsObjetivo.isEmpty()) {
            return;
        }

        // Excluir cuentas tipo Obtentor: no se les crea CG ni expedientes
        Set<Id> productoresObjetivo = new Set<Id>();
        for (Cuenta_Granaria__c cg : cuentaPorId.values()) {
            if (cg.Productor__c != null) {
                productoresObjetivo.add(cg.Productor__c);
            }
        }
        Set<Id> productoresObtentor = new Set<Id>();
        if (!productoresObjetivo.isEmpty()) {
            for (Account cuentaObtentor : [
                SELECT Id
                FROM Account
                WHERE Id IN :productoresObjetivo
                    AND RecordType.Name = 'Obtentor'
            ]) {
                productoresObtentor.add(cuentaObtentor.Id);
            }
        }
        if (!productoresObtentor.isEmpty()) {
            for (Id cuentaId : new Set<Id>(cuentaIdsObjetivo)) {
                Cuenta_Granaria__c cg = cuentaPorId.get(cuentaId);
                if (cg != null && productoresObtentor.contains(cg.Productor__c)) {
                    cuentaIdsObjetivo.remove(cuentaId);
                    cuentaPorId.remove(cuentaId);
                }
            }
            if (cuentaIdsObjetivo.isEmpty()) {
                return;
            }
        }

        Map<Id, Expediente_de_Negativos__c> expedienteActivoPorCg = new Map<Id, Expediente_de_Negativos__c>();
        for (Expediente_de_Negativos__c exp : [
            SELECT Id, Cuenta_Granaria__c, Estado_de_la_Etapa__c, CreatedDate
            FROM Expediente_de_Negativos__c
            WHERE Cuenta_Granaria__c IN :cuentaIdsObjetivo
                AND Cuenta_Granaria__c != null
                AND Estado_de_la_Etapa__c != 'Finalizado'
            ORDER BY CreatedDate DESC
        ]) {
            if (!expedienteActivoPorCg.containsKey(exp.Cuenta_Granaria__c)) {
                expedienteActivoPorCg.put(exp.Cuenta_Granaria__c, exp);
            }
        }

        Sembra_Evolucion__c config = Sembra_Evolucion__c.getInstance();
        Id obtentorId = (config != null && config.Corteva_30_Id__c != null)
            ? Id.valueOf(config.Corteva_30_Id__c)
            : null;

        List<Expediente_de_Negativos__c> expedientesACrear = new List<Expediente_de_Negativos__c>();
        List<Expediente_de_Negativos__c> expedientesAActualizar = new List<Expediente_de_Negativos__c>();
        Map<Id, Id> expedientePorCg = new Map<Id, Id>();

        for (Id cuentaId : cuentaIdsObjetivo) {
            Cuenta_Granaria__c cg = cuentaPorId.get(cuentaId);
            if (cg == null) {
                continue;
            }

            Decimal saldoNegativo = cg.Saldo_Cuenta__c;
            Expediente_de_Negativos__c expedienteActivo = expedienteActivoPorCg.get(cuentaId);

            if (expedienteActivo != null) {
                expedientesAActualizar.add(new Expediente_de_Negativos__c(
                    Id = expedienteActivo.Id,
                    Saldo_Expediente__c = saldoNegativo
                ));
                expedientePorCg.put(cuentaId, expedienteActivo.Id);
                continue;
            }

            if (!HABILITAR_CREACION_EXPEDIENTES_NEGATIVOS) {
                continue;
            }

            Expediente_de_Negativos__c nuevoExpediente = new Expediente_de_Negativos__c();
            nuevoExpediente.Campania__c = cg.Campania__c;
            nuevoExpediente.Cuenta__c = cg.Productor__c;
            nuevoExpediente.Cuenta_Granaria__c = cg.Id;
            nuevoExpediente.Saldo_Previo_al_Expediente__c = saldoNegativo;
            nuevoExpediente.Saldo_Expediente__c = saldoNegativo;
            nuevoExpediente.Tipo_expendiente__c = 'EXP';
            nuevoExpediente.Estado_de_la_Etapa__c = 'No empezado';
            nuevoExpediente.Etapa__c = 'Llamar';
            nuevoExpediente.Fecha_Cambio_Etapa__c = Date.today();
            nuevoExpediente.Gestionar__c = true;
            if (obtentorId != null) {
                nuevoExpediente.Obtentor__c = obtentorId;
            }
            expedientesACrear.add(nuevoExpediente);
        }

        if (!expedientesAActualizar.isEmpty()) {
            Database.update(expedientesAActualizar, false);
        }
        if (!expedientesACrear.isEmpty()) {
            List<Database.SaveResult> insertResults = Database.insert(expedientesACrear, false);
            for (Integer i = 0; i < insertResults.size(); i++) {
                if (insertResults[i].isSuccess()) {
                    Id cgId = expedientesACrear[i].Cuenta_Granaria__c;
                    if (cgId != null) {
                        expedientePorCg.put(cgId, insertResults[i].getId());
                    }
                }
            }
        }
        if (!expedientePorCg.isEmpty()) {
            CuentaGranariaExpedienteService.vincularToneladasYMovimientosPorCg(expedientePorCg);
        }
    }
}