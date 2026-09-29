@isTest
public class HomeMulticultivoTest {

    @isTest
    static void testHomeLoadDataCoverage() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Cultivo__c cultivo2 = Test_TestUtils.crearCultivo('TRIGO', 75, false);
        cultivo2.Sembra_Evolucion__c = true;
        insert cultivo2;

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

        Parametro_PPH__c param2 = new Parametro_PPH__c();
        param2.Cultivo__c = cultivo2.Id;
        param2.Fecha_Inicio_Adhesion_PPH__c = Date.today().addDays(40);
        param2.Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(3);
        param2.Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(60);
        param2.Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(80);
        param2.Fecha_Fin_Rectificacion_1__c = Date.today().addDays(70);
        param2.Fecha_Fin_Rectificacion_2__c = Date.today().addDays(90);
        param2.Fecha_Vencimiento_PPH__c = Date.today().addMonths(8);
        insert param2;

        Plan_de_Siembra__c plan = new Plan_de_Siembra__c();
        plan.Productor__c = productor.Id;
        plan.Parametro_PPH__c = param.Id;
        plan.Estado__c = 'Adherido';
        plan.Version__c = 'Original';
        plan.Name = 'Plan Test Original';
        insert plan;

        Variedad__c var = new Variedad__c(
            Name = 'test',
            Obtentor_Comercializa__c = obtentor.Id,
            Biotecnologia__c = 'Enlist E3'
        );
        insert var;

        insert new List<Hectareas_Tecnologicas__c>{
            new Hectareas_Tecnologicas__c(
                Fecha_Inicio__c = Date.today().addMonths(-1),
                Fecha_Fin__c = Date.today().addMonths(1),
                Signo__c = 1,
                Cantidad__c = 150,
                Productor__c = productor.Id,
                Biotecnologia__c = 'Enlist E3',
                Cultivo__c = cultivo.Id,
                Variedad__c = var.Id,
                Origen__c = 'PPH',
                Valor_Conversion__c = 3000,
                Plan_de_Siembra__c = plan.Id
            ),
            new Hectareas_Tecnologicas__c(
                Fecha_Inicio__c = Date.today().addMonths(-1),
                Fecha_Fin__c = Date.today().addMonths(1),
                Signo__c = -1,
                Cantidad__c = 50,
                Productor__c = productor.Id,
                Biotecnologia__c = 'Enlist E3',
                Cultivo__c = cultivo.Id,
                Variedad__c = var.Id,
                Origen__c = 'PPH',
                Valor_Conversion__c = 3000,
                Plan_de_Siembra__c = plan.Id
            )
        };

        Campana_Agricola__c campPrep = Test_TestUtils.crearCampanaAgricola(
            '2026',
            cultivo,
            Date.today().addDays(13),
            Date.today().addMonths(8),
            '2026 Prep',
            false
        );
        campPrep.Estado__c = 'En Preparación';
        insert campPrep;

        Campana_Agricola__c campActiva = Test_TestUtils.crearCampanaAgricola(
            '2026',
            cultivo2,
            Date.today().addMonths(-1),
            Date.today().addDays(10),
            '2026 Activa',
            false
        );
        campActiva.Estado__c = 'Activa';
        insert campActiva;

        Campana_Agricola__c campPasada = Test_TestUtils.crearCampanaAgricola(
            '2025',
            cultivo,
            Date.today().addYears(-1),
            Date.today().addMonths(-6),
            '2025 Pasada',
            false
        );
        campPasada.Estado__c = 'Cerrada';
        insert campPasada;

        insert new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = null,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Es_Carga_Manual__c = true,
            Saldo_Cuenta__c = 45,
            Clave_Unica__c = productor.Id + '|' + cultivo.Id + '|null|Enlist'
        );
        insert new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campPasada.Id,
            Tecnologia__c = 'Enlist E3/Conkesta E3',
            Es_Carga_Manual__c = true,
            Saldo_Cuenta__c = -10,
            Clave_Unica__c = productor.Id + '|' + campPasada.Id + '|' + cultivo.Id + '|Enlist'
        );

        Test.startTest();
        HomeMulticultivo.HomeData data = HomeMulticultivo.getLoadData();
        Test.stopTest();

        System.assertNotEquals(null, data);
        System.assert(data.cultivos.size() >= 1, 'Debe devolver al menos un cultivo');
        for (HomeMulticultivo.Tarjeta t : data.cultivos) {
            System.assertNotEquals(null, t.htAdquirida);
            System.assertNotEquals(null, t.version);
        }
    }

    @isTest
    static void testPickParametroPrefiereAdheridoRealSobreTest() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Account productor = Test_TestUtils.crearProductor();

        Parametro_PPH__c realParam = new Parametro_PPH__c(
            Cultivo__c = cultivo.Id,
            Name = 'Plan de Siembra 2025/2026 - SOJA',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addMonths(-2),
            Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2),
            Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(10),
            Fecha_Fin_Rectificacion_1__c = Date.today().addDays(20),
            Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(30),
            Fecha_Fin_Rectificacion_2__c = Date.today().addDays(60),
            Fecha_Vencimiento_PPH__c = Date.today().addMonths(6)
        );
        insert realParam;

        Parametro_PPH__c testParam = new Parametro_PPH__c(
            Cultivo__c = cultivo.Id,
            Name = 'TEST Rectificacion SOJA',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addMonths(-1),
            Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(1),
            Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(5),
            Fecha_Fin_Rectificacion_1__c = Date.today().addDays(15),
            Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(25),
            Fecha_Fin_Rectificacion_2__c = Date.today().addDays(90),
            Fecha_Vencimiento_PPH__c = Date.today().addMonths(8)
        );
        insert testParam;

        Plan_de_Siembra__c plan = new Plan_de_Siembra__c(
            Productor__c = productor.Id,
            Parametro_PPH__c = realParam.Id,
            Estado__c = 'Adherido',
            Version__c = 'Original',
            Name = 'Plan Real'
        );
        insert plan;

        Map<Id, Plan_de_Siembra__c> planes = new Map<Id, Plan_de_Siembra__c>{
            realParam.Id => plan
        };

        List<Parametro_PPH__c> params = [
            SELECT Id, Name, Cultivo__c, CreatedDate,
                   Fecha_Inicio_Adhesion_PPH__c, Fecha_Fin_Adhesion_PPH__c, Fecha_Fin_Rectificacion_2__c
            FROM Parametro_PPH__c
            WHERE Id IN :new Set<Id>{ realParam.Id, testParam.Id }
            ORDER BY CreatedDate DESC
        ];

        Parametro_PPH__c elegido = HomeMulticultivo.pickParametroVigente(params, planes);
        System.assertEquals(
            realParam.Id,
            elegido.Id,
            'Debe preferir el param real con Adherido sobre el TEST más nuevo'
        );
    }

    @isTest
    static void testPickParametroVentanaYProximos() {
        Test_TestUtils.disableFlows();

        Cultivo__c cultivo = Test_TestUtils.crearCultivo('CEBADA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Parametro_PPH__c cerrado = new Parametro_PPH__c(
            Cultivo__c = cultivo.Id,
            Name = 'Cerrado viejo',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addYears(-2),
            Fecha_Fin_Adhesion_PPH__c = Date.today().addYears(-1),
            Fecha_Inicio_Rectificacion_1__c = Date.today().addYears(-1).addDays(10),
            Fecha_Fin_Rectificacion_1__c = Date.today().addYears(-1).addDays(20),
            Fecha_Inicio_Rectificacion_2__c = Date.today().addYears(-1).addDays(30),
            Fecha_Fin_Rectificacion_2__c = Date.today().addYears(-1).addDays(40),
            Fecha_Vencimiento_PPH__c = Date.today().addMonths(-6)
        );
        insert cerrado;

        Parametro_PPH__c futuro = new Parametro_PPH__c(
            Cultivo__c = cultivo.Id,
            Name = 'TEST Adhesion No Comenzada',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addDays(40),
            Fecha_Fin_Adhesion_PPH__c = Date.today().addDays(80),
            Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(90),
            Fecha_Fin_Rectificacion_1__c = Date.today().addDays(100),
            Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(110),
            Fecha_Fin_Rectificacion_2__c = Date.today().addDays(120),
            Fecha_Vencimiento_PPH__c = Date.today().addMonths(8)
        );
        insert futuro;

        Parametro_PPH__c vigente = new Parametro_PPH__c(
            Cultivo__c = cultivo.Id,
            Name = 'Plan de Siembra 2026 - CEBADA',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addMonths(-1),
            Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2),
            Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(20),
            Fecha_Fin_Rectificacion_1__c = Date.today().addDays(30),
            Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(40),
            Fecha_Fin_Rectificacion_2__c = Date.today().addDays(60),
            Fecha_Vencimiento_PPH__c = Date.today().addMonths(6)
        );
        insert vigente;

        List<Parametro_PPH__c> params = [
            SELECT Id, Name, Cultivo__c, CreatedDate,
                   Fecha_Inicio_Adhesion_PPH__c, Fecha_Fin_Adhesion_PPH__c, Fecha_Fin_Rectificacion_2__c
            FROM Parametro_PPH__c
            WHERE Id IN :new Set<Id>{ cerrado.Id, futuro.Id, vigente.Id }
        ];

        Parametro_PPH__c elegido = HomeMulticultivo.pickParametroVigente(
            params,
            new Map<Id, Plan_de_Siembra__c>()
        );
        System.assertEquals(vigente.Id, elegido.Id, 'Debe preferir ventana abierta sobre TEST futuro y cerrado');

        System.assertEquals(
            false,
            HomeMulticultivo.isInPphLifecycle(cerrado, Date.today()),
            'Param cerrado no está en lifecycle'
        );
        System.assertEquals(
            true,
            HomeMulticultivo.isInPphLifecycle(vigente, Date.today()),
            'Param vigente está en lifecycle'
        );
        System.assertEquals(null, HomeMulticultivo.pickParametroVigente(null, null));
        System.assertEquals(
            null,
            HomeMulticultivo.pickParametroVigente(new List<Parametro_PPH__c>(), null)
        );

        // Sin DML: ramas de score Adherido fuera de ventana + tie-break TEST vs real
        Parametro_PPH__c fueraVentana = new Parametro_PPH__c(
            Id = cerrado.Id,
            Name = 'Plan cerrado con Adherido',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addYears(-2),
            Fecha_Fin_Rectificacion_2__c = Date.today().addDays(-10)
        );
        Parametro_PPH__c testEmpate = new Parametro_PPH__c(
            Id = futuro.Id,
            Name = 'TEST Empate',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addDays(-5),
            Fecha_Fin_Rectificacion_2__c = Date.today().addDays(30)
        );
        Parametro_PPH__c realEmpate = new Parametro_PPH__c(
            Id = vigente.Id,
            Name = 'Plan Empate Real',
            Fecha_Inicio_Adhesion_PPH__c = Date.today().addDays(-5),
            Fecha_Fin_Rectificacion_2__c = Date.today().addDays(30)
        );
        Plan_de_Siembra__c planFuera = new Plan_de_Siembra__c();
        Parametro_PPH__c elegidoFuera = HomeMulticultivo.pickParametroVigente(
            new List<Parametro_PPH__c>{ fueraVentana, futuro },
            new Map<Id, Plan_de_Siembra__c>{ fueraVentana.Id => planFuera }
        );
        System.assertEquals(
            fueraVentana.Id,
            elegidoFuera.Id,
            'Adherido cerrado (150) gana a adhesión futura (100)'
        );

        Parametro_PPH__c elegidoEmpate = HomeMulticultivo.pickParametroVigente(
            new List<Parametro_PPH__c>{ testEmpate, realEmpate },
            new Map<Id, Plan_de_Siembra__c>()
        );
        System.assertEquals(realEmpate.Id, elegidoEmpate.Id, 'En empate de score evita Name TEST');

        System.assertEquals(false, HomeMulticultivo.isInPphLifecycle(null, Date.today()));
        System.assertEquals(
            false,
            HomeMulticultivo.isInPphLifecycle(
                new Parametro_PPH__c(Fecha_Inicio_Adhesion_PPH__c = null),
                Date.today()
            )
        );
    }

    @isTest
    static void testUrgenciaAdhesionPph() {
        Parametro_PPH__c cierraPronto = new Parametro_PPH__c(
            Fecha_Fin_Adhesion_PPH__c = Date.today().addDays(5)
        );

        HomeMulticultivo.Tarjeta sinFase = new HomeMulticultivo.Tarjeta();
        HomeMulticultivo.applyUrgenciaPph(sinFase, cierraPronto, 'adherir');
        System.assertEquals(true, sinFase.hasFase);
        System.assertEquals(true, sinFase.faseUrgent);
        System.assertEquals(5, sinFase.faseDias);
        System.assertEquals('Adhesión PPH', sinFase.faseLabel);

        HomeMulticultivo.Tarjeta campania = new HomeMulticultivo.Tarjeta();
        campania.hasFase = true;
        campania.faseLabel = 'Campaña 2026';
        campania.faseUrgent = true;
        campania.faseDias = 2;
        HomeMulticultivo.applyUrgenciaPph(campania, cierraPronto, 'adherir');
        System.assertEquals(2, campania.faseDias, 'Mantiene el hito más próximo');

        HomeMulticultivo.Tarjeta yaAdherido = new HomeMulticultivo.Tarjeta();
        HomeMulticultivo.applyUrgenciaPph(yaAdherido, cierraPronto, 'adherido');
        System.assertNotEquals(true, yaAdherido.faseUrgent);

        HomeMulticultivo.Tarjeta lejano = new HomeMulticultivo.Tarjeta();
        HomeMulticultivo.applyUrgenciaPph(
            lejano,
            new Parametro_PPH__c(Fecha_Fin_Adhesion_PPH__c = Date.today().addDays(40)),
            'adherir'
        );
        System.assertNotEquals(true, lejano.faseUrgent);
    }
}
