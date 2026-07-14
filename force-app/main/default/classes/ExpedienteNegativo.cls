public without sharing class ExpedienteNegativo {

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchAccounts(String searchTerm, List<String> selectedIds) {
        String safeTerm = String.escapeSingleQuotes(searchTerm);
        String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(searchTerm);
        String cuitCondition = String.isNotBlank(normalizedCuitTerm)
            ? ' or N_CUIT__c like \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\''
            : '';
        return CrearVentaController.accountsToLookup(Database.query(
            'select RecordType.DeveloperName, N_CUIT__c, Name from account where (name like \'%' + safeTerm + '%\'' + cuitCondition + ') ' +
            'and recordType.DeveloperName in (\'Productor\', \'Comercio\', \'Distribuidor\') ' +
            'and id != \'' + String.escapeSingleQuotes(CrearCompraController.getAccount().id) + '\' limit 5'
        ));
    }

    @AuraEnabled
    public static Expediente_de_Negativos__c getExpedienteNegativosById(String recordId){
        return [SELECT Id, Name, Saldo_Cuenta__c FROM Expediente_de_Negativos__c WHERE Id = :recordId];
    }

    @AuraEnabled
    public static Expediente_de_Negativos__c getExpedienteNegativosByAccountId(String cuentaId){
        Expediente_de_Negativos__c expediente;
        try {
            expediente = [SELECT Id, Name FROM Expediente_de_Negativos__c WHERE Obtentor__c = :CrearCompraController.getAccount().Id AND Cuenta__c = :cuentaId AND Estado_de_la_Etapa__c != 'Finalizado' LIMIT 1];
        } catch (Exception e) {
            throw new AuraHandledException('No se encontró un expediente de negativos abierto para la cuenta seleccionada');
        }

        return expediente;
    }

    @AuraEnabled
    public static void facturarRegaliaEnlist(String expedienteId){
        Expediente_de_Negativos__c expediente = [SELECT Id, Etapa__c, TNRE3_Id__c, Saldo_Cuenta__c, Cuenta__c, Cuenta__r.N_CUIT__c, Cuenta__r.TN_Disponibles__c FROM Expediente_de_Negativos__c WHERE Id = :expedienteId];

        if(expediente.Etapa__c == 'Facturar Regalía E3' || expediente.TNRE3_Id__c != null){
            throw newException('El expediente ya facturó Regalía Enlist');
        } 

        if(expediente.Etapa__c == 'Cerrado'){
            throw newException('El expediente ya está cerrado');
        }

        if(expediente.Etapa__c == 'Deriva a CTV' && expediente.TNRE3_Id__c == null){
            if(expediente.Saldo_Cuenta__c >= 0){
                throw newException('El expediente tiene la cuenta granaria mayor o igual a cero');
            }

            Cultivo__c soja = [SELECT Id, Fecha_Vencimiento_de_Tonelada__c FROM Cultivo__c WHERE Name = 'SOJA'];

            Tonelada__c tn = newTonelada(expediente, soja);
            insert tn;

            TN_Regalia_Enlist__c tnre = newTNRegaliaEnlist(expediente, soja);
            insert tnre;

            expediente = [SELECT Id, Cuenta__r.TN_Disponibles__c FROM Expediente_de_Negativos__c WHERE Id = :expedienteId];

            expediente.Estado_de_la_Etapa__c = 'Finalizado';
            expediente.Etapa__c = 'Facturar Regalía E3';
            expediente.Fecha_Cambio_Etapa__c = Date.today();
            expediente.TNRE3_Id__c = tnre.Id;
            expediente.ValidationBypassDateTime__c = Datetime.now();
            expediente.Saldo_del_Expediente_al_Cierre__c = expediente.Cuenta__r.TN_Disponibles__c;

            update expediente;
        }else{
            throw newException('El expediente debe estar en etapa Deriva a CTV para facturar Regalía Enlist');
        }
    }

    @AuraEnabled
    public static List<Tonelada__c> getToneladasExpediente(String expedienteId){
        return [SELECT Id, Name, CreatedDate, Cantidad_con_Signo__c FROM Tonelada__c WHERE Expediente_de_Negativos__c = :expedienteId AND Origen__c = 'BolsaTech' AND FT_RE3_id__c = null];
    }

    @AuraEnabled
    public static void cerrarExpediente(String expedienteId){
        Expediente_de_Negativos__c expediente = [SELECT Id, Name, Etapa__c, Cuenta__c, Cuenta__r.Name, Cuenta__r.TN_Disponibles__c FROM Expediente_de_Negativos__c WHERE Id = :expedienteId];
        
        if(expediente.Etapa__c == 'Cerrado'){
            throw newException('El expediente ' + expediente.Name + ' ya se encuentra cerrado');
        }

        if(expediente.Cuenta__r.TN_Disponibles__c < 0){
            throw newException('La cuenta granaria de ' + expediente.Cuenta__r.Name + ' es negativa');
        }

        if([SELECT Count() FROM TN_Regalia_Enlist__c WHERE Expediente_de_Negativos__c = :expediente.Id AND Etapa__c != 'Pagada'] > 0){
            throw newException('No se puede cerrar el expediente ya que hay facturas regalías enlist no pagadas');
        }

        expediente.Estado_de_la_Etapa__c = 'Finalizado';
        expediente.ValidationBypassDateTime__c = Datetime.now();
        expediente.Saldo_del_Expediente_al_Cierre__c = expediente.Cuenta__r.TN_Disponibles__c;

        update expediente;
    }

    private static Tonelada__c newTonelada(Expediente_de_Negativos__c expediente, Cultivo__c soja){
        Tonelada__c tn = new Tonelada__c();
        tn.Biotecnologia__c = 'Enlist E3';
        tn.Cantidad__c = expediente.Saldo_Cuenta__c * -1;
        tn.Cultivo__c = soja.Id;
        tn.Etapa__c = 'Cobrada';
        tn.Expediente_de_Negativos__c = expediente.Id;
        tn.Fecha_Fin_Original__c = getFechaFinTN(soja.Fecha_Vencimiento_de_Tonelada__c);
        tn.Fecha_Fin__c = getFechaFinTN(soja.Fecha_Vencimiento_de_Tonelada__c);
        tn.Fecha_Inicio__c = Date.today();
        tn.N_CUIT__c = expediente.Cuenta__r.N_CUIT__c;
        tn.Origen__c = 'Regalía Enlist';
        tn.Productor__c = expediente.Cuenta__c;
        tn.Signo__c = 1;
        tn.Tipo_de_Movimiento__c = 'C';
        System.debug('new tonelada regalia enlist: ' + tn);
        return tn;
    }

    private static TN_Regalia_Enlist__c newTNRegaliaEnlist(Expediente_de_Negativos__c expediente, Cultivo__c soja){
        TN_Regalia_Enlist__c tnre = new TN_Regalia_Enlist__c();
        tnre.Biotecnologia__c = 'Enlist';
        tnre.Cantidad__c = expediente.Saldo_Cuenta__c * -1;
        tnre.Cultivo__c = soja.Id;
        tnre.Etapa__c = 'Facturada';
        tnre.Expediente_de_Negativos__c = expediente.Id;
        tnre.N_CUIT__c = expediente.Cuenta__r.N_CUIT__c;
        tnre.Productor__c = expediente.Cuenta__c;
        tnre.Obtentor__c = Sembra_Evolucion__c.getOrgDefaults().Corteva_30_Id__c;

        return tnre;
    }

    private static Date getFechaFinTN(Date fechaVencimientoTN){
        Date hoy = Date.today();
        Date fechaFin = fechaVencimientoTN;

        if(hoy > fechaVencimientoTN && hoy <= Date.newInstance(hoy.year(), 12, 31)){
            fechaFin = fechaFin.addYears(1);
        }

        return fechaFin;
    }

    private static AuraHandledException newException(String message){
        AuraHandledException exc = new AuraHandledException(message);
        exc.setMessage(message);
        return exc;
    }
}