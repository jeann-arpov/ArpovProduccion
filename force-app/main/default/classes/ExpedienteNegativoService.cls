public class ExpedienteNegativoService {

    public class Request {
        @InvocableVariable(required=true)
        public Id cuentaId;

        @InvocableVariable
        public Id campaniaId;

        @InvocableVariable
        public String nombreExpediente;

        @InvocableVariable
        public String tipoExpediente;

        @InvocableVariable(required=true)
        public Decimal toneladas;

        @InvocableVariable
        public String obtentorId;
    }

    public class Response {
        @InvocableVariable
        public Id expedienteId;
    }

    @InvocableMethod(label='Crear o Actualizar Expediente de Negativos')
    public static List<Response> crearActualizar(List<Request> requests) {

        List<Response> responses = new List<Response>();

        // 1️⃣ Recolectar claves únicas (Cuenta + Tipo)
        Set<Id> cuentas = new Set<Id>();
        Set<String> tipos = new Set<String>();

        for (Request req : requests) {
            cuentas.add(req.cuentaId);
            tipos.add(req.tipoExpediente);
        }

        // 2️⃣ Query única para traer expedientes existentes
        Map<String, Expediente_de_Negativos__c> existentes = new Map<String, Expediente_de_Negativos__c>();

        for (Expediente_de_Negativos__c exp : [
            SELECT Id, Cuenta__c, Tipo_expendiente__c, Saldo_Expediente__c, Estado_de_la_Etapa__c
            FROM Expediente_de_Negativos__c
            WHERE Cuenta__c IN :cuentas
            AND Tipo_expendiente__c IN :tipos
            AND Estado_de_la_Etapa__c != 'Finalizado'
            FOR UPDATE
        ]) {
            String key = exp.Cuenta__c + '-' + exp.Tipo_expendiente__c;
            existentes.put(key, exp);
        }

        // 3️⃣ Mapa para evitar duplicados en DML
        Map<String, Expediente_de_Negativos__c> expedientesProcesados = new Map<String, Expediente_de_Negativos__c>();

        // 4️⃣ Procesar cada request en memoria
        for (Request req : requests) {

            String key = req.cuentaId + '-' + req.tipoExpediente;
            Expediente_de_Negativos__c expediente = existentes.get(key);

            if (expediente == null) {
                // Crear nuevo expediente
                expediente = new Expediente_de_Negativos__c(
                    Cuenta__c = req.cuentaId,
                    Estado_de_la_Etapa__c = 'No empezado',
                    Etapa__c = 'Pendiente',
                    Fecha_Cambio_Etapa__c = Date.today(),
                    Gestionar__c = true,
                    Tipo_expendiente__c = req.tipoExpediente,
                    Saldo_Expediente__c = req.toneladas,
                    Campania__c = req.campaniaId,
                    Obtentor__c = req.obtentorId,
                    Name = req.nombreExpediente
                );

                existentes.put(key, expediente);
                expedientesProcesados.put(key, expediente);

            } else {
                // Acumular toneladas
                expediente.Saldo_Expediente__c += req.toneladas;
                expedientesProcesados.put(key, expediente);
            }
        }

        // 5️⃣ Separar nuevos y actualizados sin duplicados
        List<Expediente_de_Negativos__c> nuevos = new List<Expediente_de_Negativos__c>();
        List<Expediente_de_Negativos__c> actualizados = new List<Expediente_de_Negativos__c>();

        for (Expediente_de_Negativos__c exp : expedientesProcesados.values()) {
            if (exp.Id == null) {
                nuevos.add(exp);
            } else {
                actualizados.add(exp);
            }
        }

        // 6️⃣ DML masivo
        if (!nuevos.isEmpty()) insert nuevos;
        if (!actualizados.isEmpty()) update actualizados;

        // 7️⃣ Respuestas
        for (Request req : requests) {
            String key = req.cuentaId + '-' + req.tipoExpediente;
            Response r = new Response();
            r.expedienteId = existentes.get(key).Id;
            responses.add(r);
        }

        return responses;
    }
}