@IsTest
private class CargaMasivaGestionesSETest {

    @TestSetup
    static void setup() {
        Test_TestUtils.disableFlows();
    }

    @IsTest
    static void creaGestionEnCasoSe() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Case caso = casoSe(null, null);
            CargaMasivaGestionesSE.FilaEntrada fila = fila(String.valueOf(caso.Id).left(15), 'whatsapp', 'saliente');

            Test.startTest();
            CargaMasivaGestionesSE.Resumen preview = CargaMasivaGestionesSE.validar(new List<CargaMasivaGestionesSE.FilaEntrada>{ fila });
            CargaMasivaGestionesSE.Resumen resultado = CargaMasivaGestionesSE.crear(new List<CargaMasivaGestionesSE.FilaEntrada>{ fila });
            Test.stopTest();

            System.assertEquals(1, preview.validos);
            System.assertEquals(0, preview.conError);
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Gestion_Expedientes__c creada = [
                SELECT Caso__c, Medio__c, Tipo_Gestion__c, Operador__c, Name
                FROM Gestion_Expedientes__c
                WHERE Id = :resultado.filas[0].gestionId
            ];
            System.assertEquals(caso.Id, creada.Caso__c);
            System.assertEquals('WhatsApp', creada.Medio__c);
            System.assertEquals('Saliente', creada.Tipo_Gestion__c);
            System.assertEquals('Caso', creada.Operador__c);
            System.assert(creada.Name.startsWith('GE-'));
        }
    }

    @IsTest
    static void usaOperadorDeVentaHtFuturaSoja() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Case caso = casoSe('Venta HT', 'Futura Soja');
            CargaMasivaGestionesSE.FilaEntrada fila = fila(caso.Id, 'Email', 'Entrante');
            CargaMasivaGestionesSE.Resumen resultado = CargaMasivaGestionesSE.crear(
                new List<CargaMasivaGestionesSE.FilaEntrada>{ fila }
            );
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Gestion_Expedientes__c creada = [
                SELECT Operador__c FROM Gestion_Expedientes__c WHERE Id = :resultado.filas[0].gestionId
            ];
            System.assertEquals('Caso VHT', creada.Operador__c);
        }
    }

    @IsTest
    static void rechazaInvalidasYCreaLaValida() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Case caso = casoSe(null, null);
            Case otro = new Case(
                Subject = 'Otro proceso',
                Status = 'Abierto',
                Origin = 'Phone',
                RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                    .get('Venta_HT')
                    .getRecordTypeId()
            );
            insert otro;
            Case borrado = casoSe(null, null);
            Id idBorrado = borrado.Id;
            delete borrado;

            CargaMasivaGestionesSE.FilaEntrada valida = fila(caso.Id, 'Llamada', 'Saliente');
            valida.nroFila = 1;
            CargaMasivaGestionesSE.FilaEntrada medioMal = fila(caso.Id, 'Telegram', 'Entrante');
            medioMal.nroFila = 2;
            CargaMasivaGestionesSE.FilaEntrada tipoVacio = fila(caso.Id, 'Email', '');
            tipoVacio.nroFila = 3;
            CargaMasivaGestionesSE.FilaEntrada idMal = fila('123', 'WhatsApp', 'Saliente');
            idMal.nroFila = 4;
            CargaMasivaGestionesSE.FilaEntrada inexistente = fila(idBorrado, 'WhatsApp', 'Entrante');
            inexistente.nroFila = 5;
            CargaMasivaGestionesSE.FilaEntrada otroProceso = fila(otro.Id, 'WhatsApp', 'Saliente');
            otroProceso.nroFila = 6;

            List<CargaMasivaGestionesSE.FilaEntrada> filas = new List<CargaMasivaGestionesSE.FilaEntrada>{
                valida, medioMal, tipoVacio, idMal, inexistente, otroProceso
            };
            CargaMasivaGestionesSE.Resumen preview = CargaMasivaGestionesSE.validar(filas);
            System.assertEquals(6, preview.procesados);
            System.assertEquals(1, preview.validos);
            System.assertEquals(5, preview.conError);
            System.assert(preview.filas[1].motivo.contains('Medio'));
            System.assert(preview.filas[2].motivo.contains('Tipo de Gestión'));
            System.assert(preview.filas[3].motivo.contains('Id de Caso'));
            System.assert(preview.filas[4].motivo.contains('No existe'));
            System.assert(preview.filas[5].motivo.contains('Sembrá Evolución'));

            CargaMasivaGestionesSE.Resumen creado = CargaMasivaGestionesSE.crear(filas);
            System.assertEquals(1, creado.creados);
            System.assertEquals(1, [SELECT COUNT() FROM Gestion_Expedientes__c WHERE Caso__c = :caso.Id]);
        }
    }

    @IsTest
    static void sinPermisoNoValida() {
        User operador = usuarioSinPermiso();

        System.runAs(operador) {
            Boolean lanzo = false;
            try {
                CargaMasivaGestionesSE.validar(new List<CargaMasivaGestionesSE.FilaEntrada>{
                    fila('500000000000000', 'WhatsApp', 'Saliente')
                });
            } catch (AuraHandledException ex) {
                lanzo = true;
            }
            System.assert(lanzo, 'Sin el permiso custom no se puede validar');
            System.assertEquals(false, CargaMasivaGestionesSE.puedeUsar());
        }
    }

    @IsTest
    static void editaMedioSinCambiarElTipo() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Case caso = casoSe(null, null);
            CargaMasivaGestionesSE.Resumen creado = CargaMasivaGestionesSE.crear(
                new List<CargaMasivaGestionesSE.FilaEntrada>{ fila(caso.Id, 'WhatsApp', 'Saliente') }
            );
            System.assertEquals(1, creado.creados, creado.filas[0].motivo);

            CargaMasivaGestionesSE.FilaEntrada edicion = new CargaMasivaGestionesSE.FilaEntrada();
            edicion.nroFila = 1;
            edicion.idGestion = creado.filas[0].gestionId;
            edicion.medio = 'Email';

            CargaMasivaGestionesSE.Resumen resultado = CargaMasivaGestionesSE.editar(
                new List<CargaMasivaGestionesSE.FilaEntrada>{ edicion }
            );
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Gestion_Expedientes__c actual = [
                SELECT Medio__c, Tipo_Gestion__c
                FROM Gestion_Expedientes__c
                WHERE Id = :creado.filas[0].gestionId
            ];
            System.assertEquals('Email', actual.Medio__c);
            System.assertEquals('Saliente', actual.Tipo_Gestion__c);
        }
    }

    @IsTest
    static void editaPorNumeroDeGestion() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Case caso = casoSe(null, null);
            CargaMasivaGestionesSE.Resumen creado = CargaMasivaGestionesSE.crear(
                new List<CargaMasivaGestionesSE.FilaEntrada>{ fila(caso.Id, 'WhatsApp', 'Saliente') }
            );
            Gestion_Expedientes__c creada = [
                SELECT Name FROM Gestion_Expedientes__c WHERE Id = :creado.filas[0].gestionId
            ];
            String numero = creada.Name.substring(3).replaceFirst('^0+', '');
            if (String.isBlank(numero)) {
                numero = '0';
            }

            CargaMasivaGestionesSE.FilaEntrada edicion = new CargaMasivaGestionesSE.FilaEntrada();
            edicion.nroFila = 1;
            edicion.idGestion = numero;
            edicion.tipoGestion = 'Entrante';

            CargaMasivaGestionesSE.Resumen resultado = CargaMasivaGestionesSE.editar(
                new List<CargaMasivaGestionesSE.FilaEntrada>{ edicion }
            );
            System.assertEquals(1, resultado.creados, resultado.filas[0].motivo);

            Gestion_Expedientes__c actual = [
                SELECT Medio__c, Tipo_Gestion__c FROM Gestion_Expedientes__c WHERE Id = :creada.Id
            ];
            System.assertEquals('WhatsApp', actual.Medio__c);
            System.assertEquals('Entrante', actual.Tipo_Gestion__c);
        }
    }

    @IsTest
    static void rechazaEdicionSinDatosORepetida() {
        User operador = usuarioConPermiso();

        System.runAs(operador) {
            Case caso = casoSe(null, null);
            CargaMasivaGestionesSE.Resumen creado = CargaMasivaGestionesSE.crear(
                new List<CargaMasivaGestionesSE.FilaEntrada>{ fila(caso.Id, 'Llamada', 'Entrante') }
            );

            CargaMasivaGestionesSE.FilaEntrada repetida = new CargaMasivaGestionesSE.FilaEntrada();
            repetida.nroFila = 1;
            repetida.idGestion = creado.filas[0].gestionId;
            repetida.medio = 'Email';
            CargaMasivaGestionesSE.FilaEntrada otraVez = new CargaMasivaGestionesSE.FilaEntrada();
            otraVez.nroFila = 2;
            otraVez.idGestion = creado.filas[0].gestionId;
            otraVez.tipoGestion = 'Saliente';
            CargaMasivaGestionesSE.FilaEntrada sinDatos = new CargaMasivaGestionesSE.FilaEntrada();
            sinDatos.nroFila = 3;
            sinDatos.idGestion = creado.filas[0].gestionId;

            CargaMasivaGestionesSE.Resumen preview = CargaMasivaGestionesSE.validarEdicion(
                new List<CargaMasivaGestionesSE.FilaEntrada>{ repetida, otraVez, sinDatos }
            );
            System.assertEquals(0, preview.validos);
            System.assert(preview.filas[0].motivo.contains('repetida'));
            System.assert(preview.filas[2].motivo.contains('No hay datos'));
        }
    }

    private static CargaMasivaGestionesSE.FilaEntrada fila(Id casoId, String medio, String tipo) {
        return fila(String.valueOf(casoId), medio, tipo);
    }

    private static CargaMasivaGestionesSE.FilaEntrada fila(String casoId, String medio, String tipo) {
        CargaMasivaGestionesSE.FilaEntrada fila = new CargaMasivaGestionesSE.FilaEntrada();
        fila.nroFila = 1;
        fila.casoId = casoId;
        fila.medio = medio;
        fila.tipoGestion = tipo;
        return fila;
    }

    private static Case casoSe(String tipo, String tema) {
        Case caso = new Case(
            Subject = 'Caso SE gestiones',
            Status = 'Abierto',
            Origin = 'Phone',
            RecordTypeId = Schema.SObjectType.Case.getRecordTypeInfosByDeveloperName()
                .get('Sembra_Evolucion')
                .getRecordTypeId(),
            Type = tipo,
            Tema__c = tema
        );
        insert caso;
        return caso;
    }

    private static User usuarioConPermiso() {
        User operador = insertarUsuario();
        insert new PermissionSetAssignment(
            AssigneeId = operador.Id,
            PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = :CargaMasivaGestionesSE.PERMISO LIMIT 1].Id
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
            Alias = 'cmge',
            Email = 'cmge' + token + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Carga Gestiones',
            LanguageLocaleKey = 'es',
            LocaleSidKey = 'es_AR',
            ProfileId = perfil.Id,
            TimeZoneSidKey = 'America/Argentina/Buenos_Aires',
            Username = 'cmge' + token + '@example.com'
        );
        insert operador;
        return operador;
    }
}
