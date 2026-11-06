@isTest
public class EntradaPrecioObtentorTest {
    
    @TestSetup
    static void setup(){
        Test_TestUtils.disableFlows();

        Account obtentor = Test_TestUtils.crearObtentor();

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id);
        insert var;

        Producto_Obtentor__c productoObtentor = new Producto_Obtentor__c();
        productoObtentor.Obtentor__c = obtentor.Id;
        productoObtentor.Variedad__c = var.Id;
        insert productoObtentor;

        Entrada_Precio_Obtentor__c entrada = new Entrada_Precio_Obtentor__c();
        entrada.Producto_Obtentor__c = productoObtentor.Id;
        entrada.Precio_Unitario__c = 10;
        entrada.Fecha_Inicio__c = Date.today().addDays(2);
        insert entrada;
    }

    @isTest 
    static void testNuevaEntrada(){
        
        Producto_Obtentor__c po = [SELECT Id FROM Producto_Obtentor__c LIMIT 1];

        Entrada_Precio_Obtentor__c entrada = new Entrada_Precio_Obtentor__c();
        entrada.Producto_Obtentor__c = po.Id;
        entrada.Precio_Unitario__c = 15;
        entrada.Fecha_Inicio__c = Date.today().addDays(4);
        insert entrada;

        Entrada_Precio_Obtentor__c entradaPrevia = [SELECT Id, Fecha_Fin__c FROM Entrada_Precio_Obtentor__c ORDER BY CreatedDate asc][0];

        Assert.isTrue(entradaPrevia.Fecha_Fin__c == Date.today().addDays(3));
    }

    @isTest
    static void testDuplicado(){
        Entrada_Precio_Obtentor__c existente = [
            SELECT Producto_Obtentor__c, Fecha_Inicio__c
            FROM Entrada_Precio_Obtentor__c
            LIMIT 1
        ];

        Entrada_Precio_Obtentor__c entrada = new Entrada_Precio_Obtentor__c();
        entrada.Producto_Obtentor__c = existente.Producto_Obtentor__c;
        entrada.Precio_Unitario__c = 15;
        entrada.Fecha_Inicio__c = existente.Fecha_Inicio__c;

        Boolean errorEsperado = false;
        try {
            insert entrada;
        } catch (Exception e) {
            errorEsperado = true;
            Assert.isTrue(e.getMessage().contains('No puede haber más de una entrada para un producto obtentor con la misma fecha de inicio'));
        }
        Assert.isTrue(errorEsperado, 'Debe fallar al duplicar fecha de inicio para el mismo producto obtentor');
    }

    @isTest
    static void testPrimeraEntradaProcesadaInmediatamente(){
        Producto_Obtentor__c productoReferencia = [
            SELECT Obtentor__c
            FROM Producto_Obtentor__c
            LIMIT 1
        ];

        Variedad__c var = new Variedad__c(
            Name = 'var-primera-entrada',
            Obtentor_Comercializa__c = productoReferencia.Obtentor__c
        );
        insert var;

        Producto_Obtentor__c productoObtentor = new Producto_Obtentor__c();
        productoObtentor.Obtentor__c = productoReferencia.Obtentor__c;
        productoObtentor.Variedad__c = var.Id;
        insert productoObtentor;

        Entrada_Precio_Obtentor__c entrada = new Entrada_Precio_Obtentor__c();
        entrada.Producto_Obtentor__c = productoObtentor.Id;
        entrada.Precio_Unitario__c = 99;
        entrada.Fecha_Inicio__c = Date.today().addDays(5);
        insert entrada;

        entrada = [
            SELECT Estado__c, Fecha_Inicio__c
            FROM Entrada_Precio_Obtentor__c
            WHERE Id = :entrada.Id
        ];

        Assert.areEqual(Date.today(), entrada.Fecha_Inicio__c);
        Assert.areEqual('Procesada', entrada.Estado__c);
    }

    @isTest
    static void testEdicionFechaInicioVigenteProcesaEnElMomento(){
        Producto_Obtentor__c po = [SELECT Id FROM Producto_Obtentor__c LIMIT 1];
        PricebookEntry pbe = crearListaSembraEvolucion(po, 10);
        moverPrimeraEntradaAlPasado(po.Id, Date.today().addDays(-10));

        Entrada_Precio_Obtentor__c entrada = new Entrada_Precio_Obtentor__c();
        entrada.Producto_Obtentor__c = po.Id;
        entrada.Precio_Unitario__c = 17;
        entrada.Fecha_Inicio__c = Date.today().addDays(4);
        insert entrada;

        Test.startTest();
        entrada.Fecha_Inicio__c = Date.today();
        update entrada;
        Test.stopTest();

        entrada = [SELECT Estado__c FROM Entrada_Precio_Obtentor__c WHERE Id = :entrada.Id];
        Assert.areEqual('Procesada', entrada.Estado__c);
        Assert.areEqual(17, [SELECT UnitPrice FROM PricebookEntry WHERE Id = :pbe.Id].UnitPrice);
    }

    @isTest
    static void testSoloSeAplicaLaEntradaVigenteMasReciente(){
        Producto_Obtentor__c po = [SELECT Id FROM Producto_Obtentor__c LIMIT 1];
        PricebookEntry pbe = crearListaSembraEvolucion(po, 10);
        moverPrimeraEntradaAlPasado(po.Id, Date.today().addDays(-10));

        Entrada_Precio_Obtentor__c reemplazada = new Entrada_Precio_Obtentor__c(
            Producto_Obtentor__c = po.Id, Precio_Unitario__c = 17, Fecha_Inicio__c = Date.today().addDays(4)
        );
        Entrada_Precio_Obtentor__c vigente = new Entrada_Precio_Obtentor__c(
            Producto_Obtentor__c = po.Id, Precio_Unitario__c = 20, Fecha_Inicio__c = Date.today().addDays(6)
        );
        insert new List<Entrada_Precio_Obtentor__c>{ reemplazada, vigente };

        reemplazada.Fecha_Inicio__c = Date.today().addDays(-5);
        vigente.Fecha_Inicio__c = Date.today().addDays(-2);
        update new List<Entrada_Precio_Obtentor__c>{ reemplazada, vigente };

        Test.startTest();
        EntradaPrecioObtentorHandler.procesarEntradasVigentes(new List<Id>{ reemplazada.Id, vigente.Id });
        Test.stopTest();

        Map<Id, Entrada_Precio_Obtentor__c> entradas = new Map<Id, Entrada_Precio_Obtentor__c>([
            SELECT Estado__c FROM Entrada_Precio_Obtentor__c WHERE Id IN :new List<Id>{ reemplazada.Id, vigente.Id }
        ]);
        Assert.areEqual('Creada', entradas.get(reemplazada.Id).Estado__c);
        Assert.areEqual('Procesada', entradas.get(vigente.Id).Estado__c);
        Assert.areEqual(20, [SELECT UnitPrice FROM PricebookEntry WHERE Id = :pbe.Id].UnitPrice);
    }

    private static PricebookEntry crearListaSembraEvolucion(Producto_Obtentor__c productoObtentor, Decimal precio){
        Variedad__c variedad = [SELECT Id, Name FROM Variedad__c WHERE Id IN (SELECT Variedad__c FROM Producto_Obtentor__c WHERE Id = :productoObtentor.Id)];
        Product2 producto = new Product2(Name = 'Producto EPO Test', IsActive = true, Variedad__c = variedad.Name, Variedad2__c = variedad.Id);
        insert producto;
        insert new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = producto.Id, UnitPrice = precio, IsActive = true);

        Pricebook2 listaSembra = new Pricebook2(Name = 'Lista de Precios Sembrá Evolución', IsActive = true);
        insert listaSembra;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = listaSembra.Id, Product2Id = producto.Id, UnitPrice = precio, IsActive = true);
        insert pbe;

        productoObtentor.ProductoId__c = producto.Id;
        update productoObtentor;
        return pbe;
    }

    private static void moverPrimeraEntradaAlPasado(Id productoObtentorId, Date fechaInicio){
        Entrada_Precio_Obtentor__c primera = [
            SELECT Id FROM Entrada_Precio_Obtentor__c
            WHERE Producto_Obtentor__c = :productoObtentorId
            ORDER BY Fecha_Inicio__c ASC
            LIMIT 1
        ];
        update new Entrada_Precio_Obtentor__c(Id = primera.Id, Fecha_Inicio__c = fechaInicio, Trigger_Update__c = true);
    }

    @isTest
    static void testBorrarEntrada(){
        Producto_Obtentor__c po = [SELECT Id FROM Producto_Obtentor__c LIMIT 1];

        Entrada_Precio_Obtentor__c entrada = new Entrada_Precio_Obtentor__c();
        entrada.Producto_Obtentor__c = po.Id;
        entrada.Precio_Unitario__c = 15;
        entrada.Fecha_Inicio__c = Date.today().addDays(4);
        insert entrada;

        delete entrada;

        Entrada_Precio_Obtentor__c entradaPrevia = [SELECT Id, Fecha_Fin__c FROM Entrada_Precio_Obtentor__c LIMIT 1];

        Assert.isTrue(entradaPrevia.Fecha_Fin__c == null);
    }
}