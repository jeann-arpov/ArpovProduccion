public with sharing class ActualizarCampaniaToneladasDesdeMBT {
    public class Request {
        @InvocableVariable(required=true label='Id Movimiento BolsaTech')
        public Id movimientoBolsaTechId;
    }

    @InvocableMethod(label='Actualizar campania de toneladas por MBT')
    public static void ejecutar(List<Request> requests) {
        System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - requests recibidos: ' + (requests == null ? 0 : requests.size()));
        if (requests == null || requests.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - fin: sin requests');
            return;
        }

        Set<Id> mbtIds = new Set<Id>();
        for (Request req : requests) {
            if (req != null && req.movimientoBolsaTechId != null) {
                mbtIds.add(req.movimientoBolsaTechId);
            }
        }
        System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - MBT Ids a procesar: ' + mbtIds);
        if (mbtIds.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - fin: sin MBT Ids validos');
            return;
        }

        Map<Id, String> anioPorMbt = new Map<Id, String>();
        for (Movimiento_BolsaTech__c mbt : [
            SELECT Id, Cosecha__c
            FROM Movimiento_BolsaTech__c
            WHERE Id IN :mbtIds
        ]) {
            if (String.isNotBlank(mbt.Cosecha__c) && mbt.Cosecha__c.length() >= 2) {
                anioPorMbt.put(mbt.Id, '20' + mbt.Cosecha__c.substring(0, 2));
            }
        }
        System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - anio por MBT: ' + anioPorMbt);
        if (anioPorMbt.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - fin: no hay cosechas validas');
            return;
        }

        List<Tonelada__c> toneladas = [
            SELECT Id, Cultivo__c, Mov_BolsaTech__c, Campania__c
            FROM Tonelada__c
            WHERE Mov_BolsaTech__c IN :anioPorMbt.keySet()
            AND Cultivo__c != null
        ];
        System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - toneladas encontradas: ' + toneladas.size());
        if (toneladas.isEmpty()) {
            System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - fin: sin toneladas relacionadas');
            return;
        }

        Set<Id> cultivoIds = new Set<Id>();
        Set<String> anios = new Set<String>();
        for (Tonelada__c tn : toneladas) {
            cultivoIds.add(tn.Cultivo__c);
            anios.add(anioPorMbt.get(tn.Mov_BolsaTech__c));
        }

        Map<String, Id> campaniaPorCultivoAnio = new Map<String, Id>();
        for (Campana_Agricola__c camp : [
            SELECT Id, Cultivo__c, Ano__c
            FROM Campana_Agricola__c
            WHERE Cultivo__c IN :cultivoIds
            AND Ano__c IN :anios
        ]) {
            campaniaPorCultivoAnio.put(camp.Cultivo__c + '_' + camp.Ano__c, camp.Id);
        }
        System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - campanias encontradas: ' + campaniaPorCultivoAnio.size());

        List<Tonelada__c> toneladasAActualizar = new List<Tonelada__c>();
        for (Tonelada__c tn : toneladas) {
            String anio = anioPorMbt.get(tn.Mov_BolsaTech__c);
            if (String.isBlank(anio)) {
                continue;
            }
            Id campaniaId = campaniaPorCultivoAnio.get(tn.Cultivo__c + '_' + anio);
            if (campaniaId != null && campaniaId != tn.Campania__c) {
                toneladasAActualizar.add(new Tonelada__c(
                    Id = tn.Id,
                    Campania__c = campaniaId
                ));
            }
        }
        System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - toneladas a actualizar: ' + toneladasAActualizar.size());

        if (!toneladasAActualizar.isEmpty()) {
            update toneladasAActualizar;
            System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - update realizado');
        } else {
            System.debug(LoggingLevel.INFO, 'ActualizarCampaniaToneladasDesdeMBT.ejecutar - fin: sin cambios para persistir');
        }
    }
}