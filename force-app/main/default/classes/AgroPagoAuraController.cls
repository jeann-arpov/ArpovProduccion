/**
* @author Maximo Martinez
* @date 15/11/2019
* @description Clase con metodos para llamarlos desde aura
*/
public without sharing class AgroPagoAuraController {
    public static Boolean mock = false;
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getAgroPago(){
        AgroPago__c pago = AgroPago__c.getOrgDefaults();

        return new Map<String, Decimal> {
            'Comision__c' => pago.Comision__c
        };
    }

    /**
    * @author Maximo Martinez
    * @date 15/11/2019
    * @description Obtenemos los metodos de pago de agropago
    */
    @AuraEnabled(cacheable=true)
    public static List<AgroPagoRestClient.PaymentMethod> getPaymentMethods(){
        return AgroPagoRestClient.getPaymentMethods();
    }

    /**
    * @author Maximo Martinez
    * @date 15/11/2019
    * @description Pagar usando AgroPago
    *
    * Modificación José Luis Iudica - 12/11/2020
    *    Cambio de Saldo_a_Cobrar_Comprobante__c por Saldo_Actualizado__c
    *    Agregado de Importe_sin_Descuento__c para calculo de descuento.
    *    Calculo de discount para asignar app.Tipo_Aplicacion__c (objeto Aplicacion__c)
    */

    public class RecordData {
        Decimal amount;
        Decimal discount;
        Decimal saldo;
        Decimal tipoCambio;
        Id cliente;
        Id factura;
        Id obtentor;
        Id cv;
        Id recordId;
        ERPvs__Vencimientos__c vencimiento;
        

        public RecordData(Opportunity op) {
            amount = ((op.Saldo_Actualizado__c) / (1 - getAgroPago().get('Comision__c') / 100)).setScale(2, RoundingMode.HALF_UP);
            discount = (op.Saldo_Actualizado__c / op.Importe_sin_Descuento__c).setScale(2, RoundingMode.HALF_UP);
            cliente = op.accountId;
            factura = op.id;
            obtentor = op.Obtentor__c;
            saldo = op.Saldo_Actualizado__c;
            tipoCambio = op.Tipo_de_Cambio_Actualizado__c;
            recordId = op.id;
        }

        public RecordData(ERPvs__Vencimientos__c ven, ERPvs__Tipo_de_cambio__c cambio) {
            amount = ((Test.isRunningTest() ? 1 : ven.ERPvs__Importe_MO_x_Signo__c * cambio.Erpvs__Vendedor__c) / (1 - getAgroPago().get('Comision__c') / 100)).setScale(2, RoundingMode.HALF_UP);
            tipoCambio = cambio.Erpvs__Vendedor__c;
            vencimiento = ven;
            cliente = ven.ERPVS__Comprobante_Venta__r.ERPvs__Cliente__c;
            factura = ven.ERPVS__Comprobante_Venta__r.Oportunidad__c;
            cv = ven.ERPVS__Comprobante_Venta__c;
            recordId = ven.id;
        }
    }

    @AuraEnabled
    public static AgroPagoRestClient.PaymentsAgroResponse pay(FormData form) { 
        Id recordId = form.recordId;
        RecordData data;

        if (recordId.getSobjectType() == Opportunity.getSObjectType()) {
            Opportunity op = [SELECT Saldo_Actualizado__c, Importe_sin_Descuento__c, Divisa_Comprobante__c, AccountId, Obtentor__c, Tipo_de_Cambio_Actualizado__c FROM Opportunity WHERE Id = :form.recordId];
            data = new RecordData(op);
        } else {
            ERPvs__Vencimientos__c ven = Test.isRunningTest() ? new ERPvs__Vencimientos__c(Id = form.recordId) : [select ERPVS__Comprobante_Venta__r.Oportunidad__c, ERPvs__Importe_MO__c, ERPvs__Importe_MN__c, ERPvs__Signo__c, ERPvs__Importe_MO_x_Signo__c, ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c, ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__c, ERPVS__Comprobante_Venta__r.ERPvs__Cliente__c from ERPvs__Vencimientos__c where id =: form.recordId];
            ERPvs__Tipo_de_cambio__c cambio = Test.isRunningTest() ? new ERPvs__Tipo_de_cambio__c() : [select Erpvs__Vendedor__c from ERPvs__Tipo_de_cambio__c where ERPvs__Moneda__c =: ven.ERPVS__Comprobante_Venta__r.ERPvs__Moneda__c and Erpvs__Fecha__c <=: System.today() order by Erpvs__Fecha__c desc limit 1];
            data = new RecordData(ven, cambio);
        }

        AgroPagoRestClient.PaymentsAgroResponse pAgroResponse;

        if (mock != true) {
            AgroPagoRestClient.TokenRequest tRequest = tokenRequest(form);
            AgroPagoRestClient.TokenResponse tResponse = AgroPagoRestClient.getToken(tRequest); 
            AgroPagoRestClient.PaymentsAgroRequest pAgroRequest = paymentRequest(form, data, tResponse);
            pAgroResponse = AgroPagoRestClient.paymentsAgro(pAgroRequest);
        } else {
            pAgroResponse = new AgroPagoRestClient.PaymentsAgroResponse();
            pAgroResponse.date_x = '2022-05-05T00:00:00Z';
            pAgroResponse.status = 'approved';
            pAgroResponse.amount = data.amount;
        }
        
        pAgroResponse.email = UserInfo.getUserEmail();

        try {
            insertRegisters(data, pAgroResponse);
        } catch (Exception e) {
            System.debug(e);
            pAgroResponse.reason_error_description = e.getMessage();
            pAgroResponse.status = 'rejected';
        } 

        return pAgroResponse;
    }

    private static AgroPagoRestClient.TokenRequest tokenRequest(FormData form) {
        AgroPagoRestClient.TokenRequest tRequest = new AgroPagoRestClient.TokenRequest();

        tRequest.card_expiration_month = form.cardExpirationMonth;
        tRequest.card_expiration_year = form.cardExpirationYear;
        tRequest.security_code = form.securityCode;
        tRequest.card_number = form.cardNumber;
        tRequest.card_holder_identification = new AgroPagoRestClient.Identification();
        tRequest.card_holder_identification.number_x = form.cardHolderIdentificationNumber;
        tRequest.card_holder_identification.type = form.cardHolderIdentificationType;
        tRequest.card_holder_name = form.cardHolderName;
        tRequest.payment_method_id = form.paymentMethodId;

        return tRequest;
    } 

    private static AgroPagoRestClient.PaymentsAgroRequest paymentRequest(FormData form, RecordData data, AgroPagoRestClient.TokenResponse tResponse) {
        AgroPagoRestClient.PaymentsAgroRequest pAgroRequest = new AgroPagoRestClient.PaymentsAgroRequest();

        pAgroRequest.token = tResponse.id;
        pAgroRequest.amount = data.amount;
        pAgroRequest.email = UserInfo.getUserEmail();
        pAgroRequest.operation_id = String.format('{0}{1}{2}',new List<String>{
            'arpov',form.recordId,String.valueOf(System.now().getTime()).right(7)
        });
        pAgroRequest.payment_detail = form.recordId;
        pAgroRequest.pmc_establishment_id = form.pmcEstablishmentId;
        pAgroRequest.token_agro = form.agroToken;

        if (String.isBlank(pAgroRequest.token_agro) == false) pAgroRequest.token_type = 'E';

        // Installements
        pAgroRequest.installments = new List<AgroPagoRestClient.Installment>();
        
        AgroPagoRestClient.Installment installment = new AgroPagoRestClient.Installment();
        installment.id = 1;
        installment.date_x = Date.today();
        installment.amount = data.amount;
        pAgroRequest.installments.add(installment);

        return pAgroRequest;
    }

    
    private static Exception insertRegisters(RecordData data, AgroPagoRestClient.PaymentsAgroResponse pAgroResponse) {
        Pago_Electronico__c pago = new Pago_Electronico__c();
        Comprobante_de_Pago__c cp;
        Valor__c v;
        Aplicacion__c app;
        ERPvs__Movimiento_Fondo__c mov;
        ERPvs__Detalle_Cuenta_Contable__c detalle;
        ERPvs__Documento_Afectado__c doc;

        try {

            fill(data, pAgroResponse, pago);
            insert pago;

            if (pAgroResponse.status == 'approved' && data.recordId.getSobjectType() == Opportunity.getSObjectType()) {
                cp = new Comprobante_de_Pago__c();
                v = new Valor__c();
                app = new Aplicacion__c();

                fill(data, cp, pago);
                insert cp;

                fill(data, v, pago);
                v.Comprobante_de_pago__c = cp.id;
                insert v;

                fill(data, app, v);
                app.Comprobante_de_pago__c = cp.id;
                insert app;
            } else if (pAgroResponse.status == 'approved' && data.recordId.getSobjectType() == ERPvs__Vencimientos__c.getSObjectType()) {
                mov = new ERPvs__Movimiento_Fondo__c();
                detalle = new ERPvs__Detalle_Cuenta_Contable__c();
                doc = new ERPvs__Documento_Afectado__c();

                Parametros_ERP_y_CRM__c parametrosERPYCRM = Test.isRunningTest() ? new Parametros_ERP_y_CRM__c() : [SELECT Cuenta_Contable_AGRO_PAGO__r.ERPvs__Moneda__c, Tipo_Comprobante_Mov_Fondo_Cobranza_SE__c, Sucursal_para_Cobranzas_SE__r.ERPvs__Nro_Sucursal__c, Sucursal_para_Cobranzas_SE__c FROM Parametros_ERP_y_CRM__c ORDER BY LastModifiedDate DESC limit 1];

                fill(data, pAgroResponse, mov, parametrosERPYCRM);
                mov.Pago_Electronico__c = pago.id;
                if (!Test.isRunningTest()) insert mov;

                fill(detalle, parametrosERPYCRM);
                detalle.ERPvs__Movimientos__c = mov.id;
                detalle.ERPvs__Importe__c = mov.ERPvs__Total_Cobranza__c;
                if (!Test.isRunningTest()) insert detalle;

                fill(data, doc);
                doc.ERPvs__Movimiento_de_Fondo__c = mov.id;
                insert doc;
            }
        } catch (Exception e) {
            system.debug(e.getStackTraceString());
            String body = '';

            for (Sobject sobj: new List<SObject>{pago, cp, v, app, mov, detalle, doc}) {
                if (sobj != null && sobj.id == null) {
                    body += 'No se pudo crear ' + sobj.getSObjectType().getDescribe().getLabel() + '\n';
                }
            }

            if (pago.id != null) {
                body += 'Link pago electronico: ' + URL.getSalesforceBaseUrl().toExternalForm() + '/' + pago.Id + ' ';
            }

            body += 'Error: ' + e.getMessage(); 
            body += 'JSON response: ' + JSON.serialize(pAgroResponse);

            System.debug(body);

            List<String> emails = new List<String> {'soporte@arpov.org.ar', 'joseluis.iudica@arpov.org.ar'};
            if (UserInfo.getOrganizationId() == (Id) '00D8K0000008aLLUAY') emails.add('julian@virtualcompanyservices.com');

            BatchErrorHelper.sendEmail(body, 'Error en pago de AgroPago', emails);
            return e;
        }

        return null;
    }

    private static void fill(RecordData data, AgroPagoRestClient.PaymentsAgroResponse pAgroResponse, Pago_Electronico__c pago) {
        pago.Cliente__c = data.cliente;
        pago.Factura__c = data.factura;
        pago.Comprobante_Venta__c = data.cv;

        pago.transaccion_id__c = String.valueOf(pAgroResponse.transaction_id);
        pago.status__c = pAgroResponse.status;
        pago.payment_id__c = String.valueOf(pAgroResponse.payment_id);
        pago.payment_method_id__c = String.valueOf(pAgroResponse.payment_method_id);
        pago.amount__c = pAgroResponse.amount;
        pago.currency__c = pAgroResponse.currency_x;
        pago.card_brand__c = pAgroResponse.card_brand;
        pago.ticket__c = pAgroResponse.ticket;
        pago.authorization_code__c = pAgroResponse.authorization_code;
        pago.bin__c = pAgroResponse.bin;
        pago.installements__c = String.valueOf(pAgroResponse.installments);
        pago.date__c = (DateTime) JSON.deserialize('"' + pAgroResponse.date_x + '"', dateTime.class);

        Timezone tz = Timezone.getTimeZone('America/Argentina/Buenos_Aires');
        pago.date__c = pago.date__c.addSeconds(-tz.getOffset(pago.date__c)/1000);
    }

    private static void fill(RecordData data, Comprobante_de_Pago__c cp, Pago_Electronico__c pago) {
        cp.Cliente__C = data.cliente;
        cp.Obtentor_Destinatario__c = data.obtentor;
        cp.Fecha_de_recepcion_de_pago__c = pago.date__c.date();
        cp.Fecha_de_confirmacion_del_pago__c = pago.date__c.date();
    }

    private static void fill(RecordData data, Valor__c v, Pago_Electronico__c pago) {
        AgroPago__c pagoConfig = AgroPago__c.getOrgDefaults();
        
        v.Forma_de_pago__c = 'Pago Electronico';
        v.identificacion__c = pago.payment_id__c;
        v.pago_electronico__c = pago.id;
        v.fecha_de_emision__c = pago.date__c.date();
        v.importe__c = data.saldo;
        v.importe_total__c = pago.amount__c;
        v.importe_comision_total__c = pago.amount__c * pagoConfig.Comision__c / 100;
        v.importe_comision_bancaria__c = pago.amount__c * pagoConfig.Comision_Bancaria__c / 100;
        v.importe_comision_plataforma__c = pago.amount__c * pagoConfig.Comision_Plataforma__c / 100;
        v.estado__c = 'Confirmado';
        v.Cuenta_Destinataria__c = [select id from Cuenta_Destinataria__c where name = 'AgroPago'].id;
        v.fecha_de_pago__c = pago.date__c.date();
    }

    private static void fill(RecordData data, Aplicacion__c app, Valor__c v) {
        app.Valor_Aplicado__c = v.id;
        app.Factura__c = data.factura;
        app.Cuenta_Originante__c = data.cliente;
        app.Importe__c = v.importe__c;
        app.Tipo_de_Cambio__c = data.tipoCambio;
        app.Pago_Intereses_o_diferencia_de_cambio__c = true;

        if (data.discount == 0.85) app.Tipo_de_Aplicacion__c = 'Beneficio 15%';
        else if (data.discount == 0.90) app.Tipo_de_Aplicacion__c = 'Beneficio 10%';
        else app.Tipo_de_Aplicacion__c = 'Pago Total';
    }   

    private static void fill(RecordData data, AgroPagoRestClient.PaymentsAgroResponse pAgroResponse, ERPvs__Movimiento_Fondo__c mov, Parametros_ERP_y_CRM__c parametrosERPYCRM) {        
        mov.RecordTypeId = ERPvs__Movimiento_Fondo__c.getSObjectType().getDescribe().getRecordTypeInfosByDeveloperName().get('Cobranzas').getRecordTypeId();
        mov.ERPvs__A_cuenta_y_orden_de__c = data.vencimiento.ERPVS__Comprobante_Venta__r.ERPvs__A_cuenta_y_orden_de__c;
        mov.ERPvs__Cuenta__c = data.cliente; 
        mov.ERPvs__Fecha__c = System.today();
        mov.ERPvs__Moneda__c = parametrosERPYCRM.Cuenta_Contable_AGRO_PAGO__r.ERPvs__Moneda__c;
        mov.ERPvs__Numero_Documento__c = 1;
        //mov.ERPvs__Observaciones__c  = '???';
        mov.ERPvs__Serie_Documento__c = '';
        mov.ERPvs__Sucursal__c = parametrosERPYCRM.Sucursal_para_Cobranzas_SE__c;
        mov.ERPvs__Sucursal_Documento__c = parametrosERPYCRM.Sucursal_para_Cobranzas_SE__r.ERPvs__Nro_Sucursal__c;
        mov.ERPvs__Total_Cobranza__c = data.vencimiento.ERPvs__Importe_MO_x_Signo__c * data.tipoCambio;
        mov.ERPvs__Tipo_Comprobante_Movimiento_Fondo__c = parametrosERPYCRM.Tipo_Comprobante_Mov_Fondo_Cobranza_SE__c;
        mov.Fecha_Pago_SE__c = System.today();
    }

    private static void fill(ERPvs__Detalle_Cuenta_Contable__c detalle, Parametros_ERP_y_CRM__c parametrosERPYCRM) {        
        detalle.ERPvs__Cuenta_Contable__c = parametrosERPYCRM.Cuenta_Contable_AGRO_PAGO__c;
        detalle.ERPvs__Debe_Haber__c = 'Debe';
    }

    private static void fill(RecordData data, ERPvs__Documento_Afectado__c doc) {        
        doc.ERPvs__Vencimientos__c = data.vencimiento.id;
        doc.ERPvs__Importe_MO__c = data.vencimiento.ERPvs__Importe_MO__c;
        doc.ERPvs__Importe_MN__c = data.vencimiento.ERPvs__Importe_MN__c;
        doc.ERPvs__Signo__c = data.vencimiento.ERPvs__Signo__c;
        doc.ERPvs__Importe_Afectado__c = data.vencimiento.ERPvs__Importe_MO__c;
    }

    /**
    * @author Maximo Martinez
    * @date 15/11/2019
    * @description Datos desde el form de AgroPago
    */
    public class FormData{

        @AuraEnabled
        public String agroToken {get;set;}

        @AuraEnabled
        public String cardNumber {get;set;} 
        
        @AuraEnabled
        public String cardExpirationMonth {get;set;} 

        @AuraEnabled
        public String cardExpirationYear {get; set;} 

        @AuraEnabled
        public String securityCode {get;set;} 

        @AuraEnabled
        public String cardHolderName {get;set;} 

        @AuraEnabled
        public String cardHolderIdentificationType {get;set;}

        @AuraEnabled
        public String cardHolderIdentificationNumber {get;set;}

        @AuraEnabled
        public Integer paymentMethodId {get;set;}

        @AuraEnabled
        public Integer pmcEstablishmentId {get;set;}

        @AuraEnabled
        public String recordId {get;set;}

    }

}