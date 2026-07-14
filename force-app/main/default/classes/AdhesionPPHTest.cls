@isTest
public class AdhesionPPHTest {
    public static testmethod void main() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = new Cultivo__c(Name = 'Test', Densidad_de_Siembra__c = 5, Fecha_Vencimiento_Tonelada__c = Date.today());
        insert cultivo;

        Parametro_PPH__c parametro = new Parametro_PPH__c(Name = 'Test', cultivo__c = cultivo.id, Biotecnologia__c = 'Enlist E3');
        parametro.Fecha_Inicio_Adhesion_PPH__c = parametro.Fecha_Inicio_Rectificacion_1__c = parametro.Fecha_Inicio_Rectificacion_2__c = System.today().addDays(-2);
        parametro.Fecha_Fin_Adhesion_PPH__c = parametro.Fecha_Fin_Rectificacion_1__c = parametro.Fecha_Fin_Rectificacion_2__c = System.today().addDays(2);
        insert parametro;

        Account productor = Test_TestUtils.crearProductor();

        Variedad__c var = new Variedad__c(Name = 'test', Biotecnologia__c = 'Enlist E3');
        insert var;

        Hectareas_Tecnologicas__c hectarea = new Hectareas_Tecnologicas__c(Fecha_Inicio__c = Date.today().addDays(-5), Fecha_Fin__c = Date.today().addDays(30), Signo__c = 1, Cantidad__c = 3, Productor__c = productor.id, Biotecnologia__c = 'Enlist E3', Cultivo__c = cultivo.id, Variedad__c = var.id, Origen__c = 'Compra HT', Saldo_PPH__c = false);
        insert hectarea;

        AdhesionPPH.getLoadData(parametro.id);

        List<Plan_de_siembra__c> planes = [select id from Plan_de_siembra__c];
        System.assertEquals(1, planes.size());

        AdhesionPPH.Data data = AdhesionPPH.getTestData(var.id);

        AdhesionPPH.save(JSON.serialize(data), planes[0].id);

        List<Establecimiento_PPH__c> establecimientosPPH = [select Establecimiento__c from Establecimiento_PPH__c];

        System.assertEquals(1, establecimientosPPH.size());
        
        AdhesionPPH.hasHT();

        AdhesionPPH.acceptTerms(planes[0].id);
        AdhesionPPH.sendAdhesion(planes[0].id);
        AdhesionPPH.rectificarAdhesion(planes[0].id);
        AdhesionPPH.rectificarAdhesion2(planes[0].id);

        System.assertEquals(1, [select id from plan_de_siembra__c].size());

        //AdhesionPPH.deleteEstablecimiento([select Establecimiento__c from Establecimiento_PPH__c where plan_de_siembra__r.Estado__c = 'Rectificado' limit 1].Establecimiento__c);
    }
}