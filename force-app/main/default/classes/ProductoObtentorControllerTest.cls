@IsTest
public class ProductoObtentorControllerTest {

    @TestSetup
    static void setup() {
        // Obtentor relacionado
        Account obtentor = new Account(Name = 'Obtentor Test');
        insert obtentor;

        // Producto (solo campos editables)
        Producto_Obtentor__c prod = new Producto_Obtentor__c(
            Name = 'Producto Test',
            Obtentor__c = obtentor.Id,
            Tipo_de_Compra__c = 'Disponible',
            Vigente__c = true
        );
        insert prod;

        // Precios (sin Name porque es autonumber)
        List<Entrada_Precio_Obtentor__c> precios = new List<Entrada_Precio_Obtentor__c>();
        precios.add(new Entrada_Precio_Obtentor__c(
            Producto_Obtentor__c = prod.Id,
            Precio_Unitario__c = 10,
            Fecha_Inicio__c = Date.today().addDays(1),
            Fecha_Fin__c = Date.today().addDays(10),
            Estado__c = 'Procesada'
        ));
        precios.add(new Entrada_Precio_Obtentor__c(
            Producto_Obtentor__c = prod.Id,
            Precio_Unitario__c = 20,
            Fecha_Inicio__c = Date.today().addDays(1),
            Fecha_Fin__c = Date.today().addDays(20),
            Estado__c = 'Creada'
        ));
        insert precios;
    }

    @IsTest
    static void testGetProductoObtentorData_ok() {
        Producto_Obtentor__c prod = [SELECT Id FROM Producto_Obtentor__c LIMIT 1];

        Test.startTest();
        ProductoObtentorController.ProductoWrapper result =
            ProductoObtentorController.getProductoObtentorData(prod.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals(null, result.producto);
        System.assertEquals(prod.Id, result.producto.Id);

        System.assertEquals(2, result.precios.size());

        // Validar estadoClass
        Map<String, Object> precio1 = result.precios[0];
        Map<String, Object> precio2 = result.precios[1];

        System.assertEquals('estado ok', precio1.get('estadoClass'));
        System.assertEquals('estado no', precio2.get('estadoClass'));
    }

    @IsTest
    static void testGetProductoObtentorData_parametroVacio() {
        try {
            ProductoObtentorController.getProductoObtentorData('');
            System.assert(false, 'Debe lanzar excepción si el parámetro está vacío');
        } catch (AuraHandledException e) {
            
        }
    }
    
    @isTest
    static void testCreateEntradaSuccess() {
        // 1. Preparar los datos de prueba
        Producto_Obtentor__c prod = [SELECT Id FROM Producto_Obtentor__c LIMIT 1];
        // Nota: Asegúrate de incluir todos los campos obligatorios de tu objeto
        Entrada_Precio_Obtentor__c nuevaEntrada = new Entrada_Precio_Obtentor__c(
            Precio_Unitario__c = 150.50,
            Fecha_Inicio__c = Date.today().addDays(5),
            Producto_Obtentor__c = prod.Id,
            Fecha_Fin__c = Date.today().addDays(30),
            Estado__c = 'Creada'
        );

        // 2. Ejecutar el método
        Test.startTest();
        Map<String, Object> resultado = ProductoObtentorController.createEntrada(nuevaEntrada);
        Test.stopTest();

        // 3. Verificaciones (Assertions)
        
        // Verificar que el registro se insertó (Id no es nulo)
        System.assertNotEquals(null, resultado.get('Id'), 'El Id no debería ser nulo después de la inserción');
        
        // Verificar campos mapeados
        System.assertEquals(150.50, resultado.get('Precio_Unitario__c'));
        System.assertEquals('Creada', resultado.get('Estado__c'));
        
        // Verificar que el registro realmente existe en la base de datos
        Entrada_Precio_Obtentor__c dbRecord = [SELECT Id, Estado__c FROM Entrada_Precio_Obtentor__c WHERE Id = :(Id)resultado.get('Id')];
        System.assertEquals('Creada', dbRecord.Estado__c);
    }

}