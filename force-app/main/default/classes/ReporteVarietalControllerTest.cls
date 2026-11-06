@isTest
private class ReporteVarietalControllerTest {

    @testSetup
    static void setup() {
        Test_TestUtils.disableFlows();

        Account productor = Test_TestUtils.crearProductor();

        Cultivo__c cultivo = new Cultivo__c(
            Name = 'TRIGO',
            Tipo_de_Especie__c = 'Autógama',
            Densidad_de_Siembra__c = 75,
            Sembra_Evolucion__c = true
        );
        insert cultivo;

        Campana_Agricola__c campana = new Campana_Agricola__c(
            Name = 'TRIGO 2025 RV',
            Ano__c = '2025',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addMonths(-2),
            SKEY_CAMPANIA__c = 8800002025L,
            Z9_Clave_Unica__c = 'RV-TRIGO-2025',
            Id_Externo__c = 'RV-TRIGO-2025'
        );
        Campana_Agricola__c campanaAnterior = new Campana_Agricola__c(
            Name = 'TRIGO 2024 RV',
            Ano__c = '2024',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addYears(-1),
            SKEY_CAMPANIA__c = 8800002024L,
            Z9_Clave_Unica__c = 'RV-TRIGO-2024',
            Id_Externo__c = 'RV-TRIGO-2024'
        );
        insert new List<Campana_Agricola__c>{ campana, campanaAnterior };

        RecordType tipoObtentor = [
            SELECT Id
            FROM RecordType
            WHERE SObjectType = 'Account' AND DeveloperName = 'Obtentor'
            LIMIT 1
        ];
        Account semilleroA = new Account(
            Name = 'Semillero Alfa RV (81)',
            RecordTypeId = tipoObtentor.Id,
            Id_Obtentor__c = '81',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'ALFA'
        );
        Account semilleroB = new Account(
            Name = 'Semillero Beta RV (82)',
            RecordTypeId = tipoObtentor.Id,
            Id_Obtentor__c = '82',
            Type = 'Obtentor',
            Nombre_Obtentor__c = 'BETA'
        );
        insert new List<Account>{ semilleroA, semilleroB };

        Variedad__c catalpa = variedad('Catalpa RV', semilleroA.Id);
        Variedad__c donMario = variedad('Don Mario RV', semilleroB.Id);
        Variedad__c araucaria = variedad('Araucaria RV', semilleroA.Id);
        Variedad__c meteoro = variedad('Meteoro RV', semilleroB.Id);
        Variedad__c pequena = variedad('Pequena RV', semilleroA.Id);
        insert new List<Variedad__c>{ catalpa, donMario, araucaria, meteoro, pequena };

        Cuenta_Granaria__c cg = new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Tecnologia__c = 'RR1/RR2 - BT/Convencional',
            Clave_Unica__c = productor.Id + '|' + campana.Id + '|' + cultivo.Id + '|RV'
        );
        Cuenta_Granaria__c cgAnterior = new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campanaAnterior.Id,
            Tecnologia__c = 'RR1/RR2 - BT/Convencional',
            Clave_Unica__c = productor.Id + '|' + campanaAnterior.Id + '|' + cultivo.Id + '|RV'
        );
        insert new List<Cuenta_Granaria__c>{ cg, cgAnterior };

        List<Tonelada__c> toneladas = new List<Tonelada__c>{
            tonelada(productor, cultivo, campana, cg, catalpa, 'Compra SF', 1000, 1),
            tonelada(productor, cultivo, campana, cg, catalpa, 'Compra HT', 400, 1),
            tonelada(productor, cultivo, campana, cg, catalpa, 'Cesión HT', 200, 1),
            tonelada(productor, cultivo, campana, cg, catalpa, 'Escáner varietal', 800, -1),
            tonelada(productor, cultivo, campana, cg, catalpa, 'Compra SF', 50, -1),
            tonelada(productor, cultivo, campana, cg, donMario, 'Compra SF', 500, 1),
            tonelada(productor, cultivo, campana, cg, araucaria, 'Compra SF', 100, 1),
            tonelada(productor, cultivo, campana, cg, araucaria, 'Escáner varietal', 400, -1),
            tonelada(productor, cultivo, campana, cg, meteoro, 'Cesión HT', 40, -1),
            tonelada(productor, cultivo, campana, cg, pequena, 'Compra SF', 10, 1),
            tonelada(productor, cultivo, campana, cg, pequena, 'Escáner varietal', 13, -1),
            tonelada(productor, cultivo, campanaAnterior, cgAnterior, catalpa, 'Compra SF', 50, 1)
        };
        Tonelada__c pendiente = tonelada(productor, cultivo, campana, cg, donMario, 'Compra SF', 9999, 1);
        pendiente.Etapa__c = 'Pendiente';
        toneladas.add(pendiente);
        toneladas.add(tonelada(productor, cultivo, campana, cg, donMario, 'Balance Anual', 777, 1));
        insert toneladas;

        insert new List<Expediente_de_Negativos__c>{
            new Expediente_de_Negativos__c(
                Cuenta__c = productor.Id,
                Cuenta_Granaria__c = cg.Id,
                Saldo_Previo_al_Expediente__c = -100,
                Estado_de_la_Etapa__c = 'En progreso',
                Etapa__c = 'Llamar',
                Fecha_Cambio_Etapa__c = Date.today(),
                Gestionar__c = true
            ),
            new Expediente_de_Negativos__c(
                Cuenta__c = productor.Id,
                Cuenta_Granaria__c = cg.Id,
                Saldo_Previo_al_Expediente__c = -100,
                Estado_de_la_Etapa__c = 'Finalizado',
                Etapa__c = 'Llamar',
                Fecha_Cambio_Etapa__c = Date.today(),
                Gestionar__c = true
            )
        };
    }

    @isTest
    static void agrupaPorVariedadYFiltra() {
        Account productor = [SELECT Id FROM Account WHERE Name = 'productor' ORDER BY CreatedDate DESC LIMIT 1];
        Campana_Agricola__c campana = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'RV-TRIGO-2025' LIMIT 1];
        Campana_Agricola__c campanaAnterior = [SELECT Id FROM Campana_Agricola__c WHERE Z9_Clave_Unica__c = 'RV-TRIGO-2024' LIMIT 1];

        Cultivo__c cultivo = [SELECT Id FROM Cultivo__c WHERE Name = 'TRIGO' LIMIT 1];
        Campana_Agricola__c sinToneladas = new Campana_Agricola__c(
            Name = 'TRIGO 2010 RV',
            Ano__c = '2010',
            Estado__c = 'Activa',
            Cultivo__c = cultivo.Id,
            Fecha_de_Inicio__c = Date.today().addYears(-16),
            SKEY_CAMPANIA__c = 8800002010L,
            Z9_Clave_Unica__c = 'RV-TRIGO-2010',
            Id_Externo__c = 'RV-TRIGO-2010'
        );
        insert sinToneladas;
        insert new Cuenta_Granaria__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = sinToneladas.Id,
            Tecnologia__c = 'RR1/RR2 - BT/Convencional',
            Clave_Unica__c = productor.Id + '|' + sinToneladas.Id + '|' + cultivo.Id + '|RV-VACIA'
        );

        Test.startTest();
        ReporteVarietalController.Opciones opciones = ReporteVarietalController.getOpciones(productor.Id);
        ReporteVarietalController.Reporte reporte = ReporteVarietalController.getReporte(productor.Id, null, null, null);
        ReporteVarietalController.Reporte soloAlfa = ReporteVarietalController.getReporte(productor.Id, campana.Id, 'ALFA', null);
        ReporteVarietalController.Reporte soloSinEntregas = ReporteVarietalController.getReporte(productor.Id, campana.Id, null, 'Sin entregas');
        ReporteVarietalController.Reporte campanaVieja = ReporteVarietalController.getReporte(productor.Id, campanaAnterior.Id, null, null);
        Test.stopTest();

        System.assertEquals(2, opciones.campanas.size(), 'No lista campañas sin toneladas de trigo con variedad');
        System.assertEquals('25/26', opciones.campanas[0].nombre);
        System.assertEquals('24/25', opciones.campanas[1].nombre);
        System.assertEquals(campana.Id, (Id) opciones.campaniaActual, 'Abre en la campaña actual');
        System.assertEquals(2, opciones.semilleros.size());
        System.assertEquals('ALFA', opciones.semilleros[0].nombre, 'Muestra la marca, no la razón social');

        Map<String, ReporteVarietalController.Fila> filas = indexar(reporte.filas);
        System.assertEquals(5, filas.size(), 'Sin campaña elegida usa la actual');

        ReporteVarietalController.Fila catalpa = filas.get('Catalpa RV');
        System.assertEquals(1000, catalpa.compraSf, 'Compra SF positiva, sin netear la anulación');
        System.assertEquals(-50, catalpa.compraSfDebito, 'Compra SF negativa va a débito');
        System.assertEquals(400, catalpa.compraHt);
        System.assertEquals(200, catalpa.cesion);
        System.assertEquals(-800, catalpa.entregas, 'Toma las entregas del escáner varietal');
        System.assertEquals(1600, catalpa.credito);
        System.assertEquals(-850, catalpa.debito);
        System.assertEquals(750, catalpa.saldo);
        System.assertEquals('En regla', catalpa.estado);
        System.assertEquals('ALFA', catalpa.semillero);

        System.assertEquals('Sin entregas', filas.get('Don Mario RV').estado);
        System.assertEquals('Debe regularizar', filas.get('Araucaria RV').estado);
        System.assertEquals(-300, filas.get('Araucaria RV').saldo);
        System.assertEquals('Debe regularizar', filas.get('Meteoro RV').estado, 'Saldo negativo sin entregas regulariza');
        System.assertEquals('En regla', filas.get('Pequena RV').estado, 'Hasta -1 HT no regulariza');
        System.assertEquals('Araucaria RV', reporte.filas[0].variedad, 'Primero las que deben regularizar');

        System.assertEquals(2210, reporte.credito, 'Crédito por movimiento, igual que la vista de la CG');
        System.assertEquals(-1303, reporte.debito);
        System.assertEquals(907, reporte.saldo);

        System.assertEquals(3, soloAlfa.filas.size());
        System.assertEquals(1, soloSinEntregas.filas.size());
        System.assertEquals('Don Mario RV', soloSinEntregas.filas[0].variedad);
        System.assertEquals(500, soloSinEntregas.credito);

        System.assertEquals(1, campanaVieja.filas.size());
        System.assertEquals(50, campanaVieja.filas[0].compraSf);
        System.assertEquals('Sin entregas', campanaVieja.filas[0].estado);

        System.assertEquals(1, reporte.expedientesAbiertos);
        System.assertEquals(0, campanaVieja.expedientesAbiertos);
        System.assertEquals(0, soloAlfa.expedientesAbiertos, 'El expediente no está asociado a una variedad de ALFA');
    }

    @isTest
    static void rechazaCuentaInvalida() {
        Boolean lanzo = false;
        try {
            ReporteVarietalController.getReporte(null, null, null, null);
        } catch (AuraHandledException ex) {
            lanzo = true;
            System.assert(ex.getMessage().contains('productor'));
        }
        System.assertEquals(true, lanzo);
    }

    private static Map<String, ReporteVarietalController.Fila> indexar(List<ReporteVarietalController.Fila> filas) {
        Map<String, ReporteVarietalController.Fila> porNombre = new Map<String, ReporteVarietalController.Fila>();
        for (ReporteVarietalController.Fila fila : filas) {
            porNombre.put(fila.variedad, fila);
        }
        return porNombre;
    }

    private static Variedad__c variedad(String nombre, Id obtentorId) {
        return new Variedad__c(
            Name = nombre,
            Biotecnologia__c = 'Convencional',
            Sembra_Evolucion__c = true,
            Obtentor_Comercializa__c = obtentorId
        );
    }

    private static Tonelada__c tonelada(
        Account productor,
        Cultivo__c cultivo,
        Campana_Agricola__c campana,
        Cuenta_Granaria__c cg,
        Variedad__c variedad,
        String origen,
        Decimal cantidad,
        Integer signo
    ) {
        return new Tonelada__c(
            Productor__c = productor.Id,
            Cultivo__c = cultivo.Id,
            Campania__c = campana.Id,
            Biotecnologia__c = 'Convencional',
            Cantidad__c = cantidad,
            Signo__c = signo,
            Fecha_Inicio__c = Date.today().addDays(-10),
            Fecha_Fin__c = Date.today().addYears(1),
            Etapa__c = 'Aplicada',
            Origen__c = origen,
            Variedad__c = variedad.Id,
            Cuenta_Granaria__c = cg.Id
        );
    }
}
