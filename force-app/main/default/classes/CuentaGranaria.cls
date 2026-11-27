public without sharing class CuentaGranaria {

    // Wrapper para devolver campañas con su total de toneladas
    public class CampanaConTotales {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String ano;
        @AuraEnabled public String estado;
        @AuraEnabled public String cultivoName;
        @AuraEnabled public Decimal totalToneladas;
        @AuraEnabled public Decimal totalCompraHT;
        @AuraEnabled public Decimal saldoCuentaGranaria;
        @AuraEnabled public Boolean pphAdherida;
        @AuraEnabled public Date pphVencimiento;
        @AuraEnabled public Boolean esActual;
    }

    private static final Set<String> ESTADOS_VISIBLES = new Set<String>{ 'Activa', 'Completa', 'En Preparación' };
    private static final Set<String> ESTADOS_PPH = new Set<String>{ 'Adherido', 'Vencido', 'Rectificado' };
    private static final Integer CAMPANAS_ANTERIORES_VISIBLES = 2;
    // El portal no usa el crédito guardado de SE-345/SE-410 (Detalle_Variedad_CG__c).
    // Resumen y detalle salen de Tonelada__c; si la compra cobrada no generó tonelada,
    // el crédito se completa desde la HT. Solo los tests pueden prender este flag.
    @TestVisible
    static Boolean usarCreditoVarietalGuardado = false;

    private static Boolean usaCreditoVarietalGuardado() {
        return usarCreditoVarietalGuardado
            && Schema.getGlobalDescribe().containsKey('Detalle_Variedad_CG__c');
    }

    private static Boolean detalleTieneSaldoVariedad() {
        Schema.SObjectType tipo = Schema.getGlobalDescribe().get('Detalle_Variedad_CG__c');
        return tipo != null && tipo.getDescribe().fields.getMap().containsKey('Saldo_Variedad__c');
    }

    /**
     * Campañas que muestra Cuenta Granaria por cultivo: la actual primero y luego las 2 anteriores.
     * La actual es la última cuya ventana Sembrá Evolución (Fecha_Fin_SE__c) ya cerró, mismo criterio
     * con el que ObtenerCampana asigna las TNs que no son Compra Futura. Así la campaña nueva aparece
     * según las fechas cargadas en cada cultivo (Soja: marzo; Trigo/Cebada: noviembre).
     * Cultivos sin fechas SE usan Fecha_de_Inicio__c.
     */
    public static Map<Id, List<Campana_Agricola__c>> getCampanasVisiblesPorCultivo(Set<Id> cultivoIds) {
        Map<Id, List<Campana_Agricola__c>> campanasPorCultivo = new Map<Id, List<Campana_Agricola__c>>();
        Set<Id> cultivosConFechasSE = new Set<Id>();
        for (Campana_Agricola__c c : [SELECT Id, Name, Ano__c, Estado__c, Cultivo__c, Cultivo__r.Name,
                                             Fecha_de_Inicio__c, Fecha_Fin_SE__c
                                      FROM   Campana_Agricola__c
                                      WHERE  Cultivo__c IN :cultivoIds
                                      AND    Estado__c IN :ESTADOS_VISIBLES
                                      ORDER BY Ano__c DESC]) {
            if (String.isBlank(c.Ano__c) || !c.Ano__c.isNumeric()) continue;
            if (!campanasPorCultivo.containsKey(c.Cultivo__c)) {
                campanasPorCultivo.put(c.Cultivo__c, new List<Campana_Agricola__c>());
            }
            campanasPorCultivo.get(c.Cultivo__c).add(c);
            if (c.Fecha_Fin_SE__c != null) cultivosConFechasSE.add(c.Cultivo__c);
        }

        Date hoy = Date.today();
        Map<Id, List<Campana_Agricola__c>> result = new Map<Id, List<Campana_Agricola__c>>();
        for (Id cultivoId : campanasPorCultivo.keySet()) {
            List<Campana_Agricola__c> campanas = campanasPorCultivo.get(cultivoId);
            Boolean usaFechasSE = cultivosConFechasSE.contains(cultivoId);

            Campana_Agricola__c actual;
            Date fechaActual;
            for (Campana_Agricola__c c : campanas) {
                Date fecha = usaFechasSE ? c.Fecha_Fin_SE__c : c.Fecha_de_Inicio__c;
                Boolean iniciada = fecha != null && (usaFechasSE ? fecha < hoy : fecha <= hoy);
                if (iniciada && (fechaActual == null || fecha > fechaActual)) {
                    actual = c;
                    fechaActual = fecha;
                }
            }
            if (actual == null) continue;

            List<Campana_Agricola__c> visibles = new List<Campana_Agricola__c>{ actual };
            Integer anoActual = Integer.valueOf(actual.Ano__c);
            for (Campana_Agricola__c c : campanas) {
                if (visibles.size() > CAMPANAS_ANTERIORES_VISIBLES) break;
                if (Integer.valueOf(c.Ano__c) < anoActual) visibles.add(c);
            }
            result.put(cultivoId, visibles);
        }
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> getLoadData(){
       return new Map<String, Object>{'cultivos' => [SELECT Id, Name, Fecha_Vencimiento_de_Tonelada__c, Fecha_Vencimiento_Tonelada__c FROM Cultivo__c WHERE Sembra_Evolucion__c = true]};
    }

    @AuraEnabled
    public static List<Plan_de_Siembra__c> getAdhesion(String cultivoId){
        List<Plan_de_Siembra__c> planesSiembra = [
            SELECT Parametro_PPH__r.Fecha_Vencimiento_PPH__c, Parametro_PPH__r.Campana__c
            FROM Plan_de_Siembra__c
            WHERE Productor__c = :CrearCompraController.getAccount().Id
            AND Estado__c IN :ESTADOS_PPH
            AND Parametro_PPH__r.Cultivo__c = :cultivoId
            
        ];
        return planesSiembra;
    }

    // PPH vigente de la campaña: Adherido, Vencido o Rectificado. No usa el flag sticky de Cuenta_Granaria.
    private static Map<Id, Plan_de_Siembra__c> planesPphPorCampana(Id productorId, Set<Id> campanaIds) {
        Map<Id, Plan_de_Siembra__c> porCampana = new Map<Id, Plan_de_Siembra__c>();
        if (productorId == null || campanaIds == null || campanaIds.isEmpty()) {
            return porCampana;
        }
        for (Plan_de_Siembra__c plan : [
            SELECT Estado__c, Parametro_PPH__r.Campana__c, Parametro_PPH__r.Fecha_Vencimiento_PPH__c
            FROM Plan_de_Siembra__c
            WHERE Productor__c = :productorId
            AND Estado__c IN :ESTADOS_PPH
            AND Parametro_PPH__r.Campana__c IN :campanaIds
        ]) {
            Id campanaId = plan.Parametro_PPH__r.Campana__c;
            if (campanaId == null) {
                continue;
            }
            Plan_de_Siembra__c actual = porCampana.get(campanaId);
            if (actual == null || (plan.Estado__c == 'Adherido' && actual.Estado__c != 'Adherido')) {
                porCampana.put(campanaId, plan);
            }
        }
        return porCampana;
    }

    // Obtiene las 3 campañas vigentes (actual + 2 anteriores) con el total de toneladas de cada una
    @AuraEnabled
    public static List<CampanaConTotales> getCampanasConTotales(String cultivoId, String tecnologias){
        List<String> values = tecnologias.split('/');
        // 1. Campañas visibles del cultivo, la actual primero
        Id cultivoIdValue = (Id) cultivoId;
        List<Campana_Agricola__c> campanas = getCampanasVisiblesPorCultivo(new Set<Id>{ cultivoIdValue }).get(cultivoIdValue);

        if (campanas == null || campanas.isEmpty()) return new List<CampanaConTotales>();
        Id campanaActualId = campanas[0].Id;

        // 2. Obtenemos los IDs de las campañas
        Set<Id> campanaIds = new Set<Id>();
        for (Campana_Agricola__c c : campanas) {
            campanaIds.add(c.Id);
        }

        // 3. Agregamos toneladas por campana para el productor (Compra HT Futura se suma aqui)
        Id productorId = CrearCompraController.getAccount().Id;
        Map<Id, Decimal> totalesPorCampana = new Map<Id, Decimal>();
        for (AggregateResult ar : [SELECT Campania__c campId, SUM(Cantidad_con_Signo__c) total
                                    FROM   Tonelada__c
                                    WHERE  Productor__c = :productorId
                                    AND    Campania__c IN :campanaIds
                                    AND    Biotecnologia__c IN :values
                                    AND    Fecha_Inicio__c <= TODAY
                                    AND    Etapa__c != 'Pendiente'
                                    AND    Origen__c != 'Balance Anual'
                                    AND    (Origen__c != 'Compra HT' 
                                           OR HT_Id__r.Linea_de_Compra_HT__r.Tipo_de_Compra__c != 'Disponible')
                                    AND (Origen__c != 'Consumo' OR Signo__c != -1)

                                    GROUP BY Campania__c]) {
            totalesPorCampana.put((Id)ar.get('campId'), (Decimal)ar.get('total'));
        }

        // 3b. Compra HT Disponible: obtener saldo de la Cuenta Granaria HT (sin campaña)
        Decimal totalCompraHTDisponible = 0;
        List<Cuenta_Granaria__c> cgHT = [SELECT Saldo_Cuenta__c
                                          FROM   Cuenta_Granaria__c
                                          WHERE  Productor__c = :productorId
                                          AND    Cultivo__c = :cultivoId
                                          AND    Tecnologia__c = :tecnologias
                                          AND    Campania__c = null
                                          LIMIT 1];
        if (!cgHT.isEmpty() && cgHT[0].Saldo_Cuenta__c != null) {
            totalCompraHTDisponible = cgHT[0].Saldo_Cuenta__c;
        }

        System.debug('productorId: ' + productorId);
        System.debug('Campanas encontradas: ' + campanas);
        System.debug('CultivoId: ' + cultivoId);

        // 3c. Saldos de Cuentas Granarias por campaña
        Map<Id, Decimal> saldosCuentaGranaria = new Map<Id, Decimal>();
        for (Cuenta_Granaria__c cg : [SELECT Campania__c, Saldo_Cuenta__c
                                       FROM   Cuenta_Granaria__c
                                       WHERE  Productor__c = :productorId
                                       AND    Campania__c IN :campanaIds
                                       AND Tecnologia__c = :tecnologias
                                       AND    Cultivo__c = :cultivoId]) {
            Decimal saldo = cg.Saldo_Cuenta__c != null ? cg.Saldo_Cuenta__c : 0;
            saldosCuentaGranaria.put(cg.Campania__c, saldo);
        }
        Map<Id, Plan_de_Siembra__c> pphPorCampana = planesPphPorCampana(productorId, campanaIds);
        System.debug('Saldos de Cuenta Granaria encontrados: ' + saldosCuentaGranaria);

        // 4. Armamos la respuesta
        List<CampanaConTotales> result = new List<CampanaConTotales>();
        for (Campana_Agricola__c c : campanas) {
            CampanaConTotales cct = new CampanaConTotales();
            cct.id = c.Id;
            cct.name = c.Name;
            cct.ano = c.Ano__c;
            cct.estado = c.Estado__c;
            cct.cultivoName = c.Cultivo__r.Name;
            cct.totalToneladas = totalesPorCampana.containsKey(c.Id) ? totalesPorCampana.get(c.Id) : 0;
            cct.totalCompraHT = totalCompraHTDisponible;
            cct.saldoCuentaGranaria = saldosCuentaGranaria.containsKey(c.Id) ? saldosCuentaGranaria.get(c.Id) : 0;
            Plan_de_Siembra__c planPph = pphPorCampana.get(c.Id);
            cct.pphAdherida = planPph != null;
            cct.pphVencimiento = planPph == null ? null : planPph.Parametro_PPH__r.Fecha_Vencimiento_PPH__c;
            cct.esActual = c.Id == campanaActualId;
            result.add(cct);
        }

        return result;
    }

    // Mantiene el método original por si se necesita solo la lista de campañas
    @AuraEnabled
    public static List<Campana_Agricola__c> getCampanas(String cultivoId){
        return [SELECT Id, Name, Ano__c, Estado__c, Cultivo__c, Cultivo__r.Name
                FROM   Campana_Agricola__c
                WHERE  Cultivo__c = :cultivoId
                AND    Ano__c != '2212'
                ORDER BY Ano__c DESC
                LIMIT 3];
    }

    // Obtiene toneladas por campaña (nuevo flujo por campaña)
    @AuraEnabled
    public static List<Tonelada__c> getToneladasByCampana(String cultivoId, String campanaId, String tecnologias){
        List<String> values = tecnologias.split('/');
        return [SELECT Fecha_Inicio__c, 
                       Fecha_Fin__c, 
                       Origen__c,
                       Cantidad_con_Signo__c,
                       CreatedDate,
                       Etapa__c,
                       TN_Vigente__c,
                       Campania__c,
                       Campania__r.Name
                FROM   Tonelada__c
                WHERE  Productor__c = :CrearCompraController.getAccount().Id 
                AND    Cultivo__c = :cultivoId 
                AND    Campania__c = :campanaId
                AND    Biotecnologia__c IN :values
                AND    Fecha_Inicio__c <= TODAY
                AND    Etapa__c != 'Pendiente'
                AND    Origen__c != 'Balance Anual'

                AND    HT_Id__r.Linea_de_Compra_HT__r.Tipo_de_Compra__c != 'Disponible'
            AND (Origen__c != 'Consumo' OR Signo__c != -1)
        ];
    }

    /* COMENTADO - Método original que filtraba por biotecnología
    @AuraEnabled
    public static List<Tonelada__c> getToneladas(String cultivoId, String tecnologias){
        List<String> values = tecnologias.split('/');
        return [SELECT Fecha_Inicio__c, 
                       Fecha_Fin__c, 
                       Origen__c,
                       Cantidad_con_Signo__c,
                       CreatedDate,
                       Etapa__c,
                       TN_Vigente__c
                FROM   Tonelada__c
                WHERE  Productor__c = :CrearCompraController.getAccount().Id 
                AND  Cultivo__c = :cultivoId 
                AND  Biotecnologia__c IN :values
                AND  Etapa__c != 'Pendiente'
                AND  TN_Vigente__c = true];
    }
    */

    @AuraEnabled
    public static String getDetalleBT(List<String> toneladasIds){

        List<Tonelada__c> toneladasBT = [SELECT Id, Mov_BolsaTech__r.CTG__c, Mov_BolsaTech__r.Peso_Neto__c, Mov_BolsaTech__r.CUIT_Titular__c, Mov_BolsaTech__r.Razon_Social_Destinatario__c, Mov_BolsaTech__r.Fecha_de_Entrega__c FROM Tonelada__c WHERE Id IN :toneladasIds AND Mov_Bolsatech__c != null];

        String columns = 'Codigo de Trazabilidad de Granos;Razon Social Destinatario;Fecha de Entrega;Peso neto;Cuit del titular' + '\n';

        String detail = '';
        for(Tonelada__c tn : toneladasBT){
            detail += tn.Mov_BolsaTech__r.CTG__c + ';' + tn.Mov_BolsaTech__r.Razon_Social_Destinatario__c + ';' + tn.Mov_BolsaTech__r.Fecha_de_Entrega__c + ';' + tn.Mov_Bolsatech__r.Peso_Neto__c + ';' + tn.Mov_Bolsatech__r.CUIT_Titular__c + '\n';
        }

        return columns + detail;
    }

    // Vista varietal de trigo del portal. El productor no ve expedientes.
    // Estados de pantalla: EstadoVarietal.calcularVista (D-26, saldo < 0). El CRM sigue con calcular().
    @AuraEnabled
    public static ResumenVarietal getResumenVarietal(Id campaniaId, String tecnologias) {
        if (campaniaId == null) {
            throw errorVarietal('Elegí una campaña.');
        }
        Id productorId = CrearCompraController.getAccount().Id;
        List<String> bios = biotecnologias(tecnologias);

        Map<Id, VariedadPortal> porVariedad = agruparVariedades(productorId, campaniaId, bios, null);
        completarNombres(porVariedad);

        Map<Id, MarcaPortal> porMarca = new Map<Id, MarcaPortal>();
        Decimal aRegularizar = 0;
        for (VariedadPortal variedad : porVariedad.values()) {
            if (variedad.estado == EstadoVarietal.DEBE_REGULARIZAR) {
                aRegularizar += EstadoVarietal.toneladasMostradasARegularizar(variedad.credito, variedad.debito);
            }
            MarcaPortal marca = porMarca.get(variedad.marcaId);
            if (marca == null) {
                marca = new MarcaPortal();
                marca.id = variedad.marcaId;
                marca.nombre = variedad.marca;
                marca.idObtentor = variedad.idObtentor;
                marca.variedades = new List<VariedadPortal>();
                porMarca.put(variedad.marcaId, marca);
            }
            marca.variedades.add(variedad);
        }

        ResumenVarietal resumen = new ResumenVarietal();
        resumen.toneladasARegularizar = aRegularizar;
        resumen.marcas = new List<MarcaPortal>();
        for (MarcaPortal marca : porMarca.values()) {
            marca.variedades.sort();
            Integer negativas = 0;
            Integer sinEntregas = 0;
            for (VariedadPortal variedad : marca.variedades) {
                if (variedad.estado == 'Debe regularizar') {
                    negativas++;
                } else if (variedad.estado == 'Sin entregas') {
                    sinEntregas++;
                }
            }
            marca.aRegularizar = negativas;
            if (negativas > 0) {
                marca.estado = 'regularizar';
                marca.etiqueta = negativas + ' a regularizar';
            } else if (sinEntregas == marca.variedades.size()) {
                marca.estado = 'Sin entregas';
                marca.etiqueta = 'Sin entregas';
            } else {
                marca.estado = 'En regla';
                marca.etiqueta = 'En regla';
            }
            resumen.marcas.add(marca);
        }
        resumen.marcas.sort();
        resumen.ultimaEntrega = ultimaEntrega(productorId, campaniaId, bios);
        return resumen;
    }

    @AuraEnabled
    public static DetalleVariedad getDetalleVarietal(Id campaniaId, Id variedadId, String tecnologias) {
        if (campaniaId == null || variedadId == null) {
            throw errorVarietal('Elegí una variedad.');
        }
        Id productorId = CrearCompraController.getAccount().Id;
        List<String> bios = biotecnologias(tecnologias);
        Map<Id, VariedadPortal> porVariedad = agruparVariedades(productorId, campaniaId, bios, variedadId);
        completarNombres(porVariedad);
        VariedadPortal variedad = porVariedad.get(variedadId);
        if (variedad == null) {
            throw errorVarietal('No encontramos esa variedad en la campaña.');
        }

        DetalleVariedad detalle = new DetalleVariedad();
        detalle.variedadId = variedad.id;
        detalle.variedad = variedad.nombre;
        detalle.marca = variedad.marca;
        detalle.idObtentor = variedad.idObtentor;
        detalle.estado = variedad.estado;
        detalle.toneladasARegularizar = EstadoVarietal.toneladasMostradasARegularizar(variedad.credito, variedad.debito);
        detalle.creditos = new List<MovimientoPortal>();
        detalle.debitos = new List<MovimientoPortal>();
        detalle.entregas = new List<MovimientoPortal>();
        detalle.totalCreditos = 0;
        detalle.totalDebitado = 0;
        detalle.tieneCesionSaliente = false;

        String consulta = 'SELECT Fecha_Inicio__c, CreatedDate, Origen__c, Etapa__c, Cantidad_con_Signo__c, '
            + 'Mov_BolsaTech__r.CTG__c, Mov_BolsaTech__r.Peso_Neto__c, Mov_BolsaTech__r.Fecha_de_Entrega__c '
            + 'FROM Tonelada__c WHERE Productor__c = :productorId AND Campania__c = :campaniaId '
            + 'AND Variedad__c = :variedadId AND Cultivo__r.Name = \'TRIGO\' '
            + 'AND Fecha_Inicio__c <= TODAY AND Etapa__c != \'Pendiente\' '
            + 'AND Origen__c IN (\'Compra SF\', \'Compra HT\', \'Cesión HT\', \'BolsaTech\', \'Escáner varietal\') ';
        if (!bios.isEmpty()) {
            consulta += 'AND Biotecnologia__c IN :bios ';
        }
        consulta += 'ORDER BY CreatedDate DESC, Id DESC';

        Decimal entregasNetas = 0;
        for (Tonelada__c tn : Database.query(consulta)) {
            Decimal toneladas = tn.Cantidad_con_Signo__c == null ? 0 : tn.Cantidad_con_Signo__c;
            if (!EstadoVarietal.acreditaCompra(tn.Origen__c, tn.Etapa__c)) {
                continue;
            }
            if (EstadoVarietal.esEntrega(tn.Origen__c)) {
                MovimientoPortal entrega = new MovimientoPortal();
                entrega.fecha = tn.Fecha_Inicio__c;
                entrega.ctg = enmascararCtg(tn.Mov_BolsaTech__r?.CTG__c);
                entrega.kgNetos = tn.Mov_BolsaTech__r?.Peso_Neto__c;
                entrega.toneladas = toneladas;
                detalle.entregas.add(entrega);
                entregasNetas += toneladas;
                if (toneladas < 0) {
                    detalle.totalDebitado += -toneladas;
                }
            } else if (toneladas < 0) {
                // Cesión saliente u otra anulación: débito, no crédito (SE-350).
                MovimientoPortal debito = movimientoCredito(fechaCredito(tn), tn.Origen__c, toneladas);
                detalle.debitos.add(debito);
                if (tn.Origen__c == 'Cesión HT') {
                    detalle.tieneCesionSaliente = true;
                }
            } else {
                MovimientoPortal credito = movimientoCredito(fechaCredito(tn), tn.Origen__c, toneladas);
                detalle.creditos.add(credito);
                detalle.totalCreditos += toneladas;
            }
        }
        ordenarPorFechaDesc(detalle.entregas);
        if (detalle.creditos.isEmpty()) {
            agregarCreditosDesdeHt(detalle, productorId, campaniaId, variedadId, bios);
        }
        // Tarjetas = suma de las filas. Independiente del crédito guardado de SE-410.
        detalle.credito = detalle.totalCreditos;
        detalle.debito = 0;
        for (MovimientoPortal mov : detalle.debitos) {
            detalle.debito += mov.toneladas == null ? 0 : -mov.toneladas;
        }
        detalle.debito += detalle.totalDebitado;
        detalle.saldo = detalle.credito - detalle.debito;
        detalle.estado = EstadoVarietal.calcularVista(detalle.saldo, entregasNetas);
        detalle.toneladasARegularizar = EstadoVarietal.toneladasMostradasARegularizar(detalle.credito, detalle.debito);
        return detalle;
    }

    @AuraEnabled
    public static Map<Id, RegularizarCampana> getRegularizarPorCampana(List<Id> campaniaIds, String tecnologias) {
        Map<Id, RegularizarCampana> porCampana = new Map<Id, RegularizarCampana>();
        if (campaniaIds == null || campaniaIds.isEmpty()) {
            return porCampana;
        }
        Id productorId = CrearCompraController.getAccount().Id;
        List<String> bios = biotecnologias(tecnologias);
        if (usaCreditoVarietalGuardado()) {
            return regularizarPorCreditoGuardado(productorId, campaniaIds, bios);
        }
        for (Id campaniaId : campaniaIds) {
            Map<Id, VariedadPortal> porVariedad = agruparVariedades(productorId, campaniaId, bios, null);
            completarNombres(porVariedad);
            List<VariedadPortal> lista = new List<VariedadPortal>();
            RegularizarCampana resumen = new RegularizarCampana();
            resumen.toneladas = 0;
            resumen.variedades = new List<String>();
            for (VariedadPortal variedad : porVariedad.values()) {
                if (!EstadoVarietal.saldoNegativo(variedad.saldo)) {
                    continue;
                }
                lista.add(variedad);
                resumen.toneladas += EstadoVarietal.toneladasMostradasARegularizar(variedad.credito, variedad.debito);
            }
            if (lista.isEmpty()) {
                continue;
            }
            lista.sort();
            for (VariedadPortal variedad : lista) {
                resumen.variedades.add(variedad.nombre);
            }
            porCampana.put(campaniaId, resumen);
        }
        return porCampana;
    }

    @AuraEnabled
    public static List<MovimientoPortal> getEntregasVarietal(Id campaniaId, String tecnologias) {
        if (campaniaId == null) {
            throw errorVarietal('Elegí una campaña.');
        }
        Id productorId = CrearCompraController.getAccount().Id;
        List<String> bios = biotecnologias(tecnologias);
        String consulta = 'SELECT Fecha_Inicio__c, Cantidad_con_Signo__c, Variedad__r.Name, Variedad__r.Cultivar_INASE__c, '
            + 'Variedad__r.Nombre_Obtentor__c, Variedad__r.Obtentor_Comercializa__r.Nombre_Obtentor__c, '
            + 'Mov_BolsaTech__r.CTG__c, Mov_BolsaTech__r.Peso_Neto__c '
            + 'FROM Tonelada__c WHERE Productor__c = :productorId AND Campania__c = :campaniaId '
            + 'AND Cultivo__r.Name = \'TRIGO\' AND Variedad__c != null '
            + 'AND Fecha_Inicio__c <= TODAY AND Etapa__c != \'Pendiente\' '
            + 'AND Origen__c IN (\'BolsaTech\', \'Escáner varietal\') ';
        if (!bios.isEmpty()) {
            consulta += 'AND Biotecnologia__c IN :bios ';
        }
        consulta += 'ORDER BY Fecha_Inicio__c DESC';

        List<MovimientoPortal> entregas = new List<MovimientoPortal>();
        for (Tonelada__c tn : Database.query(consulta)) {
            MovimientoPortal entrega = new MovimientoPortal();
            entrega.fecha = tn.Fecha_Inicio__c;
            entrega.variedad = nombreCatalogo(tn.Variedad__r);
            entrega.marca = nombreMarca(tn.Variedad__r);
            entrega.ctg = enmascararCtg(tn.Mov_BolsaTech__r?.CTG__c);
            entrega.kgNetos = tn.Mov_BolsaTech__r?.Peso_Neto__c;
            entrega.toneladas = tn.Cantidad_con_Signo__c;
            entregas.add(entrega);
        }
        return entregas;
    }

    // Crédito y débito por signo, no por origen neto.
    // NO unificar en un solo GROUP BY Variedad+Origen: SOQL suma + y − del mismo origen
    // y las Compra SF negativas (anulaciones) desaparecen del débito. Las tarjetas
    // dejan de cerrar con las tablas (IS BANDURRIA 25/26: +1504 y −548 → 956/0). SE-157.
    private static Map<Id, VariedadPortal> agruparVariedades(Id productorId, Id campaniaId, List<String> bios, Id variedadId) {
        if (usaCreditoVarietalGuardado()) {
            return agruparVariedadesGuardadas(productorId, campaniaId, bios, variedadId);
        }
        String base = 'SELECT Variedad__c variedadId, Origen__c origen, Etapa__c etapa, SUM(Cantidad_con_Signo__c) toneladas '
            + 'FROM Tonelada__c WHERE Productor__c = :productorId AND Campania__c = :campaniaId '
            + 'AND Cultivo__r.Name = \'TRIGO\' AND Variedad__c != null '
            + 'AND Fecha_Inicio__c <= TODAY AND Etapa__c != \'Pendiente\' '
            + 'AND Origen__c IN (\'Compra SF\', \'Compra HT\', \'Cesión HT\', \'BolsaTech\', \'Escáner varietal\') ';
        if (variedadId != null) {
            base += 'AND Variedad__c = :variedadId ';
        }
        if (!bios.isEmpty()) {
            base += 'AND Biotecnologia__c IN :bios ';
        }

        Map<Id, VariedadPortal> porVariedad = new Map<Id, VariedadPortal>();
        Set<Id> conCompraTonelada = new Set<Id>();
        acumularPorSigno(
            porVariedad,
            Database.query(base + 'AND Cantidad_con_Signo__c >= 0 GROUP BY Variedad__c, Origen__c, Etapa__c'),
            conCompraTonelada
        );
        acumularPorSigno(
            porVariedad,
            Database.query(base + 'AND Cantidad_con_Signo__c < 0 GROUP BY Variedad__c, Origen__c, Etapa__c'),
            conCompraTonelada
        );
        completarCreditoDesdeHt(porVariedad, productorId, campaniaId, bios, variedadId, conCompraTonelada);
        for (VariedadPortal variedad : porVariedad.values()) {
            variedad.saldo = variedad.credito - variedad.debito;
            variedad.estado = EstadoVarietal.calcularVista(variedad.saldo, variedad.entregas);
        }
        return porVariedad;
    }

    private static Map<Id, VariedadPortal> agruparVariedadesGuardadas(
        Id productorId,
        Id campaniaId,
        List<String> bios,
        Id variedadId
    ) {
        Map<Id, VariedadPortal> porVariedad = new Map<Id, VariedadPortal>();
        Boolean usaSaldo = detalleTieneSaldoVariedad();
        Set<Id> conSaldoGuardado = new Set<Id>();
        String creditos = 'SELECT Variedad__c, Credito_Variedad__c'
            + (usaSaldo ? ', Saldo_Variedad__c' : '')
            + ' FROM Detalle_Variedad_CG__c '
            + 'WHERE Cuenta_Granaria__r.Productor__c = :productorId '
            + 'AND Cuenta_Granaria__r.Campania__c = :campaniaId '
            + 'AND Variedad__c != null';
        if (variedadId != null) {
            creditos += ' AND Variedad__c = :variedadId';
        }
        for (SObject detalle : Database.query(creditos)) {
            Id idVariedad = (Id) detalle.get('Variedad__c');
            VariedadPortal actual = variedadPortal(porVariedad, idVariedad);
            Decimal credito = (Decimal) detalle.get('Credito_Variedad__c');
            actual.credito = credito == null ? 0 : credito;
            if (usaSaldo && detalle.get('Saldo_Variedad__c') != null) {
                actual.saldo = (Decimal) detalle.get('Saldo_Variedad__c');
                actual.debito = actual.credito - actual.saldo;
                conSaldoGuardado.add(idVariedad);
            }
        }

        String movs = 'SELECT Variedad__c variedadId, Origen__c origen, SUM(Cantidad_con_Signo__c) toneladas '
            + 'FROM Tonelada__c WHERE Productor__c = :productorId AND Campania__c = :campaniaId '
            + 'AND Cultivo__r.Name = \'TRIGO\' AND Variedad__c != null '
            + 'AND Fecha_Inicio__c <= TODAY AND Etapa__c != \'Pendiente\' '
            + 'AND Origen__c IN (\'Compra SF\', \'Compra HT\', \'Cesión HT\', \'BolsaTech\', \'Escáner varietal\') ';
        if (variedadId != null) {
            movs += 'AND Variedad__c = :variedadId ';
        }
        if (!bios.isEmpty()) {
            movs += 'AND Biotecnologia__c IN :bios ';
        }
        String entregas = movs + 'AND Origen__c IN (\'BolsaTech\', \'Escáner varietal\') GROUP BY Variedad__c, Origen__c';
        for (AggregateResult fila : Database.query(entregas)) {
            Id idVariedad = (Id) fila.get('variedadId');
            VariedadPortal actual = variedadPortal(porVariedad, idVariedad);
            Decimal toneladas = fila.get('toneladas') == null ? 0 : (Decimal) fila.get('toneladas');
            actual.entregas += toneladas < 0 ? -toneladas : toneladas;
        }
        String debitos = movs + 'AND Cantidad_con_Signo__c < 0 GROUP BY Variedad__c, Origen__c';
        for (AggregateResult fila : Database.query(debitos)) {
            Id idVariedad = (Id) fila.get('variedadId');
            VariedadPortal actual = variedadPortal(porVariedad, idVariedad);
            if ((String) fila.get('origen') == 'Cesión HT') {
                actual.tieneCesionSaliente = true;
            }
            if (conSaldoGuardado.contains(idVariedad)) {
                continue;
            }
            Decimal toneladas = fila.get('toneladas') == null ? 0 : (Decimal) fila.get('toneladas');
            actual.debito += -toneladas;
        }
        for (VariedadPortal variedad : porVariedad.values()) {
            if (!conSaldoGuardado.contains(variedad.id)) {
                variedad.saldo = variedad.credito - variedad.debito;
            }
            variedad.estado = EstadoVarietal.calcularVista(variedad.saldo, variedad.entregas);
        }
        return porVariedad;
    }

    private static Map<Id, RegularizarCampana> regularizarPorCreditoGuardado(
        Id productorId,
        List<Id> campaniaIds,
        List<String> bios
    ) {
        Map<Id, RegularizarCampana> porCampana = new Map<Id, RegularizarCampana>();
        Map<Id, Map<Id, Decimal>> saldoPorCampana = new Map<Id, Map<Id, Decimal>>();
        Boolean usaSaldo = detalleTieneSaldoVariedad();
        Set<String> conSaldoGuardado = new Set<String>();
        String creditos = 'SELECT Variedad__c, Credito_Variedad__c, Cuenta_Granaria__r.Campania__c'
            + (usaSaldo ? ', Saldo_Variedad__c' : '')
            + ' FROM Detalle_Variedad_CG__c '
            + 'WHERE Cuenta_Granaria__r.Productor__c = :productorId '
            + 'AND Cuenta_Granaria__r.Campania__c IN :campaniaIds '
            + 'AND Variedad__c != null';
        for (SObject detalle : Database.query(creditos)) {
            SObject cuenta = detalle.getSObject('Cuenta_Granaria__r');
            if (cuenta == null) {
                continue;
            }
            Id campaniaId = (Id) cuenta.get('Campania__c');
            Id idVariedad = (Id) detalle.get('Variedad__c');
            if (!saldoPorCampana.containsKey(campaniaId)) {
                saldoPorCampana.put(campaniaId, new Map<Id, Decimal>());
            }
            Decimal credito = (Decimal) detalle.get('Credito_Variedad__c');
            Decimal saldo = credito == null ? 0 : credito;
            if (usaSaldo && detalle.get('Saldo_Variedad__c') != null) {
                saldo = (Decimal) detalle.get('Saldo_Variedad__c');
                conSaldoGuardado.add(String.valueOf(campaniaId) + ':' + String.valueOf(idVariedad));
            }
            saldoPorCampana.get(campaniaId).put(idVariedad, saldo);
        }
        String consulta = 'SELECT Campania__c campaniaId, Variedad__c variedadId, SUM(Cantidad_con_Signo__c) tn '
            + 'FROM Tonelada__c WHERE Productor__c = :productorId AND Campania__c IN :campaniaIds '
            + 'AND Cultivo__r.Name = \'TRIGO\' AND Variedad__c != null '
            + 'AND Fecha_Inicio__c <= TODAY AND Etapa__c != \'Pendiente\' '
            + 'AND Origen__c IN (\'Compra SF\', \'Compra HT\', \'Cesión HT\', \'BolsaTech\', \'Escáner varietal\') '
            + 'AND Cantidad_con_Signo__c < 0 ';
        if (!bios.isEmpty()) {
            consulta += 'AND Biotecnologia__c IN :bios ';
        }
        consulta += 'GROUP BY Campania__c, Variedad__c';
        for (AggregateResult fila : Database.query(consulta)) {
            Id campaniaId = (Id) fila.get('campaniaId');
            Id variedadId = (Id) fila.get('variedadId');
            if (conSaldoGuardado.contains(String.valueOf(campaniaId) + ':' + String.valueOf(variedadId))) {
                continue;
            }
            Decimal tn = fila.get('tn') == null ? 0 : (Decimal) fila.get('tn');
            if (!saldoPorCampana.containsKey(campaniaId)) {
                saldoPorCampana.put(campaniaId, new Map<Id, Decimal>());
            }
            Decimal credito = saldoPorCampana.get(campaniaId).containsKey(variedadId)
                ? saldoPorCampana.get(campaniaId).get(variedadId)
                : 0;
            saldoPorCampana.get(campaniaId).put(variedadId, credito + tn);
        }

        Set<Id> variedadIds = new Set<Id>();
        Map<Id, Map<Id, Decimal>> negativas = new Map<Id, Map<Id, Decimal>>();
        for (Id campaniaId : saldoPorCampana.keySet()) {
            for (Id variedadId : saldoPorCampana.get(campaniaId).keySet()) {
                Decimal saldo = saldoPorCampana.get(campaniaId).get(variedadId);
                if (!EstadoVarietal.saldoNegativo(saldo)) {
                    continue;
                }
                if (!negativas.containsKey(campaniaId)) {
                    negativas.put(campaniaId, new Map<Id, Decimal>());
                }
                negativas.get(campaniaId).put(variedadId, saldo);
                variedadIds.add(variedadId);
            }
        }
        if (variedadIds.isEmpty()) {
            return porCampana;
        }
        Map<Id, Variedad__c> nombres = new Map<Id, Variedad__c>([
            SELECT Name, Cultivar_INASE__c FROM Variedad__c WHERE Id IN :variedadIds
        ]);
        for (Id campaniaId : negativas.keySet()) {
            List<VariedadPortal> lista = new List<VariedadPortal>();
            RegularizarCampana resumen = new RegularizarCampana();
            resumen.toneladas = 0;
            resumen.variedades = new List<String>();
            for (Id variedadId : negativas.get(campaniaId).keySet()) {
                VariedadPortal variedad = new VariedadPortal();
                variedad.estado = 'Debe regularizar';
                variedad.saldo = negativas.get(campaniaId).get(variedadId);
                variedad.nombre = nombreCatalogo(nombres.get(variedadId));
                lista.add(variedad);
                resumen.toneladas += -variedad.saldo;
            }
            lista.sort();
            for (VariedadPortal variedad : lista) {
                resumen.variedades.add(variedad.nombre);
            }
            porCampana.put(campaniaId, resumen);
        }
        return porCampana;
    }

    private static VariedadPortal variedadPortal(Map<Id, VariedadPortal> porVariedad, Id variedadId) {
        VariedadPortal actual = porVariedad.get(variedadId);
        if (actual == null) {
            actual = new VariedadPortal();
            actual.id = variedadId;
            porVariedad.put(variedadId, actual);
        }
        return actual;
    }

    private static void acumularPorSigno(
        Map<Id, VariedadPortal> porVariedad,
        List<AggregateResult> filas,
        Set<Id> conCompraTonelada
    ) {
        for (AggregateResult fila : filas) {
            Id idVariedad = (Id) fila.get('variedadId');
            VariedadPortal actual = porVariedad.get(idVariedad);
            if (actual == null) {
                actual = new VariedadPortal();
                actual.id = idVariedad;
                porVariedad.put(idVariedad, actual);
            }
            Decimal toneladas = fila.get('toneladas') == null ? 0 : (Decimal) fila.get('toneladas');
            String origen = (String) fila.get('origen');
            String etapa = (String) fila.get('etapa');
            if (!EstadoVarietal.acreditaCompra(origen, etapa)) {
                continue;
            }
            if (EstadoVarietal.esEntrega(origen)) {
                actual.entregas += toneladas < 0 ? -toneladas : toneladas;
                actual.debito += -toneladas;
            } else {
                actual.credito += toneladas;
                if (origen == 'Cesión HT' && toneladas < 0) {
                    actual.tieneCesionSaliente = true;
                }
                if ((origen == 'Compra HT' || origen == 'Compra SF') && toneladas > 0 && conCompraTonelada != null) {
                    conCompraTonelada.add(idVariedad);
                }
            }
        }
    }

    private static final Set<String> ETAPAS_CREDITO_HT = EstadoVarietal.ETAPAS_CREDITO_COMPRA;

    /**
     * Si la compra cobrada no llegó a Tonelada (B-01 / B-05), el portal igual
     * muestra el crédito desde la HT. No pisa el cálculo cuando ya hay toneladas.
     */
    private static void completarCreditoDesdeHt(
        Map<Id, VariedadPortal> porVariedad,
        Id productorId,
        Id campaniaId,
        List<String> bios,
        Id variedadId,
        Set<Id> conCompraTonelada
    ) {
        for (Hectareas_Tecnologicas__c ht : consultarHtsCredito(productorId, campaniaId, bios, variedadId)) {
            if (ht.Variedad__c == null || (conCompraTonelada != null && conCompraTonelada.contains(ht.Variedad__c))) {
                continue;
            }
            Decimal toneladas = toneladasDeHt(ht);
            if (toneladas <= 0) {
                continue;
            }
            VariedadPortal actual = variedadPortal(porVariedad, ht.Variedad__c);
            actual.credito += toneladas;
        }
    }

    private static void agregarCreditosDesdeHt(
        DetalleVariedad detalle,
        Id productorId,
        Id campaniaId,
        Id variedadId,
        List<String> bios
    ) {
        for (Hectareas_Tecnologicas__c ht : consultarHtsCredito(productorId, campaniaId, bios, variedadId)) {
            Decimal toneladas = toneladasDeHt(ht);
            if (toneladas <= 0) {
                continue;
            }
            Date fecha = ht.CreatedDate != null ? ht.CreatedDate.date() : ht.Fecha_de_la_Transaccion__c;
            MovimientoPortal credito = movimientoCredito(fecha, ht.Origen__c, toneladas);
            detalle.creditos.add(credito);
            detalle.totalCreditos += toneladas;
        }
        ordenarPorFechaDesc(detalle.creditos);
    }

    private static List<Hectareas_Tecnologicas__c> consultarHtsCredito(
        Id productorId,
        Id campaniaId,
        List<String> bios,
        Id variedadId
    ) {
        String consulta = 'SELECT Variedad__c, Origen__c, Toneladas__c, Signo__c, CreatedDate, Fecha_de_la_Transaccion__c '
            + 'FROM Hectareas_Tecnologicas__c '
            + 'WHERE Productor__c = :productorId AND Campania__c = :campaniaId '
            + 'AND Cultivo__r.Name = \'TRIGO\' AND Variedad__c != null '
            + 'AND Origen__c IN (\'Compra HT\', \'Compra SF\') '
            + 'AND Etapa__c IN :ETAPAS_CREDITO_HT ';
        if (variedadId != null) {
            consulta += 'AND Variedad__c = :variedadId ';
        }
        if (!bios.isEmpty()) {
            consulta += 'AND Biotecnologia__c IN :bios ';
        }
        consulta += 'ORDER BY CreatedDate DESC, Id DESC';
        return Database.query(consulta);
    }

    private static Decimal toneladasDeHt(Hectareas_Tecnologicas__c ht) {
        Decimal toneladas = ht.Toneladas__c == null ? 0 : ht.Toneladas__c;
        Decimal signo = ht.Signo__c == null ? 1 : ht.Signo__c;
        return toneladas * signo;
    }

    private static void completarNombres(Map<Id, VariedadPortal> porVariedad) {
        if (porVariedad.isEmpty()) {
            return;
        }
        Map<Id, Variedad__c> variedades = new Map<Id, Variedad__c>([
            SELECT Name, Cultivar_INASE__c, Obtentor_Comercializa__c, Nombre_Obtentor__c, Obtentor_Comercializa__r.Id_Obtentor__c,
                Obtentor_Comercializa__r.Nombre_Obtentor__c
            FROM Variedad__c
            WHERE Id IN :porVariedad.keySet()
        ]);
        for (VariedadPortal variedad : porVariedad.values()) {
            Variedad__c registro = variedades.get(variedad.id);
            variedad.nombre = nombreCatalogo(registro);
            variedad.idObtentor = registro == null ? null : registro.Obtentor_Comercializa__r?.Id_Obtentor__c;
            variedad.marcaId = registro == null || registro.Obtentor_Comercializa__c == null
                ? variedad.id
                : registro.Obtentor_Comercializa__c;
            variedad.marca = nombreMarca(registro);
        }
    }

    private static String nombreCatalogo(Variedad__c registro) {
        if (registro == null) {
            return 'Sin variedad';
        }
        if (String.isNotBlank(registro.Name)) {
            return registro.Name;
        }
        return String.isBlank(registro.Cultivar_INASE__c) ? 'Sin variedad' : registro.Cultivar_INASE__c;
    }

    private static String nombreMarca(Variedad__c registro) {
        if (registro == null) {
            return 'Sin marca';
        }
        String comercial = registro.Obtentor_Comercializa__r?.Nombre_Obtentor__c;
        if (String.isNotBlank(comercial)) {
            return comercial;
        }
        return String.isBlank(registro.Nombre_Obtentor__c) ? 'Sin marca' : registro.Nombre_Obtentor__c;
    }

    private static List<String> biotecnologias(String tecnologias) {
        List<String> values = new List<String>();
        if (String.isBlank(tecnologias)) {
            return values;
        }
        for (String parte : tecnologias.split('/')) {
            if (String.isNotBlank(parte)) {
                values.add(parte.trim());
            }
        }
        return values;
    }

    private static Date fechaCredito(Tonelada__c tn) {
        if (tn.CreatedDate != null) {
            return tn.CreatedDate.date();
        }
        return tn.Fecha_Inicio__c;
    }

    private static void ordenarPorFechaDesc(List<MovimientoPortal> movimientos) {
        for (Integer i = 0; i < movimientos.size(); i++) {
            Integer mejor = i;
            for (Integer j = i + 1; j < movimientos.size(); j++) {
                Date actual = movimientos[mejor].fecha;
                Date candidata = movimientos[j].fecha;
                if (candidata != null && (actual == null || candidata > actual)) {
                    mejor = j;
                }
            }
            if (mejor != i) {
                MovimientoPortal tmp = movimientos[i];
                movimientos[i] = movimientos[mejor];
                movimientos[mejor] = tmp;
            }
        }
    }

    private static MovimientoPortal movimientoCredito(Date fecha, String origen, Decimal toneladas) {
        MovimientoPortal movimiento = new MovimientoPortal();
        movimiento.fecha = fecha;
        movimiento.origen = etiquetaCredito(origen, toneladas);
        movimiento.toneladas = toneladas;
        if (toneladas != 0) {
            // 1 HT = 4 t. Sin redondear: 25 t son 6,25 HT, no 6 HT.
            movimiento.ht = toneladas / 4;
        }
        return movimiento;
    }

    // Un crédito negativo es la anulación de una venta o compra, o una cesión a otro productor.
    private static String etiquetaCredito(String origen, Decimal toneladas) {
        if (toneladas >= 0) {
            return etiquetaOrigen(origen);
        }
        if (origen == 'Cesión HT') return 'Cesión a otro productor';
        return 'Anulación · ' + etiquetaOrigen(origen);
    }

    private static String etiquetaOrigen(String origen) {
        if (origen == 'Compra SF') return 'Semilla Fiscalizada';
        if (origen == 'Compra HT') return 'Compra de HT';
        if (origen == 'Cesión HT') return 'Cesión';
        return origen;
    }

    private static String enmascararCtg(String ctg) {
        if (String.isBlank(ctg) || ctg.length() <= 4) {
            return ctg;
        }
        return '••••' + ctg.right(4);
    }

    private static Date ultimaEntrega(Id productorId, Id campaniaId, List<String> bios) {
        String consulta = 'SELECT MAX(Fecha_Inicio__c) ultima FROM Tonelada__c '
            + 'WHERE Productor__c = :productorId AND Campania__c = :campaniaId '
            + 'AND Cultivo__r.Name = \'TRIGO\' AND Fecha_Inicio__c <= TODAY '
            + 'AND Etapa__c != \'Pendiente\' AND Origen__c IN (\'BolsaTech\', \'Escáner varietal\') ';
        if (!bios.isEmpty()) {
            consulta += 'AND Biotecnologia__c IN :bios ';
        }
        List<AggregateResult> filas = Database.query(consulta);
        return filas.isEmpty() ? null : (Date) filas[0].get('ultima');
    }

    private static AuraHandledException errorVarietal(String mensaje) {
        AuraHandledException ex = new AuraHandledException(mensaje);
        ex.setMessage(mensaje);
        return ex;
    }

    private static Integer grupoEstado(String estado) {
        if (estado == 'Debe regularizar' || estado == 'regularizar') return 0;
        if (estado == 'En regla') return 1;
        return 2;
    }

    public class RegularizarCampana {
        @AuraEnabled public Decimal toneladas;
        @AuraEnabled public List<String> variedades;
    }

    public class ResumenVarietal {
        @AuraEnabled public Decimal toneladasARegularizar;
        @AuraEnabled public Date ultimaEntrega;
        @AuraEnabled public List<MarcaPortal> marcas;
    }

    public class MarcaPortal implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String nombre;
        @AuraEnabled public String idObtentor;
        @AuraEnabled public String estado;
        @AuraEnabled public String etiqueta;
        @AuraEnabled public Integer aRegularizar;
        @AuraEnabled public List<VariedadPortal> variedades;

        public Integer compareTo(Object otro) {
            MarcaPortal marca = (MarcaPortal) otro;
            Integer grupo = grupoEstado(this.estado) - grupoEstado(marca.estado);
            if (grupo != 0) return grupo;
            return (this.nombre == null ? '' : this.nombre).toLowerCase()
                .compareTo((marca.nombre == null ? '' : marca.nombre).toLowerCase());
        }
    }

    public class VariedadPortal implements Comparable {
        @AuraEnabled public Id id;
        @AuraEnabled public String nombre;
        @AuraEnabled public Id marcaId;
        @AuraEnabled public String marca;
        @AuraEnabled public String idObtentor;
        @AuraEnabled public Decimal credito = 0;
        @AuraEnabled public Decimal debito = 0;
        @AuraEnabled public Decimal saldo = 0;
        @AuraEnabled public Decimal entregas = 0;
        @AuraEnabled public Boolean tieneCesionSaliente = false;
        @AuraEnabled public String estado;

        public Integer compareTo(Object otro) {
            VariedadPortal variedad = (VariedadPortal) otro;
            Integer grupo = grupoEstado(this.estado) - grupoEstado(variedad.estado);
            if (grupo != 0) return grupo;
            if (this.estado == 'Debe regularizar' && this.saldo != variedad.saldo) {
                return this.saldo < variedad.saldo ? -1 : 1;
            }
            return (this.nombre == null ? '' : this.nombre).toLowerCase()
                .compareTo((variedad.nombre == null ? '' : variedad.nombre).toLowerCase());
        }
    }

    public class DetalleVariedad {
        @AuraEnabled public Id variedadId;
        @AuraEnabled public String variedad;
        @AuraEnabled public String marca;
        @AuraEnabled public String idObtentor;
        @AuraEnabled public String estado;
        @AuraEnabled public Decimal credito;
        @AuraEnabled public Decimal debito;
        @AuraEnabled public Decimal saldo;
        @AuraEnabled public Decimal toneladasARegularizar;
        @AuraEnabled public Decimal totalCreditos;
        @AuraEnabled public Decimal totalDebitado;
        @AuraEnabled public Boolean tieneCesionSaliente;
        @AuraEnabled public List<MovimientoPortal> creditos;
        @AuraEnabled public List<MovimientoPortal> debitos;
        @AuraEnabled public List<MovimientoPortal> entregas;
    }

    public class MovimientoPortal {
        @AuraEnabled public Date fecha;
        @AuraEnabled public String origen;
        @AuraEnabled public String marca;
        @AuraEnabled public String variedad;
        @AuraEnabled public Decimal ht;
        @AuraEnabled public String ctg;
        @AuraEnabled public Decimal kgNetos;
        @AuraEnabled public Decimal toneladas;
    }
}