/**
 * Test del batch de validación varietal (BatchValidarCuentaGranariaVarietal):
 * un camión varietal 'Creado' con líneas válidas debe quedar 'A procesar'.
 */
@isTest
private class BatchValidarCuentaGranariaVarietalTest {
  @testSetup
  static void setup() {
    Test_TestUtils.disableFlows();

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('TRIGO', 1, true);

    // El flow "Creacion de Expedientes PRI Y SEC" (SOJA) se dispara al insertar
    // el MBT y necesita encontrar un Cultivo__c SOJA.
    insert new Cultivo__c(
      Name = 'SOJA',
      Tipo_de_Especie__c = 'SOJA',
      Densidad_de_Siembra__c = 75
    );

    Account productor = Test_TestUtils.crearProductor();
    productor.N_CUIT__c = '30502874353';
    productor.RecordTypeId = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Account' AND DeveloperName = 'Productor'
      LIMIT 1
    ]
    .Id;
    productor.Type = 'Productor';
    productor.ParentId = null;
    update productor;

    // Un workflow ("Carga Datos Proveedor") cambia el RecordType a 'Proveedor';
    // lo forzamos de vuelta a 'Productor' para que la resolución por CUIT lo encuentre.
    productor = [
      SELECT Id, N_CUIT__c, RecordTypeId, Type, ParentId
      FROM Account
      WHERE Id = :productor.Id
    ];
    productor.RecordTypeId = [
      SELECT Id
      FROM RecordType
      WHERE SObjectType = 'Account' AND DeveloperName = 'Productor'
      LIMIT 1
    ]
    .Id;
    productor.Type = 'Productor';
    productor.ParentId = null;
    update productor;

    insert new Variedad__c(
      Name = 'CATALPA',
      Cultivo__c = cultivo.Id,
      Biotecnologia__c = 'Convencional',
      Uso_Comercial_Dureza__c = 'PAN',
      Sembra_Evolucion__c = true,
      Cultivar_Inase__c = 'CATALPA'
    );
  }

  @isTest
  static void validaMbtCreadoYLoDejaAProcesar() {
    Account productor = [SELECT Id, N_CUIT__c FROM Account LIMIT 1];
    Variedad__c variedad = [
      SELECT Id, Cultivar_Inase__c
      FROM Variedad__c
      WHERE Name = 'CATALPA'
      LIMIT 1
    ];

    Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(
      Estado__c = 'Creado',
      No_Debitar__c = false,
      Peso_Neto__c = 100000,
      Cultivo__c = 'TRIGO',
      Cosecha__c = String.valueOf(Date.today().year()),
      Tecnologia__c = 'RR1/RR2 - BT/Convencional',
      CTG__c = 'CTG-VAL-001',
      Codigo_de_Muestra__c = 'MUESTRA-VAL-001',
      Fecha_de_Analisis__c = '2026-10-01',
      CUIT_Titular__c = productor.N_CUIT__c,
      Cuit_Destinatario__c = productor.N_CUIT__c
    );
    insert mbt;

    insert new Detalle_Variedad_MBT__c(
      Movimiento_BolsaTech__c = mbt.Id,
      Cultivar__c = variedad.Cultivar_Inase__c,
      Porcentaje_Varietal__c = 100,
      Clave_Linea__c = mbt.Id + '|' + variedad.Cultivar_Inase__c
    );

    Test.startTest();
    BatchValidarCuentaGranariaVarietal batch = new BatchValidarCuentaGranariaVarietal();
    batch.execute(null, new List<Movimiento_BolsaTech__c>{ mbt });
    Test.stopTest();

    Movimiento_BolsaTech__c procesado = [
      SELECT Estado__c, Resultado__c
      FROM Movimiento_BolsaTech__c
      WHERE Id = :mbt.Id
    ];
    System.assertEquals(
      'A procesar',
      procesado.Estado__c,
      'Resultado=' + procesado.Resultado__c
    );
    System.assertEquals('OK', procesado.Resultado__c);
  }
}
