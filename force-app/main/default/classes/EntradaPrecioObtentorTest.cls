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