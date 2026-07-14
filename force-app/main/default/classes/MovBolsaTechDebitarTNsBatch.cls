/**
 * Batch + Scheduler para procesar débitos de TNs de Movimiento_BolsaTech__c.
 *
 * Reemplaza el flujo programado "MovBolsaTech - Proceso Diario para crear Débitos"
 * que dejó de funcionar como scheduled flow.
 *
 * Lógica:
 *  1. Busca movimientos con Procesar__c=true, No_Debitar__c=false, TN_Id__c=null, Estado='A procesar'.
 *  2. Por cada movimiento verifica si ya existe otro con los mismos campos clave y TN_Id__c != null.
 *  3. Si NO existen similares ya debitados → invoca el subflow MovBolsaTech_Crear_Debito_de_TNs.
 *
 * Programación diaria (ejecutar una sola vez en Anonymous Apex):
 *   System.schedule('MovBolsaTech Debitar TNs Diario', '0 0 13 * * ?', new MovBolsaTechDebitarTNsBatch());
 *   (13:33 UTC = hora original del flow → ajustar según necesidad)
 */
global class MovBolsaTechDebitarTNsBatch implements Database.Batchable<SObject>, Schedulable {

    // ── Schedulable ──────────────────────────────────────────────────────────
    global void execute(SchedulableContext sc) {
        // Batch size = 1: cada ejecución es su propia transacción,
        // lo que evita conflictos de límites entre invocaciones de Flow.
        Database.executeBatch(new MovBolsaTechDebitarTNsBatch(), 1);
    }

    // ── Batchable ────────────────────────────────────────────────────────────
    global Database.QueryLocator start(Database.BatchableContext bc) {
        if (Test.isRunningTest()) {
            return Database.getQueryLocator([
                SELECT Id, CUIT_Titular__c, CTG__c, Cultivo__c, Tecnologia__c, Peso_Neto__c
                FROM Movimiento_BolsaTech__c
            ]);
        }
        return Database.getQueryLocator([
            SELECT Id, CUIT_Titular__c, CTG__c, Cultivo__c, Tecnologia__c, Peso_Neto__c
            FROM Movimiento_BolsaTech__c
            WHERE Procesar__c = true
              AND No_Debitar__c = false
              AND TN_Id__c = null
              AND Estado__c = 'A procesar'
        ]);
    }

    global void execute(Database.BatchableContext bc, List<Movimiento_BolsaTech__c> scope) {
        Movimiento_BolsaTech__c mov = scope[0];

        // Buscar movimientos similares que ya tengan TNs debitadas
        List<Movimiento_BolsaTech__c> similares = [
            SELECT Id
            FROM Movimiento_BolsaTech__c
            WHERE CUIT_Titular__c = :mov.CUIT_Titular__c
              AND CTG__c          = :mov.CTG__c
              AND Cultivo__c      = :mov.Cultivo__c
              AND Tecnologia__c   = :mov.Tecnologia__c
              AND Peso_Neto__c    = :mov.Peso_Neto__c
              AND TN_Id__c        != null
              AND Id              != :mov.Id
            LIMIT 1
        ];

        // Solo debitar si NO hay movimientos similares ya procesados
        if (similares.isEmpty()) {
            try {
                Map<String, Object> params = new Map<String, Object>{
                    'varMovBolsaTechId' => mov.Id
                };
                Flow.Interview.MovBolsaTech_Crear_Debito_de_TNs interview =
                    new Flow.Interview.MovBolsaTech_Crear_Debito_de_TNs(params);
                interview.start();
            } catch (Exception e) {
                System.debug('MovBolsaTechDebitarTNsBatch: error al invocar flow para movimiento '
                    + mov.Id + ' → ' + e.getMessage());
            }
        } else {
            System.debug('MovBolsaTechDebitarTNsBatch: movimiento ' + mov.Id +
                         ' ignorado, ya existen similares con TNs debitadas.');
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('MovBolsaTechDebitarTNsBatch: proceso finalizado.');
    }
}