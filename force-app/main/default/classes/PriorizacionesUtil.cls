/**
* @author Facundo Luna
* @date 30/05/2014
* @description Clase utilizada para Priorizaciones de Cuentas
*/

public without sharing class PriorizacionesUtil{
    
    public static final String TIPO_PROD_A = 'A';
    public static final String TIPO_PROD_B = 'B';
    public static final String TIPO_PROD_C = 'C';
    public static final String TIPO_PROD_D = 'D';
    public static final String TIPO_PROD_Z = 'Z';
    public static final String VIG_CAMP_ANT = 'VIGENTE SEGÚN CAMP. ANT.';
    public static final String VEN_CAMP_ANT = 'VENCIDO SEGÚN CAMP. ANT.';
    public static final String NEG_VIG = 'NEGOCIADO VIGENTE';
    public static final String NEG_VEN = 'NEGOCIADO VENCIDO';
    public static final String VENCIDO = 'VENCIDO';
    public static final String NO_VENCIDO = 'NO VENCIDO';
    public static final String NO_RESPONDIERON = 'NO RESPONDIO';
    public static final String NO_GESTIONADO = 'NO GESTIONADO';
    public static final String SIN_FECHA_CAMP_ANTERIOR = 'SIN FECHA';
    public static final String SIN_DUPS = 'SIN DUPS';
    public static final String INVIERNO = 'Invierno';
    public static final String VERANO = 'Verano';
    public static final String CREADA = 'Creada';
    public static final String RESPONDIDA_PARCIALMENTE = 'Respondida Parcialmente';
    public static final String CASO_ABIERTO = 'Abierto en Seguimiento';
    static final String[] TIPOS = new String[]{TIPO_PROD_A, TIPO_PROD_B, TIPO_PROD_C, TIPO_PROD_D, TIPO_PROD_Z};
    static final String[] PATRONES_DUP = new String[]{VIG_CAMP_ANT, VEN_CAMP_ANT, NEG_VIG, NEG_VEN, NO_RESPONDIERON, SIN_FECHA_CAMP_ANTERIOR};
    static final String[] PATRONES_COBRANZA = new String[]{VENCIDO, NEG_VEN, NO_VENCIDO, NEG_VIG};
    static final String[] PATRONES_VENTA = new String[]{NEG_VEN, NO_GESTIONADO, NEG_VIG, NO_RESPONDIERON};
    static final String[] TEMPORADAS = new String[]{VERANO, INVIERNO};
    
    private  Campana_Agricola__c campanaActualVerano;
    private  Campana_Agricola__c campanaActualInvierno;
    private  Campana_Agricola__c campanaVentasVerano;
    private  Campana_Agricola__c campanaVentasInvierno;
    private  Date today;
    public Map<String, Account> mapCuentas{get;set;}
    private Map<String, String> mapCuentaTipoProdVerano;
    private Map<String, String> mapCuentaTipoProdInvierno;
    private Map<String, Date> mapCuentaFechaRespuesta;
    private Map<String, Set<String>> mapTipoPatronCuentas;
    private Map<String, Set<String>> mapPatronCuentasCobranzas;
    private Map<String, Set<String>> mapPatronCuentasVentas;
    private Map<String, Date> mapFechasVentas;
    private Map<String, Date> mapFechasDUPS;
    private Map<String, Orden_Intragrupo__c> mapCuentaOrdenIntragrupo;
    private Set<String> cuentasProcesando;
    
    public PriorizacionesUtil(){
        today = Date.today();
        //Obtengo campaña actual
        try{
            campanaActualVerano = [SELECT Nombre_de_Campana_Anterior__c, Temporada__c FROM Campana_Agricola__c WHERE Estado__c = 'Activa' AND Temporada__c = :VERANO];
        }catch(Exception e) {}

        try{
            campanaVentasVerano = [SELECT Id, Temporada__c FROM Campana_Agricola__c WHERE Gestion_Venta__c = true AND Temporada__c = :VERANO LIMIT 1];
        }catch(Exception e){}

        try{
            campanaActualInvierno = [SELECT Nombre_de_Campana_Anterior__c, Temporada__c FROM Campana_Agricola__c WHERE Estado__c = 'Activa' AND Temporada__c = :INVIERNO];
        } catch (Exception e){}

        try{
            campanaVentasInvierno = [SELECT Id, Temporada__c FROM Campana_Agricola__c WHERE Gestion_Venta__c = true AND Temporada__c = :INVIERNO LIMIT 1];        
        }catch(Exception e){}
        
        //Armo map de tipo de productor y patron
        mapPatronCuentasCobranzas = new Map<String, Set<String>>();
        for(String patron : PATRONES_COBRANZA){
            mapPatronCuentasCobranzas.put(patron, new Set<String>());
        }
            
        //Armo map de tipo de productor y patron
        mapTipoPatronCuentas = new Map<String, Set<String>>();
        mapPatronCuentasVentas = new Map<String, Set<String>>();
        for(String temporada : TEMPORADAS){
            for(String tipo : TIPOS){
                for(String patron : PATRONES_DUP){
                    mapTipoPatronCuentas.put(temporada+tipo+patron, new Set<String>());
                }   
            }
            //Armo map de tipo de productor y patron
            for(String patron : PATRONES_VENTA){
                mapPatronCuentasVentas.put(temporada+patron, new Set<String>());
            }
        }
    }
    /**
    * @description Método para armar los grupos
    */
    public void armarGrupos(List<Account> cuentas, Set<String> cuentasReprogramadas){
        //try{
            cuentasProcesando = new Set<String>();
            mapCuentas = new Map<String, Account>();
            mapCuentaTipoProdVerano = new Map<String, String>();
            mapCuentaTipoProdInvierno = new Map<String, String>();
            mapFechasVentas = new Map<String, Date>();
            mapFechasDUPS = new Map<String, Date>();
            mapCuentaFechaRespuesta = new Map<String, Date>();
            mapCuentaOrdenIntragrupo = new Map<String, Orden_Intragrupo__c>();
            for(Account c : cuentas){
                c.Prioridad_DUP_Invierno_Recalculada__c = 999999;
                c.Prioridad_DUP_Invierno_Original__c = 999999;
                c.Prioridad_DUP_Verano_Recalculada__c = 999999;
                c.Prioridad_DUP_Verano_Original__c = 999999;
                c.Prioridad_Cobranzas_Original__c = 999999;
                c.Prioridad_Cobranzas_Recalculada__c = 999999;
                c.Prioridad_Venta_Invierno_Original__c = 999999;
                c.Prioridad_Venta_Invierno_Recalculada__c = 999999;
                c.Prioridad_Venta_Verano_Original__c = 999999;
                c.Prioridad_Venta_Verano_Recalculada__c = 999999;
                c.Estado_Segun_Patron_DUP_Verano__c = null;
                c.Estado_Segun_Patron_DUP_Invierno__c = null;
                c.Estado_Segun_Patron_Cobranzas__c = null;
                c.Estado_Segun_Patron_Venta_Verano__c = null;
                c.Estado_Segun_Patron_Venta_Invierno__c = null;
                if(!cuentasReprogramadas.contains(c.Id)){
                    mapCuentaOrdenIntragrupo.put(c.ID, new Orden_Intragrupo__c(Cuenta__c = c.ID));
                    cuentasProcesando.add(c.ID);
                    mapCuentas.put(c.ID, c);
                    mapCuentaTipoProdVerano.put(c.ID, c.Segmentacion_Productor_Verano__c);
                    mapCuentaTipoProdInvierno.put(c.ID, c.Segmentacion_Productor_Invierno__c);
                }
            }

            for(AggregateResult i : [SELECT Caso__r.AccountID Cuenta, MAX(Fecha_y_Hora__c) FechaHora, Caso__r.Campana__r.Temporada__c Temporada FROM Interaccion__c WHERE Caso__r.AccountID IN :cuentasProcesando GROUP BY Caso__r.AccountID, Caso__r.Campana__r.Temporada__c]){
                if((String)i.get('Temporada') == INVIERNO){
                    mapCuentaOrdenIntragrupo.get((String)i.get('Cuenta')).Dias_desde_Ultimo_Contacto_DUP_Invierno__c = i.get('FechaHora') != null ? today.daysBetween(((Datetime)i.get('FechaHora')).date()) : null;
                } else {
                    mapCuentaOrdenIntragrupo.get((String)i.get('Cuenta')).Dias_desde_Ultimo_Contacto_DUP_Verano__c = i.get('FechaHora') != null ? today.daysBetween(((Datetime)i.get('FechaHora')).date()) : null;
                }
                
            }

            gruposCobranzas();

            if(campanaActualVerano!=null)
                gruposDUPs(campanaActualVerano);

            if(campanaActualInvierno!=null)
                gruposDUPs(campanaActualInvierno);

            if(campanaVentasVerano != null)
                gruposVentas(campanaVentasVerano);

            if(campanaVentasInvierno != null)
                gruposVentas(campanaVentasInvierno);    
            
            
            
            updateCuentas(cuentas);
        //}catch(Exception e){
            
        //    System.Debug(LoggingLevel.INFO,e.getMessage());
            
        //}
    }
    /**
    * @description Método para determinar los grupos de DUPS
    * @param campanaActual: Campaña de verano o invierno que se va a priorizar
    */
    private void gruposDUPs(Campana_Agricola__c campanaActual){
        
        if(campanaActual != null){
            
            //Armo map para determinar el la deuda de cada cuenta y map de fechas de respuestas
            for(Transaccion__c t : [SELECT ID, Nombre_de_la_cuenta__c, Fecha_de_Respuesta__c FROM Transaccion__c WHERE Fecha_de_Respuesta__c = null AND Nombre_de_la_cuenta__c IN :cuentasProcesando AND Campana__c = :campanaActual.ID ORDER BY Fecha_de_Respuesta__c]){
                mapCuentaFechaRespuesta.put(t.Nombre_de_la_cuenta__c+campanaActual.Temporada__c, t.Fecha_de_Respuesta__c);
            }

            for(AggregateResult t : [SELECT MIN(Fecha_de_Respuesta__c) Fecha, Nombre_de_la_cuenta__c FROM Transaccion__c WHERE Campana__c = :campanaActual.Nombre_de_Campana_Anterior__c AND Nombre_de_la_cuenta__c IN :cuentasProcesando GROUP BY Nombre_de_la_cuenta__c]){
                mapFechasDUPS.put((String)t.get('Nombre_de_la_cuenta__c')+campanaActual.Temporada__c, t.get('Fecha') != null ? ((Date)t.get('Fecha')).addYears(1) : null);
            }
            System.debug(LoggingLevel.INFO, 'mapFechasDUPS: ' + mapFechasDUPS);

            for(AggregateResult ar : [SELECT Transaccion__r.Nombre_de_la_cuenta__c Cuenta, SUM(Kilos_Totales__c) Kilos FROM Item_de_DUP__c WHERE Transaccion__r.Campana__c = :campanaActual.Nombre_de_Campana_Anterior__c AND Transaccion__r.Nombre_de_la_cuenta__c IN :cuentasProcesando GROUP BY Transaccion__r.Nombre_de_la_cuenta__c]){
                Decimal kilos = (Decimal)ar.get('Kilos');
                String cuentaId = (String)ar.get('Cuenta');
                if(campanaActual.Temporada__c == INVIERNO){
                    mapCuentaOrdenIntragrupo.get(cuentaId).Tamano_DUP_Invierno__c = kilos;
                } else {
                    mapCuentaOrdenIntragrupo.get(cuentaId).Tamano_DUP_Verano__c = kilos;
                }
            }
            //Armo los grupos de acuerdo a tipo y patron
            Set<String> productoresCalculados = new Set<String>();
            tipoPatronCampanaAnterior(campanaActual.ID, campanaActual.Temporada__c, productoresCalculados);
            tipoPatronNegociado(campanaActual.ID, campanaActual.Temporada__c, productoresCalculados);
        
        }
    }
    /**
    * @description Método para determinar los grupos de Cobranzas
    */
    private void gruposCobranzas(){

        //Armo map para determinar el la deuda de cada cuenta
        for(AggregateResult ar : [SELECT AccountID, SUM(Saldo_a_Gestionar__c) Saldo FROM Opportunity WHERE AccountID IN :cuentasProcesando GROUP BY AccountID]){
            Decimal deudaTotal = (Decimal)ar.get('Saldo');
            String cuentaId = (String)ar.get('AccountID');
            if(deudaTotal > 0){
                mapCuentaOrdenIntragrupo.get(cuentaId).Deuda_Total_Cobranzas__c = deudaTotal;
            }
        }
        
        //Armo los grupos de acuerdo a tipo y patron
        Set<String> productoresCalculados = new Set<String>();
        patronCobranza(productoresCalculados);
        patronNegociadoCobranza(productoresCalculados);
    }
    /**
    * @description Método para determinar los grupos de Ventas
    * @param campanaActual: Campaña de verano o invierno que se va a priorizar
    */
    private void gruposVentas(Campana_Agricola__c campanaActual){

        Map<Id, Double> saldoTotalByAccounts = UtilsVentas.calcularSaldoTotal(cuentasProcesando, campanaActual.Id);

        if(saldoTotalByAccounts != null){

            Set<String> cuentasToRemove = new Set<String>();

            for(Id accId : cuentasProcesando){
                

                if(saldoTotalByAccounts.containsKey(accId) && mapCuentas.containsKey(accId)){

                    Account acc = mapCuentas.get(accId);

                    Double saldoTotal = saldoTotalByAccounts.get(accId);

                    if(campanaActual.Temporada__c == INVIERNO){
                        acc.Saldo_Total_Ventas_Invierno__c = saldoTotal;
                        mapCuentaOrdenIntragrupo.get(accId).Saldo_Total_Ventas_Invierno__c = saldoTotal;
                    } else {
                        acc.Saldo_Total_Ventas_Verano__c = saldoTotal;
                        mapCuentaOrdenIntragrupo.get(accId).Saldo_Total_Ventas_Verano__c = saldoTotal;
                    }

                    if(saldoTotal <= Double.valueOf(0)){
                        cuentasToRemove.add(accId);
                    }

                }

            }

            if(!cuentasToRemove.isEmpty()){
                cuentasProcesando.removeAll(cuentasToRemove);
            }
            
            //Armo los grupos de acuerdo a tipo y patron
            Set<String> productoresCalculados = new Set<String>();
            patronNegociadoVenta(campanaActual.ID, campanaActual.Temporada__c, productoresCalculados);
            patronVentaNoGestionado(campanaActual.ID, campanaActual.Temporada__c, productoresCalculados);
            
            if(!cuentasToRemove.isEmpty()){
                cuentasProcesando.addAll(cuentasToRemove);
            }

        }
        
    }
    /**
    * @description Método para actualizar campañas
    */
    public void updateCuentas(List<Account> cuentas){
        
        update cuentas;
        
        insert  mapCuentaOrdenIntragrupo.values();
        
    }
    
    /**
    * @description Método para determinar la vigencia o vencimiento segun campaña anterior
    * @param campana: Campaña anterior a la actual
    * @param temporada: Temporada de la campaña
    */
    private void tipoPatronCampanaAnterior(String campana, String temporada, Set<String> cuentasCalculados){

        for(Transaccion__c t : [SELECT ID, Fecha_de_Respuesta__c, Nombre_de_la_cuenta__c FROM Transaccion__c WHERE ID NOT IN (SELECT DUP__c FROM Case WHERE Fecha_Comprometida_Respuesta__c != null) AND Fecha_de_Respuesta__c = null AND Campana__c = :campana AND Nombre_de_la_cuenta__c IN :cuentasProcesando ]){
            Date fechaVigencia = mapFechasDups.get(t.Nombre_de_la_cuenta__c+temporada);
            String tipoProd;
            Date fechaRespuestaActual = mapCuentaFechaRespuesta.get(t.Nombre_de_la_cuenta__c+temporada);
            if(temporada == VERANO){
                tipoProd = mapCuentaTipoProdVerano.get(t.Nombre_de_la_cuenta__c);
            } else {
                tipoProd = mapCuentaTipoProdInvierno.get(t.Nombre_de_la_cuenta__c);
            }
            if(tipoProd == null){
                cuentasCalculados.add(t.Nombre_de_la_cuenta__c);
            }
            if(tipoProd != null && fechaVigencia != null && fechaRespuestaActual == null){
                String patron; 
                if(fechaVigencia < today ){
                    patron = VEN_CAMP_ANT;
                } else if(!cuentasCalculados.contains(t.Nombre_de_la_cuenta__c)){
                    patron = VIG_CAMP_ANT;
                }
                cuentasCalculados.add(t.Nombre_de_la_cuenta__c);
                if(patron != null){
                    System.debug(LoggingLevel.INFO, 'temporada: ' + temporada); 
                    System.debug(LoggingLevel.INFO, 'tipoProd: ' + tipoProd); 
                    System.debug(LoggingLevel.INFO, 'patron: ' + patron); 
                    mapTipoPatronCuentas.get(temporada+tipoProd+patron).add(t.Nombre_de_la_cuenta__c);
                    if(temporada == VERANO){
                        mapCuentas.get(t.Nombre_de_la_cuenta__c).Estado_Segun_Patron_DUP_Verano__c = patron;
                        mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_desde_Vencido_DUP_Verano__c = today.daysBetween(fechaVigencia);
                        mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_al_Vencimiento_DUP_Verano__c = today.daysBetween(fechaVigencia);
                    } else {
                        mapCuentas.get(t.Nombre_de_la_cuenta__c).Estado_Segun_Patron_DUP_Invierno__c = patron;
                        mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_desde_Vencido_DUP_Invierno__c = today.daysBetween(fechaVigencia);
                        mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_al_Vencimiento_DUP_Invierno__c = today.daysBetween(fechaVigencia);
                    }
                }
            } else if(!cuentasCalculados.contains(t.Nombre_de_la_cuenta__c) && fechaVigencia == null){
                if(tipoProd != TIPO_PROD_A){
                    mapTipoPatronCuentas.get(temporada+tipoProd+NO_RESPONDIERON).add(t.Nombre_de_la_cuenta__c);
                } else {
                    mapTipoPatronCuentas.get(temporada+tipoProd+VEN_CAMP_ANT).add(t.Nombre_de_la_cuenta__c);
                }
                if(temporada == VERANO){
                    mapCuentas.get(t.Nombre_de_la_cuenta__c).Estado_Segun_Patron_DUP_Verano__c = NO_RESPONDIERON;
                } else {
                    mapCuentas.get(t.Nombre_de_la_cuenta__c).Estado_Segun_Patron_DUP_Invierno__c = NO_RESPONDIERON;
                }
                cuentasCalculados.add(t.Nombre_de_la_cuenta__c);
            }
        }
        for(String id : cuentasProcesando){
            if(!cuentasCalculados.contains(id)){
                mapTipoPatronCuentas.get(temporada+TIPO_PROD_Z+SIN_FECHA_CAMP_ANTERIOR).add(id);
                if(temporada == VERANO){
                    mapCuentas.get(id).Estado_Segun_Patron_DUP_Verano__c = SIN_FECHA_CAMP_ANTERIOR;
                } else {
                    mapCuentas.get(id).Estado_Segun_Patron_DUP_Invierno__c = SIN_FECHA_CAMP_ANTERIOR;
                }
            }
        }
        System.debug(LoggingLevel.INFO, 'mapTipoPatronCuentas: ' + mapTipoPatronCuentas); 
    }
    
    /**
    * @description Método para determinar la vigencia o vencimiento de las cobranzas
    */
    private void patronCobranza(Set<String> productoresCalculados){
        
        for(Opportunity o : [SELECT ID, Fecha_Vencimiento_Comprobante__c, AccountID FROM Opportunity WHERE Saldo_a_Cobrar_Comprobante__c > 0 AND Fecha_Vencimiento_Comprobante__c != null AND AccountID IN :cuentasProcesando AND ID NOT IN(SELECT Factura__c FROM Case WHERE AccountId IN :cuentasProcesando AND Fecha_Comprometida_Pago__c != NULL) ORDER BY Fecha_Vencimiento_Comprobante__c ASC]){
            Date fechaVigencia = o.Fecha_Vencimiento_Comprobante__c;
            if(!productoresCalculados.contains(o.AccountID)){
                String patron; 
                if(fechaVigencia < today){
                    patron = VENCIDO;
                    productoresCalculados.add(o.AccountID);
                } else {
                    patron = NO_VENCIDO;
                }
                mapPatronCuentasCobranzas.get(patron).add(o.AccountID);
                mapCuentas.get(o.AccountID).Estado_Segun_Patron_Cobranzas__c = patron;
                mapCuentaOrdenIntragrupo.get(o.AccountID).Dias_desde_Vencido_Cobranzas__c = today.daysBetween(fechaVigencia);
            }
        }   
        System.debug(LoggingLevel.INFO, 'mapPatronCuentasCobranzas: ' + mapPatronCuentasCobranzas); 
    }
    
    /**
    * @description Método para determinar las ventas no gestionadas
    * @param campana: Campaña actual
    */
    private void patronVentaNoGestionado(String campana, String temporada, Set<String> productoresCalculados){

        List<Venta__c> ventas = [SELECT Fecha__c, Destinatario__c, (SELECT ID FROM Casos__r WHERE isClosed = false) FROM Venta__c WHERE ID IN(SELECT Venta__c FROM Case WHERE Venta__c != null AND Campana__c = :campana AND isClosed = false) AND Campana_Agricola__c = :campana AND Destinatario__c IN :cuentasProcesando];
        Set<String> casosIds = new Set<String>();
        for(Venta__c v : ventas){
            for(Case c : v.Casos__r){
                casosIds.add(c.Id);
            }
        }

        Map<String, Case> mapCasos = new Map<String, Case>();
        for(Case c : [SELECT ID, (SELECT ID from ActivityHistories) FROM Case WHERE ID IN :casosIds]){
            mapCasos.put(c.Id, c);
        }
        for(Venta__c v : ventas){
            Date fechaVigencia = v.get('Fecha__c')!=null?(Date)v.get('Fecha__c'):today;
            String destinatario = (String)v.get('Destinatario__c');
            Boolean casoContactado = false;
            for(Case c : v.Casos__r){
                if(!mapCasos.get(c.Id).ActivityHistories.isEmpty()){
                    casoContactado = true;
                }
            }
            //La cuenta no fue contactada, entonces es no gestionada. Puede que haya sido contactada en otra venta
            if(!casoContactado){
                String patron = null; 
                if(!productoresCalculados.contains(destinatario) ){
                    patron = NO_GESTIONADO;
                } else {
                    if(temporada == VERANO && mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Verano__c == NEG_VIG){
                        patron = NO_GESTIONADO;
                    } else if(temporada == INVIERNO && mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Invierno__c == NEG_VIG){
                        patron = NO_GESTIONADO;
                    }
                }
                if(patron != null){
                    productoresCalculados.add(destinatario);
                    System.debug(LoggingLevel.INFO, 'mapPatronCuentasVentas: ' + mapPatronCuentasVentas.keySet()); 
                    System.debug(LoggingLevel.INFO, 'temporada+patron: ' + temporada+patron); 
                    mapPatronCuentasVentas.get(temporada+patron).add(destinatario);
                    if(temporada == VERANO){
                        mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Verano__c = patron;
                        mapCuentaOrdenIntragrupo.get(destinatario).Dias_desde_Vencido_Ventas_Verano__c = today.daysBetween(fechaVigencia);
                    } else {
                        mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Invierno__c = patron;
                        mapCuentaOrdenIntragrupo.get(destinatario).Dias_desde_Vencido_Ventas_Invierno__c = today.daysBetween(fechaVigencia);
                    }
                }
            //La cuenta fue contactada, entonces va como que no respondio     
            } else {
                if(!productoresCalculados.contains(destinatario) ){
                    if(temporada == VERANO){
                        mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Verano__c = NO_RESPONDIERON;
                    } else {
                        mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Invierno__c = NO_RESPONDIERON;
                    }
                    mapPatronCuentasVentas.get(temporada+NO_RESPONDIERON).add(destinatario);
                } else {
                    if(temporada == VERANO && mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Verano__c == NO_GESTIONADO){
                        mapPatronCuentasVentas.get(temporada+NO_GESTIONADO).remove(destinatario);
                        mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Verano__c = NO_RESPONDIERON;
                        mapPatronCuentasVentas.get(temporada+NO_RESPONDIERON).add(destinatario);
                    } else if(temporada == INVIERNO && mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Invierno__c == NO_GESTIONADO){
                        mapPatronCuentasVentas.get(temporada+NO_GESTIONADO).remove(destinatario);
                        mapCuentas.get(destinatario).Estado_Segun_Patron_Venta_Invierno__c = NO_RESPONDIERON;
                        mapPatronCuentasVentas.get(temporada+NO_RESPONDIERON).add(destinatario);
                    }
                }
                productoresCalculados.add(destinatario);
            }
            
        }   
        System.debug(LoggingLevel.INFO, 'mapPatronCuentasVentas: ' + mapPatronCuentasVentas); 
    }
    
    /**
    * @description Método para determinar la vigencia o vencimiento de un negociado
    * @param campana: Campaña anterior a la actual
    * @param temporada: Temporada de la campaña
    */
    private void tipoPatronNegociado(String campana, String temporada, Set<String> productoresCalculados){    

        for(Transaccion__c t : [SELECT ID, Nombre_de_la_cuenta__c, (SELECT Fecha_Comprometida_Respuesta__c FROM Casos__r WHERE Fecha_Comprometida_Respuesta__c != null) FROM Transaccion__c WHERE Estado__c IN (:CREADA, :RESPONDIDA_PARCIALMENTE) AND Campana__c = :campana AND Nombre_de_la_cuenta__c IN :cuentasProcesando ]){
            if(t.Casos__r != null && !t.Casos__r.isEmpty()){
                Date fechaNegociado = t.Casos__r[0].Fecha_Comprometida_Respuesta__c;
                String tipoProd;
                if(temporada == VERANO){
                    tipoProd = mapCuentaTipoProdVerano.get(t.Nombre_de_la_cuenta__c);
                } else {
                    tipoProd = mapCuentaTipoProdInvierno.get(t.Nombre_de_la_cuenta__c);
                }
                if(tipoProd == null){
                    productoresCalculados.add(t.Nombre_de_la_cuenta__c);
                } else {
                    String patron; 
                    if(fechaNegociado < today){
                        patron = NEG_VEN;
                    } else if(!productoresCalculados.contains(t.Nombre_de_la_cuenta__c)){
                        patron = NEG_VIG;
                    }
                    productoresCalculados.add(t.Nombre_de_la_cuenta__c);
                    if(patron != null){
                        mapTipoPatronCuentas.get(temporada+tipoProd+patron).add(t.Nombre_de_la_cuenta__c);
                        if(temporada == VERANO){
                            mapCuentas.get(t.Nombre_de_la_cuenta__c).Estado_Segun_Patron_DUP_Verano__c = patron;
                            mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_desde_Vencido_DUP_Verano__c = today.daysBetween(fechaNegociado);
                            mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_al_Vencimiento_DUP_Verano__c = today.daysBetween(fechaNegociado);
                        } else {
                            mapCuentas.get(t.Nombre_de_la_cuenta__c).Estado_Segun_Patron_DUP_Invierno__c = patron;
                            mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_desde_Vencido_DUP_Invierno__c = today.daysBetween(fechaNegociado);
                            mapCuentaOrdenIntragrupo.get(t.Nombre_de_la_cuenta__c).Dias_al_Vencimiento_DUP_Invierno__c = today.daysBetween(fechaNegociado);
                        }
                    }
                }
            }
        }   
        System.debug(LoggingLevel.INFO, 'mapTipoPatronCuentas: ' + mapTipoPatronCuentas); 
    }
    
    /**
    * @description Método para determinar la vigencia o vencimiento de un negociado de cobranza
    * @param campana: Campaña anterior a la actual
    */
    private void patronNegociadoCobranza(Set<String> productoresCalculados){

        for(Opportunity o : [SELECT ID, AccountID, (SELECT Fecha_Comprometida_Pago__c FROM Casos__r WHERE Fecha_Comprometida_Pago__c != null) FROM Opportunity WHERE Saldo_a_Cobrar_Comprobante__c > 0 AND AccountID IN :cuentasProcesando ORDER BY Fecha_Vencimiento_Comprobante__c ASC]){
            if(o.Casos__r != null && !o.Casos__r.isEmpty()){
                Date fechaNegociado = o.Casos__r[0].Fecha_Comprometida_Pago__c;
                if(!productoresCalculados.contains(o.AccountID)){
                    String patron; 
                    if(fechaNegociado < today){
                        patron = NEG_VEN;
                        productoresCalculados.add(o.AccountID);
                    } else {
                        patron = NEG_VIG;
                    }
                    mapPatronCuentasCobranzas.get(patron).add(o.AccountID);
                    mapCuentas.get(o.AccountID).Estado_Segun_Patron_Cobranzas__c = patron;
                    mapCuentaOrdenIntragrupo.get(o.AccountID).Dias_desde_Vencido_Cobranzas__c = today.daysBetween(fechaNegociado);
                }
            }
        }   
        System.debug(LoggingLevel.INFO, 'mapPatronCuentasCobranzas: ' + mapPatronCuentasCobranzas); 
    }
    
    /**
    * @description Método para determinar la vigencia o vencimiento de un negociado de venta
    * @param campana: Campaña anterior a la actual
    */
    private void patronNegociadoVenta(String campana, String temporada, Set<String> productoresCalculados){

        for(Venta__c v : [SELECT ID, Destinatario__c, (SELECT Fecha_Comprometida_Respuesta__c FROM Casos__r WHERE Fecha_Comprometida_Respuesta__c!=null) FROM Venta__c WHERE ID IN (SELECT Venta__c FROM Case WHERE isClosed = false AND Venta__c!=null) AND Campana_Agricola__c = :campana AND Destinatario__c IN :cuentasProcesando ORDER BY Fecha__c ASC]){
            if(v.Casos__r != null && !v.Casos__r.isEmpty()){
                Date fechaNegociado = v.Casos__r[0].Fecha_Comprometida_Respuesta__c;
                String patron; 
                if(fechaNegociado < today){
                    patron = NEG_VEN;
                } else if(!productoresCalculados.contains(v.Destinatario__c)){
                    patron = NEG_VIG;
                }
                productoresCalculados.add(v.Destinatario__c);
                mapPatronCuentasVentas.get(temporada+patron).add(v.Destinatario__c);
                if(temporada == VERANO){
                    mapCuentas.get(v.Destinatario__c).Estado_Segun_Patron_Venta_Verano__c = patron;
                    mapCuentaOrdenIntragrupo.get(v.Destinatario__c).Dias_desde_Vencido_Ventas_Verano__c = today.daysBetween(fechaNegociado);
                } else {
                    mapCuentas.get(v.Destinatario__c).Estado_Segun_Patron_Venta_Invierno__c = patron;
                    mapCuentaOrdenIntragrupo.get(v.Destinatario__c).Dias_desde_Vencido_Ventas_Invierno__c = today.daysBetween(fechaNegociado);
                }
            }
        }   
        System.debug(LoggingLevel.INFO, 'mapPatronCuentasVentas: ' + mapPatronCuentasVentas); 
    }
       
}