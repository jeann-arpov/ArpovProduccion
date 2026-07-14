public  class EnviarEmailVencimiento {
    @InvocableMethod(label='Envio de Emails por Vencimientos' description='Envia emails con la plantilla y attachment de la factura a los vencimientos correspondientes' category='ERPvs__Vencimientos__c')
    public static void envioMails(List<Id> scope) {
        BatchApexCVsEnviarEmails.envioMails([select Name, ERPvs__Cliente__c, ERPvs__Empresa_Sucursal__c FROM ERPvs__Comprobante_Venta__c WHERE ERPvs__Empresa_Sucursal__c =: UtilsMovimientoFondo.parametro.Punto_de_Venta_cyo_SE__c and id in (select ERPvs__Comprobante_Venta__c from ERPvs__Vencimientos__c where id in: scope and ERPvs__Importe_MO_x_Signo__c > 0)], false, 'FE Productores SE a vencer');
    }
}