public without sharing class ExpedientesController {

    /**
     * Verifica si una Cuenta_Granaria tiene expedientes abiertos (NO finalizados)
     * @param cuentaGranariaId - ID de la Cuenta_Granaria__c
     * @return true si hay al menos un expediente abierto, false en caso contrario
     */
    // @AuraEnabled(cacheable=true)
    // public static Boolean tieneExpedienteAbierto(Id cuentaGranariaId) {
        // if (cuentaGranariaId == null) {
            // return false;
        // }

        // Integer count = [
            // SELECT COUNT()
            // FROM Expediente_de_Negativos__c
            // WHERE Cuenta_Granaria__c = :cuentaGranariaId
                // AND Estado_de_la_Etapa__c != 'Finalizado'
            // LIMIT 1
        // ];

        // return count > 0;
    // }

    /**
     * Verifica expedientes abiertos por múltiples Cuentas_Granarias (bulkificado)
     * @param cuentaGranariaIds - Set de IDs de Cuenta_Granaria__c
     * @return Map<Id, Boolean> donde la clave es el ID de la CG y el valor indica si tiene expediente abierto
     */
    // @AuraEnabled(cacheable=true)
    // public static Map<Id, Boolean> tieneExpedienteAbiertoBulk(List<Id> cuentaGranariaIds) {
        // Map<Id, Boolean> resultado = new Map<Id, Boolean>();

        // Inicializar todos con false
        // for (Id cgId : cuentaGranariaIds) {
            // resultado.put(cgId, false);
        // }

        // Query de expedientes abiertos
        // for (Expediente_de_Negativos__c exp : [
            // SELECT Cuenta_Granaria__c
            // FROM Expediente_de_Negativos__c
            // WHERE Cuenta_Granaria__c IN :cuentaGranariaIds
                // AND Estado_de_la_Etapa__c != 'Finalizado'
        // ]) {
            // if (exp.Cuenta_Granaria__c != null) {
                // resultado.put(exp.Cuenta_Granaria__c, true);
            // }
        // }

        // return resultado;
    // }

    /**
     * Obtiene información de expedientes abiertos para una Cuenta_Granaria
     * Útil para mostrar detalles en el popup
     * @param cuentaGranariaId - ID de la Cuenta_Granaria__c
     * @return Map con detalles del expediente (cantidad, estado, etc.)
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> obtenerDetallesExpediente(Id cuentaGranariaId) {
        Map<String, Object> resultado = new Map<String, Object>();
        resultado.put('tieneExpediente', false);
        resultado.put('expedientes', new List<Map<String, Object>>());

        if (cuentaGranariaId == null) {
            return resultado;
        }

        List<Map<String, Object>> expedientes = new List<Map<String, Object>>();

        for (Expediente_de_Negativos__c exp : [
            SELECT 
                Id,
                Name,
                Campania__r.Name,
                Saldo_Previo_al_Expediente__c,
                Estado_de_la_Etapa__c,
                Etapa__c,
                Fecha_Cambio_Etapa__c
            FROM Expediente_de_Negativos__c
            WHERE Cuenta_Granaria__c = :cuentaGranariaId
                AND Estado_de_la_Etapa__c != 'Finalizado'
            ORDER BY CreatedDate DESC
        ]) {
            Map<String, Object> expMap = new Map<String, Object>();
            expMap.put('id', exp.Id);
            expMap.put('name', exp.Name);
            expMap.put('campania', exp.Campania__r?.Name);
            expMap.put('saldo', exp.Saldo_Previo_al_Expediente__c);
            expMap.put('estado', exp.Estado_de_la_Etapa__c);
            expMap.put('etapa', exp.Etapa__c);
            expMap.put('fechaCambio', exp.Fecha_Cambio_Etapa__c);
            expedientes.add(expMap);
        }

        if (!expedientes.isEmpty()) {
            resultado.put('tieneExpediente', true);
            resultado.put('expedientes', expedientes);
        }

        return resultado;
    }

    /**
     * Obtiene la Cuenta_Granaria asociada a una compra/venta de HT Disponible
     * y verifica si tiene expedientes abiertos
     * @param compraVentaId - ID de la Compra_HT__c u Oportunidad (Venta)
     * @param tipoOperacion - 'compra' o 'venta'
     * @return Map con información de la CG y si tiene expediente abierto
     */
    @AuraEnabled
    public static Map<String, Object> verificarExpedienteEnHTDisponible(
        Id compraVentaId,
        String tipoOperacion
    ) {
        System.debug(LoggingLevel.INFO,
            '[ExpedientesController] verificarExpedienteEnHTDisponible - IN compraVentaId=' +
            String.valueOf(compraVentaId) + ', tipoOperacion=' + tipoOperacion
        );
        Map<String, Object> resultado = new Map<String, Object>();
        resultado.put('tieneExpediente', false);
        resultado.put('cuentaGranariaId', null);
        resultado.put('expedientes', new List<Map<String, Object>>());

        if (compraVentaId == null || String.isBlank(tipoOperacion)) {
            System.debug(LoggingLevel.WARN,
                '[ExpedientesController] Parámetros inválidos. Devuelve resultado por defecto.'
            );
            return resultado;
        }

        try {
            Id productorId = obtenerProductorDesdeOperacion(compraVentaId, tipoOperacion);
            System.debug(LoggingLevel.INFO,
                '[ExpedientesController] productorId detectado=' + String.valueOf(productorId)
            );
            if (productorId == null) {
                System.debug(LoggingLevel.WARN,
                    '[ExpedientesController] No se pudo resolver productor desde la operación.'
                );
                return resultado;
            }

            System.debug(LoggingLevel.INFO,
                '[ExpedientesController] Query de expedientes activos: Cuenta__c=' + String.valueOf(productorId)
            );
            List<Expediente_de_Negativos__c> expedientesActivos = [
                SELECT
                    Id,
                    Name,
                    Campania__r.Name,
                    Saldo_Previo_al_Expediente__c,
                    Estado_de_la_Etapa__c,
                    Etapa__c,
                    Fecha_Cambio_Etapa__c,
                    Cuenta_Granaria__c
                FROM Expediente_de_Negativos__c
                WHERE Cuenta__c = :productorId
                    AND Cuenta_Granaria__c != null
                    AND Estado_de_la_Etapa__c != 'Finalizado'
                ORDER BY CreatedDate DESC
            ];
            System.debug(LoggingLevel.INFO,
                '[ExpedientesController] expedientesActivos.size=' + expedientesActivos.size()
            );

            if (!expedientesActivos.isEmpty()) {
                resultado.put('tieneExpediente', true);
                resultado.put('cuentaGranariaId', expedientesActivos[0].Cuenta_Granaria__c);

                List<Map<String, Object>> expedientes = new List<Map<String, Object>>();
                for (Expediente_de_Negativos__c exp : expedientesActivos) {
                    Map<String, Object> expMap = new Map<String, Object>();
                    expMap.put('id', exp.Id);
                    expMap.put('name', exp.Name);
                    expMap.put('campania', exp.Campania__r?.Name);
                    expMap.put('saldo', exp.Saldo_Previo_al_Expediente__c);
                    expMap.put('estado', exp.Estado_de_la_Etapa__c);
                    expMap.put('etapa', exp.Etapa__c);
                    expMap.put('fechaCambio', exp.Fecha_Cambio_Etapa__c);
                    expMap.put('cuentaGranariaId', exp.Cuenta_Granaria__c);
                    expedientes.add(expMap);
                }
                resultado.put('expedientes', expedientes);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                '[ExpedientesController] Error verificando expediente: ' + e.getMessage()
            );
            throw new AuraHandledException(e.getMessage());
        }

        System.debug(LoggingLevel.INFO,
            '[ExpedientesController] verificarExpedienteEnHTDisponible - OUT resultado=' + JSON.serialize(resultado)
        );
        return resultado;
    }

    private static Id obtenerProductorDesdeOperacion(Id compraVentaId, String tipoOperacion) {
        if (compraVentaId == null || String.isBlank(tipoOperacion)) {
            return null;
        }

        String tipo = tipoOperacion.toLowerCase();
        System.debug(LoggingLevel.DEBUG,
            '[ExpedientesController] obtenerProductorDesdeOperacion - tipo=' + tipo +
            ', compraVentaId=' + String.valueOf(compraVentaId)
        );
        if (tipo == 'compra') {
            List<SObject> compras = Database.query(
                'SELECT Cuenta_Productor__c FROM Compra_HT__c WHERE Id = :compraVentaId LIMIT 1'
            );
            System.debug(LoggingLevel.DEBUG,
                '[ExpedientesController] Compra_HT__c encontradas=' + compras.size()
            );
            if (!compras.isEmpty()) {
                return (Id)compras[0].get('Cuenta_Productor__c');
            }
            return null;
        }

        if (tipo == 'venta') {
            // En la UI actual se envía el Id de Venta_HT__c; se deja fallback por Oportunidad__c.
            List<SObject> ventas = Database.query(
                'SELECT Cuenta_Productor__c FROM Venta_HT__c WHERE Id = :compraVentaId LIMIT 1'
            );
            System.debug(LoggingLevel.DEBUG,
                '[ExpedientesController] Venta_HT__c encontradas=' + ventas.size()
            );
            if (!ventas.isEmpty()) {
                return (Id)ventas[0].get('Cuenta_Productor__c');
            }

            List<SObject> oportunidades = Database.query(
                'SELECT Cuenta_Productor__c FROM Oportunidad__c WHERE Id = :compraVentaId LIMIT 1'
            );
            System.debug(LoggingLevel.DEBUG,
                '[ExpedientesController] Oportunidad__c encontradas=' + oportunidades.size()
            );
            if (!oportunidades.isEmpty()) {
                return (Id)oportunidades[0].get('Cuenta_Productor__c');
            }
        }

        return null;
    }

    // private static Id obtenerCuentaGranariaDesdeLinea(
        // String objectApiName,
        // String parentFieldApiName,
        // Id parentId
    // ) {
        // if (parentId == null || String.isBlank(objectApiName) || String.isBlank(parentFieldApiName)) {
            // return null;
        // }

        // String cuentaField = obtenerCampoExistente(
            // objectApiName,
            // new List<String>{ 'Cuenta_Granaria__c', 'Cuenta_Granaria_HT__c' }
        // );
        // if (String.isBlank(cuentaField)) {
            // return null;
        // }

        // String filtroTipoDisponible = '';
        // String tipoCompraField = obtenerCampoExistente(
            // objectApiName,
            // new List<String>{ 'Tipo_de_Compra__c' }
        // );
        // if (!String.isBlank(tipoCompraField)) {
            // filtroTipoDisponible = ' AND ' + tipoCompraField + ' = \'Disponible\'';
        // }

        // String query = 'SELECT Id, ' + cuentaField +
            // ' FROM ' + objectApiName +
            // ' WHERE ' + parentFieldApiName + ' = :parentId' +
            // ' AND ' + cuentaField + ' != null' +
            // filtroTipoDisponible +
            // ' LIMIT 1';

        // List<SObject> lineas = Database.query(query);
        // if (!lineas.isEmpty()) {
            // return (Id)lineas[0].get(cuentaField);
        // }

        // return null;
    // }

    private static String obtenerCampoExistente(
        String objectApiName,
        List<String> candidatos
    ) {
        Schema.SObjectType sobjectType = Schema.getGlobalDescribe().get(objectApiName);
        if (sobjectType == null) {
            return null;
        }

        Map<String, Schema.SObjectField> fieldsMap = sobjectType.getDescribe().fields.getMap();
        for (String candidato : candidatos) {
            if (fieldsMap.containsKey(candidato)) {
                return candidato;
            }
        }
        return null;
    }
}