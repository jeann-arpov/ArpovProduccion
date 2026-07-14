@IsTest
public class GestionExpedientesControllerTest {

    @TestSetup
    static void setup() {
        // Crear expediente de prueba
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c();
        insert expediente;
    }

    @IsTest
    static void testObtenerGestionesVacio() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        
        Test.startTest();
        GestionExpedientesController.GestionesResult result = 
            GestionExpedientesController.obtenerGestiones(exp.Id, 10, 0);
        Test.stopTest();
        
        System.assertEquals(0, result.total, 'No debería haber gestiones');
        System.assertEquals(0, result.gestiones.size(), 'Lista vacía');
    }

    @IsTest
    static void testCrearGestion() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        
        Test.startTest();
        Gestion_Expedientes__c gestion = GestionExpedientesController.crearGestion(
            exp.Id, '1234567890', 'WhatsApp', 'Saliente', 'SE', 'Acopio', 'Test comentario'
        );
        Test.stopTest();
        
        System.assertNotEquals(null, gestion.Id, 'Gestión creada');
        System.assert(gestion.Name.startsWith('GE-'), 'Auto-number correcto');
        System.assertEquals('WhatsApp', gestion.Medio__c);
        System.assertEquals('Saliente', gestion.Tipo_Gestion__c);
        System.assertEquals('SE', gestion.Operador__c);
        System.assertEquals('Acopio', gestion.Respuesta__c);
    }

    @IsTest
    static void testObtenerGestionesConDatos() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        
        // Crear varias gestiones
        List<Gestion_Expedientes__c> gestiones = new List<Gestion_Expedientes__c>();
        for (Integer i = 0; i < 15; i++) {
            gestiones.add(new Gestion_Expedientes__c(
                Expediente_de_Negativos__c = exp.Id,
                Medio__c = 'Llamada',
                Tipo_Gestion__c = 'Saliente',
                Operador__c = 'SE',
                Respuesta__c = 'Acopio'
            ));
        }
        insert gestiones;
        
        Test.startTest();
        // Página 1
        GestionExpedientesController.GestionesResult result1 = 
            GestionExpedientesController.obtenerGestiones(exp.Id, 10, 0);
        // Página 2
        GestionExpedientesController.GestionesResult result2 = 
            GestionExpedientesController.obtenerGestiones(exp.Id, 10, 10);
        Test.stopTest();
        
        System.assertEquals(15, result1.total, 'Total debe ser 15');
        System.assertEquals(10, result1.gestiones.size(), 'Primera página: 10 registros');
        System.assertEquals(5, result2.gestiones.size(), 'Segunda página: 5 registros');
    }

    @IsTest
    static void testObtenerSiguienteNumero() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        
        Test.startTest();
        String numero = GestionExpedientesController.obtenerSiguienteNumero(exp.Id);
        Test.stopTest();
        
        System.assertNotEquals(null, numero);
    }

    @IsTest
    static void testEliminarGestion() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        
        Gestion_Expedientes__c gestion = new Gestion_Expedientes__c(
            Expediente_de_Negativos__c = exp.Id,
            Medio__c = 'Email',
            Tipo_Gestion__c = 'Entrante',
            Operador__c = 'CTV',
            Respuesta__c = 'Sin respuesta'
        );
        insert gestion;
        
        Test.startTest();
        GestionExpedientesController.eliminarGestion(gestion.Id);
        Test.stopTest();
        
        List<Gestion_Expedientes__c> remaining = [
            SELECT Id FROM Gestion_Expedientes__c WHERE Id = :gestion.Id
        ];
        System.assertEquals(0, remaining.size(), 'Gestión eliminada');
    }
}