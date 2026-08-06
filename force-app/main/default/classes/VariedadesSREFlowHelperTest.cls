@isTest
public class VariedadesSREFlowHelperTest {

    @TestSetup
    static void setup() {
        // Desactivar flujos para evitar interferencias en la carga de datos
        Test_TestUtils.disableFlows();

        // Crear Cuentas usando las utilidades propias de la org
        Account obtentor = Test_TestUtils.crearObtentor();
        Account productor = Test_TestUtils.crearProductor(); // Name: "productor"

        // Crear Variedad respetando los campos requeridos (Obtentor_Propietario__c)
        Variedad__c var1 = new Variedad__c(
            Name = 'Variedad Test 1', 
            Obtentor_Propietario__c = obtentor.Id, 
            Obtentor_Comercializa__c = obtentor.Id,
            Sembra_Evolucion__c = false
        );
        Variedad__c var2 = new Variedad__c(
            Name = 'Variedad Test 2', 
            Obtentor_Propietario__c = obtentor.Id, 
            Obtentor_Comercializa__c = obtentor.Id,
            Sembra_Evolucion__c = false
        );
        insert new List<Variedad__c>{ var1, var2 };
    }

    @isTest
    static void testAsignarVariedadesSingle() {
        Account obtentor = [SELECT Id FROM Account LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];

        // Preparar entrada para el método Invocable
        VariedadesSREFlowHelper.FlowInput input = new VariedadesSREFlowHelper.FlowInput();
        input.productorId = productor.Id;
        input.obtentorId = obtentor.Id;

        Test.startTest();
        VariedadesSREFlowHelper.asignarTodasLasVariedades(new List<VariedadesSREFlowHelper.FlowInput>{ input });
        Test.stopTest();

        // Verificar que se hayan insertado las 2 variedades disponibles
        Assert.areEqual(2, [SELECT Count() FROM Variedad_SRE_por_Productor__c WHERE Cuenta__c = :productor.Id]);
    }

    @isTest
    static void testAsignarVariedadesBulk() {
        Account obtentor = [SELECT Id FROM Account LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' LIMIT 1];

        // Simular ejecución en lote (200 invocaciones masivas en una sola transacción)
        List<VariedadesSREFlowHelper.FlowInput> inputs = new List<VariedadesSREFlowHelper.FlowInput>();
        for (Integer i = 0; i < 200; i++) {
            VariedadesSREFlowHelper.FlowInput input = new VariedadesSREFlowHelper.FlowInput();
            input.productorId = productor.Id;
            input.obtentorId = obtentor.Id;
            inputs.add(input);
        }

        Test.startTest();
        VariedadesSREFlowHelper.asignarTodasLasVariedades(inputs);
        Test.stopTest();

        // Asegurar que a pesar de las 200 solicitudes, solo cree 2 registros y no genere duplicados
        Assert.areEqual(2, [SELECT Count() FROM Variedad_SRE_por_Productor__c WHERE Cuenta__c = :productor.Id]);
    }

    @isTest
    static void testCasosNulls() {
        Test.startTest();
        // Cobertura para invocaciones vacías o inválidas
        VariedadesSREFlowHelper.asignarTodasLasVariedades(null);
        VariedadesSREFlowHelper.asignarTodasLasVariedades(new List<VariedadesSREFlowHelper.FlowInput>());
        
        VariedadesSREFlowHelper.FlowInput inputInvalido = new VariedadesSREFlowHelper.FlowInput();
        VariedadesSREFlowHelper.asignarTodasLasVariedades(new List<VariedadesSREFlowHelper.FlowInput>{ inputInvalido });
        Test.stopTest();

        Assert.areEqual(0, [SELECT Count() FROM Variedad_SRE_por_Productor__c]);
    }
}