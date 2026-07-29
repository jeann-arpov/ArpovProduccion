@isTest
private class RelacionarFacturaEnlistMbtTest {

    @TestSetup
    static void setup() {
        Test_TestUtils.disableFlows();

        Cultivo__c soja = new Cultivo__c(Name = 'SOJA', Densidad_de_Siembra__c = 75, Sembra_Evolucion__c = true);
        insert soja;

        // Usuario_Enlist = true: si se dispara "Creacion de Expedientes PRI Y SEC",
        // sale en EsUsuarioEnlist sin llamar Apex (evita NPE en promoción/prod).
        Account productor = new Account(
            Name = 'Prod Relacionar FCRE3',
            N_CUIT__c = '30641405554',
            Usuario_Enlist__c = true
        );
        insert productor;

        Expediente_de_Negativos__c exp = new Expediente_de_Negativos__c(
            Name = 'SEC-30641405554-TEST',
            Cuenta__c = productor.Id,
            Tipo_expendiente__c = 'SEC',
            Etapa__c = 'Llamar',
            Estado_de_la_Etapa__c = 'No empezado',
            Fecha_Cambio_Etapa__c = Date.today(),
            ValidationBypassDateTime__c = Datetime.now()
        );
        insert exp;

        // Sin Tipo_de_entrega + Estado Con error + cuenta Enlist = no crea PRI/SEC.
        insert new List<Movimiento_BolsaTech__c>{
            new Movimiento_BolsaTech__c(
                Expediente_de_Negativos__c = exp.Id,
                CTG__c = '11111111111',
                Cultivo__c = 'SOJA',
                Tecnologia__c = 'ENLIST',
                Peso_Neto__c = 30000,
                Estado__c = 'Con error',
                Cuit_Remitente_Comercial__c = '30641405554',
                CUIT_Titular__c = '30641405554'
            ),
            new Movimiento_BolsaTech__c(
                Expediente_de_Negativos__c = exp.Id,
                CTG__c = '22222222222',
                Cultivo__c = 'SOJA',
                Tecnologia__c = 'ENLIST',
                Peso_Neto__c = 31000,
                Estado__c = 'Con error',
                Cuit_Remitente_Comercial__c = '30641405554',
                CUIT_Titular__c = '30641405554'
            )
        };
    }

    @isTest
    static void relacionaPorCtgCuandoHayVariasFacturas() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE N_CUIT__c = '30641405554' LIMIT 1];
        Cultivo__c soja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];

        TN_Regalia_Enlist__c f1 = new TN_Regalia_Enlist__c(
            Expediente_de_Negativos__c = exp.Id,
            Productor__c = productor.Id,
            Cultivo__c = soja.Id,
            Biotecnologia__c = 'Enlist',
            Etapa__c = 'A Facturar',
            Cantidad__c = 30,
            N_CUIT__c = '30641405554',
            CTGs_Involucrados_Largo__c = '[11111111111]'
        );
        TN_Regalia_Enlist__c f2 = new TN_Regalia_Enlist__c(
            Expediente_de_Negativos__c = exp.Id,
            Productor__c = productor.Id,
            Cultivo__c = soja.Id,
            Biotecnologia__c = 'Enlist',
            Etapa__c = 'A Facturar',
            Cantidad__c = 31,
            N_CUIT__c = '30641405554',
            CTGs_Involucrados_Largo__c = '[22222222222]'
        );
        insert new List<TN_Regalia_Enlist__c>{ f1, f2 };

        RelacionarFacturaEnlistMbt.Request req = new RelacionarFacturaEnlistMbt.Request();
        req.expedienteId = exp.Id;

        Test.startTest();
        List<RelacionarFacturaEnlistMbt.Resultado> res = RelacionarFacturaEnlistMbt.relacionar(
            new List<RelacionarFacturaEnlistMbt.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(2, res[0].mbtsActualizados);

        Map<String, Id> facturaPorCtg = new Map<String, Id>();
        for (Movimiento_BolsaTech__c mbt : [
            SELECT CTG__c, FT_RE3_Id__c FROM Movimiento_BolsaTech__c WHERE Expediente_de_Negativos__c = :exp.Id
        ]) {
            facturaPorCtg.put(String.valueOf(mbt.CTG__c), mbt.FT_RE3_Id__c);
        }
        System.assertEquals(f1.Id, facturaPorCtg.get('11111111111'));
        System.assertEquals(f2.Id, facturaPorCtg.get('22222222222'));
    }

    @isTest
    static void unaSolaFacturaSeAplicaATodosLosMbt() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE N_CUIT__c = '30641405554' LIMIT 1];
        Cultivo__c soja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];

        TN_Regalia_Enlist__c unica = new TN_Regalia_Enlist__c(
            Expediente_de_Negativos__c = exp.Id,
            Productor__c = productor.Id,
            Cultivo__c = soja.Id,
            Biotecnologia__c = 'Enlist',
            Etapa__c = 'A Facturar',
            Cantidad__c = 61,
            N_CUIT__c = '30641405554',
            CTGs_Involucrados_Largo__c = '[11111111111, 22222222222]'
        );
        insert unica;

        RelacionarFacturaEnlistMbt.Request req = new RelacionarFacturaEnlistMbt.Request();
        req.expedienteId = exp.Id;

        Test.startTest();
        RelacionarFacturaEnlistMbt.relacionar(new List<RelacionarFacturaEnlistMbt.Request>{ req });
        Test.stopTest();

        for (Movimiento_BolsaTech__c mbt : [
            SELECT FT_RE3_Id__c FROM Movimiento_BolsaTech__c WHERE Expediente_de_Negativos__c = :exp.Id
        ]) {
            System.assertEquals(unica.Id, mbt.FT_RE3_Id__c);
        }
    }

    @isTest
    static void contieneCtgHelpers() {
        System.assertEquals(true, RelacionarFacturaEnlistMbt.contieneCtg('[10227330342, 10227330688]', '10227330342'));
        System.assertEquals(false, RelacionarFacturaEnlistMbt.contieneCtg('[10227330342]', '999'));
        System.assertEquals(true, RelacionarFacturaEnlistMbt.contieneCtg('10227330342', '10227330342'));

        Movimiento_BolsaTech__c mbt = new Movimiento_BolsaTech__c(CTG__c = 'AAA');
        TN_Regalia_Enlist__c f = new TN_Regalia_Enlist__c(CTGs_Involucrados_Largo__c = '[AAA]');
        System.assertEquals(null, RelacionarFacturaEnlistMbt.resolverFacturaParaMbt(
            new Movimiento_BolsaTech__c(CTG__c = null),
            new List<TN_Regalia_Enlist__c>{ f }
        ));
        System.assertNotEquals(null, RelacionarFacturaEnlistMbt.resolverFacturaParaMbt(
            mbt,
            new List<TN_Regalia_Enlist__c>{ f }
        ));
    }

    @isTest
    static void requestVacioYSinFacturas() {
        List<RelacionarFacturaEnlistMbt.Resultado> vacio = RelacionarFacturaEnlistMbt.relacionar(
            new List<RelacionarFacturaEnlistMbt.Request>()
        );
        System.assertEquals(0, vacio.size());

        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        RelacionarFacturaEnlistMbt.Request req = new RelacionarFacturaEnlistMbt.Request();
        req.expedienteId = exp.Id;

        Test.startTest();
        List<RelacionarFacturaEnlistMbt.Resultado> res = RelacionarFacturaEnlistMbt.relacionar(
            new List<RelacionarFacturaEnlistMbt.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(0, res[0].mbtsActualizados);
    }

    @isTest
    static void actualizaTnVinculadaAlMbt() {
        Expediente_de_Negativos__c exp = [SELECT Id FROM Expediente_de_Negativos__c LIMIT 1];
        Account productor = [SELECT Id FROM Account WHERE N_CUIT__c = '30641405554' LIMIT 1];
        Cultivo__c soja = [SELECT Id FROM Cultivo__c WHERE Name = 'SOJA' LIMIT 1];
        Movimiento_BolsaTech__c mbt = [
            SELECT Id FROM Movimiento_BolsaTech__c
            WHERE Expediente_de_Negativos__c = :exp.Id AND CTG__c = '11111111111'
            LIMIT 1
        ];

        Tonelada__c tn = new Tonelada__c(
            Biotecnologia__c = 'Enlist E3',
            Cantidad__c = 30,
            Cultivo__c = soja.Id,
            Etapa__c = 'Debitada',
            Expediente_de_Negativos__c = exp.Id,
            Fecha_Inicio__c = Date.today(),
            Fecha_Fin__c = Date.today().addYears(1),
            Fecha_Fin_Original__c = Date.today().addYears(1),
            Mov_BolsaTech__c = mbt.Id,
            N_CUIT__c = '30641405554',
            Origen__c = 'BolsaTech',
            Productor__c = productor.Id,
            Signo__c = -1,
            Tipo_de_Movimiento__c = 'D'
        );
        insert tn;

        TN_Regalia_Enlist__c f1 = new TN_Regalia_Enlist__c(
            Expediente_de_Negativos__c = exp.Id,
            Productor__c = productor.Id,
            Cultivo__c = soja.Id,
            Biotecnologia__c = 'Enlist',
            Etapa__c = 'A Facturar',
            Cantidad__c = 30,
            N_CUIT__c = '30641405554',
            CTGs_Involucrados__c = '11111111111'
        );
        insert f1;

        RelacionarFacturaEnlistMbt.Request req = new RelacionarFacturaEnlistMbt.Request();
        req.expedienteId = exp.Id;

        Test.startTest();
        RelacionarFacturaEnlistMbt.relacionar(new List<RelacionarFacturaEnlistMbt.Request>{ req });
        Test.stopTest();

        tn = [SELECT FT_RE3_Id__c FROM Tonelada__c WHERE Id = :tn.Id];
        System.assertEquals(f1.Id, tn.FT_RE3_Id__c);
    }
}
