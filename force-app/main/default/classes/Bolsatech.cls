public class Bolsatech {

    public static void validate(List<Movimiento_BolsaTech__c> movimientos) {
        Map<String, Account> accountByCuit = new Map<String, Account>();
        Map<Id, List<String>> errorsById = new Map<Id, List<String>>();

        for (Movimiento_BolsaTech__c movimiento: movimientos) {
            List<String> errors = new List<String>();

            if (String.isBlank(movimiento.Fecha_de_Analisis__c)) errors.add('Fecha de Análisis Vacia');
            if (String.isBlank(movimiento.Cultivo__c)) errors.add('Cultivo Vacio');
            if (String.isBlank(movimiento.Tecnologia__c)) errors.add('Tecnologia Vacia');
            if (String.isBlank(movimiento.CTG__c)) errors.add('Código de Trazabilidad de Granos Vacio');
            if (String.isBlank(movimiento.Codigo_de_Muestra__c)) errors.add('Código de Muestra Vacio');
            if (movimiento.Peso_Neto__c == null) errors.add('Peso Neto Vacio');

            // -----------------------------
            // NUEVA LÓGICA DE TITULAR
            // -----------------------------
            String cuitTitularReal;

            if (String.isNotBlank(movimiento.CUIT_Titular__c)) {
                // Caso 1: titular completo → usarlo
                cuitTitularReal = movimiento.CUIT_Titular__c;
                accountByCuit.put(cuitTitularReal, null);

            } else if (String.isNotBlank(movimiento.Cuit_Remitente_Comercial__c)) {
                // Caso 2: titular vacío pero remitente comercial lleno → usar remitente
                cuitTitularReal = movimiento.Cuit_Remitente_Comercial__c;
                accountByCuit.put(cuitTitularReal, null);

            } else {
                // Caso 3: ambos vacíos → error
                errors.add('Cuit Titular Vacio');
            }

            // CUIT DESTINATARIO
            if (String.isBlank(movimiento.Cuit_Destinatario__c)) {
                errors.add('Cuit Destinatario Vacio');
            } else {
                accountByCuit.put(movimiento.Cuit_Destinatario__c, null);
            }

            errorsById.put(movimiento.id, errors);
        }

        // -----------------------------
        // QUERY DE CUENTAS
        // -----------------------------
        for(Account acc : [
            SELECT Id, N_CUIT__c 
            FROM Account 
            WHERE RecordType.DeveloperName != 'Proveedor'
            AND N_CUIT__c IN :accountByCuit.keySet()
            AND (
                (N_CUIT__c IN ('30569723023', '30715468294') AND Type = 'Obtentor')
                OR parentId = null
            )
        ]) {
            accountByCuit.put(acc.N_CUIT__c, acc);
        }

        // -----------------------------
        // SEGUNDA PASADA: ASIGNAR CUENTAS
        // -----------------------------
        for (Movimiento_BolsaTech__c movimiento: movimientos) {
            List<String> errors = errorsById.get(movimiento.id);

            // Determinar CUIT titular real
            String cuitTitularReal = String.isNotBlank(movimiento.CUIT_Titular__c)
                ? movimiento.CUIT_Titular__c
                : movimiento.Cuit_Remitente_Comercial__c;

            Account titular = accountByCuit.get(cuitTitularReal);
            Account destinatario = accountByCuit.get(movimiento.Cuit_Destinatario__c);

            if (String.isNotBlank(cuitTitularReal) && titular == null) {
                errors.add('El cuit titular no se encuentra en el sistema');
            }

            if (String.isNotBlank(movimiento.Cuit_Destinatario__c) && destinatario == null) {
                errors.add('El cuit destinatario no se encuentra en el sistema');
            }

            movimiento.Titular__c = titular != null ? titular.Id : null;
            movimiento.Destinatario__c = destinatario != null ? destinatario.Id : null;
        }

        validateDuplicates(movimientos, errorsById);

        // -----------------------------
        // ESTADO Y RESULTADO
        // -----------------------------
        for (Movimiento_BolsaTech__c movimiento: movimientos) {
            List<String> errors = errorsById.get(movimiento.id);

            movimiento.Estado__c = errors.isEmpty() ? 'A procesar' : 'Con error';
            movimiento.Resultado__c = errors.isEmpty() ? 'OK' : String.join(errors, ',').abbreviate(255);
        }
    }

    private static void validateDuplicates(List<Movimiento_BolsaTech__c> movimientos, Map<Id, List<String>> errorsById) {
        Set<String> codigosDeMuestra = new Set<String>();
        Set<String> codigoTrazabilidadGrano = new Set<String>();

        for (Movimiento_BolsaTech__c movimiento: movimientos) {
            List<String> errors = errorsById.get(movimiento.id);

            if (errors.isEmpty()) {
                codigosDeMuestra.add(movimiento.Codigo_de_Muestra__c);
                codigoTrazabilidadGrano.add(movimiento.CTG__c);
            }
        }

        Set<String> existingKeys = new Set<String>();

        for (Movimiento_BolsaTech__c movimiento: [
            SELECT Codigo_de_Muestra__c, CTG__c 
            FROM Movimiento_BolsaTech__c 
            WHERE CTG__c IN :codigoTrazabilidadGrano 
            AND Codigo_de_Muestra__c IN :codigosDeMuestra 
            AND Id NOT IN :movimientos
        ]) {
            existingKeys.add(key(movimiento));
        }

        for (Movimiento_BolsaTech__c movimiento: movimientos) {
            List<String> errors = errorsById.get(movimiento.id);

            if (errors.isEmpty() && existingKeys.contains(key(movimiento))) {
                errors.add('Ya existe un movimiento con mismo código de trazabilidad de granos/código de muestra');
            }
        }
    }

    private static String key(Movimiento_BolsaTech__c movimiento) {
        return String.join(new List<String>{movimiento.Codigo_de_Muestra__c, movimiento.CTG__c}, '|');
    }

    @AuraEnabled
    public static void validate(Id recordId) {
        Movimiento_BolsaTech__c movimiento = [
            SELECT Codigo_de_Muestra__c, Estado__c, CUIT_Titular__c, CUIT_Remitente_Comercial__c,
                   Cuit_Destinatario__c, Peso_Neto__c, Fecha_de_Analisis__c, Cultivo__c,
                   Tecnologia__c, CTG__c
            FROM Movimiento_BolsaTech__c 
            WHERE Id = :recordId
        ];

        if (movimiento.Estado__c != 'Creado' && movimiento.Estado__c != 'Con error') {
            throw new AuraHandledException('El estado del movimiento debe ser creado o con error');
        }

        validate(new List<Movimiento_BolsaTech__c>{movimiento});
        update movimiento;
    }
}