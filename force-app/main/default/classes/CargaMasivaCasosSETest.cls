@IsTest
private class CargaMasivaCasosSETest {

    @TestSetup
    static void setup() {
        Test_TestUtils.disableFlows();
    }

    @IsTest
    static void creaCasoSinTipoNiTema() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('20144462980', 'Productor Test SA');
            CargaMasivaCasosSE.FilaEntrada fila = filaBase(cuenta, operador.Id);
            fila.tipo = '';
            fila.tema = null;

            Test.startTest();
            CargaMasivaCasosSE.Resumen preview = CargaMasivaCasosSE.validar(new List<CargaMasivaCasosSE.FilaEntrada>{ fila });
            CargaMasivaCasosSE.Resumen resultado = CargaMasivaCasosSE.crear(new List<CargaMasivaCasosSE.FilaEntrada>{ fila });
            Test.stopTest();

            System.assertEquals(1, preview.validos, 'La fila sin Tipo ni Tema es válida');
            System.assertEquals(0, preview.conError);
            System.assertEquals(1, resultado.creados);
            System.assertEquals(0, resultado.conError);

            Case creado = [
                SELECT AccountId, RecordType.DeveloperName, Status, Type, Tema__c, Inicio__c, Capsula__c, OwnerId, CUIT__c, Subject, CaseNumber
                FROM Case
                WHERE Id = :resultado.filas[0].casoId
            ];
            System.assertEquals(cuenta.Id, creado.AccountId);
            System.assertEquals('Sembra_Evolucion', creado.RecordType.DeveloperName);
            System.assertEquals('Abierto', creado.Status);
            System.assertEquals(null, creado.Type);
            System.assertEquals(null, creado.Tema__c);
            System.assertEquals('Saliente', creado.Inicio__c);
            System.assertEquals('STINE', creado.Capsula__c);
            System.assertEquals(operador.Id, creado.OwnerId);
            System.assertEquals('20144462980', creado.CUIT__c);
            System.assertEquals('SE-Productor Test SA---' + creado.CaseNumber, creado.Subject);
        }
    }

    @IsTest
    static void aceptaTipoYTemaCuandoVienen() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('30616275905', 'Otra Razon SA');
            CargaMasivaCasosSE.FilaEntrada fila = filaBase(cuenta, operador.Id);
            fila.cuit = '30-61627590-5';
            fila.tipo = 'solicitud';
            fila.tema = 'HT';

            CargaMasivaCasosSE.Resumen resultado = CargaMasivaCasosSE.crear(new List<CargaMasivaCasosSE.FilaEntrada>{ fila });
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Case creado = [SELECT Type, Tema__c, Subject, CaseNumber FROM Case WHERE Id = :resultado.filas[0].casoId];
            System.assertEquals('Solicitud', creado.Type);
            System.assertEquals('HT', creado.Tema__c);
            System.assertEquals('SE-Otra Razon SA-Solicitud-HT-' + creado.CaseNumber, creado.Subject);
        }
    }

    @IsTest
    static void editarTemaRearmaElAsuntoYGuardaDescripcion() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('30641405554', 'COOPERATIVA AGROPECUARIA LARGA');
            CargaMasivaCasosSE.FilaEntrada alta = filaBase(cuenta, operador.Id);
            alta.tipo = 'Consulta';
            alta.tema = 'PPH';
            CargaMasivaCasosSE.Resumen creado = CargaMasivaCasosSE.crear(
                new List<CargaMasivaCasosSE.FilaEntrada>{ alta }
            );
            System.assertEquals(1, creado.creados, creado.filas[0].motivo);

            Case original = [SELECT Subject, CaseNumber FROM Case WHERE Id = :creado.filas[0].casoId];
            System.assertEquals('SE-COOPERATIVA AGROPECU-Consulta-PPH-' + original.CaseNumber, original.Subject);

            CargaMasivaCasosSE.FilaEntrada edicion = new CargaMasivaCasosSE.FilaEntrada();
            edicion.nroFila = 1;
            edicion.idCaso = creado.filas[0].casoId;
            edicion.tema = 'Licencia';
            edicion.descripcion = 'Detalle del contacto';
            CargaMasivaCasosSE.Resumen resultado = CargaMasivaCasosSE.editar(
                new List<CargaMasivaCasosSE.FilaEntrada>{ edicion }
            );
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Case actual = [SELECT Subject, Type, Tema__c, Description FROM Case WHERE Id = :original.Id];
            System.assertEquals('Consulta', actual.Type);
            System.assertEquals('Licencia', actual.Tema__c);
            System.assertEquals('Detalle del contacto', actual.Description);
            System.assertEquals('SE-COOPERATIVA AGROPECU-Consulta-Licencia-' + original.CaseNumber, actual.Subject);
        }
    }

    @IsTest
    static void rechazaCuitInvalidoCuentaInexistenteYTipo() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('20144462980', 'Productor Test SA');
            CargaMasivaCasosSE.FilaEntrada cuitMal = filaBase(cuenta, operador.Id);
            cuitMal.cuit = '123';
            cuitMal.nroFila = 2;

            CargaMasivaCasosSE.FilaEntrada sinCuenta = filaBase(cuenta, operador.Id);
            sinCuenta.cuit = '30641405554';
            sinCuenta.nroFila = 3;

            CargaMasivaCasosSE.FilaEntrada tipoMal = filaBase(cuenta, operador.Id);
            tipoMal.tipo = 'No existe';
            tipoMal.nroFila = 4;

            CargaMasivaCasosSE.Resumen preview = CargaMasivaCasosSE.validar(new List<CargaMasivaCasosSE.FilaEntrada>{
                cuitMal, sinCuenta, tipoMal
            });

            System.assertEquals(3, preview.procesados);
            System.assertEquals(0, preview.validos);
            System.assertEquals(3, preview.conError);
            System.assert(preview.filas[0].motivo.contains('formato'));
            System.assert(preview.filas[1].motivo.contains('No se encontró'));
            System.assert(preview.filas[2].motivo.contains('Tipo'));

            CargaMasivaCasosSE.Resumen creado = CargaMasivaCasosSE.crear(new List<CargaMasivaCasosSE.FilaEntrada>{
                cuitMal, sinCuenta, tipoMal
            });
            System.assertEquals(0, creado.creados);
            System.assertEquals(0, [SELECT COUNT() FROM Case]);
        }
    }

    @IsTest
    static void rechazaCuitConMasDeUnaCuenta() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            insertarObtentor('20144462980', 'Primera SA', '91');
            insertarObtentor('20144462980', 'Segunda SA', '92');
            CargaMasivaCasosSE.FilaEntrada fila = filaBase(new Account(N_CUIT__c = '20144462980', Name = 'Primera SA'), operador.Id);
            CargaMasivaCasosSE.Resumen preview = CargaMasivaCasosSE.validar(new List<CargaMasivaCasosSE.FilaEntrada>{ fila });
            System.assertEquals(0, preview.validos);
            System.assert(preview.filas[0].motivo.contains('más de una Cuenta'));
        }
    }

    @IsTest
    static void sinPermisoNoValida() {
        User operador = usuarioSinPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('20144462980', 'Productor Test SA');
            Boolean lanzo = false;
            try {
                CargaMasivaCasosSE.validar(new List<CargaMasivaCasosSE.FilaEntrada>{ filaBase(cuenta, operador.Id) });
            } catch (AuraHandledException ex) {
                lanzo = true;
            }
            System.assert(lanzo, 'Sin el permiso custom no se puede validar');
            System.assertEquals(false, CargaMasivaCasosSE.puedeUsar());
        }
    }

    @IsTest
    static void editaSoloLosDatosInformados() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('20144462980', 'Productor Test SA');
            CargaMasivaCasosSE.Resumen creado = CargaMasivaCasosSE.crear(
                new List<CargaMasivaCasosSE.FilaEntrada>{ filaBase(cuenta, operador.Id) }
            );
            System.assertEquals(1, creado.creados, creado.filas[0].motivo);

            CargaMasivaCasosSE.FilaEntrada edicion = new CargaMasivaCasosSE.FilaEntrada();
            edicion.nroFila = 1;
            edicion.idCaso = creado.filas[0].casoId;
            edicion.inicio = 'Entrante';
            edicion.capsula = 'BASF';

            CargaMasivaCasosSE.Resumen resultado = CargaMasivaCasosSE.editar(
                new List<CargaMasivaCasosSE.FilaEntrada>{ edicion }
            );
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Case actual = [
                SELECT Inicio__c, Capsula__c, Status
                FROM Case
                WHERE Id = :creado.filas[0].casoId
            ];
            System.assertEquals('Entrante', actual.Inicio__c);
            System.assertEquals('BASF', actual.Capsula__c);
            System.assertEquals('Abierto', actual.Status);
        }
    }

    @IsTest
    static void creaComentariosOpcionales() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('30616275905', 'Cuenta Comentarios SA');
            CargaMasivaCasosSE.FilaEntrada sinComentarios = filaBase(cuenta, operador.Id);
            CargaMasivaCasosSE.Resumen creado = CargaMasivaCasosSE.crear(
                new List<CargaMasivaCasosSE.FilaEntrada>{ sinComentarios }
            );
            System.assertEquals(1, creado.creados, creado.filas[0].motivo);
            Case vacio = [
                SELECT Comentario_Principal__c, Comentario_Secundario__c
                FROM Case
                WHERE Id = :creado.filas[0].casoId
            ];
            System.assertEquals(null, vacio.Comentario_Principal__c);
            System.assertEquals(null, vacio.Comentario_Secundario__c);

            CargaMasivaCasosSE.FilaEntrada soloSecundario = filaBase(cuenta, operador.Id);
            soloSecundario.nroFila = 2;
            soloSecundario.comentarioSecundario = 'INFORMA VENTAS';
            CargaMasivaCasosSE.Resumen rechazado = CargaMasivaCasosSE.validar(
                new List<CargaMasivaCasosSE.FilaEntrada>{ soloSecundario }
            );
            System.assert(rechazado.filas[0].motivo.contains('Comentario Principal'));

            CargaMasivaCasosSE.FilaEntrada pareja = filaBase(cuenta, operador.Id);
            pareja.nroFila = 3;
            pareja.comentarioPrincipal = 'FISCALIZADA';
            pareja.comentarioSecundario = 'INFORMA VENTAS';
            CargaMasivaCasosSE.Resumen conPareja = CargaMasivaCasosSE.crear(
                new List<CargaMasivaCasosSE.FilaEntrada>{ pareja }
            );
            System.assertEquals(1, conPareja.creados, conPareja.filas[0].motivo);
            Case actual = [
                SELECT Comentario_Principal__c, Comentario_Secundario__c
                FROM Case
                WHERE Id = :conPareja.filas[0].casoId
            ];
            System.assertEquals('FISCALIZADA', actual.Comentario_Principal__c);
            System.assertEquals('INFORMA VENTAS', actual.Comentario_Secundario__c);
        }
    }

    @IsTest
    static void actualizaComentariosSoloEnPareja() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('20144462980', 'Productor Test SA');
            CargaMasivaCasosSE.Resumen creado = CargaMasivaCasosSE.crear(
                new List<CargaMasivaCasosSE.FilaEntrada>{ filaBase(cuenta, operador.Id) }
            );
            Id casoId = creado.filas[0].casoId;

            CargaMasivaCasosSE.FilaEntrada soloSecundario = new CargaMasivaCasosSE.FilaEntrada();
            soloSecundario.nroFila = 1;
            soloSecundario.idCaso = casoId;
            soloSecundario.comentarioSecundario = 'INFORMA VENTAS';
            CargaMasivaCasosSE.Resumen sinPrincipal = CargaMasivaCasosSE.validarEdicion(
                new List<CargaMasivaCasosSE.FilaEntrada>{ soloSecundario }
            );
            System.assert(sinPrincipal.filas[0].motivo.contains('Comentario Principal'));

            CargaMasivaCasosSE.FilaEntrada soloPrincipal = new CargaMasivaCasosSE.FilaEntrada();
            soloPrincipal.nroFila = 1;
            soloPrincipal.idCaso = casoId;
            soloPrincipal.comentarioPrincipal = 'FISCALIZADA';
            CargaMasivaCasosSE.Resumen principalSolo = CargaMasivaCasosSE.editar(
                new List<CargaMasivaCasosSE.FilaEntrada>{ soloPrincipal }
            );
            System.assertEquals(1, principalSolo.creados, principalSolo.filas[0].motivo);

            CargaMasivaCasosSE.FilaEntrada ajeno = new CargaMasivaCasosSE.FilaEntrada();
            ajeno.nroFila = 1;
            ajeno.idCaso = casoId;
            ajeno.comentarioPrincipal = 'FISCALIZADA';
            ajeno.comentarioSecundario = 'ALQUILO EL CAMPO';
            CargaMasivaCasosSE.Resumen noCorresponde = CargaMasivaCasosSE.validarEdicion(
                new List<CargaMasivaCasosSE.FilaEntrada>{ ajeno }
            );
            System.assert(noCorresponde.filas[0].motivo.contains('no corresponde'));

            CargaMasivaCasosSE.FilaEntrada pareja = new CargaMasivaCasosSE.FilaEntrada();
            pareja.nroFila = 1;
            pareja.idCaso = casoId;
            pareja.comentarioPrincipal = 'FISCALIZADA';
            pareja.comentarioSecundario = 'INFORMA VENTAS';
            CargaMasivaCasosSE.Resumen resultado = CargaMasivaCasosSE.editar(
                new List<CargaMasivaCasosSE.FilaEntrada>{ pareja }
            );
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Case actual = [
                SELECT Comentario_Principal__c, Comentario_Secundario__c
                FROM Case
                WHERE Id = :casoId
            ];
            System.assertEquals('FISCALIZADA', actual.Comentario_Principal__c);
            System.assertEquals('INFORMA VENTAS', actual.Comentario_Secundario__c);
        }
    }

    @IsTest
    static void rechazaEdicionSinDatosRepetidaODeOtroProceso() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Account cuenta = insertarCuenta('20144462980', 'Productor Test SA');
            CargaMasivaCasosSE.Resumen creado = CargaMasivaCasosSE.crear(
                new List<CargaMasivaCasosSE.FilaEntrada>{ filaBase(cuenta, operador.Id) }
            );
            Case otro = new Case(
                Subject = 'Otro proceso',
                Status = 'Abierto',
                Origin = 'Phone',
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                    .get('Venta_HT')
                    .getRecordTypeId()
            );
            insert otro;

            CargaMasivaCasosSE.FilaEntrada repetida = new CargaMasivaCasosSE.FilaEntrada();
            repetida.nroFila = 1;
            repetida.idCaso = creado.filas[0].casoId;
            repetida.estado = 'Cerrado';
            CargaMasivaCasosSE.FilaEntrada otraVez = new CargaMasivaCasosSE.FilaEntrada();
            otraVez.nroFila = 2;
            otraVez.idCaso = creado.filas[0].casoId;
            otraVez.inicio = 'Entrante';
            CargaMasivaCasosSE.FilaEntrada sinDatos = new CargaMasivaCasosSE.FilaEntrada();
            sinDatos.nroFila = 3;
            sinDatos.idCaso = otro.Id;
            CargaMasivaCasosSE.FilaEntrada otroProceso = new CargaMasivaCasosSE.FilaEntrada();
            otroProceso.nroFila = 4;
            otroProceso.idCaso = otro.Id;
            otroProceso.inicio = 'Saliente';

            CargaMasivaCasosSE.Resumen preview = CargaMasivaCasosSE.validarEdicion(
                new List<CargaMasivaCasosSE.FilaEntrada>{ repetida, otraVez, sinDatos, otroProceso }
            );
            System.assertEquals(0, preview.validos);
            System.assert(preview.filas[0].motivo.contains('repetido'));
            System.assert(preview.filas[1].motivo.contains('repetido'));
            System.assert(preview.filas[2].motivo.contains('No hay datos'));
            System.assert(preview.filas[3].motivo.contains('Sembrá Evolución'));
        }
    }

    private static CargaMasivaCasosSE.FilaEntrada filaBase(Account cuenta, Id ownerId) {
        CargaMasivaCasosSE.FilaEntrada fila = new CargaMasivaCasosSE.FilaEntrada();
        fila.nroFila = 2;
        fila.cuit = cuenta.N_CUIT__c;
        fila.razonSocial = cuenta.Name;
        fila.tipoRegistro = 'Sembra Evolucion';
        fila.estado = 'Abierto';
        fila.inicio = 'Saliente';
        fila.capsula = 'STINE';
        fila.idPropietario = ownerId;
        return fila;
    }

    private static Account insertarObtentor(String cuit, String nombre, String codigo) {
        Account cuenta = new Account(
            Name = nombre,
            N_CUIT__c = cuit,
            Type = 'Obtentor',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('Obtentor')
                .getRecordTypeId(),
            Id_Obtentor__c = codigo,
            Nombre_Obtentor__c = nombre
        );
        insert cuenta;
        return cuenta;
    }

    private static Account insertarCuenta(String cuit, String nombre) {
        Account cuenta = new Account(
            Name = nombre,
            N_CUIT__c = cuit,
            Type = 'Productor',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                .get('Productor')
                .getRecordTypeId()
        );
        insert cuenta;
        return cuenta;
    }

    private static User usuarioConPermiso() {
        User operador = insertarUsuario();
        insert new PermissionSetAssignment(
            AssigneeId = operador.Id,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :CargaMasivaCasosSE.PERMISO LIMIT 1].Id
        );
        return operador;
    }

    private static User usuarioSinPermiso() {
        return insertarUsuario();
    }

    private static User insertarUsuario() {
        Profile perfil = [
            SELECT Id
            FROM Profile
            WHERE Name IN ('System Administrator', 'Administrador del sistema')
            LIMIT 1
        ];
        String token = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));
        User operador = new User(
            Alias = 'cmse',
            Email = 'cmse' + token + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Carga Masiva',
            LanguageLocaleKey = 'es',
            LocaleSidKey = 'es_AR',
            ProfileId = perfil.Id,
            TimeZoneSidKey = 'America/Argentina/Buenos_Aires',
            Username = 'cmse' + token + '@example.com'
        );
        insert operador;
        return operador;
    }
}
