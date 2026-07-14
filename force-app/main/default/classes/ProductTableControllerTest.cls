@IsTest
public class ProductTableControllerTest {

    @TestSetup
    static void setup() {
        Account obtentor = Test_TestUtils.crearObtentor();

        List<Producto_Obtentor__c> productos = new List<Producto_Obtentor__c>();

        for (Integer i = 0; i < 5; i++) {
            productos.add(new Producto_Obtentor__c(
                Obtentor__c = obtentor.Id,
                Tipo_de_Compra__c = 'Disponible',
                Vigente__c = true
            ));
        }

        insert productos;
    }

    private static void stubLoggedAccount() {
        CrearCompraController.acc = [SELECT Id, N_CUIT__c, Name FROM Account LIMIT 1];
    }

    @IsTest
    static void testGetProducts_basicPagination() {
        stubLoggedAccount();

        Test.startTest();
        List<ProductTableController.ProductRow> rows =
            ProductTableController.getProducts(1, 3, null);
        Test.stopTest();

        System.assertEquals(3, rows.size(), 'Debe devolver 3 registros por pageSize');

        ProductTableController.ProductRow row = rows[0];

        System.assertNotEquals(null, row.Id);
        System.assertNotEquals(null, row.ProductoObtentor, 'El Name (autonumber) debe venir');
        System.assertNotEquals(null, row.FechaCreacion, 'Debe mapear CreatedDate correctamente');
    }

    @IsTest
    static void testGetProducts_secondPage() {
        stubLoggedAccount();

        Test.startTest();
        List<ProductTableController.ProductRow> rows =
            ProductTableController.getProducts(2, 3, null);
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'La segunda página debe traer los 2 restantes');
    }

    @IsTest
    static void testGetProducts_withSearch() {
        stubLoggedAccount();

        // Cubre la rama del filtro por variedad (WHERE Nombre_Variedad__c LIKE :search)
        Test.startTest();
        List<ProductTableController.ProductRow> rows =
            ProductTableController.getProducts(1, 10, 'variedad-inexistente');
        Integer total = ProductTableController.getTotalProducts('variedad-inexistente');
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'No debe devolver filas para una variedad inexistente');
        System.assertEquals(0, total, 'El total filtrado debe ser 0');
    }

    @IsTest
    static void testGetTotalProducts() {
        stubLoggedAccount();

        Test.startTest();
        Integer total = ProductTableController.getTotalProducts(null);
        Test.stopTest();

        System.assertEquals(5, total, 'Debe contar correctamente los productos creados');
    }
}