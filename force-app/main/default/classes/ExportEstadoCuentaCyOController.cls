public with sharing class ExportEstadoCuentaCyOController {

    public class ExportData {
        @AuraEnabled public List<String> headers { get; set; }
        @AuraEnabled public List<List<String>> rows { get; set; }
    }

    @AuraEnabled
    public static ExportData getEstadoCuenta(Id accountId, Date fechaCreacionDesde, Date fechaCreacionHasta) {
        if (fechaCreacionDesde == null || fechaCreacionHasta == null) {
            throw new AuraHandledException('Debe informar el rango de fechas de creación.');
        }
        if (fechaCreacionDesde > fechaCreacionHasta) {
            throw new AuraHandledException('La fecha desde no puede ser mayor que la fecha hasta.');
        }

        DateTime createdFrom = DateTime.newInstance(fechaCreacionDesde, Time.newInstance(0, 0, 0, 0));
        DateTime createdToExclusive = DateTime.newInstance(fechaCreacionHasta.addDays(1), Time.newInstance(0, 0, 0, 0));

        ExportData result = new ExportData();

        result.headers = new List<String>{
            Account.N_CUIT__c.getDescribe().getLabel(),
            Account.Name.getDescribe().getLabel(),
            Opportunity.Obtentor__c.getDescribe().getLabel(),
            Opportunity.Fecha_Vencimiento_Comprobante__c.getDescribe().getLabel(),
            Opportunity.N_de_Comprobante__c.getDescribe().getLabel(),
            Opportunity.StageName.getDescribe().getLabel(),
            Opportunity.Divisa_Comprobante__c.getDescribe().getLabel(),
            Opportunity.Total_Aplicado_Divisa_Comprobante__c.getDescribe().getLabel(),
            Opportunity.Saldo_a_Cobrar_Comprobante__c.getDescribe().getLabel(),
            Opportunity.Total_Comprobante__c.getDescribe().getLabel()
        };

        List<Opportunity> opps = [
            SELECT
                Account.N_CUIT__c,
                Account.Name,
                Obtentor__r.Name,
                Fecha_Vencimiento_Comprobante__c,
                N_de_Comprobante__c,
                StageName,
                Divisa_Comprobante__c,
                Total_Aplicado_Divisa_Comprobante__c,
                Saldo_a_Cobrar_Comprobante__c,
                Total_Comprobante__c
            FROM Opportunity
            WHERE AccountId = :accountId
            AND CreatedDate >= :createdFrom
            AND CreatedDate < :createdToExclusive
            AND (
                N_de_Comprobante__c LIKE '%-0004-%'
                OR N_de_Comprobante__c LIKE '%-0002-%'
                OR N_de_Comprobante__c LIKE '%-0008-%'
                OR N_de_Comprobante__c LIKE '%-0006-%'
            )
            ORDER BY N_de_Comprobante__c ASC
        ];

        result.rows = new List<List<String>>();
        for (Opportunity opp : opps) {
            List<String> row = new List<String>();
            row.add(safeStr(opp.Account?.N_CUIT__c));
            row.add(safeStr(opp.Account?.Name));
            row.add(safeStr(opp.Obtentor__r?.Name));
            row.add(formatDate(opp.Fecha_Vencimiento_Comprobante__c));
            row.add(safeStr(opp.N_de_Comprobante__c));
            row.add(safeStr(opp.StageName));
            row.add(safeStr(opp.Divisa_Comprobante__c));
            row.add(formatDecimal(opp.Total_Aplicado_Divisa_Comprobante__c));
            row.add(formatDecimal(opp.Saldo_a_Cobrar_Comprobante__c));
            row.add(formatDecimal(opp.Total_Comprobante__c));
            result.rows.add(row);
        }

        return result;
    }

    private static String safeStr(String value) {
        if (value == null) {
            return '';
        }
        return value.replace('"', '""');
    }

    private static String formatDate(Date d) {
        if (d == null) {
            return '';
        }
        return String.valueOf(d.day()).leftPad(2, '0') + '/' +
               String.valueOf(d.month()).leftPad(2, '0') + '/' +
               String.valueOf(d.year());
    }

    private static String formatDecimal(Decimal d) {
        if (d == null) {
            return '';
        }
        return String.valueOf(d.setScale(2));
    }

    @AuraEnabled
    public static void sendEstadoCuentaEmail(Id accountId, Date fechaCreacionDesde, Date fechaCreacionHasta, String email) {
        if (String.isBlank(email)) {
            throw new AuraHandledException('Debe proporcionar un correo electrónico.');
        }

        ExportData data = getEstadoCuenta(accountId, fechaCreacionDesde, fechaCreacionHasta);

        if (data.rows == null || data.rows.isEmpty()) {
            throw new AuraHandledException('No se encontraron comprobantes para enviar.');
        }

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { email });
        mail.setSubject('Estado de Cuenta CyO');

        // Buscar Org-Wide Email Address con display name 'Soporte Arpov'
        List<OrgWideEmailAddress> owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'cobranzas@arpov.org.ar' LIMIT 1];
        if (!owea.isEmpty() && !Test.isRunningTest()) {
            mail.setOrgWideEmailAddressId(owea[0].Id);
        }

        // Adjuntar el archivo PDF
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName('Estado_de_Cuenta_CyO.pdf');
        Blob pdfBlob;
        if (Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('PDF test content');
        } else {
            PageReference pdfPage = Page.ExportEstadoCuentaCyOPdf;
            pdfPage.getParameters().put('accountId', String.valueOf(accountId));
            pdfPage.getParameters().put('fechaDesde', String.valueOf(fechaCreacionDesde));
            pdfPage.getParameters().put('fechaHasta', String.valueOf(fechaCreacionHasta));
            pdfBlob = pdfPage.getContentAsPDF();
        }
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');
        mail.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });

        mail.setPlainTextBody(
            'Estimado/a,' + '\n' +
            'Por medio del presente, le remitimos adjunto el estado de cuenta actualizado.' + '\n' +
            'Quedamos a su disposición para cualquier consulta o aclaración que considere necesaria.' + '\n' +
            'Saludos cordiales.' + '\n' +
            'ArPOV.'+ '\n' +
            ' '+ '\n' 
        );

        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}