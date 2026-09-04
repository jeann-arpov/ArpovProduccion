public without sharing class MisFacturasController {
    @testVisible private static List<ERPvs__Vencimientos__c> vencimientosTest;
    @testVisible private static ERPvs__Tipo_de_cambio__c tipoCambioTest;
    @testVisible private static List<Attachment> attachmentsTest;
    @testVisible private static List<Opportunity> oppsTest;

    public static List<ERPvs__Vencimientos__c> queryVencimientos(String type) {
        if (Test.isRunningTest() && vencimientosTest != null) return vencimientosTest;
        if (type == 'Productor') return [select ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Cuenta_Productor__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Nombre_Cultivo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Comercio__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.N_CUIT__c, ERPVS__Comprobante_Venta__r.ERPvs__Comprobante__c, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Nombre_Obtentor__c, ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c, ERPvs__Fecha_Vencimiento__c, ERPVS__Comprobante_Venta__r.ERPvs__Moneda__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__Total__c, ERPvs__Importe_MO_x_Signo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName from ERPvs__Vencimientos__c where ERPvs__Cuenta__c =: CrearCompraController.getAccount().id AND ERPVS__Comprobante_Venta__r.Oportunidad__r.RecordType.DeveloperName = 'Sembra_Evolucion' AND ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName in ('Facturada', 'Parcialmente Facturada', 'Pagada', 'Parcialmente Pagada', 'Cancelada por NC') AND ERPVS__Comprobante_Venta__r.erpvs__tipo_comp__c = 'Factura' order by ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c desc];
        return [select ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Cuenta_Productor__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Nombre_Cultivo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Comercio__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.N_CUIT__c, ERPVS__Comprobante_Venta__r.ERPvs__Comprobante__c, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Nombre_Obtentor__c, ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c, ERPvs__Fecha_Vencimiento__c, ERPVS__Comprobante_Venta__r.ERPvs__Moneda__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__Total__c, ERPvs__Importe_MO_x_Signo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName  from ERPvs__Vencimientos__c where ERPvs__Cuenta__c =: CrearCompraController.getAccount().id AND ERPVS__Comprobante_Venta__r.Oportunidad__r.RecordType.DeveloperName = 'Sembra_Evolucion' AND ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName in ('Facturada', 'Parcialmente Facturada', 'Pagada', 'Parcialmente Pagada', 'Cancelada por NC') AND ERPVS__Comprobante_Venta__r.erpvs__tipo_comp__c = 'Factura' order by ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c desc];
    }

    

    public static List<Opportunity> queryOportunidades(String type){
        System.debug('queryOportunidades type: ' + CrearCompraController.getAccount().Id );
        if (Test.isRunningTest() && oppsTest != null) return oppsTest;
        if (type == 'Productor') return [
            SELECT Tipo_de_Comprobante__c, N_de_Comprobante__c, Obtentor__r.Name, Obtentor__r.Nombre_Obtentor__c, Fecha_Emision_Comprobante__c, 
                Fecha_Vencimiento_Comprobante__c, Moneda__c, Moneda__r.Name, Total_Comprobante__c, Saldo_a_Cobrar_Comprobante__c, Saldo_Actualizado__c, 
                Compra_HT__r.Comercio__r.Name, Compra_HT__r.Cuenta_Productor__r.Name, StageName, Cultivo__c , CUIT__c, Account.Name
            FROM Opportunity 
            WHERE AccountId = :CrearCompraController.getAccount().Id 
            AND Tipo_de_Comprobante__c = 'FC'
            AND StageName in ('Facturada', 'Pagada')
            AND Type = 'SE' AND (Sembra_Evolucion__c = TRUE OR Sembra_Evolucion__c = FALSE)
        ];
        return [
            SELECT Tipo_de_Comprobante__c, N_de_Comprobante__c, Obtentor__r.Name, Obtentor__r.Nombre_Obtentor__c, Fecha_Emision_Comprobante__c, 
                Fecha_Vencimiento_Comprobante__c, Moneda__c, Moneda__r.Name, Total_Comprobante__c, Saldo_a_Cobrar_Comprobante__c, Saldo_Actualizado__c, 
                Compra_HT__r.Comercio__r.Name, Compra_HT__r.Cuenta_Productor__r.Name, StageName, Cultivo__c, CUIT__c, Account.Name 
            FROM Opportunity 
            WHERE Comercio__c = :CrearCompraController.getAccount().Id 
            AND Tipo_de_Comprobante__c = 'FC'
            AND StageName in ('Facturada', 'Pagada')
            AND Type = 'SE' AND (Sembra_Evolucion__c = TRUE OR Sembra_Evolucion__c = FALSE)
        ];
    }

    @AuraEnabled
    public static List<Vencimiento> getVencimientos(String type) {
        if (CrearCompraController.getAccount() == null) return new List<Vencimiento>();

        List<ERPvs__Vencimientos__c> vencimientos = queryVencimientos(type);
        List<Vencimiento> results = new List<Vencimiento>();
        List<Id> cvIds = new List<Id>();
        Map<Id, ERPvs__Tipo_de_cambio__c> monedaToTipoDeCambio = new Map<Id, ERPvs__Tipo_de_cambio__c>();
        Set<Id> vencimientosIds = new Set<Id>();

        for (ERPvs__Vencimientos__c vencimiento: vencimientos) {
            results.add(new Vencimiento(vencimiento));
            cvIds.add(vencimiento.ERPVS__Comprobante_Venta__c);
            Id monedaId = vencimiento.ERPVS__Comprobante_Venta__r != null
                ? vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c
                : null;
            if (monedaId != null) monedaToTipoDeCambio.put(monedaId, null);
            vencimientosIds.add(vencimiento.Id);
        }

        for (Id moneda: monedaToTipoDeCambio.keySet()) {
            ERPvs__Tipo_de_cambio__c cambio;
            if (Test.isRunningTest()) {
                cambio = tipoCambioTest;
            } else {
                List<ERPvs__Tipo_de_cambio__c> cambios = [
                    SELECT Erpvs__Vendedor__c
                    FROM ERPvs__Tipo_de_cambio__c
                    WHERE ERPvs__Moneda__c = :moneda AND Erpvs__Fecha__c <= :System.today()
                    ORDER BY Erpvs__Fecha__c DESC
                    LIMIT 1
                ];
                cambio = cambios.isEmpty() ? null : cambios[0];
            }
            monedaToTipoDeCambio.put(moneda, cambio);
        }

        Map<Id,EstadoDeCuentaAuraService.File> filesByCv = new Map<Id,EstadoDeCuentaAuraService.File>();

        for(Attachment at : (Test.isRunningTest() && attachmentsTest != null) ? attachmentsTest : [SELECT Id, ParentId, Body, Name, ContentType FROM Attachment WHERE ParentId IN :cvIds AND Name LIKE 'Factura%']){
            filesByCv.put(at.ParentId, new EstadoDeCuentaAuraService.File(at));
        }

        // Map<Id, String> mapLinksDePago = new Map<Id, String>();
        // for(Link_de_Pago__c link : [SELECT Url__c, Vencimiento__c FROM Link_de_Pago__c WHERE Vencimiento__c IN :vencimientosIds AND Estado__c = 'Creado' AND Expiration_Date__c <= :Date.today()]){
        //     mapLinksDePago.put(link.Vencimiento__c, link.Url__c);
        // }

        Set<Id> oppIdsYaIncluidas = new Set<Id>();
        Set<String> numerosYaIncluidos = new Set<String>();
        for (Vencimiento vencimiento: results) {
            vencimiento.file = filesByCv.get(vencimiento.comprobanteId);
            ERPvs__Tipo_de_cambio__c cambio = monedaToTipoDeCambio.get(vencimiento.monedaId);
            if (!Test.isRunningTest() && vencimiento.saldoArs != null && cambio != null && cambio.Erpvs__Vendedor__c != null) {
                vencimiento.saldoArs *= cambio.Erpvs__Vendedor__c;
            }
            //vencimiento.linkDePago = mapLinksDePago.get(vencimiento.id);
            if (vencimiento.opportunityId != null) oppIdsYaIncluidas.add(vencimiento.opportunityId);
            String numeroKey = normalizeNumeroComprobante(vencimiento.numero);
            if (String.isNotBlank(numeroKey)) numerosYaIncluidos.add(numeroKey);
        }

        List<Opportunity> oportunidades = queryOportunidades(type);
        
        if(oportunidades.isEmpty() == false){
            List<String> contentDocumentIds = new List<String>();
            Set<Id> oppIds = new Map<Id, Opportunity>(oportunidades).keySet();
            for(ContentDocumentLink cdl : [SELECT ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId IN :oppIds]){
                contentDocumentIds.add(cdl.ContentDocumentId);
            }
            
            Map<Id, String> mapFileNames = new Map<Id, String>();
            for(Opportunity opp : oportunidades){
                mapFileNames.put(opp.Id, opp.Tipo_de_Comprobante__c + opp.N_de_Comprobante__c);
            }
            
            Map<String, String> mapArchivos = new Map<String, String>();
            for(ContentVersion cv : [SELECT Id, Title, ContentDocumentId FROM ContentVersion WHERE ContentDocumentId IN :contentDocumentIds AND Title IN :mapFileNames.values()]){
                mapArchivos.put(cv.Title, cv.ContentDocumentId);
            }
            
            System.debug('archivos: ' + mapArchivos);
            for(Opportunity opp : oportunidades){
                if (alreadyListed(oppIdsYaIncluidas, numerosYaIncluidos, opp)) continue;

                Vencimiento v = new Vencimiento(opp);
                v.facturaPVId = mapArchivos.get(mapFileNames.get(opp.Id));
                System.debug(v.facturaPVId);
                results.add(v);
                if (opp.Id != null) oppIdsYaIncluidas.add(opp.Id);
                String numeroKey = normalizeNumeroComprobante(v.numero);
                if (String.isNotBlank(numeroKey)) numerosYaIncluidos.add(numeroKey);
            }
        }

        return results;
    }

    @testVisible
    static String normalizeNumeroComprobante(String numero) {
        if (String.isBlank(numero)) return '';
        String n = numero.toUpperCase().trim();
        n = n.replaceAll('\\b(FACTURA|FAC)\\b', '');
        return n.replaceAll('[^A-Z0-9]', '');
    }

    @testVisible
    static Boolean alreadyListed(Set<Id> oppIds, Set<String> numeros, Opportunity opp) {
        if (opp == null) return false;
        if (opp.Id != null && oppIds != null && oppIds.contains(opp.Id)) return true;
        String numeroKey = normalizeNumeroComprobante('Factura ' + (opp.N_de_Comprobante__c ?? ''));
        return String.isNotBlank(numeroKey) && numeros != null && numeros.contains(numeroKey);
    }
    
    public class Vencimiento {
        @AuraEnabled public Id id;
        @AuraEnabled public Id comprobanteId;
        @AuraEnabled public String numero;
        @AuraEnabled public String obtentor;
        @AuraEnabled public Id obtentorId;
        @AuraEnabled public Datetime fecha;
        @AuraEnabled public Datetime fechaVencimiento;
        @AuraEnabled public String moneda;
        Id monedaId;
        @AuraEnabled public Decimal total;
        @AuraEnabled public Decimal saldo;
        @AuraEnabled public Decimal saldoArs;
        @AuraEnabled public String cuit;
        @AuraEnabled public EstadoDeCuentaAuraService.File file;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public Boolean pagarDisabled;
        @AuraEnabled public String productor;
        @AuraEnabled public String comercio;
        @AuraEnabled public String facturaPVId;
        @AuraEnabled public String oppStage;
        //@AuraEnabled public String linkDePago;
        @AuraEnabled public String cultivo;
        @AuraEnabled public String obtentorMarca;
        @AuraEnabled public String cuentaName;

        public Vencimiento(ERPvs__Vencimientos__c vencimiento) {
            ERPvs__Comprobante_Venta__c cv = vencimiento.ERPVS__Comprobante_Venta__r;
            comprobanteId = vencimiento.ERPVS__Comprobante_Venta__c;
            if (cv != null) {
                numero = cv.ERPvs__Comprobante__c;
                obtentorId = cv.ERPvs__A_cuenta_y_orden_de__c;
                if (cv.ERPvs__A_cuenta_y_orden_de__r != null) {
                    obtentor = cv.ERPvs__A_cuenta_y_orden_de__r.Name;
                    obtentorMarca = cv.ERPvs__A_cuenta_y_orden_de__r.Nombre_Obtentor__c;
                }
                fecha = cv.ERPvs__Fecha__c;
                if (cv.ERPvs__Moneda__r != null) moneda = cv.ERPvs__Moneda__r.Name;
                monedaId = cv.ERPvs__Moneda__c;
                total = cv.ERPvs__Total__c;
                opportunityId = cv.Oportunidad__c;
                if (cv.Oportunidad__r != null) {
                    oppStage = cv.Oportunidad__r.StageName;
                    if (cv.Oportunidad__r.Compra_HT__r != null) {
                        cultivo = cv.Oportunidad__r.Compra_HT__r.Nombre_Cultivo__c;
                        if (cv.Oportunidad__r.Compra_HT__r.Cuenta_Productor__r != null) {
                            productor = cv.Oportunidad__r.Compra_HT__r.Cuenta_Productor__r.Name;
                        }
                        if (cv.Oportunidad__r.Compra_HT__r.Comercio__r != null) {
                            comercio = cv.Oportunidad__r.Compra_HT__r.Comercio__r.Name;
                        }
                    }
                }
            }
            fechaVencimiento = vencimiento.ERPvs__Fecha_Vencimiento__c;
            saldo = vencimiento.ERPvs__Importe_MO_x_Signo__c;
            saldoArs = vencimiento.ERPvs__Importe_MO_x_Signo__c;
            id = vencimiento.id;
            Account acc = CrearCompraController.getAccount();
            cuit = acc != null ? acc.N_CUIT__c : null;
            pagarDisabled = vencimiento.ERPvs__Importe_MO_x_Signo__c != null && vencimiento.ERPvs__Importe_MO_x_Signo__c <= 0;
            cuentaName = acc != null ? acc.Name : null;
        }

        public Vencimiento(Opportunity opp){
            numero = 'Factura ' + (opp.N_de_Comprobante__c ?? '');
            obtentorId = opp.Obtentor__c;
            if (opp.Obtentor__r != null) {
                obtentor = opp.Obtentor__r.Name;
                obtentorMarca = opp.Obtentor__r.Nombre_Obtentor__c;
            }
            fecha = opp.Fecha_Emision_Comprobante__c;
            fechaVencimiento = opp.Fecha_Vencimiento_Comprobante__c;
            if (opp.Moneda__r != null) moneda = opp.Moneda__r.Name;
            monedaId = opp.Moneda__c;
            total = opp.Total_Comprobante__c;
            saldo = opp.Saldo_a_Cobrar_Comprobante__c;
            saldoArs = opp.Saldo_Actualizado__c;
            pagarDisabled = true;
            if (opp.Compra_HT__r != null) {
                if (opp.Compra_HT__r.Cuenta_Productor__r != null) {
                    productor = opp.Compra_HT__r.Cuenta_Productor__r.Name;
                }
                if (opp.Compra_HT__r.Comercio__r != null) {
                    comercio = opp.Compra_HT__r.Comercio__r.Name;
                }
            }
            opportunityId = opp.Id;
            oppStage = opp.StageName;
            cultivo = opp.Cultivo__c;
            cuit = opp.CUIT__c;
            cuentaName = opp.Account != null ? opp.Account.Name : null;
        }
    }
}