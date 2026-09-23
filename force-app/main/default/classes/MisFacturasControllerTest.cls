@isTest
public class MisFacturasControllerTest {
  public static testMethod void main() {
    Account obtentor = Test_TestUtils.crearObtentor();

    MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>{
      new ERPvs__Vencimientos__c()
    };
    MisFacturasController.tipoCambioTest = new ERPvs__Tipo_de_cambio__c(
      Erpvs__Vendedor__c = 1
    );
    MisFacturasController.attachmentsTest = new List<Attachment>{
      new Attachment(Body = Blob.valueOf('test'))
    };
    MisFacturasController.oppsTest = new List<Opportunity>{
      new Opportunity(
        Id = '0068K000006KW5rQAG',
        Tipo_de_Comprobante__c = 'FC',
        N_de_Comprobante__c = 'A-0004-00000017'
      )
    };

    List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos(
      'Productor'
    );

    System.assertEquals(2, vencimientos.size());
  }

  @isTest
  static void alreadyListed_porOportunidadONumero() {
    Id oppId = '0068K000006KW5rQAG';
    Opportunity opp = new Opportunity(
      Id = oppId,
      Tipo_de_Comprobante__c = 'FC',
      N_de_Comprobante__c = 'A 1004-00002483'
    );

    System.assertEquals(
      true,
      MisFacturasController.alreadyListed(
        new Set<Id>{ oppId },
        new Set<String>(),
        opp
      ),
      'No debe repetir una factura que ya vino del vencimiento ERP de la misma oportunidad'
    );

    System.assertEquals(
      true,
      MisFacturasController.alreadyListed(
        new Set<Id>(),
        new Set<String>{ 'A100400002483' },
        opp
      ),
      'No debe repetir el mismo nro de comprobante aunque el formato difiera'
    );

    Opportunity otra = new Opportunity(
      Id = '0068K000006KW5sQAG',
      Tipo_de_Comprobante__c = 'FC',
      N_de_Comprobante__c = 'A-0261-00007867'
    );
    System.assertEquals(
      false,
      MisFacturasController.alreadyListed(
        new Set<Id>{ oppId },
        new Set<String>{ 'A100400002483' },
        otra
      ),
      'Una factura distinta se sigue mostrando'
    );

    System.assertEquals(
      false,
      MisFacturasController.alreadyListed(null, null, null)
    );
    System.assertEquals(
      false,
      MisFacturasController.alreadyListed(new Set<Id>(), new Set<String>(), opp)
    );
  }

  @isTest
  static void getVencimientos_aceptaOportunidadSinRelaciones() {
    Account obtentor = Test_TestUtils.crearObtentor();
    MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>();
    MisFacturasController.tipoCambioTest = null;
    MisFacturasController.attachmentsTest = new List<Attachment>();
    MisFacturasController.oppsTest = new List<Opportunity>{
      new Opportunity(
        Id = '0068K000006KW5rQAG',
        Tipo_de_Comprobante__c = 'FC',
        N_de_Comprobante__c = 'A-0001-00000001'
      )
    };

    List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos(
      'Productor'
    );

    System.assertEquals(1, vencimientos.size());
    System.assertEquals('Factura A-0001-00000001', vencimientos[0].numero);
  }

  @isTest
  static void normalizeNumero_ignoraPrefijoYSeparadores() {
    System.assertEquals(
      'A100400002483',
      MisFacturasController.normalizeNumeroComprobante(
        'Factura A 1004-00002483'
      )
    );
    System.assertEquals(
      'A100400002483',
      MisFacturasController.normalizeNumeroComprobante('A-1004-00002483')
    );
    System.assertEquals(
      '',
      MisFacturasController.normalizeNumeroComprobante(null)
    );
    System.assertEquals(
      '',
      MisFacturasController.normalizeNumeroComprobante('   ')
    );
    System.assertEquals(
      'A100400003327',
      MisFacturasController.normalizeNumeroComprobante(
        'Factura A 1004-00003327'
      )
    );
    System.assertEquals(
      'A100400003327',
      MisFacturasController.normalizeNumeroComprobante(
        'Factura A-1004-00003327'
      )
    );
  }

  @isTest
  static void getVencimientos_noDuplicaMismaFactura() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Id oppId = '0068K000006KW5rQAG';

    // JSON.deserialize permite hidratar campos no editables (nro comprobante ERP)
    ERPvs__Comprobante_Venta__c cv = (ERPvs__Comprobante_Venta__c) JSON.deserialize(
      '{"attributes":{"type":"ERPvs__Comprobante_Venta__c"},' +
        '"Oportunidad__c":"' +
        oppId +
        '",' +
        '"ERPvs__Comprobante__c":"Factura A 1004-00002483",' +
        '"ERPvs__Total__c":2566.8,' +
        '"Oportunidad__r":{"attributes":{"type":"Opportunity"},"StageName":"Pagada"}}',
      ERPvs__Comprobante_Venta__c.class
    );

    ERPvs__Vencimientos__c ven = (ERPvs__Vencimientos__c) JSON.deserialize(
      '{"attributes":{"type":"ERPvs__Vencimientos__c"},' +
        '"ERPVS__Comprobante_Venta__c":"a0B000000000001AAA",' +
        '"ERPvs__Importe_MO_x_Signo__c":0}',
      ERPvs__Vencimientos__c.class
    );
    ven.putSObject('ERPVS__Comprobante_Venta__r', cv);

    MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>{
      ven
    };
    MisFacturasController.tipoCambioTest = new ERPvs__Tipo_de_cambio__c(
      Erpvs__Vendedor__c = 1
    );
    MisFacturasController.attachmentsTest = new List<Attachment>();
    MisFacturasController.oppsTest = new List<Opportunity>{
      new Opportunity(
        Id = oppId,
        Tipo_de_Comprobante__c = 'FC',
        N_de_Comprobante__c = 'A-1004-00002483'
      ),
      new Opportunity(
        Id = '0068K000006KW5sQAG',
        Tipo_de_Comprobante__c = 'FC',
        N_de_Comprobante__c = 'A-0261-00007867'
      )
    };

    List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos(
      'Productor'
    );

    System.assertEquals(
      2,
      vencimientos.size(),
      'Deduplica la misma FC ERP+Opp y deja la factura distinta'
    );
    Set<String> numeros = new Set<String>();
    for (MisFacturasController.Vencimiento v : vencimientos) {
      numeros.add(MisFacturasController.normalizeNumeroComprobante(v.numero));
    }
    System.assertEquals(true, numeros.contains('A100400002483'));
    System.assertEquals(true, numeros.contains('A026100007867'));
  }

  @isTest
  static void getVencimientos_cubreQueriesSoqlYComercio() {
    Account obtentor = Test_TestUtils.crearObtentor();
    MisFacturasController.vencimientosTest = null;
    MisFacturasController.oppsTest = null;
    MisFacturasController.attachmentsTest = null;
    MisFacturasController.tipoCambioTest = null;

    List<MisFacturasController.Vencimiento> productor = MisFacturasController.getVencimientos(
      'Productor'
    );
    List<MisFacturasController.Vencimiento> comercio = MisFacturasController.getVencimientos(
      'Comercio'
    );

    System.assertNotEquals(null, productor);
    System.assertNotEquals(null, comercio);
  }

  @isTest
  static void getVencimientos_oppConRelaciones() {
    Account obtentor = Test_TestUtils.crearObtentor();
    MisFacturasController.vencimientosTest = new List<ERPvs__Vencimientos__c>();
    MisFacturasController.attachmentsTest = new List<Attachment>();
    MisFacturasController.tipoCambioTest = new ERPvs__Tipo_de_cambio__c(
      Erpvs__Vendedor__c = 1
    );

    Opportunity opp = (Opportunity) JSON.deserialize(
      '{"attributes":{"type":"Opportunity"},' +
        '"Id":"0068K000006KW5rQAG",' +
        '"Tipo_de_Comprobante__c":"FC",' +
        '"N_de_Comprobante__c":"A-1004-00003327",' +
        '"StageName":"Facturada",' +
        '"Cultivo__c":"TRIGO",' +
        '"CUIT__c":"30509292120",' +
        '"Total_Comprobante__c":2566.8,' +
        '"Saldo_a_Cobrar_Comprobante__c":2566.8,' +
        '"Saldo_Actualizado__c":1000,' +
        '"Obtentor__r":{"attributes":{"type":"Account"},"Name":"NIDERA","Nombre_Obtentor__c":"NIDERA"},' +
        '"Moneda__r":{"attributes":{"type":"ERPvs__Moneda__c"},"Name":"USD"},' +
        '"Account":{"attributes":{"type":"Account"},"Name":"TALCUAL"},' +
        '"Compra_HT__r":{"attributes":{"type":"Compra_HT__c"},' +
        '"Cuenta_Productor__r":{"attributes":{"type":"Account"},"Name":"PROD"},' +
        '"Comercio__r":{"attributes":{"type":"Account"},"Name":"COM"}}}',
      Opportunity.class
    );
    MisFacturasController.oppsTest = new List<Opportunity>{ opp };

    List<MisFacturasController.Vencimiento> vencimientos = MisFacturasController.getVencimientos(
      'Productor'
    );
    System.assertEquals(1, vencimientos.size());
    System.assertEquals('TRIGO', vencimientos[0].cultivo);
    System.assertEquals('NIDERA', vencimientos[0].obtentorMarca);
    System.assertEquals('30509292120', vencimientos[0].cuit);
  }
}
