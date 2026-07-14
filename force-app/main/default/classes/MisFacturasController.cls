public without sharing class MisFacturasController {
    @testVisible private static List<ERPvs__Vencimientos__c> vencimientosTest;
    @testVisible private static ERPvs__Tipo_de_cambio__c tipoCambioTest;
    @testVisible private static List<Attachment> attachmentsTest;
    @testVisible private static List<Opportunity> oppsTest;

    public static List<ERPvs__Vencimientos__c> queryVencimientos(String type) {
        if (Test.isRunningTest()) return vencimientosTest;
        if (type == 'Productor') return [select ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Cuenta_Productor__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Nombre_Cultivo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Comercio__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.N_CUIT__c, ERPVS__Comprobante_Venta__r.ERPvs__Comprobante__c, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Nombre_Obtentor__c, ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c, ERPvs__Fecha_Vencimiento__c, ERPVS__Comprobante_Venta__r.ERPvs__Moneda__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__Total__c, ERPvs__Importe_MO_x_Signo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName from ERPvs__Vencimientos__c where ERPvs__Cuenta__c =: CrearCompraController.getAccount().id AND ERPVS__Comprobante_Venta__r.Oportunidad__r.RecordType.DeveloperName = 'Sembra_Evolucion' AND ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName in ('Facturada', 'Parcialmente Facturada', 'Pagada', 'Parcialmente Pagada', 'Cancelada por NC') AND ERPVS__Comprobante_Venta__r.erpvs__tipo_comp__c = 'Factura' order by ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c desc];
        return [select ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Cuenta_Productor__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Name, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Nombre_Cultivo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Comercio__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.N_CUIT__c, ERPVS__Comprobante_Venta__r.ERPvs__Comprobante__c, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Nombre_Obtentor__c, ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c, ERPvs__Fecha_Vencimiento__c, ERPVS__Comprobante_Venta__r.ERPvs__Moneda__r.Name, ERPVS__Comprobante_Venta__r.ERPvs__Total__c, ERPvs__Importe_MO_x_Signo__c, ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName  from ERPvs__Vencimientos__c where ERPvs__Cuenta__c =: CrearCompraController.getAccount().id AND ERPVS__Comprobante_Venta__r.Oportunidad__r.RecordType.DeveloperName = 'Sembra_Evolucion' AND ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName in ('Facturada', 'Parcialmente Facturada', 'Pagada', 'Parcialmente Pagada', 'Cancelada por NC') AND ERPVS__Comprobante_Venta__r.erpvs__tipo_comp__c = 'Factura' order by ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c desc];
    }

    

    public static List<Opportunity> queryOportunidades(String type){
        System.debug('queryOportunidades type: ' + CrearCompraController.getAccount().Id );
        if(Test.isRunningTest()) return oppsTest;
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
        List<ERPvs__Vencimientos__c> vencimientos = queryVencimientos(type);
        List<Vencimiento> results = new List<Vencimiento>();
        List<Id> cvIds = new List<Id>();
        Map<Id, ERPvs__Tipo_de_cambio__c> monedaToTipoDeCambio = new Map<Id, ERPvs__Tipo_de_cambio__c>();
        Set<Id> vencimientosIds = new Set<Id>();

        for (ERPvs__Vencimientos__c vencimiento: vencimientos) {
            results.add(new Vencimiento(vencimiento));
            cvIds.add(vencimiento.ERPVS__Comprobante_Venta__c);
            monedaToTipoDeCambio.put(vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c, null);
            vencimientosIds.add(vencimiento.Id);
        }

        for (Id moneda: monedaToTipoDeCambio.keySet()) {
            ERPvs__Tipo_de_cambio__c cambio = Test.isRunningTest() ? tipoCambioTest : [select Erpvs__Vendedor__c from ERPvs__Tipo_de_cambio__c where ERPvs__Moneda__c =: moneda and Erpvs__Fecha__c <=: System.today() order by Erpvs__Fecha__c desc limit 1];
            monedaToTipoDeCambio.put(moneda, cambio);
        }

        Map<Id,EstadoDeCuentaAuraService.File> filesByCv = new Map<Id,EstadoDeCuentaAuraService.File>();

        for(Attachment at : Test.isRunningTest() ? attachmentsTest : [SELECT Id, ParentId, Body, Name, ContentType FROM Attachment WHERE ParentId IN :cvIds AND Name LIKE 'Factura%']){
            filesByCv.put(at.ParentId, new EstadoDeCuentaAuraService.File(at));
        }

        // Map<Id, String> mapLinksDePago = new Map<Id, String>();
        // for(Link_de_Pago__c link : [SELECT Url__c, Vencimiento__c FROM Link_de_Pago__c WHERE Vencimiento__c IN :vencimientosIds AND Estado__c = 'Creado' AND Expiration_Date__c <= :Date.today()]){
        //     mapLinksDePago.put(link.Vencimiento__c, link.Url__c);
        // }

        for (Vencimiento vencimiento: results) {
            vencimiento.file = filesByCv.get(vencimiento.comprobanteId);
            if (!Test.isRunningTest()) vencimiento.saldoArs *= monedaToTipoDeCambio.get(vencimiento.monedaId).Erpvs__Vendedor__c;
            //vencimiento.linkDePago = mapLinksDePago.get(vencimiento.id);
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
                Vencimiento v = new Vencimiento(opp);
                v.facturaPVId = mapArchivos.get(mapFileNames.get(opp.Id));
                System.debug(v.facturaPVId);
                results.add(v);
            }
        }

        return results;
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
            comprobanteId = vencimiento.ERPVS__Comprobante_Venta__c;
            numero = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__Comprobante__c;
            obtentorId = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__c;
            obtentor = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Name;
            fecha = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__Fecha__c;
            fechaVencimiento = vencimiento.ERPvs__Fecha_Vencimiento__c;
            moneda = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__r.Name;
            monedaId = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c;
            total = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__Total__c;
            saldo = vencimiento.ERPvs__Importe_MO_x_Signo__c;
            saldoArs = vencimiento.ERPvs__Importe_MO_x_Signo__c;
            id = vencimiento.id;
            cuit = CrearCompraController.getAccount().N_CUIT__c;
            opportunityId = vencimiento.ERPVS__Comprobante_Venta__r.Oportunidad__c;
            pagarDisabled = vencimiento.ERPvs__Importe_MO_x_Signo__c <= 0;
            productor = vencimiento.ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Cuenta_Productor__r.Name;
            comercio = vencimiento.ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Comercio__r.Name;
            cultivo = vencimiento.ERPVS__Comprobante_Venta__r.Oportunidad__r.Compra_HT__r.Nombre_Cultivo__c;
            obtentorMarca = vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__r.Nombre_Obtentor__c;
            oppStage = vencimiento.ERPVS__Comprobante_Venta__r.Oportunidad__r.StageName;
            cuentaName = CrearCompraController.getAccount().Name;
        }

        public Vencimiento(Opportunity opp){
            numero = 'Factura ' + (opp.N_de_Comprobante__c ?? '');
            obtentor = opp.Obtentor__r.Name;
            obtentorId = opp.Obtentor__c;
            fecha = opp.Fecha_Emision_Comprobante__c;
            fechaVencimiento = opp.Fecha_Vencimiento_Comprobante__c;
            moneda = opp.Moneda__r.Name;
            monedaId = opp.Moneda__c;
            total = opp.Total_Comprobante__c;
            saldo = opp.Saldo_a_Cobrar_Comprobante__c;
            saldoArs = opp.Saldo_Actualizado__c;
            pagarDisabled = true;
            productor = opp.Compra_HT__r.Cuenta_Productor__r.Name;
            comercio = opp.Compra_HT__r.Comercio__r.Name;
            opportunityId = opp.Id;
            oppStage = opp.StageName;
            cultivo = opp.Cultivo__c;
            obtentorMarca = opp.Obtentor__r.Nombre_Obtentor__c;
            cuit = opp.CUIT__c;
            cuentaName = opp.Account.Name;
        }
    }
}