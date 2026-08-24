@isTest
public class MisFacturasControllerTest {
    public static testmethod void main() {
        Account obtentor = Test_TestUtils.crearObtentor();

        MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>{new ERPvs__Vencimientos__c()};
        MisFacturasController.tipoCambioTest = new ERPvs__Tipo_de_cambio__c(Erpvs__Vendedor__c = 1);
        MisFacturasController.attachmentsTest = new List<Attachment>{new Attachment(Body = Blob.valueOf('test'))};
        MisFacturasController.oppsTest = new List<Opportunity>{new Opportunity(Id = '0068K000006KW5rQAG', Tipo_de_Comprobante__c = 'FC', N_de_Comprobante__c = 'A-0004-00000017')};
        
        List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos('Productor');

        System.assertEquals(2, vencimientos.size());
    }

    @isTest
    static void alreadyListed_porOportunidadONumero() {
        Id oppId = '0068K000006KW5rQAG';
        Opportunity opp = new Opportunity(Id = oppId, Tipo_de_Comprobante__c = 'FC', N_de_Comprobante__c = 'A 1004-00002483');

        System.assertEquals(
            true,
            MisFacturasController.alreadyListed(new Set<Id>{ oppId }, new Set<String>(), opp),
            'No debe repetir una factura que ya vino del vencimiento ERP de la misma oportunidad'
        );

        System.assertEquals(
            true,
            MisFacturasController.alreadyListed(new Set<Id>(), new Set<String>{ 'A100400002483' }, opp),
            'No debe repetir el mismo nro de comprobante aunque el formato difiera'
        );

        Opportunity otra = new Opportunity(Id = '0068K000006KW5sQAG', Tipo_de_Comprobante__c = 'FC', N_de_Comprobante__c = 'A-0261-00007867');
        System.assertEquals(
            false,
            MisFacturasController.alreadyListed(new Set<Id>{ oppId }, new Set<String>{ 'A100400002483' }, otra),
            'Una factura distinta se sigue mostrando'
        );
    }

    @isTest
    static void getVencimientos_aceptaOportunidadSinRelaciones() {
        Account obtentor = Test_TestUtils.crearObtentor();
        MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>();
        MisFacturasController.tipoCambioTest = null;
        MisFacturasController.attachmentsTest = new List<Attachment>();
        MisFacturasController.oppsTest = new List<Opportunity>{
            new Opportunity(Id = '0068K000006KW5rQAG', Tipo_de_Comprobante__c = 'FC', N_de_Comprobante__c = 'A-0001-00000001')
        };

        List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos('Productor');

        System.assertEquals(1, vencimientos.size());
        System.assertEquals('Factura A-0001-00000001', vencimientos[0].numero);
    }

    @isTest
    static void normalizeNumero_ignoraPrefijoYSeparadores() {
        System.assertEquals(
            'A100400002483',
            MisFacturasController.normalizeNumeroComprobante('Factura A 1004-00002483')
        );
        System.assertEquals(
            'A100400002483',
            MisFacturasController.normalizeNumeroComprobante('A-1004-00002483')
        );
    }

    @isTest
    static void getVencimientos_noDuplicaMismaFactura() {
        Account obtentor = Test_TestUtils.crearObtentor();
        Id oppId = '0068K000006KW5rQAG';

        MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>{
            (ERPvs__Vencimientos__c) JSON.deserialize(
                '{"ERPVS__Comprobante_Venta__c":"a0B000000000001AAA","ERPVS__Comprobante_Venta__r":{"Oportunidad__c":"' + oppId + '","ERPvs__Comprobante__c":"Factura A 1004-00002483","Oportunidad__r":{"StageName":"Pagada"}}}',
                ERPvs__Vencimientos__c.class
            )
        };
        MisFacturasController.tipoCambioTest = new ERPvs__Tipo_de_cambio__c(Erpvs__Vendedor__c = 1);
        MisFacturasController.attachmentsTest = new List<Attachment>();
        MisFacturasController.oppsTest = new List<Opportunity>{
            new Opportunity(Id = oppId, Tipo_de_Comprobante__c = 'FC', N_de_Comprobante__c = 'A 1004-00002483')
        };

        List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos('Productor');

        System.assertEquals(1, vencimientos.size(), 'La FC que ya está en ERP no debe repetirse desde Opportunity');
        System.assertEquals('Factura A 1004-00002483', vencimientos[0].numero);
    }
}