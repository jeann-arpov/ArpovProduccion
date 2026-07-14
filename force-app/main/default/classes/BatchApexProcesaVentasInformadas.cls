public without sharing class BatchApexProcesaVentasInformadas implements Database.Batchable<sObject>, Database.Stateful{
   
    public List<String> errors = new List<String>();
    private Set<Id> recordIds;
    private Boolean reprocesar ;

    // Ticket 1916: Cantidad_de_Bolsas__c representa Kilos Totales.
    // Regla al reprocesar: < 20 Kg = 0 bolsas; ≥ 20 Kg = redondeo a la bolsa más cercana (40 Kg c/u).
    @TestVisible private static final Decimal KILOS_TOTALES_MIN = 20;
    @TestVisible private static final Decimal KILOS_POR_BOLSA = 40;

    // Ticket 1874: mapeo defensivo de Tipo de Comprobante al reprocesar.
    // Si por cualquier motivo quedó un registro con Remito / Remito de Devolución,
    // se normaliza a FC / NC respectivamente.
    private static final Map<String, String> TIPO_COMPROBANTE_MAP = new Map<String, String>{
        'Remito' => 'FC',
        'REMITO' => 'FC',
        'Remito de Devolución' => 'NC',
        'Remito de Devolucion' => 'NC'
    };

    public BatchApexProcesaVentasInformadas(Set<Id> recordIds, Boolean reprocesar){
        this.recordIds = recordIds;
        this.reprocesar = (reprocesar != null) ? reprocesar : false;

    }

    public BatchApexProcesaVentasInformadas(Boolean reprocesar) {
        this(null, reprocesar);
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String qry = 'SELECT Venta_Interna__c,Rol_Destinatario__c,Rol_Originante__c,Categoria_Portal__c, Campana_Agricola__c,Campana_de_Ventas__c,Cantidad_de_Bolsas__c,Cantidad_Bolsas_40__c,Categoria__c,CreatedById,CreatedDate,CUIT_Destinatario__c,CUIT_Originante__c,Cultivo__c,Destinatario__c,Estado__c,Fecha_de_Facturacion__c,Id,IsDeleted,Kilos_por_Bolsa__c,LastActivityDate,LastModifiedById,LastModifiedDate,Linea_Facturacion__c,Name,N_de_Comprobante__c,Originante__c,OwnerId,Producto__c,Razon_Social_Destinatario__c,Resultado__c,SystemModstamp,Tipo_de_Comprobante__c,Variedad__c,Venta__c FROM Ventas_Informadas__c';
        qry += ' WHERE Venta__c = null';
        if (recordIds != null && !recordIds.isEmpty()) {
            // Reproceso manual: solo los IDs elegidos por el usuario (sin filtrar por Resultado).
            qry += ' AND Id IN :recordIds';
        } else {
            qry += ' AND (Resultado__c != \'OK\' OR Estado__c = null OR Estado__c = \'Preprocesado\')';
        }

        system.debug(qry);
        return Database.getQueryLocator(qry);
    }

    public void execute(Database.BatchableContext BC, List<Ventas_Informadas__c> scope) {
        Set<String> cuitsOriginante = new Set<String>();
        Set<String> cuitsDestinatarios = new Set<String>();
        Set<Decimal> cantidades = new Set<Decimal>();
        Set<String> campaigns = new Set<String>();

        Map<String,List<Ventas_Informadas__c>> ventasByCuitOriginante = new Map<String,List<Ventas_Informadas__c>>();
        Map<String,List<Ventas_Informadas__c>> ventasByCuitDestinatario = new Map<String,List<Ventas_Informadas__c>>();
        
        Set<String> variedades = new Set<String>();
        Set<String> categorias = new Set<String>();

        Map<String,List<Ventas_Informadas__c>> ventasByProductKey = new Map<String,List<Ventas_Informadas__c>>();

        Map<Id,List<Campana_Agricola__c>> campanaAgricolaByCultivoId = new Map<Id,List<Campana_Agricola__c>>();

        for(Campana_Agricola__c cAgricola : [SELECT Id, Cultivo__c, Ano__c FROM Campana_Agricola__c]){

            if(!campanaAgricolaByCultivoId.containsKey(cAgricola.Cultivo__c)){
                campanaAgricolaByCultivoId.put(cAgricola.Cultivo__c,new List<Campana_Agricola__c>());
            }

            campanaAgricolaByCultivoId.get(cAgricola.Cultivo__c).add(cAgricola);

        }

        Set<Id> omitirProcesamientoIds = new Set<Id>();

        for(Ventas_Informadas__c vInformada : scope){
            if (VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(vInformada)) {
                VentasInformadasExclusionUtil.marcarPendienteValidarSiCorresponde(vInformada);
                omitirProcesamientoIds.add(vInformada.Id);
                continue;
            }

            // Normalizar Tipo de Comprobante: Remito -> FC, Remito de Devolución -> NC.
            if (vInformada.Tipo_de_Comprobante__c != null && TIPO_COMPROBANTE_MAP.containsKey(vInformada.Tipo_de_Comprobante__c)) {
                vInformada.Tipo_de_Comprobante__c = TIPO_COMPROBANTE_MAP.get(vInformada.Tipo_de_Comprobante__c);
            }

            // Al reprocesar: Kilos Totales negativos (p. ej. NC en planilla) → valor absoluto.
            if (this.reprocesar) {
                normalizarCantidadesPositivasAlReprocesar(vInformada);
            }

            cuitsOriginante.add(vInformada.CUIT_Originante__c);
            cuitsDestinatarios.add(vInformada.CUIT_Destinatario__c);
            cantidades.add(vInformada.Cantidad_de_Bolsas__c);
            campaigns.add(vInformada.Campana_de_Ventas__c);

            if(!ventasByCuitOriginante.containsKey(vInformada.CUIT_Originante__c)){
                ventasByCuitOriginante.put(vInformada.CUIT_Originante__c,new List<Ventas_Informadas__c>());
            }

            if(!ventasByCuitDestinatario.containsKey(vInformada.CUIT_Destinatario__c)){
                ventasByCuitDestinatario.put(vInformada.CUIT_Destinatario__c,new List<Ventas_Informadas__c>());
            }

            ventasByCuitOriginante.get(vInformada.CUIT_Originante__c).add(vInformada);
            ventasByCuitDestinatario.get(vInformada.CUIT_Destinatario__c).add(vInformada);

            categorias.add(vInformada.Categoria__c);
            variedades.add(vInformada.Variedad__c);

            String key = vInformada.Categoria__c + vInformada.Variedad__c;

            if(!ventasByProductKey.containsKey(key)){
                ventasByProductKey.put(key,new List<Ventas_Informadas__c>());
            }

            ventasByProductKey.get(key).add(vInformada);
            
            vInformada.Estado__c = 'Preprocesado';

            vInformada.Resultado__c = (vInformada.CUIT_Originante__c == vInformada.CUIT_Destinatario__c && vInformada.Venta_Interna__c != true) ? 'CUIT ORIGINANTE igual a CUIT Destinatario' : '';

        }

        Map<String, Id> obtentorComercializaByVariedad =
            VentasInformadasCuitResolver.mapObtentorComercializaPorVariedad(variedades);

        Map<String, List<Account>> accountsByCuit = new Map<String, List<Account>>();
        for (Account acc : [
            SELECT Id, N_CUIT__c, RecordType.DeveloperName, Type, Name
            FROM Account
            WHERE (
                N_CUIT__c IN :ventasByCuitOriginante.keySet()
                OR N_CUIT__c IN :ventasByCuitDestinatario.keySet()
            )
            AND (
                (N_CUIT__c IN ('30569723023', '30715468294') AND Type = 'Obtentor')
                OR ParentId = NULL
            )
        ]) {
            if (String.isEmpty(acc.N_CUIT__c)) {
                continue;
            }
            if (!accountsByCuit.containsKey(acc.N_CUIT__c)) {
                accountsByCuit.put(acc.N_CUIT__c, new List<Account>());
            }
            accountsByCuit.get(acc.N_CUIT__c).add(acc);
        }

        Set<String> cuitsScope = new Set<String>();
        Set<Id> obtComIdsScope = new Set<Id>();
        for (Ventas_Informadas__c vTmp : scope) {
            if (omitirProcesamientoIds.contains(vTmp.Id)) {
                continue;
            }
            String cOrig = CrearVentaInformadaLWCController.limpiarCuit(vTmp.CUIT_Originante__c);
            String cDest = CrearVentaInformadaLWCController.limpiarCuit(vTmp.CUIT_Destinatario__c);
            if (String.isNotBlank(cOrig)) {
                cuitsScope.add(cOrig);
            }
            if (String.isNotBlank(cDest)) {
                cuitsScope.add(cDest);
            }
            Id obtTmp = obtentorComercializaByVariedad.get(vTmp.Variedad__c);
            if (obtTmp != null) {
                obtComIdsScope.add(obtTmp);
            }
        }
        VentasInformadasCuitResolver.CuitResolverCache cuitCache =
            VentasInformadasCuitResolver.buildCuitResolverCache(cuitsScope, obtComIdsScope);
        cuitCache.mergeCuentasPorCuit(accountsByCuit);

        for (Ventas_Informadas__c vInformada : scope) {
            if (omitirProcesamientoIds.contains(vInformada.Id)) {
                continue;
            }
            Id obtComId = obtentorComercializaByVariedad.get(vInformada.Variedad__c);

            VentasInformadasCuitResolver.aplicarOriginanteYDestinatario(
                vInformada,
                obtComId,
                cuitCache
            );
            agregarErroresCuentasNoResueltas(vInformada);
        }

        for(Product2 product : [SELECT Id, Unidad_de_Medida__c, Cultivo__c, Cultivo__r.Name, Cultivo__r.Unidad_de_Medida_Por_Defecto__c, Categoria__c, Variedad__c, Cultivar_Inase__c FROM Product2 WHERE Categoria__c IN :categorias AND Cultivar_Inase__c IN :variedades AND Family = 'Semilla Fiscalizada' AND IsActive = true]){

            String key = product.Categoria__c + product.Cultivar_Inase__c; 
            System.debug(product.Cultivo__r.Unidad_de_Medida_Por_Defecto__c);
            System.debug(product.Unidad_de_Medida__c);
            if(ventasByProductKey.containsKey(key) && product.Cultivo__r.Unidad_de_Medida_Por_Defecto__c == product.Unidad_de_Medida__c) { // de los varios productos que hay, tomo el que tenga unidad de medida igual al defecto del cultivo. Si Unidad_de_Medida_Por_Defecto__c esta en null no matcheara ninguno
                Decimal qty = product.Unidad_de_Medida__c == 'Granel' ? 1 : Decimal.valueOf(product.Unidad_de_Medida__c); // hectareas no aparece para las semilla fiscalizada

                for(Ventas_Informadas__c vInformada : ventasByProductKey.get(key)){
                    vInformada.Cultivo__c = product.Cultivo__c;
                    vInformada.Producto__c = product.Id;
                    vInformada.Cantidad_Bolsas_40__c = calcularBolsasDesdeKilos(vInformada.Cantidad_de_Bolsas__c, vInformada.Kilos_por_Bolsa__c, qty);
                }

                ventasByProductKey.remove(key);
            
            }

        }

        for(String key: ventasByProductKey.keySet()){
            if(ventasByProductKey.containsKey(key)){
                for(Ventas_Informadas__c vInformada : ventasByProductKey.get(key)){
                    vInformada.Resultado__c += ((String.isNotEmpty(vInformada.Resultado__c)) ? ';' : '') + 'No existe la variedad o el producto asociado o existe pero no está configurado la unidad por defecto del cultivo.';
                }
            }
        }

        Set<String> existingKeys = new Set<String>();
        Set<Id> scopeIds = new Set<Id>();
        for (Ventas_Informadas__c vScope : scope) {
            scopeIds.add(vScope.Id);
        }

        if (!scopeIds.isEmpty()) {
            for (Ventas_Informadas__c venta : [
                SELECT CUIT_Originante__c, CUIT_Destinatario__c, Variedad__c, Cantidad_de_Bolsas__c, Campana_de_Ventas__c
                FROM Ventas_Informadas__c
                WHERE CUIT_Originante__c IN :cuitsOriginante
                    AND CUIT_Destinatario__c IN :cuitsDestinatarios
                    AND Variedad__c IN :variedades AND Cantidad_de_Bolsas__c IN :cantidades
                    AND Campana_de_Ventas__c IN :campaigns
                    AND Id NOT IN :scopeIds
            ]) {
                existingKeys.add(key(venta));
            }
        }

        for(Ventas_Informadas__c vInformada : scope){
            if (omitirProcesamientoIds.contains(vInformada.Id)) {
                continue;
            }
            if(String.isNotEmpty(vInformada.Campana_de_Ventas__c) && String.isNotEmpty(vInformada.Cultivo__c) && campanaAgricolaByCultivoId.containsKey(vInformada.Cultivo__c)){

                for(Campana_Agricola__c cAgricola : campanaAgricolaByCultivoId.get(vInformada.Cultivo__c)){

                    if(cAgricola.Ano__c == vInformada.Campana_de_Ventas__c){
                        vInformada.Campana_Agricola__c = cAgricola.Id;
                        break;
                    }

                }

            }

            if(String.isEmpty(vInformada.Campana_Agricola__c)){
                vInformada.Resultado__c += ((String.isNotEmpty(vInformada.Resultado__c)) ? ';' : '') + 'No existe la campaña.';    
            }

            vInformada.Resultado__c = ConvertirVentasInformadasResumenUtil.resolverResultadoFinal(
                vInformada,
                vInformada.Resultado__c
            );
        
        }

        List<Database.SaveResult> svsrs = Database.update(scope,false);

        Integer i = 0;

        for(Database.SaveResult svr : svsrs){

            if(!svr.isSuccess()){
                this.errors.add(String.format('Record {0} : Error {1}', new List<String>{scope[i].Id,svr.getErrors()[0].getMessage()}));
            }

            i++;
                
        }

    }

    public void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Arpov: Errores en BatchApexProcesaVentasInformadas');
    } 

    public static String key(Ventas_Informadas__c venta) {
        if (venta == null || venta.Cantidad_de_Bolsas__c == null) {
            return null;
        }
        return venta.CUIT_Originante__c + '-' + venta.CUIT_Destinatario__c + '-' + venta.Variedad__c + '-' + venta.Cantidad_de_Bolsas__c.longValue() + '-' + venta.Campana_de_Ventas__c;
    }

    @TestVisible
    private static void agregarErroresCuentasNoResueltas(Ventas_Informadas__c vInformada) {
        if (vInformada == null) {
            return;
        }
        if (String.isNotBlank(vInformada.CUIT_Originante__c) && vInformada.Originante__c == null) {
            vInformada.Resultado__c += ((String.isNotEmpty(vInformada.Resultado__c)) ? ';' : '')
                + 'No existe la cuenta originante.';
        }
        if (
            vInformada.Venta_Interna__c != true
            && String.isNotBlank(vInformada.CUIT_Destinatario__c)
            && vInformada.Destinatario__c == null
        ) {
            vInformada.Resultado__c += ((String.isNotEmpty(vInformada.Resultado__c)) ? ';' : '')
                + 'No existe la cuenta destinataria';
        }
    }

    /**
     * Ticket 1470: al reprocesar no sobrescribir Rol Destinatario ya informado.
     * Venta interna: el rol lo define aplicarVentaInterna (Productor).
     */
    @TestVisible
    private Boolean debeAsignarRolDestinatario(Ventas_Informadas__c vInformada) {
        if (vInformada.Venta_Interna__c == true) {
            return false;
        }
        if (this.reprocesar && String.isNotBlank(vInformada.Rol_Destinatario__c)) {
            return false;
        }
        return true;
    }

    /**
     * Al reprocesar, la planilla puede traer Kilos Totales con signo negativo (NC / convención Excel).
     * Se guarda tal cual en la importación y aquí se normaliza a positivo antes de calcular bolsas.
     */
    @TestVisible
    public static void normalizarCantidadesPositivasAlReprocesar(Ventas_Informadas__c vInformada) {
        if (vInformada != null
            && vInformada.Cantidad_de_Bolsas__c != null
            && vInformada.Cantidad_de_Bolsas__c < 0) {
            vInformada.Cantidad_de_Bolsas__c = vInformada.Cantidad_de_Bolsas__c.abs();
        }
    }

    /**
     * Calcula la cantidad de bolsas a partir de Kilos Totales (ticket 1916).
     *  - Si Kilos Totales < KILOS_TOTALES_MIN (20 kg) => 0 bolsas
     *  - En caso contrario => round(kilosTotales / unidadDeMedida) (HALF_UP)
     *
     * @param kilosTotales valor del campo Cantidad_de_Bolsas__c (representa kilos totales).
     * @param kilosPorBolsa valor del campo Kilos_por_Bolsa__c (por compatibilidad, normalmente 1).
     * @param qty unidad de medida del producto (kg/bolsa). Si la unidad por defecto del cultivo es 40 kg/bolsa, qty=40.
     */
    @TestVisible
    public static Decimal calcularBolsasDesdeKilos(Decimal kilosTotales, Decimal kilosPorBolsa, Decimal qty){
        if (kilosTotales == null || qty == null || qty == 0) return 0;
        if (kilosPorBolsa == null || kilosPorBolsa == 0) kilosPorBolsa = 1;

        // Kilos efectivos = Cantidad_de_Bolsas__c (Kilos Totales) * Kilos_por_Bolsa__c (=1 normalmente).
        Decimal kilosEfectivos = kilosTotales * kilosPorBolsa;

        if (kilosEfectivos < KILOS_TOTALES_MIN) {
            return 0;
        }

        // round HALF_UP: 20 kg con qty=40 -> 0.5 -> 1 bolsa; 60 kg -> 1.5 -> 2 bolsas.
        return (kilosEfectivos / qty).setScale(0, System.RoundingMode.HALF_UP);
    }
}