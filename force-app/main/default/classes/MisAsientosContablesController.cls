public without sharing class MisAsientosContablesController {
    @testVisible private static List<ERPvs__Asientos_Contables__c> asientosTest;
    @testVisible private static List<Attachment> attachmentsTest;

    @AuraEnabled
    public static Map<String, Object> getData(Date desde, Date hasta) {
        Id accId = Test.isRunningTest() ? null : CrearCompraController.getAccount().id;
        List<Asiento> results = new List<Asiento>();
        List<Id> cvIds = new List<Id>();

        Parametros_ERP_y_CRM__c parametro = Test.isRunningTest() ? new Parametros_ERP_y_CRM__c() : [select Tipo_Comprobante_Mov_Fondo_Cobranza_SE__r.ERPvs__Cuenta_Contable__c, Punto_de_Venta_cyo_SE__c from Parametros_ERP_y_CRM__c limit 1];

        for (ERPvs__Asientos_Contables__c asiento: Test.isRunningTest() ? asientosTest : [select ERPVS__Comprobante_Venta__c, ERPvs__Debe__c, ERPvs__Haber__c, ERPvs__Fecha__c, ERPvs__Moneda__r.Name, Comprobante__c, ERPVS__Comprobante_Venta__r.Fecha_Vencimiento__c, ERPvs__Debe_MO__c, ERPvs__Haber_MO__c from ERPvs__Asientos_Contables__c where ERPvs__Cuenta__c =: accId AND ERPvs__Fecha__c >=: desde AND ERPvs__Fecha__c <=: hasta AND (Erpvs__Sucursal_Empresa__c =: parametro.Punto_de_Venta_cyo_SE__c or ERPvs__Cuenta_Contable__c =: parametro.Tipo_Comprobante_Mov_Fondo_Cobranza_SE__r.ERPvs__Cuenta_Contable__c) order by ERPvs__Fecha__c desc]) {
            results.add(new Asiento(asiento));
            cvIds.add(asiento.ERPVS__Comprobante_Venta__c);
        }

        Map<Id,EstadoDeCuentaAuraService.File> filesByCv = new Map<Id,EstadoDeCuentaAuraService.File>();

        for(Attachment at : Test.isRunningTest() ? attachmentsTest : [SELECT Id, ParentId, Body, Name, ContentType FROM Attachment WHERE ParentId IN :cvIds AND Name LIKE 'Factura%']){
            filesByCv.put(at.ParentId, new EstadoDeCuentaAuraService.File(at));
        }

        for (Asiento asiento: results) {
            asiento.file = filesByCv.get(asiento.comprobanteId);
        }

        return new Map<String, Object> {
            'asientos' => results,
            'totales' => [select sum(ERPvs__Debe__c) debe, sum(ERPvs__Haber__c) haber, sum(ERPvs__Debe_MO__c) debeMO, sum(ERPvs__Haber_MO__c) haberMO from ERPvs__Asientos_Contables__c where ERPvs__Cuenta__c =: accId AND (ERPvs__Fecha__c <: desde or ERPvs__Fecha__c >: hasta) AND (Erpvs__Sucursal_Empresa__c =: parametro.Punto_de_Venta_cyo_SE__c or ERPvs__Cuenta_Contable__c =: parametro.Tipo_Comprobante_Mov_Fondo_Cobranza_SE__r.ERPvs__Cuenta_Contable__c)]
        };
    }

    public class Asiento {
        @AuraEnabled public Id id;
        @AuraEnabled public String comprobante;
        Id comprobanteId;
        @AuraEnabled public Datetime fecha;
        @AuraEnabled public Datetime fechaVencimiento;
        @AuraEnabled public String moneda;
        @AuraEnabled public Decimal debeMO;
        @AuraEnabled public Decimal haberMO;
        @AuraEnabled public Decimal debe;
        @AuraEnabled public Decimal haber;
        @AuraEnabled public EstadoDeCuentaAuraService.File file;

        public Asiento(ERPvs__Asientos_Contables__c asiento) {
            id = asiento.id;
            comprobante = asiento.Comprobante__c;
            comprobanteId = asiento.ERPVS__Comprobante_Venta__c;
            fecha = asiento.ERPvs__Fecha__c;
            fechaVencimiento = asiento.ERPVS__Comprobante_Venta__r.Fecha_Vencimiento__c;
            moneda = asiento.ERPvs__Moneda__r.Name;
            debeMO = asiento.ERPvs__Debe_MO__c;
            haberMO = asiento.ERPvs__Haber_MO__c;
            debe = asiento.ERPvs__Debe__c;
            haber = asiento.ERPvs__Haber__c;
        }
    }   
}