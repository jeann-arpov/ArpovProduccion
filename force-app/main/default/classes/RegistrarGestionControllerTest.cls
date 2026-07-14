@IsTest
private class RegistrarGestionControllerTest {

    @TestSetup
    static void setup() {
        insert new Expediente_de_Negativos__c();
    }

    @IsTest
    static void testObtenerProximoNumeroGestion() {
        Test.startTest();
        Integer numero = RegistrarGestionController.obtenerProximoNumeroGestion();
        Test.stopTest();

        System.assert(numero >= 1000 && numero <= 99999, 'Número dentro del rango esperado');
    }

    @IsTest
    static void testObtenerOpcionesRespuesta() {
        Test.startTest();
        List<Map<String, String>> opciones = RegistrarGestionController.obtenerOpcionesRespuesta();
        Test.stopTest();

        System.assert(!opciones.isEmpty(), 'Debe retornar opciones de respuesta');
    }

    @IsTest
    static void testGuardarGestion() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];

        Test.startTest();
        Map<String, Object> resultado = RegistrarGestionController.guardarGestion(
            exp.Id,
            'GE-00001',
            '1234567890',
            'Llamada',
            'Saliente',
            'Contactado',
            'Comentario de prueba'
        );
        Test.stopTest();

        System.assertEquals(true, resultado.get('success'), 'Guardado exitoso');
        System.assertNotEquals(null, resultado.get('taskId'), 'Debe retornar Id de Task');
    }

    @IsTest
    static void testGuardarGestionError() {
        Test.startTest();
        Map<String, Object> resultado = RegistrarGestionController.guardarGestion(
            '001000000000000AAA',
            'GE-00001',
            '1234567890',
            'Llamada',
            'Saliente',
            'Contactado',
            'Comentario de prueba'
        );
        Test.stopTest();

        System.assertEquals(false, resultado.get('success'), 'Debe fallar con recordId inválido');
        System.assert(((String) resultado.get('message')).contains('Error al guardar gestión'), 'Mensaje de error esperado');
    }
}