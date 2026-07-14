public without sharing class AdhesionPPH {

    @AuraEnabled
    public static Map<String, Object> getLoadData(Id parametroId) {
        Parametro_PPH__c param = parametroId != null ? [select name, Fecha_Inicio_Adhesion_PPH__c, Fecha_Fin_Adhesion_PPH__c from Parametro_PPH__c where id =: parametroId] : [select name, Fecha_Inicio_Adhesion_PPH__c, Fecha_Fin_Adhesion_PPH__c from Parametro_PPH__c limit 1];

        Account acc = CrearCompraController.getAccount();
        List<Plan_de_siembra__c> planes = [select Estado__c from Plan_de_siembra__c where Productor__c =: acc.Id and parametro_pph__c =: param.id order by createddate desc];
        Plan_de_siembra__c plan;

        for (Plan_de_siembra__c p: planes) {
            if (p.Estado__c != 'Cancelado') {
                plan = p;
                break;
            }
        }

        //se pidio que cuando cancelan PPH que puedan volver a adherirse si se encuentran dentro del periodo de adhesion
        if (plan == null) {
            if (isInPeriodoAdhesion(param)) {
                plan = new Plan_de_siembra__c();

                plan.Productor__c = acc.Id;
                plan.Estado__c = 'En Preparación';
                plan.parametro_pph__c = param.id;
                plan.Name = param.name + ' ' + acc.N_CUIT__c + ' Original';
                plan.Version__c = 'Original';

                insert plan;
            } else {
                if (planes.isEmpty()) validateInPeriodoAdhesion(param, 'Original');
                else plan = planes[0];
            }
        }
        System.debug(plan);
        System.debug(planes);
        return loadData(true, plan.id);
    }

    private static Boolean isInPeriodoAdhesion(Parametro_PPH__c param) {
        return param.Fecha_Inicio_Adhesion_PPH__c <= System.today() && param.Fecha_Fin_Adhesion_PPH__c >= System.today();
    }

    @AuraEnabled
    public static Boolean hasHT() {
        return [select id from Hectareas_Tecnologicas__c where Productor__c =: CrearCompraController.getAccount().id and Origen__c not in ('Semilla Original', 'Semilla Pre Básica') limit 1].size() > 0;
    }

    public static Set<String> tecnologiasEquivalentes(String biotecnologia) {
        Set<String> tecnologias = new Set<String>{biotecnologia};

        if (biotecnologia == 'Enlist E3') tecnologias.add('Conkesta E3');
        if (biotecnologia == 'Conkesta E3') tecnologias.add('Enlist E3');

        return tecnologias;
    }

    //Al adherir queda todo el credito - debito en 0, se "reserva" incluso lo que no usas. Tengo que incluir todas las variedades por aca
    private static Map<Id, Stock> getStockPorVariedad(Id productor, String biotecnologia, String cultivo) {
        Map<Id, Stock> variedadesTotals = new Map<Id, Stock>();

        for (AggregateResult res: [select sum(Credito__c) credito, sum(Debito__c) debito, Variedad__c variedad from Hectareas_Tecnologicas__c where Productor__c =: productor and Cultivo__c =: cultivo and variedad__c != null and ht_vigente__c = true and Origen__c not in ('Semilla Original', 'Semilla Pre Básica') group by Variedad__c]) {
            variedadesTotals.put((Id) res.get('variedad'), new Stock(res)); 
        }

        return variedadesTotals;
    }

    private static Stock getStockGlobal(Id productor, String biotecnologia, String cultivo) {
        return new Stock([select sum(Credito__c) credito, sum(Debito__c) debito from Hectareas_Tecnologicas__c where Productor__c =: productor and Cultivo__c =: cultivo and variedad__c = null and ht_vigente__c = true and Origen__c not in ('Semilla Original', 'Semilla Pre Básica')]);
    }

    private static Stock getStockGlobal(Parametro_PPH__c pph) {
        return getStockGlobal(CrearCompraController.getAccount().id, pph.BioTecnologia__c, pph.Cultivo__c);
    }

    private static Map<Id, Stock> getStockPorVariedad(Parametro_PPH__c pph) {
        return getStockPorVariedad(CrearCompraController.getAccount().id, pph.BioTecnologia__c, pph.Cultivo__c);
    }

    //tengo que ver si hay una linea que se pasa del stock total que hay y bajarlo
    //llena ademas en stockVariedades el campo pph que indica cuanto habia de esa variedad en las lineas (si habia mas que el total, se aplica el fix si es updateRecords)
    private static void validateStock(Map<Id, Stock> stockVariedades, Plan_de_Siembra__c plan, Boolean updateRecords) {
        List<Linea_PPH__C> lineas = [select Variedad__r.Name, Cantidad_Declarada__c from Linea_PPH__c where Establecimiento_PPH__r.Plan_de_Siembra__c =: plan.id order by Cantidad_Declarada__c desc];

        //no deberia pasar que exita una linea de variedad que no esta en hts pero por bugs pasó que hay con RR1 por ej
        for (Linea_PPH__C linea: lineas) {
            if (stockVariedades.containsKey(linea.Variedad__c) == false) {
                stockVariedades.put(linea.Variedad__c, new Stock());
            }

            stockVariedades.get(linea.Variedad__c).pph = 0;
            stockVariedades.get(linea.Variedad__c).variedadName = linea.Variedad__r.Name;
        }

        List<Linea_PPH__c> toUpdate = new  List<Linea_PPH__c>();

        //ordeno por cantidad desc para fixear lo menos posible
        for (Linea_PPH__c linea: lineas) {
            Integer cantidad = number(linea.Cantidad_Declarada__c);
            stockVariedades.get(linea.Variedad__c).pph += cantidad;

            Integer total = stockVariedades.get(linea.Variedad__c).total;
            Integer usado = stockVariedades.get(linea.Variedad__c).pph;

            if (usado > total && updateRecords && cantidad > 0) {
                linea.Cantidad_Declarada__c = Math.max(0, total - usado + cantidad);
                toUpdate.add(linea);
            }
        }

        update toUpdate;
    }

    private static Map<String, Object> loadData(Boolean firstLoad, Id planId) {
        Map<String, Object> data = new Map<String, Object>();
        Set<Id> ids = new Set<Id>();

        if (firstLoad) {
            Plan_de_Siembra__c plan = [select Parametro_PPH__r.Fecha_Inicio_Rectificacion_1__c, 
                                                Parametro_PPH__r.Fecha_Inicio_Rectificacion_2__c, 
                                                Parametro_PPH__r.Fecha_Fin_Rectificacion_1__c, 
                                                Parametro_PPH__r.Fecha_Fin_Rectificacion_2__c, 
                                                Parametro_PPH__r.Fecha_Inicio_Adhesion_PPH__c,
                                                Parametro_PPH__r.Fecha_Fin_Adhesion_PPH__c,
                                                Parametro_PPH__r.Cultivo__r.Name,
                                                Parametro_PPH__r.Biotecnologia__c,
                                                Parametro_PPH__r.Name,
                                                Fecha_de_Adhesion__c, 
                                                Estado__c, 
                                                Terminos_y_Condiciones__c,
                                                Version__c,
                                                Name,
                                                Tiene_Hts_Pendientes__c
                                        from Plan_de_siembra__c where id =: planId][0];

            validateHtsPendientes(plan);

            Map<Id, Stock> stockPorVariedad = getStockPorVariedad(plan.Parametro_PPH__r);
            
            data.put('plan', plan);
            data.put('account', CrearCompraController.getAccount());
            data.put('stockPorVariedad', stockPorVariedad);
            data.put('variedades', [select Name, Obtentor_Comercializa__r.Id_Obtentor__c from variedad__c where id in: stockPorVariedad.keySet()]);
            data.put('isInPeriodoAdhesion', isInPeriodoAdhesion(((Plan_de_siembra__c) data.get('plan')).Parametro_PPH__r));
            data.put('stockGlobal', getStockGlobal(plan.Parametro_PPH__r));

            if (plan.Estado__c == 'En Preparación' || plan.Estado__c == 'Rectificado') {
                data.put('validation', validateStockAndGetError(stockPorVariedad, plan, true));
            }

            data.put('saldoPph', getSaldoPph(plan.Id));
        }
        
        data.put('establecimientos', [select Establecimiento__r.Coordenadas__latitude__s, Establecimiento__r.Coordenadas__longitude__s, Establecimiento__r.Name, Name, Cantidad_Variedad_No_SE__c, (Select Variedad__c, Variedad__r.Name, Variedad__r.Obtentor_Comercializa__r.Id_Obtentor__c, Cantidad_Declarada__c from Lineas_PPH__r) from Establecimiento_PPH__c where Establecimiento__r.productor__c =: CrearCompraController.getAccount().id and plan_de_siembra__c =: planId order by createddate asc]);

        return data;
    }

    //cuando el plan se envió y pasa adherido, lo que no se precertificó pasa a ser HTs debitadas marcadas como Saldo PPH
    //para que el número en rojo del resumen PPH muestre siempre lo mismo, se devuelve la suma de saldos PPH para el plan de siembra y se muestra en los planes adheridos
    private static Integer getSaldoPph(Id planId){
        Integer saldoPph = 0;
        for(AggregateResult ag : [SELECT sum(Cantidad__c) cantidad FROM Hectareas_Tecnologicas__c WHERE Origen__c = 'PPH' AND Saldo_PPH__c = true AND Plan_de_Siembra__c = :planId]){
            saldoPph += number(ag.get('cantidad'));
        }

        return saldoPph;
    }

    private static void validateHtsPendientes(Plan_de_Siembra__c plan){
        plan.Tiene_Hts_Pendientes__c = [SELECT COUNT() FROM Hectareas_Tecnologicas__c WHERE Productor__c = :CrearCompraController.getAccount().Id AND Etapa__c = 'Pendiente'] > 0;
        update plan;
    }

    @AuraEnabled
    public static void deleteEstablecimiento(Id id) {
        Establecimiento_PPH__c establecimiento = [select Id from Establecimiento_PPH__c where Establecimiento__c =: id and Plan_de_siembra__r.Estado__c in ('En Preparación', 'Rectificado') and Establecimiento__r.productor__c =: CrearCompraController.getAccount().id];
        delete establecimiento;
    }

    @AuraEnabled
    public static void acceptTerms(Id planId) {
        Plan_de_siembra__c plan = [select id from Plan_de_siembra__c where id =: planId and Productor__c =: CrearCompraController.getAccount().id];
        plan.Terminos_y_Condiciones__c = true;
        update plan;
    } 

    private static void revertirHTs(Id planId, String nuevaEtapa, Id nuevoPlan) {
        List<Hectareas_Tecnologicas__c> toUpsert = new List<Hectareas_Tecnologicas__c>();

        Map<String, Schema.SObjectField> etapaToDateField = new Map<String, Schema.SObjectField>{
            'Cancelada' => Hectareas_Tecnologicas__c.Fecha_de_Cancelacion__c
        };

        for (Hectareas_Tecnologicas__c ht: Database.query(Utils.selectByName('Hectareas_Tecnologicas__c', 'where Plan_de_Siembra__c =: planId'))) {
            if (ht.Origen__c != 'PPH') { // si es la compra original (compra ht o compra semilla) le desvinculo el plan
                ht.Plan_de_Siembra__c = nuevoPlan;
                toUpsert.add(ht);
            } else {
                if (ht.Saldo_PPH__c == true) {
                    ht.Saldo_PPH__c = false; // cambio antes del clone para que se copie bien
                    toUpsert.add(ht);
                }

                Hectareas_Tecnologicas__c inversa = ht.clone();

                if (etapaToDateField.containsKey(nuevaEtapa)) {
                    inversa.put(etapaToDateField.get(nuevaEtapa), System.today());
                }

                inversa.Etapa__c = nuevaEtapa;
                inversa.Signo__c *= -1;
                inversa.Tipo_de_Movimiento__c = ht.Tipo_de_Movimiento__c == 'D' ? 'C' : 'D';
                inversa.HT_Original__c = ht.id;

                toUpsert.add(inversa);
            }
        }

        upsert toUpsert;
    }

    private static Plan_de_Siembra__c rectificarAdhesion(Plan_de_siembra__c plan, String parametroName, String version) {
        Account acc = [select N_CUIT__c from account where id =: plan.Productor__c];
        Id planId = plan.id;

        plan.Estado__c = 'Rectificado';
        plan.Terminos_y_Condiciones__c = false;
        plan.Name = parametroName + ' ' + acc.N_CUIT__c + ' ' + version;
        plan.Version__c = 'Rectificado';
        plan.Fecha_de_Adhesion__c = System.today();
        if(plan.Numero_de_Rectificacion__c != null) {
            plan.Numero_de_Rectificacion__c += 1;
        } else {
            plan.Numero_de_Rectificacion__c = 1;
        }

        update plan;

        delete ([SELECT Id FROM Hectareas_Tecnologicas__c WHERE Plan_de_Siembra__c =: planId AND Origen__c = 'PPH']);

        return plan;
    }

    @AuraEnabled
    public static Id rectificarAdhesion(Id planId) {
        Plan_de_siembra__c plan = (Plan_de_siembra__c) Database.query(Utils.selectByName('Plan_de_siembra__c', ' where id =: planId'))[0];
        Parametro_PPH__c parametro = [select Name, Fecha_Inicio_Rectificacion_1__c, Fecha_Fin_Rectificacion_1__c from Parametro_PPH__c where id =: plan.Parametro_PPH__c];
        
        if (parametro.Fecha_Inicio_Rectificacion_1__c < System.now() == false) throw new AuraHandledException('El período de rectificación a este plan de siembra no ha comenzado');
        if (parametro.Fecha_Fin_Rectificacion_1__c > System.now() == false) throw new AuraHandledException('El período de rectificación a este plan de siembra ya ha finalizado');

        Decimal nroRectificacion = plan.Numero_de_Rectificacion__c ?? 0;
        return rectificarAdhesion(plan, parametro.Name, 'Rectificación ' +(nroRectificacion + 1)).id;
    }

    @AuraEnabled
    public static Id rectificarAdhesion2(Id planId) {
        Plan_de_siembra__c plan = (Plan_de_siembra__c) Database.query(Utils.selectByName('Plan_de_siembra__c', ' where id =: planId'))[0];
        Parametro_PPH__c parametro = [select Name, Fecha_Inicio_Rectificacion_2__c, Fecha_Fin_Rectificacion_2__c from Parametro_PPH__c where id =: plan.Parametro_PPH__c];
        
        if (parametro.Fecha_Inicio_Rectificacion_2__c < System.now() == false) throw new AuraHandledException('El período de rectificación a este plan de siembra no ha comenzado');
        if (parametro.Fecha_Fin_Rectificacion_2__c > System.now() == false) throw new AuraHandledException('El período de rectificación a este plan de siembra ya ha finalizado');
        
        return rectificarAdhesion(plan, parametro.Name, 'Rectificación 2').id;
    }

    private static void validateInPeriodoAdhesion(Parametro_PPH__c param, String version) {
        if (version == 'Original') {
            if (param.Fecha_Inicio_Adhesion_PPH__c > System.now()) throw new AuraHandledException('El período de adhesión a este plan de siembra no ha comenzado');
            if (param.Fecha_Fin_Adhesion_PPH__c < System.now()) throw new AuraHandledException('El período de adhesión a este plan de siembra ya ha finalizado');
        } else if (version == 'Rectificación 1') {
            if (param.Fecha_Inicio_Rectificacion_1__c > System.now()) throw new AuraHandledException('El período de rectificación 1 a este plan de siembra no ha comenzado');
            if (param.Fecha_Fin_Rectificacion_1__c < System.now()) throw new AuraHandledException('El período de rectificación 1 a este plan de siembra ya ha finalizado');
        }  else if (version == 'Rectificación 2') {
            if (param.Fecha_Inicio_Rectificacion_2__c > System.now()) throw new AuraHandledException('El período de rectificación 2 a este plan de siembra no ha comenzado');
            if (param.Fecha_Fin_Rectificacion_2__c < System.now()) throw new AuraHandledException('El período de rectificación 2 a este plan de siembra ya ha finalizado');
        }
    }

    private static String validateStockAndGetError(Map<Id, Stock> stockPorVariedad, Plan_de_siembra__c plan, Boolean updateRecords) {
        String error = '';

        validateStock(stockPorVariedad, plan, updateRecords);

        for (Id variedad: stockPorVariedad.keySet()) {
            Stock stock = stockPorVariedad.get(variedad);

            if (stock.total < stock.pph) {
                error += 'Hay ' + stock.total + ' de stock disponible de la variedad ' +  stock.variedadName + ' pero el formulario usa ' + stock.pph + '\n';
            }
        }

        if (String.isBlank(error) == false && updateRecords) {
            error += '\nSe han cambiado las cantidades de algunas lineas en base al stock disponible';
        }

        return error.removeEnd('\n');
    }

    @AuraEnabled
    public static void sendAdhesion(Id planId) {
        Plan_de_siembra__c plan = [select Estado__c, Version__c, Parametro_PPH__c from Plan_de_siembra__c where id =: planId and Productor__c =: CrearCompraController.getAccount().id];
        Parametro_PPH__c parametro = [
            SELECT Fecha_Inicio_Rectificacion_1__c, Fecha_Inicio_Rectificacion_2__c, Fecha_Fin_Rectificacion_1__c, Fecha_Fin_Rectificacion_2__c, Fecha_Inicio_Adhesion_PPH__c, Fecha_Fin_Adhesion_PPH__c, 
                Biotecnologia__c, Cultivo__r.HT2Kilos__c, Cultivo__r.Fecha_Vencimiento_de_Tonelada__c, Campana__c 
            FROM Parametro_PPH__c 
            WHERE id =: plan.Parametro_PPH__c
        ];

        validateInPeriodoAdhesion(parametro, plan.Version__c);
        if ([select id from Linea_PPH__c where Establecimiento_PPH__r.Plan_de_siembra__c =: planId and Cantidad_Declarada__c > 0 limit 1].isEmpty()) throw new AuraHandledException('No se puede realizar la adhesión sin tener hectareas SE en al menos un establecimiento');
        if (plan.Estado__c != 'En Preparación' && plan.Estado__c != 'Rectificado') throw new AuraHandledException('El plan debe encontrarse en estado en preparación o rectificado');

        String error = validateStockAndGetError(getStockPorVariedad(parametro), plan, false);
        if (String.isBlank(error) == false) throw new AuraHandledException(error);

        if(plan.Version__c == 'Original'){
            plan.Fecha_de_Adhesion__c = System.today();
        } else {
            plan.Fecha_de_Ultima_Rectificacion__c = System.today();
        }
        plan.Estado__c = 'Adherido';
        update plan;

        Account sembraAccount = CrearCompraController.getSembraEvolucionAccount();

        /*
            Una vez que se cambia el estado del Plan de Siembra a Adherido, se deberán crear las
            siguientes hectáreas tecnológicas negativas:
            1) Una por cada línea PPH correspondiente al Plan de Siembra:
            ● Biotecnologia__c = Plan_de_Siembra__c.Parametro_PPH__r.Biotecnologia__c
            ● Canal_de_Venta__c = Id de cuenta Sembrá Evolución
            ● Cantidad__c = Linea_PPH__c.Cantidad_Declarada__c
            ● Cultivo__c = Plan_de_Siembra__c.Parametro_PPH__r.Cultivo__r.Id
            ● Etapa__c = Aplicada
            ● Fecha de Adhesión = Hoy
            ● Linea_PPH = Linea_PPH_c.Id
            ● N_CUIT__c = Plan_de_Siembra__c.Productor__r.N_CUIT__c
            ● Origen__c = PPH
            ● Plan_de_Siembra__c = Plan_de_Siembra__c.Id
            ● Productor__c = Plan_de_Siembra__c.Productor__r.Id
            ● Signo__c = -1
            ● Tipo_de_Movimiento__c = D
            ● Variedad__c = Linea_PPH__c.Variedad__c
            ● Establecimiento = Linea_PPH__c.Establecimiento
        */

        List<Hectareas_Tecnologicas__c> htsToUpsert = new List<Hectareas_Tecnologicas__c>();
            
        Date fechaFinHT = getFechaFinHT(parametro.Cultivo__r.Fecha_Vencimiento_de_Tonelada__c);

        for (Linea_PPH__c linea: [select Establecimiento_PPH__c, Cantidad_Declarada__c, Variedad__c, Variedad__r.Biotecnologia__c from Linea_PPH__c where Establecimiento_PPH__r.Plan_de_siembra__c =: planId]) {
            Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c();

            ht.Biotecnologia__c = linea.Variedad__r.Biotecnologia__c;
            ht.Canal_de_venta__c = sembraAccount.id;
            ht.Cantidad__c = linea.Cantidad_Declarada__c;
            ht.Cultivo__c = parametro.Cultivo__c;
            ht.Etapa__c = 'Aplicada';
            ht.Fecha_de_Adhesion__c = System.today();
            ht.Linea_PPH__c = linea.id;
            ht.N_CUIT__c = CrearCompraController.getAccount().N_CUIT__c;     
            ht.Origen__c = 'PPH';
            ht.Plan_de_Siembra__c = plan.id;                   
            ht.Productor__c = CrearCompraController.getAccount().id;  
            ht.Signo__c = -1;
            ht.Tipo_de_Movimiento__c = 'D';
            ht.Variedad__c = linea.Variedad__c;
            ht.Establecimiento_PPH__c = linea.Establecimiento_PPH__c; 
            ht.Valor_Conversion__c = Test.isRunningTest() ? 3 : parametro.Cultivo__r.HT2Kilos__c;     
            ht.Fecha_Inicio__c = Date.today();
            ht.Fecha_Fin__c = fechaFinHT;
            ht.Campania__c = parametro.Campana__c;
            
            htsToUpsert.add(ht);
        }

        /*
            
            2) Una por cada variedad de las HTs existentes para el cultivo + biotecnología + productor
            del Plan de Siembra:
            ● Biotecnologia__c = Plan_de_Siembra__c.Parametro_PPH__r.Biotecnologia__c
            ● Canal_de_Venta__c = Id de cuenta Sembrá Evolución
            ● Cantidad__c = Saldo de las HTs no usadas en la precertificación por variedad
            ● Cultivo__c = Plan_de_Siembra__c.Parametro_PPH__r.Cultivo__r.Id
            ● Etapa__c = Aplicada
            ● Fecha de Adhesión = Hoy
            ● N_CUIT__c = Plan_de_Siembra__c.Productor__r.N_CUIT__c
            ● Origen__c = PPH
            ● Plan_de_Siembra__c = Plan_de_Siembra__c.Id
            ● Productor__c = Plan_de_Siembra__c.Productor__r.Id
            ● Signo__c = -1
            ● Tipo_de_Movimiento__c = D
            ● Variedad__c = HT.Variedad__c
            ● Saldo PPH = True

            Nota: Se creará esta HT negativa siempre que el saldo de la variedad sea > 0.
        */

        Map<Id, Integer> disponiblesPorVariedad = calculateDisponiblesByVariedad(parametro, plan);
        Map<Id, String> biotecnologiaPorVariedad = getBiotecPorVariedad(disponiblesPorVariedad.keySet());

        for (Id variedadId: disponiblesPorVariedad.keySet()) {
            Hectareas_Tecnologicas__c ht = new Hectareas_Tecnologicas__c();

            ht.Biotecnologia__c = biotecnologiaPorVariedad.get(variedadId);
            ht.Canal_de_Venta__c = sembraAccount.id;
            ht.Cantidad__c = disponiblesPorVariedad.get(variedadId);
            ht.Cultivo__c = parametro.Cultivo__c;
            ht.Etapa__c = 'Aplicada';
            ht.Fecha_de_Adhesion__c = System.today();
            ht.N_CUIT__c = CrearCompraController.getAccount().N_CUIT__c;     
            ht.Origen__c = 'PPH';
            ht.Plan_de_Siembra__c = plan.id;                   
            ht.Productor__c = CrearCompraController.getAccount().id;  
            ht.Signo__c = -1;
            ht.Tipo_de_Movimiento__c = 'D';
            ht.Variedad__c = variedadId;
            ht.Saldo_PPH__c = true;
            ht.Valor_Conversion__c = Test.isRunningTest() ? 3 : parametro.Cultivo__r.HT2Kilos__c; 
            ht.Fecha_Inicio__c = Date.today();
            ht.Fecha_Fin__c = fechaFinHT; 
            ht.Campania__c = parametro.Campana__c;

            if (ht.Cantidad__c > 0) htsToUpsert.add(ht);
        }

        for (Hectareas_Tecnologicas__c ht: [select id from Hectareas_Tecnologicas__c where Plan_de_Siembra__c =: null and Productor__c =: CrearCompraController.getAccount().id and Cultivo__c =: parametro.Cultivo__c and createddate >=: Date.newInstance(2022, 1, 1) and Origen__c not in ('Semilla Original', 'Semilla Pre Básica') AND HT_Vigente__c = true AND HT_Tardia__c = false]) {
            ht.Plan_de_Siembra__c = plan.id;
            htsToUpsert.add(ht);
        }

        upsert htsToUpsert;

        List<Tonelada__c> tnsToUpdate = new List<Tonelada__c>();
        Date fechaFinTN = getFechaFinTN(parametro.Cultivo__r.Fecha_Vencimiento_de_Tonelada__c);

        for(Tonelada__c tonelada : [SELECT Id, Fecha_Inicio__c FROM Tonelada__c WHERE Productor__c = :CrearCompraController.getAccount().Id AND Cultivo__c = :parametro.Cultivo__c AND HT_Id__r.Plan_de_Siembra__c = :plan.id]){
            tnsToUpdate.add(new Tonelada__c(Id = tonelada.Id, Fecha_Fin__c = tonelada.Fecha_Inicio__c.addYears(1)));
        }

        update tnsToUpdate;
    }

    private static Map<Id, String> getBiotecPorVariedad(Set<Id> variedadIds){
        Map<Id, String> biotecsPorVariedad = new Map<Id, String>();
        for(Variedad__c var : [SELECT Id, Biotecnologia__c FROM Variedad__c WHERE Id IN :variedadIds]){
            biotecsPorVariedad.put(var.Id, var.Biotecnologia__c);
        }
        return biotecsPorVariedad;
    }

    private static Date getFechaFinHT(Date fechaVencimientoTN){
        Date hoy = Date.today();
        Date fechaFin = fechaVencimientoTN;

        if(hoy >= Date.newInstance(hoy.year(), 4, 1) && hoy <= Date.newInstance(hoy.year(), 12, 31)){
            fechaFin = fechaFin.addYears(1);
        }

        return fechaFin;
    }

    private static Date getFechaFinTN(Date fechaVencimientoTN){
        Date hoy = Date.today();
        Date fechaFin = fechaVencimientoTN.addYears(1);

        if(hoy >= Date.newInstance(hoy.year(), 4, 1) && hoy <= Date.newInstance(hoy.year(), 12, 31)){
            fechaFin = fechaFin.addYears(1);
        }

        return fechaFin;
    }

    private static Integer number(Object val) {
        return val == null ? 0 : Integer.valueOf(val);
    }

    private static Map<Id, Integer> calculateDisponiblesByVariedad(Parametro_PPH__c parametro, Plan_de_Siembra__c plan) {
        Map<Id, Stock> stockVariedades = getStockPorVariedad(parametro);
        validateStock(stockVariedades, plan, false);

        Map<Id, Integer> disponibles = new Map<Id, Integer>();

        for(Id variedad: stockVariedades.keySet()) {
            disponibles.put(variedad, stockVariedades.get(variedad).total - stockVariedades.get(variedad).pph);
        }

        return disponibles;
    }


    private static Integer calculateDisponibles(Parametro_PPH__c parametro, Plan_de_Siembra__c plan) {
        Integer total = 0;

        for (Integer cantidad: calculateDisponiblesByVariedad(parametro, plan).values()) {
            total += cantidad;
        }

        return total;
    }

    @AuraEnabled
    public static Map<String, Object> save(String js, Id planId) {
        Data data = (Data) JSON.deserialize(js, Data.class);
        Plan_de_siembra__c plan = [select id, Parametro_PPH__c from Plan_de_siembra__c where id =: planId and Productor__c =: CrearCompraController.getAccount().id];

        List<Establecimiento__c> establecimientos = new List<Establecimiento__c>();
        List<Establecimiento_PPH__c> establecimientosPPH = new List<Establecimiento_PPH__c>();
        List<Linea_PPH__c> lineasPPH = new List<Linea_PPH__c>();

        Set<Id> setEstablecimientos = new Set<Id>();

        for (Establecimiento est: data.establecimientos) {
            est.fillInternal();

            if(setEstablecimientos.contains(est.establecimiento.Id)){
                throw new AuraHandledException('No puede seleccionar el mismo establecimiento más de una vez en un mismo plan de siembra');
            }else{
                setEstablecimientos.add(est.establecimiento.Id);
            }

            establecimientos.add(est.establecimiento);
            establecimientosPPH.add(est.establecimientoPPH);
        }

        upsert establecimientos;

        for (Establecimiento est: data.establecimientos) {
            if (est.establecimientoPPH.Id == null) {
                est.establecimientoPPH.Establecimiento__c = est.establecimiento.id;
                est.establecimientoPPH.Plan_de_siembra__c = plan.id;
            }
        }

        upsert establecimientosPPH;

        for (Establecimiento est: data.establecimientos) {
            for (Linea_PPH__c linea: est.lineas.values()) {
                if (linea.Id == null) {
                    linea.Establecimiento_PPH__c = est.establecimientoPPH.Id;
                }
                lineasPPH.add(linea);
            }
        }

        upsert lineasPPH;

        Map<String, Object> dt = loadData(false, plan.id);

        plan.HT_Disponible__c = calculateDisponibles([select Biotecnologia__c, Cultivo__c from Parametro_PPH__C where id =: plan.Parametro_PPH__c], plan);
        update plan;

        return dt;
    }

    @AuraEnabled(cacheable=true)
    public static List<LookupSearchResult> searchEstablecimientos(String searchTerm){
        List<Establecimiento__c> establecimientos = [SELECT Id, Name, Coordenadas__latitude__s, Coordenadas__longitude__s FROM Establecimiento__c WHERE Name LIKE: '%' + searchTerm + '%' AND Productor__c = :CrearCompraController.getAccount().Id AND Origen__c = 'Propio' AND Vigente__c = true];

        List<LookupSearchResult> results = new List<LookupSearchResult>();

        String icon = 'standard:address';

        for (Establecimiento__c establecimiento : establecimientos) {
            results.add(new LookupSearchResult(establecimiento.Id, 'Establecimiento__c', icon, establecimiento.Name, 'Establecimiento'));
            results[results.size() - 1].record = establecimiento;
        }

        results.sort();

        return results;
    }

    @TestVisible
    private static Data getTestData(Id variedadId) {
        Data data = new Data();
        Establecimiento est = new Establecimiento();
        est.latitude = est.longitude = est.cantidadNoSE = 3;

        Variedad variedad = new Variedad();
        variedad.cantidad = 3;

        est.variedades = new Map<Id, Variedad> {
            variedadId => variedad
        };

        data.establecimientos = new List<Establecimiento>{est};

        return data;
    }

    @TestVisible
    private class Data {
        List<Establecimiento> establecimientos;
    }

    private class Establecimiento {
        Id id;
        Id pphId;
        Decimal latitude;
        Decimal longitude;
        Integer cantidadNoSE;
        String name;
        String origen;
        Map<Id, Variedad> variedades;

        //internos, no me lo mandan
        Establecimiento__c establecimiento;
        Establecimiento_PPH__c establecimientoPPH;
        Map<Id, Linea_PPH__c> lineas;

        void fillInternal() {
            establecimiento = new Establecimiento__c();

            establecimiento.Coordenadas__latitude__s = latitude;
            establecimiento.Coordenadas__longitude__s = longitude;
            establecimiento.id = id;
            establecimiento.name = name;
            establecimiento.Origen__c = origen;
            establecimiento.Vigente__c = true;

            if (id == null) {
                establecimiento.Productor__c = CrearCompraController.getAccount().Id;
            }

            establecimientoPPH = new Establecimiento_PPH__c();
            establecimientoPPH.Id = pphId;
            establecimientoPPH.Cantidad_Variedad_No_SE__c = cantidadNoSE;
            establecimientoPPH.Name = name;

            lineas = new Map<Id, Linea_PPH__c>();

            for (Id variedad: variedades.keySet()) {
                Linea_PPH__c linea = new Linea_PPH__c();

                linea.id = variedades.get(variedad).id;
                linea.Variedad__c = variedad;
                linea.Cantidad_Declarada__c = variedades.get(variedad).cantidad;

                lineas.put(variedad, linea);
            }
        }
    }

    private class Variedad {
        Id id;
        Integer cantidad;
    }

    public class Stock {
        @AuraEnabled public Integer debito;
        @AuraEnabled public Integer credito;
        @AuraEnabled public Integer total;
        @AuraEnabled public Integer pph = 0;
        String variedadName;

        Stock(AggregateResult res) {
            this.debito = number(res.get('debito'));
            this.credito = number(res.get('credito'));
            this.total = this.credito - this.debito;
        }

        Stock() {
            this.debito = this.credito = this.total = 0;
        }
    }
}