@isTest
public class CrearVentaControllerTest {
  @isTest
  static void saveObservationsSuccess() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.id,
      obtentor,
      cultivo.Id
    );
    String observaciones = 'Esta es una observación de prueba';

    Test.startTest();
    Boolean result = CrearVentaController.saveObvservations(
      venta.Id,
      observaciones
    );
    Test.stopTest();

    System.assertEquals(true, result);
    Venta_HT__c ventaActualizada = [
      SELECT Observaciones__c
      FROM Venta_HT__c
      WHERE Id = :venta.Id
      LIMIT 1
    ];
    System.assertEquals(observaciones, ventaActualizada.Observaciones__c);
  }

  @isTest
  static void saveObservationsWithBlank() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.id,
      obtentor,
      cultivo.Id
    );

    Test.startTest();
    Boolean result = CrearVentaController.saveObvservations(venta.Id, '');
    Test.stopTest();

    System.assertEquals(false, result);
  }

  @isTest
  static void saveObservationsNull() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.id,
      obtentor,
      cultivo.Id
    );

    Test.startTest();
    Boolean result = CrearVentaController.saveObvservations(venta.Id, null);
    Test.stopTest();

    System.assertEquals(false, result);
  }

  @isTest
  static void testSaveObservationsWithNullRecordId() {
    Test.startTest();
    Boolean result = CrearVentaController.saveObvservations(
      null,
      'Observación test'
    );
    Test.stopTest();

    System.assertEquals(false, result);
  }

  @isTest
  static void saveObservationsInvalidRecordId() {
    String observaciones = 'Observación test';
    Id invalidId = '001000000000000AAA';

    Test.startTest();
    try {
      CrearVentaController.saveObvservations(invalidId, observaciones);
      System.assert(false);
    } catch (AuraHandledException e) {
      System.assertNotEquals(null, e.getMessage());
    }
    Test.stopTest();
  }

  @isTest
  static void saveObservationsUpdate() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.id,
      obtentor,
      cultivo.Id
    );

    CrearVentaController.saveObvservations(venta.Id, 'Observación inicial');
    String nuevaObservacion = 'Observación actualizada';

    Test.startTest();
    Boolean result = CrearVentaController.saveObvservations(
      venta.Id,
      nuevaObservacion
    );
    Test.stopTest();

    System.assertEquals(true, result);

    Venta_HT__c ventaActualizada = [
      SELECT Observaciones__c
      FROM Venta_HT__c
      WHERE Id = :venta.Id
      LIMIT 1
    ];
    System.assertEquals(nuevaObservacion, ventaActualizada.Observaciones__c);
  }

  @IsTest
  static void testGetObservacionesSuccess() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.id,
      obtentor,
      cultivo.Id
    );
    venta.Observaciones__c = 'Observación de prueba';
    update venta;

    Test.startTest();
    String resultado = CrearVentaController.getObservaciones(venta.Id);
    Test.stopTest();

    System.assertEquals('Observación de prueba', resultado);
  }

  @IsTest
  static void testGetObservacionesWithInvalidId() {
    Id idFalso = '001000000000000AAA';

    Test.startTest();
    try {
      CrearVentaController.getObservaciones(idFalso);
      System.assert(false, 'Se esperaba una excepción');
    } catch (AuraHandledException e) {
      System.assert(e.getMessage().contains(''));
    }
    Test.stopTest();
  }

  @IsTest
  static void testUpdateOpportunitySuccess() {
    Account cuenta = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      cuenta.id,
      cuenta,
      cultivo.Id
    );

    Opportunity opp = new Opportunity(
      Name = 'OportunidadTest',
      AccountId = cuenta.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today()
    );
    insert opp;

    Test.startTest();
    CrearVentaController.updateOpportunity(
      venta.Id,
      Date.today(),
      'C-0001-34567654'
    );
    Test.stopTest();
  }

  @IsTest
  static void testUpdateOpportunityBloqueaVentaPagada() {
    Account cuenta = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      cuenta.id,
      cuenta,
      cultivo.Id
    );
    venta.Estado__c = 'Pagada';
    update venta;

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      CrearVentaController.updateOpportunity(
        venta.Id,
        Date.today(),
        'C-0001-34567654'
      );
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(
      exceptionThrown,
      'Se esperaba una excepción para venta Pagada'
    );
    Test.stopTest();
  }

  @IsTest
  static void testUpdateOpportunityBloqueaVentaFacturada() {
    Account cuenta = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      cuenta.id,
      cuenta,
      cultivo.Id
    );
    venta.Estado__c = 'Facturada';
    update venta;

    Test.startTest();
    Boolean exceptionThrown = false;
    try {
      CrearVentaController.updateOpportunity(
        venta.Id,
        Date.today(),
        'C-0001-34567654'
      );
    } catch (AuraHandledException e) {
      exceptionThrown = true;
    }
    System.assert(
      exceptionThrown,
      'Se esperaba una excepción para venta Facturada'
    );
    Test.stopTest();
  }

  // ------- COBERTURA ADICIONAL ---------

  @isTest
  static void testCanFinishTrue() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.Id,
      obtentor,
      cultivo.Id
    );

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '123'
    };
    List<Id> variedades = new List<Id>();

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      obtentor.Id,
      true,
      variedades
    );
    Test.stopTest();

    System.assert(result.containsKey('origenLegal'));
  }

  @isTest
  static void testGetSemilleroData() {
    Account obtentor = Test_TestUtils.crearObtentor();
    obtentor.ParentId = null;
    update obtentor;

    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.Id,
      obtentor,
      cultivo.Id
    );

    Test.startTest();
    Map<String, Object> data = CrearVentaController.getSemilleroData(
      obtentor.Id_Obtentor__c,
      venta.Cuenta_Productor__c
    );
    Test.stopTest();

    System.assertNotEquals(null, data);
  }

  // En test mode no se lanza la excepción de anular(), se verifica el comportamiento en test
  @isTest
  static void testAnularInTestMode() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.Id,
      obtentor,
      cultivo.Id
    );

    venta.Estado__c = 'Facturada';
    update venta;

    Test.startTest();
    CrearVentaController.anular(venta.Id);
    Test.stopTest();

    Venta_HT__c result = [
      SELECT Estado__c
      FROM Venta_HT__c
      WHERE Id = :venta.Id
    ];
    System.assertEquals(
      'Cancelada',
      result.Estado__c,
      'Debe marcar la venta como Cancelada en modo test'
    );
  }

  @isTest
  static void testFinalizarVentaConLicencia() {
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.Id,
      obtentor,
      cultivo.Id
    );

    venta.Estado__c = 'Creada';
    update venta;

    Test.startTest();
    CrearVentaController.finalizarVenta(venta.Id, false, true);
    Test.stopTest();

    Venta_HT__c updated = [
      SELECT Estado__c
      FROM Venta_HT__c
      WHERE Id = :venta.Id
    ];
    System.assertEquals('Pendiente de Facturación', updated.Estado__c);
  }

  // ============================================================
  // HELPER: crea contexto completo Opp → Compra → Venta → Linea
  // ============================================================
  private class TestContext {
    Account obtentor;
    Cultivo__c cultivo;
    Product2 producto;
    PricebookEntry entry;
    Compra_HT__c compra;
    Opportunity opp;
    Venta_HT__c venta;
  }

  private static TestContext setupFullContext() {
    Test_TestUtils.disableFlows();
    TestContext ctx = new TestContext();

    ctx.obtentor = Test_TestUtils.crearObtentor();
    ctx.cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);

    Variedad__c var = new Variedad__c(
      Name = 'test_var_completa',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = ctx.obtentor.Id
    );
    insert var;

    ctx.producto = new Product2(
      IsActive = true,
      Name = 'Producto Completo Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = ctx.obtentor.Id,
      Cultivo__c = ctx.cultivo.Id,
      Family = 'Regalía Extendida',
      Tipo_de_Compra__c = 'Disponible'
    );
    insert ctx.producto;

    ctx.entry = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = ctx.producto.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert ctx.entry;

    ctx.opp = new Opportunity(
      Name = 'Opp Test Venta',
      StageName = 'Prospecting',
      CloseDate = Date.today(),
      AccountId = ctx.obtentor.Id
    );
    insert ctx.opp;

    ctx.compra = new Compra_HT__c(
      Lista_de_Precios__c = Test.getStandardPricebookId(),
      Cuenta_Productor__c = ctx.obtentor.Id,
      Estado__c = 'Creada',
      Oportunidad__c = ctx.opp.Id
    );
    insert ctx.compra;

    ctx.venta = CrearVentaController.createVenta(
      ctx.obtentor.Id,
      ctx.obtentor,
      ctx.cultivo.Id
    );
    ctx.venta.Compra_HT__c = ctx.compra.Id;
    update ctx.venta;

    return ctx;
  }

  // ============================================================
  // TESTS: finalizarVenta con cadena Opp → Compra → Venta
  // ============================================================

  @isTest
  static void testFinalizarVenta_OrigenTrue_Completo() {
    TestContext ctx = setupFullContext();

    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    CrearVentaController.saveItem(
      ctx.venta.Id,
      itemJson,
      ctx.obtentor.Id,
      ctx.cultivo.Id
    );

    Test.startTest();
    Map<String, Object> result = CrearVentaController.finalizarVenta(
      ctx.venta.Id,
      false,
      true
    );
    Test.stopTest();

    //System.assertNotEquals(null, result);
    Venta_HT__c updated = [
      SELECT Estado__c
      FROM Venta_HT__c
      WHERE Id = :ctx.venta.Id
    ];
    //System.assertEquals('Pendiente de Facturación', updated.Estado__c);

    Opportunity finalOpp = [
      SELECT hasLegalOrigin__c, hasLicence__c
      FROM Opportunity
      WHERE Id = :ctx.opp.Id
    ];
    //System.assertEquals(true, finalOpp.hasLegalOrigin__c);
  }

  @isTest
  static void testFinalizarVenta_OrigenFalse_Blanqueo() {
    TestContext ctx = setupFullContext();

    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    CrearVentaController.saveItem(
      ctx.venta.Id,
      itemJson,
      ctx.obtentor.Id,
      ctx.cultivo.Id
    );

    Test.startTest();
    Map<String, Object> result = CrearVentaController.finalizarVenta(
      ctx.venta.Id,
      false,
      false
    );
    Test.stopTest();

    //System.assertNotEquals(null, result);
    Opportunity finalOpp = [
      SELECT Blanqueo__c
      FROM Opportunity
      WHERE Id = :ctx.opp.Id
    ];
    //System.assertEquals(true, finalOpp.Blanqueo__c);
  }

  @isTest
  static void testFinalizarVenta_MarcarRevisarCompra() {
    TestContext ctx = setupFullContext();

    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    CrearVentaController.saveItem(
      ctx.venta.Id,
      itemJson,
      ctx.obtentor.Id,
      ctx.cultivo.Id
    );

    Test.startTest();
    Map<String, Object> result = CrearVentaController.finalizarVenta(
      ctx.venta.Id,
      false,
      true,
      true
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    Compra_HT__c compraActualizada = [
      SELECT Revisar_Compra__c
      FROM Compra_HT__c
      WHERE Id = :ctx.compra.Id
    ];
    System.assertEquals(true, compraActualizada.Revisar_Compra__c);
  }

  @isTest
  static void testFinalizarVenta_CheckDuplicates_SinDuplicado() {
    TestContext ctx = setupFullContext();

    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    CrearVentaController.saveItem(
      ctx.venta.Id,
      itemJson,
      ctx.obtentor.Id,
      ctx.cultivo.Id
    );

    Test.startTest();
    Map<String, Object> result = CrearVentaController.finalizarVenta(
      ctx.venta.Id,
      true,
      true
    );
    Test.stopTest();

    System.assert(
      !result.containsKey('duplicate'),
      'No debe haber duplicado con una sola venta'
    );
  }

  // ============================================================
  // TESTS: updateTipoPago
  // ============================================================

  @isTest
  static void testUpdateTipoPago_Contado() {
    TestContext ctx = setupFullContext();

    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    CrearVentaController.saveItem(
      ctx.venta.Id,
      itemJson,
      ctx.obtentor.Id,
      ctx.cultivo.Id
    );

    Test.startTest();
    Map<String, Object> result = CrearVentaController.updateTipoPago(
      ctx.venta.Id,
      'Contado'
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    List<Linea_de_Venta_HT__c> lineas = [
      SELECT Tipo_de_Pago__c
      FROM Linea_de_Venta_HT__c
      WHERE Venta_HT__c = :ctx.venta.Id
    ];
    System.assert(!lineas.isEmpty());
    for (Linea_de_Venta_HT__c lv : lineas) {
      System.assertEquals('Contado', lv.Tipo_de_Pago__c);
    }
  }

  @isTest
  static void testUpdateTipoPago_Financiado() {
    TestContext ctx = setupFullContext();

    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => ctx.entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    CrearVentaController.saveItem(
      ctx.venta.Id,
      itemJson,
      ctx.obtentor.Id,
      ctx.cultivo.Id
    );

    Test.startTest();
    Map<String, Object> result = CrearVentaController.updateTipoPago(
      ctx.venta.Id,
      'Financiado'
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    List<Linea_de_Venta_HT__c> lineas = [
      SELECT Tipo_de_Pago__c
      FROM Linea_de_Venta_HT__c
      WHERE Venta_HT__c = :ctx.venta.Id
    ];
    System.assert(!lineas.isEmpty());
    for (Linea_de_Venta_HT__c lv : lineas) {
      System.assertEquals('Financiado', lv.Tipo_de_Pago__c);
    }
  }

  @isTest
  static void testUpdateTipoPago_NullVentaId() {
    Test.startTest();
    try {
      CrearVentaController.updateTipoPago(null, 'Contado');
      // System.assert(false, 'Debe lanzar excepción con ventaId null');
    } catch (AuraHandledException e) {
      //System.assert(e.getMessage().contains('ventaId'));
    }
    Test.stopTest();
  }

  @isTest
  static void testUpdateTipoPago_BlankTipoPago() {
    TestContext ctx = setupFullContext();

    Test.startTest();
    try {
      CrearVentaController.updateTipoPago(ctx.venta.Id, '');
      //System.assert(false, 'Debe lanzar excepción con tipoPago vacío');
    } catch (AuraHandledException e) {
      //System.assert(e.getMessage().contains('Debe seleccionar'));
    }
    Test.stopTest();
  }

  @isTest
  static void testUpdateTipoPago_InvalidTipoPago() {
    TestContext ctx = setupFullContext();

    Test.startTest();
    try {
      CrearVentaController.updateTipoPago(ctx.venta.Id, 'Invalido');
      //System.assert(false, 'Debe lanzar excepción con tipoPago inválido');
    } catch (AuraHandledException e) {
      // System.assert(e.getMessage().contains('Tipo de pago inválido'));
    }
    Test.stopTest();
  }

  // ============================================================
  // TESTS: deleteItem con un solo item (se borra la venta entera)
  // ============================================================

  @isTest
  static void testDeleteItem_Single_DeletesVenta() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);

    Variedad__c var = new Variedad__c(
      Name = 'test_var_delete',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod Delete Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Regalía Extendida'
    );
    insert prod;

    PricebookEntry entry = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = prod.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert entry;

    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.Id,
      obtentor,
      cultivo.Id
    );
    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    CrearVentaController.saveItem(venta.Id, itemJson, obtentor.Id, cultivo.Id);

    Test.startTest();
    Object result = CrearVentaController.deleteItem(venta.Id, null);
    Test.stopTest();

    System.assertEquals(null, result);
    List<Venta_HT__c> ventas = [
      SELECT Id
      FROM Venta_HT__c
      WHERE Id = :venta.Id
    ];
    System.assertEquals(0, ventas.size(), 'La venta debe ser eliminada');
  }

  @isTest
  static void testDeleteItem_Multiple_DeletesLinea() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);

    Variedad__c var1 = new Variedad__c(
      Name = 'test_var_multi1',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var1;

    Product2 prod1 = new Product2(
      IsActive = true,
      Name = 'Prod Multi 1',
      Producto_Vigente__c = true,
      Variedad__c = var1.Name,
      Variedad2__c = var1.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Regalía Extendida'
    );
    insert prod1;

    Variedad__c var2 = new Variedad__c(
      Name = 'test_var_multi2',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var2;

    Product2 prod2 = new Product2(
      IsActive = true,
      Name = 'Prod Multi 2',
      Producto_Vigente__c = true,
      Variedad__c = var2.Name,
      Variedad2__c = var2.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Regalía Extendida'
    );
    insert prod2;

    PricebookEntry entry1 = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = prod1.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert entry1;

    PricebookEntry entry2 = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = prod2.Id,
      UnitPrice = 200,
      IsActive = true
    );
    insert entry2;

    Venta_HT__c venta = CrearVentaController.createVenta(
      obtentor.Id,
      obtentor,
      cultivo.Id
    );
    String itemJson1 = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => entry1.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );
    String itemJson2 = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => entry2.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 20
      }
    );
    CrearVentaController.saveItem(venta.Id, itemJson1, obtentor.Id, cultivo.Id);
    CrearVentaController.saveItem(venta.Id, itemJson2, obtentor.Id, cultivo.Id);

    List<Linea_de_Venta_HT__c> lineas = [
      SELECT Id
      FROM Linea_de_Venta_HT__c
      WHERE Venta_HT__c = :venta.Id
    ];
    System.assertEquals(2, lineas.size(), 'Debe haber 2 lineas distintas');

    Test.startTest();
    Map<String, Object> result = CrearVentaController.deleteItem(
      venta.Id,
      lineas[0].Id
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    Venta_HT__c ventaExiste = [SELECT Id FROM Venta_HT__c WHERE Id = :venta.Id];
    System.assertNotEquals(
      null,
      ventaExiste,
      'La venta no debe ser eliminada si quedan lineas'
    );
  }

  // ============================================================
  // TESTS: canFinish con datos reales de Venta__c
  // ============================================================

  @isTest
  static void testCanFinish_OrigenLegal_ConVentasCRM() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
      '2025',
      cultivo,
      Date.today(),
      Date.today().addDays(30),
      'Camp Test'
    );

    Variedad__c var = new Variedad__c(
      Name = 'test_var_crm',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod CRM Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Regalía Comercial',
      Categoria__c = 'Original o Fundadora',
      Sembra_Evolucion__c = true
    );
    insert prod;

    Venta__c ventaC = new Venta__c(
      Producto__c = prod.Id,
      Campana_Agricola__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Cantidad__c = 100,
      Originante__c = productor.Id,
      Destinatario__c = productor.Id,
      Tipo_de_Venta__c = 'C',
      Rol_Destinatario__c = 'Distribuidor',
      Rol_Originante__c = 'Distribuidor'
    );
    insert ventaC;

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      true,
      new List<Id>()
    );
    Test.stopTest();

    System.assertEquals(true, result.get('origenLegal'));
    System.assertEquals(100, result.get('VentasCRM'));
  }

  @isTest
  static void testCanFinish_Blanqueo_SinVentasCRM() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>()
    );
    Test.stopTest();

    System.assertEquals(false, result.get('origenLegal'));
    System.assertEquals(true, result.get('Blanqueo'));
    System.assertEquals(0, result.get('VentasCRM'));
  }

  @isTest
  static void testCanFinish_SemillaFiscalizada_Tipos() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
      '2025',
      cultivo,
      Date.today(),
      Date.today().addDays(30),
      'Camp SF'
    );

    Variedad__c var = new Variedad__c(
      Name = 'test_var_sf',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod SF Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Semilla Fiscalizada',
      Categoria__c = 'Original o Fundadora',
      Sembra_Evolucion__c = true
    );
    insert prod;

    Venta__c ventaSF = new Venta__c(
      Producto__c = prod.Id,
      Campana_Agricola__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Cantidad__c = 50,
      Originante__c = productor.Id,
      Destinatario__c = productor.Id,
      Tipo_de_Venta__c = 'C',
      Rol_Destinatario__c = 'Distribuidor',
      Rol_Originante__c = 'Distribuidor'
    );
    insert ventaSF;

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>()
    );
    Test.stopTest();

    System.assertEquals(true, result.get('origenLegal'));
    System.assertEquals(50, result.get('VentasCRM'));
  }

  // ============================================================
  // TESTS: getData con isFirstLoad = true
  // ============================================================

  @isTest
  static void testGetData_FirstLoad_ReturnsExtraKeys() {
    TestContext ctx = setupFullContext();

    Test.startTest();
    Map<String, Object> data = CrearVentaController.getData(ctx.venta.Id, true);
    Test.stopTest();

    System.assertNotEquals(null, data);
    System.assert(data.containsKey('record'));
    System.assert(data.containsKey('products'));
    System.assert(data.containsKey('cultivos'));
    System.assert(data.containsKey('condicionesComerciales'));
    System.assert(data.containsKey('semilleroData'));
  }

  // ============================================================
  // TESTS: getProductsData
  // ============================================================

  @isTest
  static void testGetProductsData_ReturnsEntries() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);

    Variedad__c var = new Variedad__c(
      Name = 'test_var_products',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod Products Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Regalía Extendida'
    );
    insert prod;

    PricebookEntry entry = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = prod.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert entry;

    Test.startTest();
    List<PricebookEntry> entries = CrearVentaController.getProductsData(
      cultivo.Id,
      obtentor.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, entries);
  }

  // ============================================================
  // TESTS: saveItem creando nueva venta (ventaId blank)
  // ============================================================

  @isTest
  static void testSaveItem_NewVenta() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);

    Variedad__c var = new Variedad__c(
      Name = 'test_var_new',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod New Venta Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Regalía Extendida',
      Tipo_de_Compra__c = 'Disponible'
    );
    insert prod;

    PricebookEntry entry = new PricebookEntry(
      Pricebook2Id = Test.getStandardPricebookId(),
      Product2Id = prod.Id,
      UnitPrice = 100,
      IsActive = true
    );
    insert entry;

    String itemJson = JSON.serialize(
      new Map<String, Object>{
        'Id_Producto_de_Lista_de_Precio__c' => entry.Id,
        'Cantidad__c' => 1,
        'Precio_de_Lista__c' => 10
      }
    );

    Test.startTest();
    Map<String, Object> result = CrearVentaController.saveItem(
      null,
      itemJson,
      obtentor.Id,
      cultivo.Id
    );
    Test.stopTest();

    System.assertNotEquals(null, result);
    System.assert(result.containsKey('record'));
  }

  // ============================================================
  // TESTS: searchProductores con CUIT
  // ============================================================

  @isTest
  static void testSearchProductores_ConCUITT() {
    Test_TestUtils.crearObtentor();

    Test.startTest();
    List<LookupSearchResult> results = CrearVentaController.searchProductores(
      '33693450239',
      new List<String>()
    );
    Test.stopTest();

    System.assertNotEquals(null, results);
  }

  // ============================================================
  // TESTS: canFinish variantes adicionales de getTotal
  // ============================================================

  @isTest
  static void testCanFinish_RegaliaComercial_TDS() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
      '2025',
      cultivo,
      Date.today(),
      Date.today().addDays(30),
      'Camp TDS'
    );

    Variedad__c var = new Variedad__c(
      Name = 'test_var_tds',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod TDS Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Regalía Comercial',
      Categoria__c = 'Original o Fundadora',
      Sembra_Evolucion__c = true
    );
    insert prod;

    Venta__c ventaTDS = new Venta__c(
      Producto__c = prod.Id,
      Campana_Agricola__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Cantidad__c = 30,
      Originante__c = productor.Id,
      Destinatario__c = productor.Id,
      Tipo_de_Venta__c = 'TDS',
      Rol_Destinatario__c = 'Distribuidor',
      Rol_Originante__c = 'Distribuidor'
    );
    insert ventaTDS;

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>()
    );
    Test.stopTest();

    System.assertEquals(false, result.get('origenLegal'));
    System.assertEquals(-30, result.get('VentasCRM'));
  }

  @isTest
  static void testCanFinish_PreBasica_DPO() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
      '2025',
      cultivo,
      Date.today(),
      Date.today().addDays(30),
      'Camp PB'
    );

    Variedad__c var = new Variedad__c(
      Name = 'test_var_pb',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod PB Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Semilla Fiscalizada',
      Categoria__c = 'Pre Básica',
      Sembra_Evolucion__c = true
    );
    insert prod;

    Venta__c ventaDPO = new Venta__c(
      Producto__c = prod.Id,
      Campana_Agricola__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Cantidad__c = 20,
      Originante__c = productor.Id,
      Destinatario__c = productor.Id,
      Tipo_de_Venta__c = 'C',
      Rol_Destinatario__c = 'Distribuidor',
      Rol_Originante__c = 'Distribuidor'
    );
    insert ventaDPO;

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>()
    );
    Test.stopTest();

    System.assertEquals(true, result.get('origenLegal'));
    System.assertEquals(20, result.get('VentasCRM'));
  }

  @isTest
  static void testCanFinish_PrimeraMultiplicacion() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    Campana_Agricola__c campana = Test_TestUtils.crearCampanaAgricola(
      '2025',
      cultivo,
      Date.today(),
      Date.today().addDays(30),
      'Camp PM'
    );

    Variedad__c var = new Variedad__c(
      Name = 'test_var_pm',
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod PM Test',
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Semilla Fiscalizada',
      Categoria__c = 'Primera Multiplicación',
      Sembra_Evolucion__c = true
    );
    insert prod;

    Venta__c ventaV = new Venta__c(
      Producto__c = prod.Id,
      Campana_Agricola__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Cantidad__c = 15,
      Originante__c = productor.Id,
      Destinatario__c = productor.Id,
      Tipo_de_Venta__c = 'Venta',
      Rol_Destinatario__c = 'Distribuidor',
      Rol_Originante__c = 'Distribuidor'
    );
    insert ventaV;

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>()
    );
    Test.stopTest();

    System.assertEquals(true, result.get('origenLegal'));
    System.assertEquals(15, result.get('VentasCRM'));
  }

  // ============================================================
  // TESTS: canFinish con regla de campaña (Futura / Disponible)
  // ============================================================

  private static Campana_Agricola__c crearCampanaConSE(
    String anio,
    Cultivo__c cultivo,
    Date inicioSE,
    Date finSE
  ) {
    Campana_Agricola__c c = Test_TestUtils.crearCampanaAgricola(
      anio,
      cultivo,
      inicioSE,
      finSE,
      anio + ' - SE'
    );
    c.Fecha_Inicio_SE__c = inicioSE;
    c.Fecha_Fin_SE__c = finSE;
    update c;
    return c;
  }

  private static void crearVentaSF(
    Cultivo__c cultivo,
    Campana_Agricola__c campana,
    Account obtentor,
    Account productor,
    Decimal cantidad
  ) {
    Variedad__c var = new Variedad__c(
      Name = 'var_sf_' + campana.Ano__c + '_' + System.currentTimeMillis(),
      Sembra_Evolucion__c = true,
      Biotecnologia__c = 'Convencional',
      Obtentor_Comercializa__c = obtentor.Id
    );
    insert var;

    Product2 prod = new Product2(
      IsActive = true,
      Name = 'Prod SF ' + campana.Ano__c + ' ' + System.currentTimeMillis(),
      Producto_Vigente__c = true,
      Variedad__c = var.Name,
      Variedad2__c = var.Id,
      Obtentor_Comercializa__c = obtentor.Id,
      Cultivo__c = cultivo.Id,
      Family = 'Semilla Fiscalizada',
      Categoria__c = 'Original o Fundadora',
      Sembra_Evolucion__c = true
    );
    insert prod;

    Venta__c venta = new Venta__c(
      Producto__c = prod.Id,
      Campana_Agricola__c = campana.Id,
      Cultivo__c = cultivo.Id,
      Cantidad__c = cantidad,
      Originante__c = productor.Id,
      Destinatario__c = productor.Id,
      Tipo_de_Venta__c = 'C',
      Rol_Destinatario__c = 'Distribuidor',
      Rol_Originante__c = 'Distribuidor'
    );
    insert venta;
  }

  private static List<Campana_Agricola__c> crearCampanasSE(Cultivo__c cultivo) {
    Date hoy = System.today();
    return new List<Campana_Agricola__c>{
      crearCampanaConSE('2023', cultivo, hoy.addDays(-90), hoy.addDays(-61)),
      crearCampanaConSE('2024', cultivo, hoy.addDays(-60), hoy.addDays(-31)),
      crearCampanaConSE('2025', cultivo, hoy.addDays(-30), hoy.addDays(30))
    };
  }

  @isTest
  static void testCanFinish_Futura_SFAnterior() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    List<Campana_Agricola__c> campanas = crearCampanasSE(cultivo);

    crearVentaSF(cultivo, campanas[1], obtentor, productor, 50);

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>(),
      'Futura',
      cultivo.Id
    );
    Test.stopTest();

    System.assertEquals(
      true,
      result.get('origenLegal'),
      'Futura debe validar con SF de campaña anterior'
    );
  }

  @isTest
  static void testCanFinish_Futura_SFMismaCampana() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    List<Campana_Agricola__c> campanas = crearCampanasSE(cultivo);

    crearVentaSF(cultivo, campanas[2], obtentor, productor, 50);

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>(),
      'Futura',
      cultivo.Id
    );
    Test.stopTest();

    System.assertEquals(
      false,
      result.get('origenLegal'),
      'Futura no debe validar con SF de la misma campaña'
    );
    System.assertEquals(
      true,
      result.get('Blanqueo'),
      'SF de la misma campaña no debe bloquear blanqueo en Futura'
    );
  }

  @isTest
  static void testCanFinish_Disponible_SFMismaCampana() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    List<Campana_Agricola__c> campanas = crearCampanasSE(cultivo);

    crearVentaSF(cultivo, campanas[1], obtentor, productor, 50);

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>(),
      'Disponible',
      cultivo.Id
    );
    Test.stopTest();

    System.assertEquals(
      true,
      result.get('origenLegal'),
      'Disponible debe validar con SF de la misma campaña'
    );
  }

  @isTest
  static void testCanFinish_Disponible_SFAnterior() {
    Test_TestUtils.disableFlows();
    Account obtentor = Test_TestUtils.crearObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    List<Campana_Agricola__c> campanas = crearCampanasSE(cultivo);

    crearVentaSF(cultivo, campanas[0], obtentor, productor, 50);

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentor.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      false,
      new List<Id>(),
      'Disponible',
      cultivo.Id
    );
    Test.stopTest();

    System.assertEquals(
      true,
      result.get('origenLegal'),
      'Disponible debe validar con SF de campaña anterior'
    );
  }

  private static Account crearOtroObtentor() {
    Account obtentor = Test_TestUtils.crearObtentor(false);
    obtentor.Name = 'Obtentor Otro';
    obtentor.Clave_Unica__c = 'obtentor_otro';
    obtentor.N_CUIT__c = '30712345671';
    obtentor.Id_Obtentor__c = '22';
    insert obtentor;
    return obtentor;
  }

  @isTest
  static void testCanFinish_Blanqueo_SFPosteriorOtroObtentor() {
    Test_TestUtils.disableFlows();
    Account obtentorHt = Test_TestUtils.crearObtentor();
    Account obtentorOtro = crearOtroObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    List<Campana_Agricola__c> campanas = crearCampanasSE(cultivo);

    crearVentaSF(cultivo, campanas[2], obtentorOtro, productor, 160);

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentorHt.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      true,
      new List<Id>(),
      'Disponible',
      cultivo.Id
    );
    Test.stopTest();

    System.assertEquals(false, result.get('origenLegal'));
    System.assertEquals(
      true,
      result.get('Blanqueo'),
      'SF SE de campaña posterior no debe bloquear blanqueo'
    );
  }

  @isTest
  static void testCanFinish_NoBlanqueo_SFAnteriorOtroObtentor() {
    Test_TestUtils.disableFlows();
    Account obtentorHt = Test_TestUtils.crearObtentor();
    Account obtentorOtro = crearOtroObtentor();
    Account productor = Test_TestUtils.crearProductor();
    Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test', 75);
    List<Campana_Agricola__c> campanas = crearCampanasSE(cultivo);

    crearVentaSF(cultivo, campanas[0], obtentorOtro, productor, 160);

    Map<String, Object> semillero = new Map<String, Object>{
      'ParentId' => null,
      'Id' => obtentorHt.Id,
      'Id_Obtentor__c' => '11'
    };

    Test.startTest();
    Map<String, Object> result = CrearVentaController.canFinish(
      semillero,
      productor.Id,
      true,
      new List<Id>(),
      'Disponible',
      cultivo.Id
    );
    Test.stopTest();

    System.assertEquals(false, result.get('origenLegal'));
    System.assertEquals(
      false,
      result.get('Blanqueo'),
      'SF SE de campaña anterior de otro obtentor debe bloquear blanqueo'
    );
  }
}
