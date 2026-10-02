@IsTest
public class GestionExpedientesControllerTest {

    @TestSetup
    static void setup() {
        Expediente_de_Negativos__c expediente = new Expediente_de_Negativos__c();
        insert expediente;

        Case caso = new Case(Subject = 'Caso test gestiones', Status = 'New', Origin = 'Phone');
        insert caso;
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
            exp.Id, '1234567890', 'WhatsApp', 'Saliente', 'SE', 'Acopio', 'Test comentario', 'Efectiva'
        );
        Test.stopTest();

        System.assertNotEquals(null, gestion.Id, 'Gestión creada');
        System.assert(gestion.Name.startsWith('GE-'), 'Auto-number correcto');
        System.assertEquals('WhatsApp', gestion.Medio__c);
        System.assertEquals('Saliente', gestion.Tipo_Gestion__c);
        System.assertEquals('SE', gestion.Operador__c);
        System.assertEquals('Acopio', gestion.Respuesta__c);
        System.assertEquals('Efectiva', gestion.Efectividad__c);

        Gestion_Expedientes__c guardada = [
            SELECT Expediente_de_Negativos__c, Caso__c
            FROM Gestion_Expedientes__c
            WHERE Id = :gestion.Id
        ];
        System.assertEquals(exp.Id, guardada.Expediente_de_Negativos__c);
        System.assertEquals(null, guardada.Caso__c);
    }

    @IsTest
    static void testCrearGestionEnCaso() {
        Case caso = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Gestion_Expedientes__c gestion = GestionExpedientesController.crearGestion(
            caso.Id, '1199999999', 'Llamada', 'Entrante', null, 'Sin contacto', 'Gestión desde caso', 'Efectiva'
        );
        Test.stopTest();

        Gestion_Expedientes__c guardada = [
            SELECT Caso__c, Expediente_de_Negativos__c, Medio__c, Operador__c, Respuesta__c, Efectividad__c
            FROM Gestion_Expedientes__c
            WHERE Id = :gestion.Id
        ];
        System.assertEquals(caso.Id, guardada.Caso__c);
        System.assertEquals(null, guardada.Expediente_de_Negativos__c);
        System.assertEquals('Llamada', guardada.Medio__c);
        System.assertEquals('Caso', guardada.Operador__c);
        System.assertEquals('Sin contacto', guardada.Respuesta__c);
        System.assertEquals('Efectiva', guardada.Efectividad__c);

        GestionExpedientesController.GestionesResult result =
            GestionExpedientesController.obtenerGestiones(caso.Id, 10, 0);
        System.assertEquals(1, result.total);
        System.assertEquals(1, result.gestiones.size());
    }

    @IsTest
    static void testCrearGestionEnCasoConRespuestasRenombradas() {
        Case caso = [SELECT Id FROM Case LIMIT 1];

        Test.startTest();
        Gestion_Expedientes__c siembra = GestionExpedientesController.crearGestion(
            caso.Id, '1100000001', 'WhatsApp', 'Saliente', null, 'Cesión conjunta', 'Siembra Asociada', 'Efectiva'
        );
        Gestion_Expedientes__c ncHt = GestionExpedientesController.crearGestion(
            caso.Id, '1100000002', 'Email', 'Entrante', null, 'Solicita NC', 'Solicita NC HT', 'No Efectiva'
        );
        Gestion_Expedientes__c otraMarca = GestionExpedientesController.crearGestion(
            caso.Id, '1100000003', 'Llamada', 'Saliente', null, 'Promesa Compra HT', 'Siembra otra marca', 'Efectiva'
        );
        Gestion_Expedientes__c licencia = GestionExpedientesController.crearGestion(
            caso.Id, '1100000004', 'WhatsApp', 'Entrante', null, 'Licencia E3 en gestión', 'Licencia en gestión', 'Efectiva'
        );
        Test.stopTest();

        System.assertEquals('Cesión conjunta', siembra.Respuesta__c, 'API Name de Siembra Asociada se mantiene');
        System.assertEquals('Solicita NC', ncHt.Respuesta__c, 'API Name de Solicita NC HT se mantiene');
        System.assertEquals('Promesa Compra HT', otraMarca.Respuesta__c, 'API Name de Siembra otra marca se mantiene');
        System.assertEquals('Licencia E3 en gestión', licencia.Respuesta__c, 'API Name de Licencia en gestión se mantiene');
        System.assertEquals('Caso', siembra.Operador__c);
    }

    @IsTest
    static void testCrearGestionVentaHtFuturaSoja() {
        Id rtId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName().get('Sembra_Evolucion').getRecordTypeId();
        Case futuraSoja = new Case(
            Subject = 'Venta HT Futura Soja',
            Status = 'New',
            Origin = 'Phone',
            RecordTypeId = rtId,
            Type = 'Venta HT',
            Tema__c = 'Futura Soja'
        );
        Case otroTema = new Case(
            Subject = 'Venta HT otro tema',
            Status = 'New',
            Origin = 'Phone',
            RecordTypeId = rtId,
            Type = 'Venta HT',
            Tema__c = 'HT'
        );
        insert new List<Case>{ futuraSoja, otroTema };

        Test.startTest();
        Gestion_Expedientes__c sinCompra = GestionExpedientesController.crearGestion(
            futuraSoja.Id, '1188888888', 'WhatsApp', 'Saliente', null,
            'Sin intención de compra', 'Lista VHT', 'Efectiva'
        );
        Gestion_Expedientes__c promesa = GestionExpedientesController.crearGestion(
            futuraSoja.Id, '1188888887', 'Llamada', 'Entrante', null,
            'Promesa de respuesta', 'Lista VHT', 'No Efectiva'
        );
        Gestion_Expedientes__c contacto = GestionExpedientesController.crearGestion(
            futuraSoja.Id, '1188888886', 'Email', 'Saliente', null,
            'Sin contacto activo', 'Lista VHT', 'Efectiva'
        );
        Gestion_Expedientes__c otro = GestionExpedientesController.crearGestion(
            otroTema.Id, '1188888885', 'Llamada', 'Saliente', null,
            'Sin contacto', 'Otro tema', 'Efectiva'
        );
        Boolean rechazoListaGeneral = false;
        try {
            GestionExpedientesController.crearGestion(
                futuraSoja.Id, '1188888884', 'Email', 'Entrante', null,
                'Ensayo', 'No corresponde a Futura Soja', 'Efectiva'
            );
        } catch (Exception e) {
            rechazoListaGeneral = true;
        }
        Test.stopTest();

        System.assertEquals('Caso VHT', sinCompra.Operador__c);
        System.assertEquals('Sin intención de compra', sinCompra.Respuesta__c);
        System.assertEquals('Caso VHT', promesa.Operador__c);
        System.assertEquals('Promesa de respuesta', promesa.Respuesta__c);
        System.assertEquals('Caso VHT', contacto.Operador__c);
        System.assertEquals('Sin contacto activo', contacto.Respuesta__c);
        System.assertEquals('Caso', otro.Operador__c);
        System.assertEquals('Sin contacto', otro.Respuesta__c);
        System.assertEquals(true, rechazoListaGeneral, 'Futura Soja no acepta respuestas del menú general de casos');
    }

    @IsTest
    static void testObtenerGestionesConDatos() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];

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
        GestionExpedientesController.GestionesResult result1 =
            GestionExpedientesController.obtenerGestiones(exp.Id, 10, 0);
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
