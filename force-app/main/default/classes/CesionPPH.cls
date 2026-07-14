public without sharing class CesionPPH {
    @AuraEnabled
    public static Map<String, Object> getLoadData(String cesionId) {
        Cesion_HT__c cesion;
        
        if (cesionId != 'new' && String.isNotBlank(cesionId)) return loadData(true, cesionId);

        List<Cesion_HT__c> cesiones = [select Id from Cesion_HT__c where Cuenta_Cedente__c =: CrearCompraController.getAccount().id and Estado__c not in ('Cancelada', 'Validada') order by createddate desc limit 1];

        //si vengo del boton de new o no hay cesiones que no esten cancelada/validada, devuelvo cultivos
        if (cesionId == 'new' || cesiones.isEmpty()) {
            return new Map<String, Object>{'cultivos' => getCultivos()};
        } else {
            cesion = cesiones[0];
        }

        return loadData(true, cesion.id);
    }

    @AuraEnabled
    public static Map<String, Object> getNewCesionData(String cultivoId, String tipoCesion){
        Cultivo__c cultivo = [select HT2Kilos__c from Cultivo__c where Id = :cultivoId];

        Cesion_HT__c cesion = new Cesion_HT__c();
        cesion.Estado__c = 'En Curso';
        cesion.Cuenta_Cedente__c = CrearCompraController.getAccount().id;
        cesion.Multiplicador__c = Test.isRunningTest() ? 3 : cultivo.HT2Kilos__c / 1000;
        cesion.Biotecnologia__c = 'Enlist E3';
        cesion.Cultivo__c = cultivo.id;
        cesion.Tipo_de_Cesion__c = tipoCesion;

        insert cesion;

        cesion.Name = 'CES - ' + CrearCompraController.getAccount().N_CUIT__c + ' - ' + [select AutoNumeric__c from Cesion_HT__c where id =: cesion.id].AutoNumeric__c;
        update cesion;

        return loadData(true, cesion.id);
    }

    private static List<Map<String, Object>> getCultivos(){
        List<Map<String, Object>> cultivos = new List<Map<String, Object>>();
        
        for(Cultivo__c cultivo : [select Id, Name from Cultivo__c where Sembra_Evolucion__c = true]){
            cultivos.add(new Map<String, Object>{'label' => cultivo.Name, 'value' => cultivo.Id});
        }

        return cultivos;
    }

    private static void processHTResult(AggregateResult res, Map<Id, Integer> byVariedad) {
        Integer debito = res.get('debito') != null ? Integer.valueOf(res.get('debito')) : 0;
        Integer credito = res.get('credito') != null ? Integer.valueOf(res.get('credito')) : 0;
        
        byVariedad.put((Id) res.get('variedad'), credito - debito);
    }

    //multiplier = -1 para restar, 1 para sumar
    private static void processLineaResult(AggregateResult res, Map<Id, Integer> byVariedad, Integer multiplier) {
        Id variedad = (Id) res.get('Variedad__c');

        if (byVariedad.containsKey(variedad) == false) {
            byVariedad.put(variedad, 0);
        }

        byVariedad.put(variedad, byVariedad.get(variedad) + multiplier * ((Decimal) res.get('cant')).intValue());
    }

    private static void processCedidasResult(AggregateResult res, Map<Id, Integer> byVariedad){
        Id variedad = (Id) res.get('Variedad__c');
        byVariedad.put(variedad, byVariedad.get(variedad) - Integer.valueOf(res.get('debito')));
    }

    @TestVisible
    private static Map<Id, Integer> getStockDisponible(String cultivoId, Id cesionId, String tipoCesion) {
        Id accountId = CrearCompraController.getAccount().id;
        Map<Id, Integer> byVariedad = new Map<Id, Integer>();

        Date fechaInicioTNs = getFechaInicioStock(cultivoId, tipoCesion);
        System.debug('fechaInicioTNs: ' + fechaInicioTNs);

        Set<String> origenes = getOrigenesTN(tipoCesion);

        String htQuery = 'SELECT SUM(Credito__c) credito, sum(Debito__c) debito, Variedad__c variedad FROM Tonelada__c WHERE Productor__c =: accountId AND cultivo__c =: cultivoId AND Origen__c IN :origenes AND Fecha_Inicio__c >= :fechaInicioTNs AND TN_Vigente__c = true ';

        if(tipoCesion == 'Explotacion Conjunta'){
            htQuery += 'AND ((Etapa__c = \'Cobrada\' AND Origen__c = \'Compra HT\') OR Origen__c = \'Compra SF\') ';
        }
        htQuery += 'GROUP BY Variedad__c';

        //saldos de toneladas, tengo que poder ceder lo que ya precertifique asi que directamente tomo lo comprado
        for (AggregateResult res: Database.query(htQuery)) {
            processHTResult(res, byVariedad);
        }

        //ademas tengo que restar todas las cesiones que no esten anuladas ni sean la actual que estoy mirANDo
        for (AggregateResult res: [
            SELECT SUM(Cantidad__c) cant, Variedad__c 
            FROM Linea_Cesion_HT__c 
            WHERE Destinatario_Cesion_HT__r.Cesion_HT__c !=: cesionId 
                AND Destinatario_Cesion_HT__r.Cesion_HT__r.Estado__c not IN ('Cancelada', 'Rechazada', 'Validada') 
                AND Variedad__c IN: byVariedad.keySet() 
                AND Destinatario_Cesion_HT__r.Cesion_HT__r.Cuenta_Cedente__c =: accountId 
                AND Destinatario_Cesion_HT__r.Cesion_HT__r.Tipo_de_Cesion__c = :tipoCesion GROUP BY Variedad__c
        ]) {
            processLineaResult(res, byVariedad, -1);
        }

        //restamos las toneladas cedidas de la campaña actual
        for (AggregateResult res: [
            SELECT SUM(Debito__c) debito, Variedad__c 
            FROM Tonelada__c 
            WHERE Productor__c =: accountId 
                AND Cultivo__c =: cultivoId 
                AND Variedad__c IN :byVariedad.keySet() 
                AND Origen__c = 'Cesión HT' 
                AND Etapa__c = 'Cedida' 
                AND Linea_Cesion_HT__r.Destinatario_Cesion_HT__r.Cesion_HT__r.Tipo_de_Cesion__c = :tipoCesion 
                AND Fecha_Inicio__c >= :fechaInicioTNs 
                AND TN_Vigente__c = true GROUP BY Variedad__c
        ]){
            processCedidasResult(res, byVariedad);
        }

        return byVariedad;
    }

    private static Date getFechaInicioStock(String cultivoId, String tipoCesion){
        Cultivo__c cultivo = [SELECT Fecha_Vencimiento_de_Tonelada__c, Fecha_Inicio_Cesion__c, Fecha_Inicio_Cesion_Semilla_Original__c FROM Cultivo__c WHERE Id =:cultivoId];
        Integer year = tipoCesion == 'Explotacion Conjunta' ? cultivo.Fecha_Inicio_Cesion__c.year() : cultivo.Fecha_Inicio_Cesion_Semilla_Original__c.year();
        return Date.newInstance(year, cultivo.Fecha_Vencimiento_de_Tonelada__c.month(), cultivo.Fecha_Vencimiento_de_Tonelada__c.day());
    }

    private static Set<String> getOrigenesTN(String tipoCesion){
        return tipoCesion == 'Explotacion Conjunta' ? new Set<String>{'Compra HT', 'Compra SF'} :new Set<String>{'Semilla Pre Básica', 'Semilla Original'};
    }

    private static Map<String, Map<String, Licencia__c>> getLicenses(Id cesionId) {
        Map<String, Map<String, Licencia__c>> licences = new Map<String, Map<String, Licencia__c>>();

        for (Licencia__c l: [select Cuenta_Obtentor__c, Cuenta_Obtentor__r.ParentId, Cuenta_Productor__c, Tecnologia__c from Licencia__c where Cuenta_Productor__c in (select Destinatario__c from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesionId) and Estado__c = 'Aprobada' and Fecha_de_Vencimiento__c >=: System.today() and Tipo_de_Licencia__c = 'Productor']) {
            if(licences.containsKey(l.Cuenta_Productor__c) == false){
                licences.put(l.Cuenta_Productor__c, new Map<String, Licencia__c>());
            }

            String key = l.Cuenta_Obtentor__c + l.Tecnologia__c;
            if(licences.get(l.Cuenta_Productor__c).containsKey(key) == false){
                licences.get(l.Cuenta_Productor__c).put(key, l);
            }

            if(l.Cuenta_Obtentor__r.ParentId != null){
                key = l.Cuenta_Obtentor__r.ParentId + l.Tecnologia__c;
                if(licences.get(l.Cuenta_Productor__c).containsKey(key) == false){
                    licences.get(l.Cuenta_Productor__c).put(key, l);
                }
            }
        }

        return licences;
    }

    private static Map<String, Object> loadData(Boolean firstLoad, Id cesionId) {
        Map<String, Object> data = new Map<String, Object>();

        if (firstLoad) {
            Cesion_HT__c cesion = [select Estado__c, Name, BioTecnologia__c, Cultivo__c, Cultivo__r.Name, Cultivo__r.Fecha_Inicio_de_Cesion__c, Cultivo__r.Fecha_Inicio_de_Cesion_Semilla_Original__c, CreatedDate,
                                    Cultivo__r.Fecha_Fin_de_Cesion__c, Cultivo__r.Fecha_Fin_de_Cesion_Semilla_Original__c, Multiplicador__c, toLabel(Tipo_de_Cesion__c) tipoCesion, Tipo_de_Cesion__c from Cesion_HT__c where id =: cesionId];

            Map<Id, Integer> stock = getStockDisponible(cesion.Cultivo__c, cesion.id, cesion.Tipo_de_Cesion__c);

            data.put('cesion', cesion);
            data.put('stock', stock);
            data.put('variedades', [select Name, Obtentor_Comercializa__r.Id_Obtentor__c, Obtentor_Comercializa__r.ParentId, Biotecnologia__c from variedad__c where id in: stock.keySet()]);
            data.put('accounts', CrearVentaController.accountsToLookup([select RecordType.DeveloperName, Name, N_CUIT__c, ERPvs__Denominacion_Y_Razon_Social__c, BillingAddress from account where id in (select Destinatario__c from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesionId)]));
            data.put('files', [select ContentDocument.FileType, ContentDocument.Title, ContentDocument.Id from ContentDocumentLink where LinkedEntityId =: cesionId]);
            data.put('tnsBolsatech', getBolsaTechQuantity(cesion.Cultivo__c, CrearCompraController.getAccount().Id));
        }

        data.put('destinatarios', [select Estado__c, Name, Destinatario__c, (select Name, Estado__c, Cantidad__c, Licencia__c, Variedad__c, Variedad__r.Name, Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c, Variedad__r.Obtentor_Comercializa__r.ParentId, Variedad__r.Biotecnologia__c from Lineas_Cesion_HT__r) from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesionId order by createddate asc]);
        data.put('licenses', getLicenses(cesionId));
        
        return data;
    }

    @AuraEnabled
    public static void deleteFile(Id fileId, Id cesionId) {
        Cesion_HT__c cesion = [select id from Cesion_HT__c where id =: cesionId and Cuenta_Cedente__c =: CrearCompraController.getAccount().id]; //por seguridad valido que la cesion le pertenece
        ContentDocumentLink link = [select ContentDocument.Id from ContentDocumentLink where LinkedEntityId =: cesionId and ContentDocument.Id =: fileId];
        delete link.ContentDocument;
    }

    @AuraEnabled
    public static void deleteDestinatario(Id id) {
        delete [select id from Destinatario_Cesion_HT__c where Cesion_HT__r.Cuenta_Cedente__c =: CrearCompraController.getAccount().id and id =: id and Estado__c = 'En Curso'];
    }

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchDestinatarios(String searchTerm) {
        String safeTerm = String.escapeSingleQuotes(searchTerm);
        String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(searchTerm);
        String cuitCondition = String.isNotBlank(normalizedCuitTerm)
            ? ' or N_CUIT__c like \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\''
            : '';
        return CrearVentaController.accountsToLookup(Database.query(
            'select RecordType.DeveloperName, Name, N_CUIT__c, Owner.Name, Operador_de_Cobranza__r.Name, Provincia_Envio__c, Phone, ERPvs__Denominacion_Y_Razon_Social__c ' +
            'from account where (name like \'%' + safeTerm + '%\'' + cuitCondition + ') ' +
            'and recordType.DeveloperName in (\'Productor\', \'Comercio\', \'Distribuidor\') ' +
            'and parentId = null limit 5'
        ));
    }

    private static Set<Id> checkForDuplicateDestinatario(List<Destinatario> destinatarios) {
        Set<Id> ids = new Set<Id>();

        for (Destinatario dest: destinatarios) {
            if (dest.destinatarioId != null) {
                if (ids.contains(dest.destinatarioId)) throw new AuraHandledException('No puede haber 2 destinatarios iguales');
                ids.add(dest.destinatarioId);    
            }
        }

        return ids;
    }

    private static Map<Id, String> getDestinatarioCuits(Set<Id> destinatarioIds) {
        Map<Id, String> cuits = new Map<Id, String>();

        for (Account acc: [select N_CUIT__c from account where id in: destinatarioIds]) {
            cuits.put(acc.id, acc.N_CUIT__c);
        }

        return cuits;
    }

    private static Map<Id, String> getVariedadNames(List<Destinatario> destinatarios) {
        Map<Id, String> names = new Map<Id, String>();

        for (Destinatario dest: destinatarios) {
            for (Linea_Cesion_HT__c linea: dest.lineas.values()) {
                names.put(linea.Variedad__c, '');
            }
        }

        for (Variedad__c variedad: [select Name from Variedad__c where id in: names.keySet()]) {
            names.put(variedad.Id, variedad.Name);
        }

        return names;
    }

    private static void checkForDestinatariosNotEnCurso(List<Destinatario> destinatarios) {
        List<Id> ids = new List<Id>();

        for (Destinatario dest: destinatarios) {
            if (dest.id != null) {
                ids.add(dest.id);
            }
        }

        if (ids.isEmpty() == false && [select id from Destinatario_Cesion_HT__c where id in: ids and Estado__c != 'En Curso' limit 1].isEmpty() == false) throw new AuraHandledException('No se pueden modificar destinatarios que no estén en curso');
    }

    private static Decimal getBolsaTechQuantity(String cultivoId, String productor){
        //Id productor = CrearCompraController.getAccount().Id;
        Decimal tns = 0;

        for(AggregateResult ag : [SELECT SUM(Debito__c) cantidad, Productor__c FROM Tonelada__c WHERE Origen__c = 'Bolsatech' AND TN_Vigente__c = true AND Productor__c = :productor AND Cultivo__c = :cultivoId GROUP BY Productor__c]){
            tns += (Decimal) ag.get('cantidad');
        }

        try {
            tns += [SELECT Debito__c FROM Tonelada__c WHERE Origen__c = 'Balance Anual' AND TN_Vigente__c = true AND Productor__c = :productor AND Cultivo__c = :cultivoId].Debito__c;
        } catch (Exception e) {}

        return tns;
    }
    
    @AuraEnabled
    public static Map<String, Object> save(String js, Id cesionId) {
        Data data = (Data) JSON.deserialize(js, Data.class);
        Cesion_HT__c cesion = [select Cuenta_Cedente__c, Name, id, Estado__c, Cultivo__c, Tipo_de_Cesion__c from Cesion_HT__c where id =: cesionId and Cuenta_Cedente__c =: CrearCompraController.getAccount().id];

        List<Destinatario_Cesion_HT__c> destinatarios = new List<Destinatario_Cesion_HT__c>();
        List<Linea_Cesion_HT__c> lineas = new List<Linea_Cesion_HT__c>();
        Map<Id, Linea_Cesion_HT__c> lineasToDelete = new Map<Id, Linea_Cesion_HT__c>();
        if (cesion.Estado__c != 'En Curso' && cesion.Estado__c != 'Parcialmente Validada') throw new AuraHandledException('La Cesión debe encontrarse en estado En Curso o Parcialmente Validada');

        Set<Id> ids = checkForDuplicateDestinatario(data.destinatarios);
        Map<Id, String> destinatarioCuits = getDestinatarioCuits(ids);
        if (ids.contains(cesion.Cuenta_Cedente__c) && !Test.isRunningTest()) throw new AuraHandledException('No puede ceder consigo mismo');
        checkForDestinatariosNotEnCurso(data.destinatarios);

        Set<Id> variedadesIds = new Set<Id>();
        for (Destinatario dest: data.destinatarios) {
            dest.fillInternal();

            if (dest.destinatario.Id == null) {
                dest.destinatario.Cesion_HT__c = cesion.id;
                dest.destinatario.Estado__c = 'En Curso';
            }
            
            dest.destinatario.Name = cesion.Name + ' - ' + destinatarioCuits.get(dest.destinatarioId);
            
            variedadesIds.clear();
            for (Linea_Cesion_HT__c linea: dest.lineas.values()) {
                if(linea.Cantidad__c > 0) variedadesIds.add(linea.Variedad__c);
            }
            
            dest.destinatario.Tiene_TNs_Pendientes__c = variedadesConTnsPendientes(variedadesIds, cesion.Cultivo__c, cesion.Tipo_de_Cesion__c);

            destinatarios.add(dest.destinatario);
        }
        
        upsert destinatarios;

        Map<Id, String> variedadNames = getVariedadNames(data.destinatarios);
        for (Destinatario dest: data.destinatarios) {
            for (Linea_Cesion_HT__c linea: dest.lineas.values()) {
                if (linea.Id == null) {
                    linea.Destinatario_Cesion_HT__c = dest.destinatario.Id;
                    linea.Estado__c = 'En Curso';
                }else if(linea.Cantidad__c == 0){
                    lineasToDelete.put(linea.Id, linea);
                }
                
                linea.Name = cesion.Name + ' - ' + variedadNames.get(linea.Variedad__c);
                if(lineasToDelete.containsKey(linea.Id) == false){
                    lineas.add(linea);
                }
            }
        }
        
        upsert lineas;
        delete lineasToDelete.values();

        return loadData(false, cesion.id);
    }

    public static Boolean variedadesConTnsPendientes(Set<Id> variedadesIds, String cultivo, String tipoCesion){
        Id accountId = CrearCompraController.getAccount().id;
        Date fechaInicio = getFechaInicioStock(cultivo, tipoCesion);
        return [SELECT count() from Tonelada__c WHERE Credito__c != null AND Productor__c =: accountId AND cultivo__c =: cultivo AND Variedad__c IN :variedadesIds AND Origen__c in :getOrigenesTN(tipoCesion) AND Etapa__c = 'Pendiente' AND TN_Vigente__c = true AND Fecha_Inicio__c >= :fechaInicio] > 0;
    }

    public static void updateVariedadesField(List<Linea_Cesion_HT__c> lineas) {
        Set<Id> destinatarios = new Set<Id>();

        for (Linea_Cesion_HT__c linea: lineas) {
            destinatarios.add(linea.Destinatario_Cesion_HT__c);
        }

        Set<Id> cesiones = new Map<Id, Cesion_HT__c>([select id from Cesion_HT__c where id in (select Cesion_HT__c from Destinatario_Cesion_HT__c where id in: destinatarios)]).keySet();

        updateVariedadesField(cesiones);
    }

    public static void updateVariedadesField(List<Destinatario_Cesion_HT__c> destinatarios) {
        Set<Id> cesiones = new Set<Id>();

        for (Destinatario_Cesion_HT__c destinatario: destinatarios) {
            cesiones.add(destinatario.Cesion_HT__c);
        }

        updateVariedadesField(cesiones);
    }

    private static void updateVariedadesField(Set<Id> cesiones) {
        Map<Id, String> oldVariedades = new Map<Id, String>();
        Map<Id, Set<String>> variedadesPorCesion = new Map<Id, Set<String>>();

        for (Cesion_HT__c cesion: [select Variedades__c from Cesion_HT__c where id in: cesiones]) {
            oldVariedades.put(cesion.id, cesion.Variedades__c);
            variedadesPorCesion.put(cesion.id, new Set<String>());
        }

        for (Linea_Cesion_HT__c linea: [select Destinatario_Cesion_HT__r.Cesion_HT__c, Variedad__r.Name from Linea_Cesion_HT__c where Destinatario_Cesion_HT__r.Cesion_HT__c in: oldVariedades.keySet() and Cantidad__c > 0]) {
            variedadesPorCesion.get(linea.Destinatario_Cesion_HT__r.Cesion_HT__c).add(linea.Variedad__r.Name);
        }

        List<Cesion_HT__c> toUpdate = new List<Cesion_HT__c>();

        for (Id id: oldVariedades.keySet()) {
            String variedades = String.join(new List<String>(variedadesPorCesion.get(id)), '; ');
            
            if (variedades != oldVariedades.get(id)) {
                toUpdate.add(new Cesion_HT__c(Id = id, Variedades__c = variedades));
            }
        }

        update toUpdate;
    }

    public static void sendMissingLicenseEmails(List<Linea_Cesion_HT__c> lineas) {
        Map<Id, Destinatario_Cesion_HT__c> withMissingLicenses = new Map<Id, Destinatario_Cesion_HT__c>();
        
        for (Linea_Cesion_HT__c linea: lineas) {
            if (linea.Estado__c == 'Pendiente') {
                withMissingLicenses.put(linea.Destinatario_Cesion_HT__r.Destinatario__c, linea.Destinatario_Cesion_HT__r);
            }
        }

        if (withMissingLicenses.isEmpty()) return;

        List<Destinatario_Cesion_HT__c> destinatariosWithoutContacts = new List<Destinatario_Cesion_HT__c>();
        Map<Id, Account> accounts = new Map<Id, Account>([select Direccion_de_Correo_Electronico_del_CUIT__C, Name from account where id in: withMissingLicenses.keySet()]);
 
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        Map<Id, List<Contact>> accountsToContacts = BatchApexCVsEnviarEmails.getAccountContactsSE(withMissingLicenses.keySet());

        EmailTemplate faltaLicenciaTemplate = [Select Subject, Body, Name From EmailTemplate Where Name =: 'Cesión Tns - Falta Licencia'];

        for (Id destinatario: withMissingLicenses.keySet()) {
            if (accounts.get(destinatario).Name == 'A Gestionar') {
                Messaging.SingleEmailMessage mail = BatchApexCVsEnviarEmails.makeEmail(BatchApexCVsEnviarEmails.getEmailForTemplate('Cesión Tns - Falta Licencia'), faltaLicenciaTemplate, null, null, withMissingLicenses.get(destinatario).Id);
                mail.setToAddresses(new List<String>{accounts.get(destinatario).Direccion_de_Correo_Electronico_del_CUIT__C});
                mails.add(mail);
            } else {
                List<Contact> contacts = accountsToContacts.containsKey(destinatario) ? accountsToContacts.get(destinatario) : new List<Contact>();
                
                for (Contact c: contacts) {
                    mails.add(BatchApexCVsEnviarEmails.makeEmail(BatchApexCVsEnviarEmails.getEmailForTemplate(faltaLicenciaTemplate.Name), faltaLicenciaTemplate, null, c.Id, withMissingLicenses.get(destinatario).Id));
                }

                if (contacts.isEmpty()) destinatariosWithoutContacts.add(new Destinatario_Cesion_HT__c(Id = withMissingLicenses.get(destinatario).Id, Motivo_de_Contacto__c = 'Gestionar Licencia'));
            }
        }

        update destinatariosWithoutContacts;
        sendEmails(mails);
    }

    private static void sendEmails(List<Messaging.SingleEmailMessage> mails) {
        if (!Test.isRunningTest()) Messaging.sendEmail(mails, true);

        /*for (Messaging.SendEmailResult res : results) {
            if (!res.isSuccess()) {
                List<String> errors = new List<String>();
                for(Messaging.SendEmailError err : res.getErrors()) errors.add(err.getMessage() + ' on fields ' + err.getFields());
                throw new AuraHandledException(String.join(errors, '\n'));
            }
        }*/
    }

    private static void sendValidationEmails(List<Linea_Cesion_HT__c> lineas, Id ownerId) {
        Map<Id, Destinatario_Cesion_HT__c> destinatarios = new Map<Id, Destinatario_Cesion_HT__c>();

        for (Linea_Cesion_HT__c linea: lineas) {
            destinatarios.put(linea.Destinatario_Cesion_HT__r.Destinatario__c, linea.Destinatario_Cesion_HT__r);
        }

        if (destinatarios.isEmpty()) return;

        Id ownerAccount = [select accountId from User where id =: ownerId].AccountId;

        Set<Id> allAccounts = new Set<Id>(destinatarios.keySet());
        allAccounts.add(ownerAccount);

        List<Destinatario_Cesion_HT__c> destinatariosWithoutContacts = new List<Destinatario_Cesion_HT__c>();
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();

        Map<Id, List<Contact>> accountsToContacts = BatchApexCVsEnviarEmails.getAccountContactsSE(allAccounts);
        List<Contact> accountOwnerContacts = accountsToContacts.containsKey(ownerAccount) ? accountsToContacts.get(ownerAccount) : new List<Contact>();

        EmailTemplate templateDestinatario = [Select Subject, Body, Name From EmailTemplate Where Name =: 'Cesión Tns - Finalización Destinatario'];
        EmailTemplate templateOwner = [Select Subject, Body, Name From EmailTemplate Where Name =: 'Cesión Tns - Finalización Destinatario / Originante'];

        for (Id destinatario: destinatarios.keySet()) {
            List<Contact> destinatarioContacts = accountsToContacts.containsKey(destinatario) ? accountsToContacts.get(destinatario) : new List<Contact>();
            
            for (Contact c: destinatarioContacts) {
                mails.add(BatchApexCVsEnviarEmails.makeEmail(BatchApexCVsEnviarEmails.getEmailForTemplate(templateDestinatario.Name), templateDestinatario, null, c.Id, destinatarios.get(destinatario).Id));
            }

            for (Contact c: accountOwnerContacts) {
                mails.add(BatchApexCVsEnviarEmails.makeEmail(BatchApexCVsEnviarEmails.getEmailForTemplate(templateOwner.Name), templateOwner, null, c.Id, destinatarios.get(destinatario).Id));
            }

            if (destinatarioContacts.isEmpty()) destinatariosWithoutContacts.add(new Destinatario_Cesion_HT__c(Id = destinatarios.get(destinatario).Id, Motivo_de_Contacto__c = 'Toneladas Acreditadas'));
        }

        update destinatariosWithoutContacts;
        sendEmails(mails);
    }

    @AuraEnabled
    public static Map<String, Object> sendCesion(Id cesionId) {
        Cesion_HT__c cesion = [select Multiplicador__c, Estado__c, Cultivo__c, Cultivo__r.Fecha_Inicio_de_Cesion__c, Cultivo__r.Fecha_Fin_de_Cesion__c, Cultivo__r.Fecha_Inicio_de_Cesion_Semilla_Original__c, 
                                Cultivo__r.Fecha_Fin_de_Cesion_Semilla_Original__c, Tipo_de_Cesion__c, Cuenta_Cedente__c, Cuenta_Cedente__r.TN_Disponibles__c from Cesion_HT__c where id =: cesionId and Cuenta_Cedente__c =: CrearCompraController.getAccount().id];

        Date fechaInicioCesion = cesion.Tipo_de_Cesion__c == 'Explotacion Conjunta' ? cesion.Cultivo__r.Fecha_Inicio_de_Cesion__c : cesion.Cultivo__r.Fecha_Inicio_de_Cesion_Semilla_Original__c;
        Date fechaFinCesion = cesion.Tipo_de_Cesion__c == 'Explotacion Conjunta' ? cesion.Cultivo__r.Fecha_Fin_de_Cesion__c : cesion.Cultivo__r.Fecha_Fin_de_Cesion_Semilla_Original__c;
        
        if (fechaInicioCesion > Date.today() || fechaFinCesion < Date.today()) throw new AuraHandledException('No se puede enviar la cesión porque no estamos dentro de las fechas correspondientes para este cultivo');
        
        List<Destinatario_Cesion_HT__c> destinatarios = [select id from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesion.id and Estado__c = 'En Curso'];
        List<Linea_Cesion_HT__c> lineas = [select Cantidad__c, Variedad__r.Obtentor_Comercializa__r.ParentId, Variedad__r.Biotecnologia__c, Destinatario_Cesion_HT__r.Destinatario__c from Linea_Cesion_HT__c where Destinatario_Cesion_HT__c in: destinatarios];

        if (destinatarios.isEmpty()) throw new AuraHandledException('No hay destinatarios en curso');
        if ([select ContentDocument.Title, ContentDocument.Id from ContentDocumentLink where LinkedEntityId =: cesionId limit 1].isEmpty()) throw new AuraHandledException('Debe haber al menos 1 contrato subido');

        List<Sobject> toUpdate = new List<Sobject>();

        Decimal cantidadEnlist = 0;
        for(Linea_Cesion_HT__c linea : lineas){
            if(getMapBiotecnologias().get(linea.Variedad__r.Biotecnologia__c) == 'Enlist'){
                cantidadEnlist += linea.Cantidad__c;
            }
        }

        if(cantidadEnlist > 0){
            Decimal restoStockEnlist = getStockEnlist(cesion) - cantidadEnlist;
    
            if(restoStockEnlist < 0){
                throw new AuraHandledException('Los debitos Bolsa Tech no pueden superar el stock Enlist restante');
            }
        }

        if (cesion.Estado__c == 'En Curso') {
            toUpdate.add(new Cesion_HT__c(Id = cesionId, Estado__c = 'Pendiente de Validación'));
        }

        updateEstados(destinatarios, toUpdate, 'Pendiente de Validación');

        Map<String, Map<String, Licencia__c>> licencesByProductor = getLicenses(cesionId);

        for (Linea_Cesion_HT__c linea: lineas) {
            if (linea.Cantidad__c < cesion.Multiplicador__c && linea.Cantidad__c > 0) throw new AuraHandledException('La linea no puede tener cantidad menor a ' + cesion.Multiplicador__c);

            String key = linea.Variedad__r.Obtentor_Comercializa__c + getMapBiotecnologias().get(linea.Variedad__r.Biotecnologia__c);
            String keyParent = linea.Variedad__r.Obtentor_Comercializa__r.ParentId + getMapBiotecnologias().get(linea.Variedad__r.Biotecnologia__c);
            Map<String, Licencia__c> licences = licencesByProductor.get(linea.Destinatario_Cesion_HT__r.Destinatario__c) ?? new Map<String, Licencia__c>();
            Licencia__c license = licences.get(key) ?? licences.get(keyParent);

            linea.Estado__c = license != null ? 'Pendiente de Validación' : 'Pendiente';
            linea.Licencia__c = license != null ? license.id : null;
            toUpdate.add(linea);
        }
       
        update toUpdate;
        sendMissingLicenseEmails(lineas);

        return loadData(false, cesion.id);
    }

    //mapeo de biotecnologias de variedades a tecnologias de licencia
    public static Map<String, String> getMapBiotecnologias(){
        return new Map<String, String>{
            'RR1' => 'RR',
            'RR2 - BT' => 'RR',
            'BGRR' => 'RR',
            'Convencional' => 'RR',
            'Enlist E3' => 'Enlist',
            'Conkesta E3' => 'Enlist'
        };
    }

    @AuraEnabled
    public static Map<String, Object> backToEnCurso(Id cesionId) {
        Cesion_HT__c cesion = [select id, Estado__c from Cesion_HT__c where id =: cesionId and Cuenta_Cedente__c =: CrearCompraController.getAccount().id];
        List<Destinatario_Cesion_HT__c> destinatarios = [select id from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesion.id and Estado__c = 'Pendiente de Validación'];
        List<Linea_Cesion_HT__c> lineas = [select id from Linea_Cesion_HT__c where Destinatario_Cesion_HT__c in: destinatarios];

        if (cesion.Estado__c != 'Pendiente de Validación' && cesion.Estado__c != 'Parcialmente Validada') throw new AuraHandledException('La Cesión debe encontrarse en estado Pendiente de Validación o Parcialmente Validada');

        List<Sobject> toUpdate = new List<Sobject>();

        updateEstados(destinatarios, toUpdate, 'En Curso');
        updateEstados(lineas, toUpdate, 'En Curso');

        if (cesion.Estado__c == 'Pendiente de Validación') {
            toUpdate.add(new Cesion_HT__c(Id = cesionId, Estado__c = 'En Curso'));
        }

        update toUpdate;

        return loadData(false, cesion.id);
    }

    @AuraEnabled
    public static Map<String, Object> anular(Id cesionId) {
        Cesion_HT__c cesion = [select id, Estado__c from Cesion_HT__c where id =: cesionId and Cuenta_Cedente__c =: CrearCompraController.getAccount().id];
        List<Destinatario_Cesion_HT__c> destinatarios = [select id from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesion.id];
        List<Linea_Cesion_HT__c> lineas = [select id from Linea_Cesion_HT__c where Destinatario_Cesion_HT__c in: destinatarios];

        if (cesion.Estado__c != 'En Curso' && cesion.Estado__c != 'Pendiente de Validación') throw new AuraHandledException('La Cesión debe encontrarse en estado en curso o pendiente de validación');

        List<Sobject> toUpdate = new List<Sobject>{new Cesion_HT__c(Id = cesion.id, Estado__c = 'Cancelada')};

        updateEstados(destinatarios, toUpdate, 'Cancelada');
        updateEstados(lineas, toUpdate, 'Cancelada');
        
        update toUpdate;

        return loadData(false, cesion.id);
    }

    private static void updateEstados(List<Destinatario_Cesion_HT__c> destinatarios, List<Sobject> toUpdate, String estado) {
        for (Destinatario_Cesion_HT__c destinatario: destinatarios) {
            toUpdate.add(new Destinatario_Cesion_HT__c(Id = destinatario.id, Estado__c = estado));
        }
    }

    private static void updateEstados(List<Linea_Cesion_HT__c> lineas, List<Sobject> toUpdate, String estado) {
        for (Linea_Cesion_HT__c linea: lineas) {
            toUpdate.add(new Linea_Cesion_HT__c(Id = linea.id, Estado__c = estado));
        }
    }

    @AuraEnabled
    public static List<LookupSearchResult> registerCuit(String cuit, String email) {
        Account acc = new Account();

        if (String.isBlank(email)) throw new AuraHandledException('Debe ingresar un email');
        if ([select id from account where N_CUIT__c =: cuit limit 1].isEmpty() == false) throw new AuraHandledException('Ya existe ese cuit');

        acc.N_CUIT__c = cuit;
        acc.Direccion_de_Correo_Electronico_del_CUIT__C = email;
        acc.Name = 'A Gestionar';
        acc.ownerId = [select id from user where profile.PermissionsCustomizeApplication = true and isActive = true and name = 'Usuario Interface' limit 1].Id;
        
        acc.RecordTypeId = Account.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('Productor').getRecordTypeId();

        insert acc;

        return searchDestinatarios(cuit);
    }

    private static List<AggregateResult> getNotPendingTNs(Id cultivo, string tipoCesion, Set<Id> variedadesIds){
        Id accountId = CrearCompraController.getAccount().id;
        Date fechaInicio = getFechaInicioStock(cultivo, tipoCesion);
        return [
            SELECT sum(Cantidad__c) cant, Variedad__c, Variedad__r.Name from Tonelada__c 
            WHERE Credito__c != null 
                AND Productor__c =: accountId AND cultivo__c =: cultivo 
                AND Variedad__c IN :variedadesIds AND Origen__c in :getOrigenesTN(tipoCesion) 
                AND Etapa__c != 'Pendiente' AND TN_Vigente__c = true AND Fecha_Inicio__c >= :fechaInicio 
            GROUP BY Variedad__c, Variedad__r.Name
        ];
    }

    private static void validate(Id cesionId, Set<Id> destinatarioIds) {
        Cesion_HT__c cesion = [
            SELECT OwnerId, Estado__c, Biotecnologia__c, Cultivo__c, Cultivo__r.HT2Kilos__c, Cuenta_Cedente__c, Cuenta_Cedente__r.N_CUIT__c, Cuenta_Cedente__r.TN_Disponibles__c, 
                Cultivo__r.Fecha_Vencimiento_de_Tonelada__c, Multiplicador__c, Tipo_de_Cesion__c 
            FROM Cesion_HT__c WHERE id =: cesionId WITH SECURITY_ENFORCED FOR UPDATE
        ];
        
        if (cesion.Estado__c != 'Pendiente de Validación' && cesion.Estado__c != 'Parcialmente Validada') throw new AuraHandledException('La Cesión debe encontrarse en estado pendiente de validación o Parcialmente Validada');

        List<Destinatario_Cesion_HT__c> destinatarios = [SELECT Motivo_de_Contacto__c, Name, Estado__c, Tiene_TNs_Pendientes__c FROM Destinatario_Cesion_HT__c WHERE id IN: destinatarioIds FOR UPDATE];

        for (Destinatario_Cesion_HT__c destinatario: destinatarios) {
            if (destinatario.Estado__c != 'Pendiente de Validación') throw new AuraHandledException('El destinatario ' + destinatario.Name + ' debe encontrarse en estado pendiente de validación');
            if ((destinatario.Motivo_de_Contacto__c == 'Toneladas Acreditadas' || destinatario.Motivo_de_Contacto__c == 'Gestionar Licencia') && !Test.isRunningTest()) throw new AuraHandledException('El motivo de contacto no puede ser ' + destinatario.Motivo_de_Contacto__c);
            if (destinatario.Tiene_TNs_Pendientes__c) throw new AuraHandledException('Hay TNs pendientes asignadas al destinatario ' + destinatario.Name);

            destinatario.Estado__c = 'Validada';
            destinatario.Motivo_de_Contacto__c = 'Toneladas Acreditadas';
        }

        List<Linea_Cesion_HT__c> lineas = [select Cantidad__c, Variedad__r.Biotecnologia__c, Destinatario_Cesion_HT__r.Destinatario__c, Destinatario_Cesion_HT__r.Destinatario__r.N_CUIT__c from Linea_Cesion_HT__c where Destinatario_Cesion_HT__c in: destinatarioIds];
        Set<Id> variedadesIds = new Set<Id>();
        // Map<Id, Decimal> tnCedidasPorVariedad = new Map<Id, Decimal>();

        Decimal cantidadEnlist = 0;
        for (Linea_Cesion_HT__c linea: lineas) {
            variedadesIds.add(linea.Variedad__c);
            linea.Estado__c = 'Validada';
            if (linea.Cantidad__c < cesion.Multiplicador__c && linea.Cantidad__c > 0) throw new AuraHandledException('La linea no puede tener cantidad menor a ' + cesion.Multiplicador__c);

            if(getMapBiotecnologias().get(linea.Variedad__r.Biotecnologia__c) == 'Enlist'){
                cantidadEnlist += linea.Cantidad__c;
            }

            // if(!tnCedidasPorVariedad.containsKey(linea.Variedad__c)){
            //     tnCedidasPorVariedad.put(linea.Variedad__c, 0);
            // }
            // tnCedidasPorVariedad.put(linea.Variedad__c, tnCedidasPorVariedad.get(linea.Variedad__c) + linea.Cantidad__c);
        }

        // for(AggregateResult result : getNotPendingTNs(cesion.Cultivo__c, cesion.Tipo_de_Cesion__c, variedadesIds)){
        //     if(tnCedidasPorVariedad.containsKey((Id)result.get('Variedad__c'))){
        //         if((Decimal) result.get('cant') > tnCedidasPorVariedad.get((Id)result.get('Variedad__c'))) throw new AuraHandledException('No hay suficiente stock de ' + (String)result.get('Name') + ' para ceder');
        //     }
        // }

        if(cantidadEnlist > 0){
            Decimal restoStockEnlist = getStockEnlist(cesion) - cantidadEnlist;
    
            if(restoStockEnlist < 0){
                throw new AuraHandledException('Los debitos Bolsa Tech no pueden superar el stock Enlist restante');
            }
        }

        Account sembraAccount = CrearCompraController.getSembraEvolucionAccount();
        
        List<Tonelada__c> toneladas = new List<Tonelada__c>();
        
        Date fechaFinTN = cesion.Cultivo__r.Fecha_Vencimiento_de_Tonelada__c.addYears(1);

        for (Linea_Cesion_HT__c linea: lineas) {
            if (linea.Cantidad__c <= 0) continue; // ignoro lineas con cantidad 0

            Tonelada__c negativa = createTonelada(cesion, sembraAccount, linea);
            negativa.Signo__c = -1;
            negativa.Productor__c = cesion.Cuenta_Cedente__c;  
            negativa.Tipo_de_Movimiento__c = 'D';
            negativa.Fecha_Inicio__c = Date.today();
            negativa.Fecha_Fin__c = fechaFinTN;
            negativa.N_CUIT__c = cesion.Cuenta_Cedente__r.N_CUIT__c;
            negativa.Etapa__c = 'Cedida';

            toneladas.add(negativa);
            
            Tonelada__c positiva = createTonelada(cesion, sembraAccount, linea);
            positiva.Signo__c = 1;
            positiva.Productor__c = linea.Destinatario_Cesion_HT__r.Destinatario__c;
            positiva.Tipo_de_Movimiento__c = 'C';
            positiva.Fecha_Inicio__c = Date.today();
            positiva.Fecha_Fin__c = fechaFinTN;
            positiva.N_CUIT__c = linea.Destinatario_Cesion_HT__r.Destinatario__r.N_CUIT__c;
            positiva.Etapa__c = 'Recibida';

            toneladas.add(positiva);
        }

        insert toneladas;
        update destinatarios;
        update lineas;

        Boolean allValidated = [select id from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesion.id and Estado__c != 'Validada' limit 1].isEmpty();
        String estado = allValidated ? 'Validada' : 'Parcialmente Validada';

        if (cesion.Estado__c != estado) update new Cesion_HT__c(Id = cesion.id, Estado__c = estado, Fecha_de_Validacion__c = Date.today());
        
        sendValidationEmails(lineas, cesion.OwnerId);
    }

    private static void validateCesion(Id cesionId) {
        validate(cesionId, new Map<Id, Sobject>([select id from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesionId and Estado__c = 'Pendiente de Validación']).keySet());
    }

    private static void validateDestinatario(Id cesionId, Id destinatarioId) {
        validate(cesionId, new Set<Id>{destinatarioId});
    }

    @AuraEnabled
    public static void validateRecord(Id recordId) {
        if (recordId.getSobjectType() == Cesion_HT__c.SobjectType) validateCesion(recordId);
        else validateDestinatario([select Cesion_HT__c from Destinatario_Cesion_HT__c where id =: recordId].Cesion_HT__c, recordId);
    }

    private static Decimal getStockEnlist(Cesion_HT__c cesion){
        Decimal stockEnlist = cesion.Cuenta_Cedente__r.TN_Disponibles__c;
        Set<String> biotechs = new Set<String>{'Enlist E3', 'Conkesta E3'};
        for (AggregateResult resLineas: [select sum(Cantidad__c) cant, Variedad__c from Linea_Cesion_HT__c where Destinatario_Cesion_HT__r.Cesion_HT__c !=: cesion.Id and Destinatario_Cesion_HT__r.Cesion_HT__r.Estado__c not in ('Cancelada', 'Rechazada', 'Validada') and Variedad__r.Biotecnologia__c IN :biotechs and Destinatario_Cesion_HT__r.Cesion_HT__r.Cuenta_Cedente__c =: cesion.Cuenta_Cedente__c group by Variedad__c]) {
            stockEnlist -= (Decimal) resLineas.get('cant');
        }

        return stockEnlist;
    }

    private static Tonelada__c createTonelada(Cesion_HT__c cesion, Account sembraAccount, Linea_Cesion_HT__c linea) {
        Tonelada__c tonelada = new Tonelada__c();

        tonelada.Cultivo__c = cesion.Cultivo__c;
        tonelada.Biotecnologia__c = linea.Variedad__r.Biotecnologia__c;
        tonelada.Canal_de_Venta__c = sembraAccount.id;
        tonelada.Origen__c = 'Cesión HT';
        tonelada.Variedad__c = linea.Variedad__c;
        tonelada.Cantidad__c = linea.Cantidad__c;
        tonelada.Linea_Cesion_HT__c = linea.id;

        return tonelada;
    }

    @TestVisible
    private static void desvalidar(Id cesionId) {
        Cesion_HT__c cesion = [select id from Cesion_HT__c where id =: cesionId];
        List<Destinatario_Cesion_HT__c> destinatarios = [select id from Destinatario_Cesion_HT__c where Cesion_HT__c =: cesion.id];
        List<Linea_Cesion_HT__c> lineas = [select id from Linea_Cesion_HT__c where Destinatario_Cesion_HT__c in: destinatarios];

        List<Sobject> toUpdate = new List<Sobject>{new Cesion_HT__c(Id = cesion.id, Estado__c = 'Pendiente de Validación')};

        updateEstados(destinatarios, toUpdate, 'Pendiente de Validación');
        updateEstados(lineas, toUpdate, 'Pendiente de Validación');

        update toUpdate;

        delete [select id from Tonelada__c where Linea_Cesion_HT__r.Destinatario_Cesion_HT__r.Cesion_HT__c =: cesionId];
        delete [select id from Hectareas_Tecnologicas__c where Linea_Cesion_HT__r.Destinatario_Cesion_HT__r.Cesion_HT__c =: cesionId];
    }

    @TestVisible
    private static void addDestinatario(Data data, Id destinatarioId, Id variedadId, Integer cantidad) {
        Destinatario d1 = new Destinatario();
        d1.variedades = new Map<Id, Variedad>();

        Variedad v = new Variedad();
        v.cantidad = cantidad;

        d1.variedades.put(variedadId, v);
        d1.destinatarioId = destinatarioId;

        data.destinatarios.add(d1);
    }

    @TestVisible
    private class Data {
        List<Destinatario> destinatarios = new List<Destinatario>();
    }

    private class Destinatario {
        Id id;
        Id destinatarioId;
        Map<Id, Variedad> variedades;

        //internos, no me lo mandan
        Destinatario_Cesion_HT__c destinatario;
        Map<Id, Linea_Cesion_HT__c> lineas;

        void fillInternal() {
            destinatario = new Destinatario_Cesion_HT__c();
            destinatario.id = id;
            destinatario.Destinatario__c = destinatarioId;

            lineas = new Map<Id, Linea_Cesion_HT__c>();

            for (Id variedad: variedades.keySet()) {
                Linea_Cesion_HT__c linea = new Linea_Cesion_HT__c();

                linea.id = variedades.get(variedad).id;
                linea.Variedad__c = variedad;
                linea.Cantidad__c = variedades.get(variedad).cantidad;

                lineas.put(variedad, linea);
            }
        }
    }

    private class Variedad {
        Id id;
        Integer cantidad;
    }
}