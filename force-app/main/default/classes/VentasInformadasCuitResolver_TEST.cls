@IsTest
private class VentasInformadasCuitResolver_TEST {

  @TestSetup
  static void setup() {
    Test_TestUtils.disableFlows();
  }

  @IsTest
  static void resolveUnicaCuentaDevuelveEsa() {
    Account acc = crearObtentor('30616275905', '03');
    List<Account> candidatos = new List<Account>{
      new Account(
        Id = acc.Id,
        N_CUIT__c = '30616275905',
        Type = 'Obtentor',
        RecordType = new RecordType(DeveloperName = 'Obtentor')
      )
    };

    Account res = VentasInformadasCuitResolver.resolveCuentaPorCuit(
      '30616275905',
      null,
      candidatos
    );
    System.assertEquals(acc.Id, res.Id);
  }

  @IsTest
  static void resolveVariasFirmasUsaObtentorComercializa() {
    Account acc03 = crearObtentor('30616275905', '03');
    Account acc85 = crearObtentor('30616275905', '85');

    List<Account> candidatos = new List<Account>{
      stubAccount(acc03.Id, '30616275905'),
      stubAccount(acc85.Id, '30616275905')
    };

    Account res = VentasInformadasCuitResolver.resolveCuentaPorCuit(
      '30616275905',
      acc85.Id,
      candidatos
    );
    System.assertEquals(acc85.Id, res.Id, 'Debe elegir Obtentor Comercializa (85).');
  }

  @IsTest
  static void resolveObtentorComercializaHijoNoEnCandidatos() {
    Account acc03 = crearObtentor('30616275905', '03');
    Account acc85 = crearObtentorHijo(acc03.Id, '30616275905', '85');

    List<Account> candidatos = new List<Account>{
      stubAccount(acc03.Id, '30616275905')
    };

    Account res = VentasInformadasCuitResolver.resolveCuentaPorCuit(
      '30616275905',
      acc85.Id,
      candidatos
    );
    System.assertEquals(acc85.Id, res.Id, 'Debe usar Obtentor Comercializa aunque no esté en candidatos por CUIT.');
  }

  @IsTest
  static void resolveObtentorComercializaNoAplicaSiCuitDistinto() {
    Account acc03 = crearObtentor('30616275905', '03');
    Account acc85 = crearObtentor('30616275905', '85');
    Account productor = new Account(
      Name = 'Productor Test',
      N_CUIT__c = '20144462980',
      Type = 'Productor',
      RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('Productor')
        .getRecordTypeId()
    );
    insert productor;

    Account res = VentasInformadasCuitResolver.resolveCuentaPorCuit(
      '20144462980',
      acc85.Id,
      new List<Account>{
        new Account(
          Id = productor.Id,
          N_CUIT__c = '20144462980',
          Type = 'Productor',
          RecordType = new RecordType(DeveloperName = 'Productor')
        )
      }
    );
    System.assertEquals(productor.Id, res.Id);
  }

  @IsTest
  static void mapObtentorComercializaPorVariedadTest() {
    Account acc85 = crearObtentor('30616275905', '85');
    insert new Variedad__c(
      Name = 'NEO 46S25 SE',
      Cultivar_INASE__c = 'NEO 46S25 SE',
      Obtentor_Comercializa__c = acc85.Id
    );

    Map<String, Id> mapa = VentasInformadasCuitResolver.mapObtentorComercializaPorVariedad(
      new Set<String>{ 'NEO 46S25 SE' }
    );
    System.assertEquals(acc85.Id, mapa.get('NEO 46S25 SE'));
  }

  @IsTest
  static void aplicarRolOriginanteDesdeTypeTest() {
    Ventas_Informadas__c v = new Ventas_Informadas__c();
    Account dist = new Account(
      Type = 'Distribuidor',
      RecordType = new RecordType(DeveloperName = 'Distribuidor')
    );
    VentasInformadasCuitResolver.aplicarRolOriginante(v, dist);
    System.assertEquals('Distribuidor', v.Rol_Originante__c);
  }

  @IsTest
  static void aplicarOriginanteYDestinatarioSeteaRolOriginanteTest() {
    Id rtDist = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Distribuidor')
      .getRecordTypeId();
    Account originante = new Account(
      Name = 'Distribuidor Rol Test',
      N_CUIT__c = '33645022659',
      Type = 'Distribuidor',
      RecordTypeId = rtDist
    );
    Account destinatario = new Account(
      Name = 'Productor Rol Test',
      N_CUIT__c = '20144462980',
      Type = 'Productor',
      RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
        .get('Productor')
        .getRecordTypeId()
    );
    insert new List<Account>{ originante, destinatario };

    Ventas_Informadas__c v = new Ventas_Informadas__c(
      CUIT_Originante__c = '33645022659',
      CUIT_Destinatario__c = '20144462980'
    );

    VentasInformadasCuitResolver.aplicarOriginanteYDestinatario(v, null);

    System.assertEquals(originante.Id, v.Originante__c);
    System.assertEquals('Distribuidor', v.Rol_Originante__c);
    System.assertEquals(destinatario.Id, v.Destinatario__c);
    System.assertEquals('Productor', v.Rol_Destinatario__c);
  }

  @IsTest
  static void agruparCuentasPorCuitUsaClaveNormalizadaTest() {
    Account acc = new Account(
      N_CUIT__c = '20144462980',
      Type = 'Productor',
      RecordType = new RecordType(DeveloperName = 'Productor')
    );
    Map<String, List<Account>> mapa = VentasInformadasCuitResolver.agruparCuentasPorCuit(
      new List<Account>{ acc }
    );
    System.assertEquals(1, mapa.get('20144462980').size());
  }

  @IsTest
  static void aplicarVentaInternaCopiaOriginante() {
    Account acc03 = crearObtentor('30616275905', '03');
    Ventas_Informadas__c v = new Ventas_Informadas__c(
      Venta_Interna__c = true,
      CUIT_Originante__c = '30616275905',
      CUIT_Destinatario__c = '20111111111',
      Originante__c = acc03.Id
    );

    VentasInformadasCuitResolver.aplicarVentaInterna(v);

    System.assertEquals(true, v.Venta_Interna__c);
    System.assertEquals('30616275905', v.CUIT_Destinatario__c);
    System.assertEquals(acc03.Id, v.Destinatario__c);
    System.assertEquals('Productor', v.Rol_Destinatario__c);
    System.assertEquals(acc03.Name, v.Razon_Social_Destinatario__c);
  }

  @IsTest
  static void aplicarVentaInternaSobrescribeRolDistribuidor() {
    Account acc03 = crearObtentor('30616275905', '03');
    Ventas_Informadas__c v = new Ventas_Informadas__c(
      Venta_Interna__c = true,
      CUIT_Originante__c = '30616275905',
      CUIT_Destinatario__c = '30616275905',
      Originante__c = acc03.Id,
      Rol_Destinatario__c = 'Distribuidor'
    );

    VentasInformadasCuitResolver.aplicarVentaInterna(v);

    System.assertEquals('Productor', v.Rol_Destinatario__c);
  }

  @IsTest
  static void aplicarOriginanteYDestinatarioBulkUsaPocasQueries() {
    Account acc85 = crearObtentor('30616275905', '85');
    Id rtProd = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Productor')
      .getRecordTypeId();
    Account productor = new Account(
      Name = 'Productor Bulk',
      N_CUIT__c = '20144462980',
      Type = 'Productor',
      RecordTypeId = rtProd
    );
    insert productor;

    List<Ventas_Informadas__c> ventas = new List<Ventas_Informadas__c>();
    for (Integer i = 0; i < 150; i++) {
      ventas.add(
        new Ventas_Informadas__c(
          CUIT_Originante__c = '30616275905',
          CUIT_Destinatario__c = '20144462980',
          Variedad__c = 'NEO 46S25 SE'
        )
      );
    }

    Integer q0 = Limits.getQueries();
    VentasInformadasCuitResolver.aplicarOriginanteYDestinatarioBulk(
      ventas,
      new Map<String, Id>{ 'NEO 46S25 SE' => acc85.Id }
    );
    Integer qDelta = Limits.getQueries() - q0;

    System.assert(qDelta < 10, 'Bulk debe usar pocas queries SOQL, uso: ' + qDelta);
    System.assertEquals(acc85.Id, ventas[0].Originante__c);
    System.assertEquals(productor.Id, ventas[0].Destinatario__c);
  }

  @IsTest
  static void queryCuentasPorCuitsConGuionesEncuentraPorNormalizado() {
    Id rtProd = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Productor')
      .getRecordTypeId();
    insert new Account(
      Name = 'Productor CUIT Guiones',
      N_CUIT__c = '20144462980',
      Type = 'Productor',
      RecordTypeId = rtProd
    );

    Map<String, List<Account>> porCuit = VentasInformadasCuitResolver.queryCuentasPorCuitsNormalizados(
      new Set<String>{ '20-14446298-0' }
    );

    System.assert(porCuit.containsKey('20144462980'));
    System.assertEquals(1, porCuit.get('20144462980').size());
  }

  @IsTest
  static void resolverCuentasCuitFaltantesSegundaPasada() {
    Id rtProd = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Productor')
      .getRecordTypeId();
    Account acc = new Account(
      Name = 'Productor Segunda Pasada',
      N_CUIT__c = '27999999994',
      Type = 'Productor',
      RecordTypeId = rtProd
    );
    insert acc;

    List<Account> cuentas = new List<Account>();
    Set<String> missing = new Set<String>{ '27999999994' };
    Set<String> encontrados = new Set<String>();

    VentasInformadasCuitResolver.resolverCuentasCuitFaltantes(cuentas, missing, encontrados);

    System.assertEquals(1, cuentas.size());
    System.assertEquals(acc.Id, cuentas[0].Id);
    System.assert(encontrados.contains('27999999994'));
  }

  @IsTest
  static void aplicarVentaInternaUsaAccountsById() {
    Account acc03 = crearObtentor('30616275905', '03');
    Map<Id, Account> byId = new Map<Id, Account>{ acc03.Id => acc03 };
    Ventas_Informadas__c v = new Ventas_Informadas__c(
      Venta_Interna__c = true,
      CUIT_Originante__c = '30616275905',
      Originante__c = acc03.Id
    );

    VentasInformadasCuitResolver.aplicarVentaInterna(v, byId);

    System.assertEquals(acc03.Name, v.Razon_Social_Destinatario__c);
    System.assertEquals(acc03.Id, v.Destinatario__c);
  }

  @IsTest
  static void variantesCuitParaBusquedaGeneraFormatoConGuiones() {
    Set<String> variantes = VentasInformadasCuitResolver.variantesCuitParaBusqueda('20144462980');
    System.assert(variantes.contains('20144462980'));
    System.assert(variantes.contains('20-14446298-0'));
  }

  @IsTest
  static void chunkStringsParteLista() {
    List<List<String>> chunks = VentasInformadasCuitResolver.chunkStrings(
      new List<String>{ 'a', 'b', 'c' },
      2
    );
    System.assertEquals(2, chunks.size());
    System.assertEquals(2, chunks[0].size());
    System.assertEquals(1, chunks[1].size());
  }

  private static Account stubAccount(Id accId, String cuit) {
    return new Account(
      Id = accId,
      N_CUIT__c = cuit,
      Type = 'Obtentor',
      RecordType = new RecordType(DeveloperName = 'Obtentor')
    );
  }

  private static Account crearObtentor(String cuit, String sufijo) {
    Id rtObtentor = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Obtentor')
      .getRecordTypeId();
    Account acc = new Account(
      Name = 'GDM ARGENTINA S. A. (' + sufijo + ')',
      N_CUIT__c = cuit,
      Type = 'Obtentor',
      RecordTypeId = rtObtentor,
      Id_Obtentor__c = sufijo,
      Nombre_Obtentor__c = 'GDM ' + sufijo
    );
    insert acc;
    return acc;
  }

  private static Account crearObtentorHijo(Id parentId, String cuit, String sufijo) {
    Id rtObtentor = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Obtentor')
      .getRecordTypeId();
    Account acc = new Account(
      Name = 'GDM ARGENTINA S. A. (' + sufijo + ')',
      N_CUIT__c = cuit,
      Type = 'Obtentor',
      RecordTypeId = rtObtentor,
      ParentId = parentId,
      Id_Obtentor__c = sufijo,
      Nombre_Obtentor__c = 'GDM ' + sufijo
    );
    insert acc;
    return acc;
  }
}