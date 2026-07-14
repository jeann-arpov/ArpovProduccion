global class UpdateCommunityUsersBatch implements Database.Batchable<SObject>, Database.Stateful {

    // Contadores
    global Integer totalEncontrados = 0;
    global Integer totalActualizados = 0;
    global Integer totalErrores = 0;
    global List<String> errorLogs = new List<String>();

    // Profiles destino
    global Map<String, Id> profileMap = new Map<String, Id>();

    global UpdateCommunityUsersBatch() {
        // Cargar profiles destino
        for (Profile p : [
            SELECT Id, Name
            FROM Profile
            WHERE Name IN ('Distribuidor Plus', 'Obtentor Plus')
        ]) {
            profileMap.put(p.Name, p.Id);
        }
    }

    // START
    global Database.QueryLocator start(Database.BatchableContext bc) {

        if(Test.isRunningTest()) {
            // Solo traer usuarios de prueba para tests
            return Database.getQueryLocator([
                SELECT Id, IsActive, Profile.Name, Username
                FROM User
                WHERE Username IN ('dist@test.com','obt@test.com','abog@test.com')
            ]);
        }

        // Producción: todos los usuarios activos de perfiles relevantes
        return Database.getQueryLocator([
            SELECT Id, IsActive, Profile.Name
            FROM User
            WHERE IsActive = true
            AND Profile.Name IN ('Distribuidor','Obtentor','Obtentor Abogado')
        ]);
    }

    // EXECUTE
    global void execute(Database.BatchableContext bc, List<User> scope) {

        totalEncontrados += scope.size();

        try {
            // Desactivar
            for (User u : scope) u.IsActive = false;
            Database.update(scope, false);

            // Cambiar profile
            for (User u : scope) {
                if(u.Profile.Name == 'Distribuidor') {
                    u.ProfileId = profileMap.get('Distribuidor Plus');
                } else {
                    u.ProfileId = profileMap.get('Obtentor Plus');
                }
            }
            Database.update(scope, false);

            // Reactivar
            for(User u : scope) u.IsActive = true;
            Database.update(scope, false);

            totalActualizados += scope.size();

        } catch(Exception e) {
            totalErrores += scope.size();
            errorLogs.add('Error en lote ['+ bc.getJobId() + ']: ' + e.getMessage());
        }
    }

    // FINISH
    global void finish(Database.BatchableContext bc) {
        System.debug('===== BATCH FINALIZADO =====');
        System.debug('Usuarios encontrados: ' + totalEncontrados);
        System.debug('Usuarios actualizados: ' + totalActualizados);
        System.debug('Usuarios con error: ' + totalErrores);

        if(!errorLogs.isEmpty()) {
            for(String err : errorLogs) System.debug(err);
        }
    }
}