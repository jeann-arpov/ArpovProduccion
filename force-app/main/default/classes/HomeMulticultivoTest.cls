@isTest
public class HomeMulticultivoTest {
    
    @isTest static void test(){

        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Account obtentor = Test_TestUtils.crearObtentor();
        Account productor = Test_TestUtils.crearProductor();

        Parametro_PPH__c param = new Parametro_PPH__c();
        param.Cultivo__c = cultivo.Id;
        param.Fecha_Inicio_Adhesion_PPH__c = Date.today();
        param.Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2);
        param.Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(30);
        param.Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(50);
        param.Fecha_Fin_Rectificacion_1__c = Date.today().addDays(40);
        param.Fecha_Fin_Rectificacion_2__c = Date.today().addDays(60);
        param.Fecha_Vencimiento_PPH__c = Date.today().addMonths(6);
        insert param;

        Variedad__c var = new Variedad__c(Name = 'test', Obtentor_Comercializa__c = obtentor.id, Biotecnologia__c = 'Enlist E3');
        insert var;

        Hectareas_Tecnologicas__c hectarea = new Hectareas_Tecnologicas__c(Fecha_Inicio__c = Date.today().addMonths(-1), Fecha_Fin__c = Date.today().addMonths(1), Signo__c = 1, Cantidad__c = 150, Productor__c = productor.id, Biotecnologia__c = 'Enlist E3', Cultivo__c = cultivo.id, Variedad__c = var.id, Origen__c = 'PPH', Valor_Conversion__c = 3000);
        Hectareas_Tecnologicas__c hectarea2 = new Hectareas_Tecnologicas__c(Fecha_Inicio__c = Date.today().addMonths(-1), Fecha_Fin__c = Date.today().addMonths(1), Signo__c = -1, Cantidad__c = 50, Productor__c = productor.id, Biotecnologia__c = 'Enlist E3', Cultivo__c = cultivo.id, Variedad__c = var.id, Origen__c = 'PPH', Valor_Conversion__c = 3000);
        insert new List<Hectareas_Tecnologicas__c>{hectarea, hectarea2};

        List<HomeMulticultivo.Tarjeta> results = HomeMulticultivo.getLoadData();

        System.assertEquals(1, results.size());
    }
}