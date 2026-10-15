public with sharing class CargaMasivaCasosSE {

    public static final Integer LIMITE_FILAS = 200;
    public static final String PERMISO = 'Carga_Masiva_Casos_SE';

    @AuraEnabled(cacheable=true)
    public static Boolean puedeUsar() {
        return autorizado();
    }

    @AuraEnabled
    public static Resumen validar(List<FilaEntrada> filas) {
        exigirAutorizado();
        return procesar(filas, false);
    }

    @AuraEnabled
    public static Resumen crear(List<FilaEntrada> filas) {
        exigirAutorizado();
        return procesar(filas, true);
    }

    @AuraEnabled
    public static Resumen validarEdicion(List<FilaEntrada> filas) {
        exigirEdicion();
        return procesarEdicion(filas, false);
    }

    @AuraEnabled
    public static Resumen editar(List<FilaEntrada> filas) {
        exigirEdicion();
        return procesarEdicion(filas, true);
    }

    private static Resumen procesar(List<FilaEntrada> filas, Boolean insertar) {
        if (filas == null || filas.isEmpty()) {
            throw errorUsuario('El archivo no tiene filas para procesar.');
        }
        if (filas.size() > LIMITE_FILAS) {
            throw errorUsuario('Cada lote admite hasta ' + LIMITE_FILAS + ' filas.');
        }

        List<FilaTrabajo> trabajos = new List<FilaTrabajo>();
        Set<String> cuits = new Set<String>();
        Set<Id> propietarios = new Set<Id>();

        for (Integer i = 0; i < filas.size(); i++) {
            FilaEntrada entrada = filas[i];
            FilaTrabajo trabajo = new FilaTrabajo();
            trabajo.entrada = entrada == null ? new FilaEntrada() : entrada;
            trabajo.resultado = new FilaResultado();
            trabajo.resultado.nroFila = trabajo.entrada.nroFila == null ? i + 2 : trabajo.entrada.nroFila;
            trabajo.resultado.cuit = texto(trabajo.entrada.cuit);
            trabajo.resultado.razonSocial = '';
            trabajo.resultado.valido = false;
            trabajos.add(trabajo);

            evaluarFila(trabajo);
            if (trabajo.digitosCuit != null) {
                cuits.add(trabajo.digitosCuit);
                cuits.add(cuitConGuiones(trabajo.digitosCuit));
            }
            if (trabajo.ownerId != null) {
                propietarios.add(trabajo.ownerId);
            }
        }

        Map<String, List<Account>> cuentasPorCuit = buscarCuentas(cuits);
        Map<Id, User> usuarios = propietarios.isEmpty()
            ? new Map<Id, User>()
            : new Map<Id, User>([SELECT Id, IsActive FROM User WHERE Id IN :propietarios]);

        List<Case> aInsertar = new List<Case>();
        List<FilaTrabajo> pendientes = new List<FilaTrabajo>();

        for (FilaTrabajo trabajo : trabajos) {
            if (trabajo.motivo != null) {
                trabajo.resultado.motivo = trabajo.motivo;
                continue;
            }
            completarCuentaYOwner(trabajo, cuentasPorCuit, usuarios);
            if (trabajo.motivo != null) {
                trabajo.resultado.motivo = trabajo.motivo;
                continue;
            }
            trabajo.resultado.valido = true;
            trabajo.resultado.cuentaId = trabajo.cuenta.Id;
            trabajo.resultado.cuentaNombre = trabajo.cuenta.Name;
            if (insertar) {
                aInsertar.add(armarCaso(trabajo));
                pendientes.add(trabajo);
            }
        }

        if (insertar && !aInsertar.isEmpty()) {
            Database.SaveResult[] resultados;
            try {
                resultados = Database.insert(aInsertar, false, AccessLevel.USER_MODE);
            } catch (Exception ex) {
                throw errorUsuario(ex.getMessage());
            }
            Set<Id> creados = new Set<Id>();
            for (Integer i = 0; i < resultados.size(); i++) {
                FilaTrabajo trabajo = pendientes[i];
                if (resultados[i].isSuccess()) {
                    trabajo.resultado.casoId = resultados[i].getId();
                    creados.add(trabajo.resultado.casoId);
                } else {
                    trabajo.resultado.valido = false;
                    trabajo.resultado.casoId = null;
                    trabajo.resultado.motivo = mensajeDml(resultados[i].getErrors());
                }
            }
            if (!creados.isEmpty()) {
                Map<Id, Case> numeros = new Map<Id, Case>([
                    SELECT Id, CaseNumber FROM Case WHERE Id IN :creados
                ]);
                List<Case> asuntos = new List<Case>();
                List<FilaTrabajo> conNumero = new List<FilaTrabajo>();
                for (FilaTrabajo trabajo : pendientes) {
                    if (trabajo.resultado.casoId == null || !numeros.containsKey(trabajo.resultado.casoId)) {
                        continue;
                    }
                    trabajo.resultado.casoNumero = numeros.get(trabajo.resultado.casoId).CaseNumber;
                    trabajo.resultado.razonSocial = trabajo.cuenta.Name;
                    asuntos.add(new Case(
                        Id = trabajo.resultado.casoId,
                        Subject = asuntoSe(trabajo.cuenta.Name, trabajo.tipo, trabajo.tema, trabajo.resultado.casoNumero)
                    ));
                    conNumero.add(trabajo);
                }
                if (!asuntos.isEmpty()) {
                    Database.SaveResult[] ajustes = Database.update(asuntos, false, AccessLevel.USER_MODE);
                    for (Integer i = 0; i < ajustes.size(); i++) {
                        if (!ajustes[i].isSuccess()) {
                            conNumero[i].resultado.valido = false;
                            conNumero[i].resultado.motivo = mensajeDml(ajustes[i].getErrors());
                        }
                    }
                }
            }
        }

        Resumen resumen = new Resumen();
        for (FilaTrabajo trabajo : trabajos) {
            resumen.filas.add(trabajo.resultado);
            resumen.procesados++;
            if (trabajo.resultado.casoId != null) {
                resumen.creados++;
            }
            if (trabajo.resultado.valido) {
                resumen.validos++;
            } else {
                resumen.conError++;
            }
        }
        return resumen;
    }

    private static void evaluarFila(FilaTrabajo trabajo) {
        FilaEntrada entrada = trabajo.entrada;
        if (String.isBlank(entrada.cuit)) {
            trabajo.motivo = 'El CUIT es obligatorio.';
            return;
        }
        trabajo.digitosCuit = entrada.cuit.replaceAll('\\D', '');
        trabajo.resultado.cuit = trabajo.digitosCuit;
        if (!cuitValido(trabajo.digitosCuit)) {
            trabajo.motivo = 'El CUIT no tiene un formato válido.';
            return;
        }
        Schema.RecordTypeInfo tipoRegistro = resolverRecordType(entrada.tipoRegistro);
        if (tipoRegistro == null) {
            trabajo.motivo = String.isBlank(entrada.tipoRegistro)
                ? 'El tipo de registro del Caso es obligatorio.'
                : 'El tipo de registro "' + entrada.tipoRegistro.trim() + '" no existe.';
            return;
        }
        if (!tipoRegistro.isAvailable()) {
            trabajo.motivo = 'No tiene acceso al tipo de registro ' + tipoRegistro.getName() + '.';
            return;
        }
        trabajo.recordTypeId = tipoRegistro.getRecordTypeId();

        String estado = valorPicklist(Case.Status, entrada.estado);
        if (estado == null) {
            trabajo.motivo = String.isBlank(entrada.estado)
                ? 'El Estado es obligatorio.'
                : 'El Estado "' + entrada.estado.trim() + '" no es válido.';
            return;
        }
        trabajo.estado = estado;

        String tipo = valorOpcional(Case.Type, entrada.tipo);
        if (tipo == ERROR_PICKLIST) {
            trabajo.motivo = 'El Tipo "' + entrada.tipo.trim() + '" no es válido.';
            return;
        }
        trabajo.tipo = tipo;

        String tema = valorOpcional(Case.Tema__c, entrada.tema);
        if (tema == ERROR_PICKLIST) {
            trabajo.motivo = 'El Tema "' + entrada.tema.trim() + '" no es válido.';
            return;
        }
        trabajo.tema = tema;

        String inicio = valorPicklist(Case.Inicio__c, entrada.inicio);
        if (inicio == null) {
            trabajo.motivo = String.isBlank(entrada.inicio)
                ? 'Inicio es obligatorio. Use Entrante o Saliente.'
                : 'Inicio debe ser Entrante o Saliente.';
            return;
        }
        trabajo.inicio = inicio;

        String capsula = valorPicklist(Case.Capsula__c, entrada.capsula);
        if (capsula == null) {
            trabajo.motivo = String.isBlank(entrada.capsula)
                ? 'La Cápsula es obligatoria.'
                : 'La Cápsula "' + entrada.capsula.trim() + '" no es válida.';
            return;
        }
        trabajo.capsula = capsula;

        if (String.isBlank(entrada.idPropietario)) {
            trabajo.motivo = 'El ID Propietario es obligatorio.';
            return;
        }
        trabajo.ownerId = idUsuario(entrada.idPropietario);
        if (trabajo.ownerId == null) {
            trabajo.motivo = 'El ID Propietario no corresponde a un usuario de Salesforce.';
            return;
        }
        aplicarComentarios(trabajo);
    }

    private static void completarCuentaYOwner(
        FilaTrabajo trabajo,
        Map<String, List<Account>> cuentasPorCuit,
        Map<Id, User> usuarios
    ) {
        User propietario = usuarios.get(trabajo.ownerId);
        if (propietario == null || !propietario.IsActive) {
            trabajo.motivo = 'El propietario no existe o no está activo.';
            return;
        }

        List<Account> cuentas = cuentasPorCuit.get(trabajo.digitosCuit);
        if (cuentas == null || cuentas.isEmpty()) {
            trabajo.motivo = 'No se encontró una Cuenta visible con este CUIT.';
            return;
        }
        if (cuentas.size() > 1) {
            trabajo.motivo = 'Hay más de una Cuenta con este CUIT.';
            return;
        }
        trabajo.cuenta = cuentas[0];
        trabajo.resultado.razonSocial = trabajo.cuenta.Name;
    }

    private static Case armarCaso(FilaTrabajo trabajo) {
        Case caso = new Case();
        caso.AccountId = trabajo.cuenta.Id;
        caso.RecordTypeId = trabajo.recordTypeId;
        caso.Status = trabajo.estado;
        caso.Inicio__c = trabajo.inicio;
        caso.Capsula__c = trabajo.capsula;
        caso.OwnerId = trabajo.ownerId;
        caso.CUIT__c = trabajo.digitosCuit;
        caso.Subject = asuntoSe(trabajo.cuenta.Name, trabajo.tipo, trabajo.tema, null);
        if (trabajo.tipo != null) {
            caso.Type = trabajo.tipo;
        }
        if (trabajo.tema != null) {
            caso.Tema__c = trabajo.tema;
        }
        if (trabajo.comentarioPrincipal != null) {
            caso.Comentario_Principal__c = trabajo.comentarioPrincipal;
        }
        if (trabajo.comentarioSecundario != null) {
            caso.Comentario_Secundario__c = trabajo.comentarioSecundario;
        }
        return caso;
    }

    private static Map<String, List<Account>> buscarCuentas(Set<String> cuits) {
        Map<String, List<Account>> porCuit = new Map<String, List<Account>>();
        if (cuits.isEmpty()) {
            return porCuit;
        }
        for (Account cuenta : [
            SELECT Id, Name, N_CUIT__c
            FROM Account
            WHERE N_CUIT__c IN :cuits
        ]) {
            String digitos = cuenta.N_CUIT__c == null ? '' : cuenta.N_CUIT__c.replaceAll('\\D', '');
            if (!porCuit.containsKey(digitos)) {
                porCuit.put(digitos, new List<Account>());
            }
            porCuit.get(digitos).add(cuenta);
        }
        return porCuit;
    }

    private static Boolean autorizado() {
        return FeatureManagement.checkPermission(PERMISO) && Schema.sObjectType.Case.isCreateable();
    }

    private static void exigirAutorizado() {
        if (!FeatureManagement.checkPermission(PERMISO)) {
            throw errorUsuario('No está autorizado a usar la carga masiva de Casos.');
        }
        if (!Schema.sObjectType.Case.isCreateable()) {
            throw errorUsuario('No tiene permisos para crear Casos.');
        }
    }

    private static void exigirEdicion() {
        if (!FeatureManagement.checkPermission(PERMISO)) {
            throw errorUsuario('No está autorizado a usar la carga masiva de Casos.');
        }
        if (!Schema.sObjectType.Case.isUpdateable()) {
            throw errorUsuario('No tiene permisos para editar Casos.');
        }
    }

    private static Resumen procesarEdicion(List<FilaEntrada> filas, Boolean actualizar) {
        if (filas == null || filas.isEmpty()) {
            throw errorUsuario('El archivo no tiene filas para procesar.');
        }
        if (filas.size() > LIMITE_FILAS) {
            throw errorUsuario('Cada lote admite hasta ' + LIMITE_FILAS + ' filas.');
        }

        List<FilaTrabajo> trabajos = new List<FilaTrabajo>();
        Map<Id, Integer> repeticiones = new Map<Id, Integer>();
        Set<Id> propietarios = new Set<Id>();

        for (Integer i = 0; i < filas.size(); i++) {
            FilaEntrada entrada = filas[i] == null ? new FilaEntrada() : filas[i];
            FilaTrabajo trabajo = new FilaTrabajo();
            trabajo.entrada = entrada;
            trabajo.resultado = new FilaResultado();
            trabajo.resultado.nroFila = entrada.nroFila == null ? i + 1 : entrada.nroFila;
            trabajo.resultado.idInformado = texto(entrada.idCaso);
            trabajo.resultado.valido = false;
            trabajos.add(trabajo);
            evaluarEdicion(trabajo);
            if (trabajo.casoObjetivo != null && trabajo.motivo == null) {
                Integer veces = repeticiones.containsKey(trabajo.casoObjetivo) ? repeticiones.get(trabajo.casoObjetivo) : 0;
                repeticiones.put(trabajo.casoObjetivo, veces + 1);
            }
            if (trabajo.ownerId != null) {
                propietarios.add(trabajo.ownerId);
            }
        }

        for (FilaTrabajo trabajo : trabajos) {
            if (trabajo.motivo == null && trabajo.casoObjetivo != null && repeticiones.get(trabajo.casoObjetivo) > 1) {
                trabajo.motivo = 'El Id del Caso está repetido en el archivo.';
            }
        }

        Set<Id> idsCaso = repeticiones.keySet();
        Map<Id, Case> casos = idsCaso.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                SELECT Id, CaseNumber, Type, Tema__c, Account.Name, RecordType.DeveloperName
                FROM Case
                WHERE Id IN :idsCaso
            ]);
        Map<Id, User> usuarios = propietarios.isEmpty()
            ? new Map<Id, User>()
            : new Map<Id, User>([SELECT Id, IsActive FROM User WHERE Id IN :propietarios]);

        List<Case> aActualizar = new List<Case>();
        List<FilaTrabajo> pendientes = new List<FilaTrabajo>();
        for (FilaTrabajo trabajo : trabajos) {
            if (trabajo.motivo != null) {
                trabajo.resultado.motivo = trabajo.motivo;
                continue;
            }
            Case caso = casos.get(trabajo.casoObjetivo);
            if (caso == null) {
                trabajo.resultado.motivo = 'No existe un Caso con este Id o no tiene acceso.';
                continue;
            }
            trabajo.resultado.casoNumero = caso.CaseNumber;
            if (caso.RecordType == null || caso.RecordType.DeveloperName != 'Sembra_Evolucion') {
                trabajo.resultado.motivo = 'El Caso no es de Sembrá Evolución.';
                continue;
            }
            if (trabajo.ownerId != null) {
                User propietario = usuarios.get(trabajo.ownerId);
                if (propietario == null || !propietario.IsActive) {
                    trabajo.resultado.motivo = 'El propietario no existe o no está activo.';
                    continue;
                }
            }
            trabajo.resultado.valido = true;
            if (actualizar) {
                aActualizar.add(armarActualizacion(trabajo, caso));
                pendientes.add(trabajo);
            }
        }

        if (actualizar && !aActualizar.isEmpty()) {
            Database.SaveResult[] resultados;
            try {
                resultados = Database.update(aActualizar, false, AccessLevel.USER_MODE);
            } catch (Exception ex) {
                throw errorUsuario(ex.getMessage());
            }
            for (Integer i = 0; i < resultados.size(); i++) {
                FilaTrabajo trabajo = pendientes[i];
                if (resultados[i].isSuccess()) {
                    trabajo.resultado.casoId = trabajo.casoObjetivo;
                } else {
                    trabajo.resultado.valido = false;
                    trabajo.resultado.casoId = null;
                    trabajo.resultado.motivo = mensajeDml(resultados[i].getErrors());
                }
            }
        }

        Resumen resumen = new Resumen();
        for (FilaTrabajo trabajo : trabajos) {
            resumen.filas.add(trabajo.resultado);
            resumen.procesados++;
            if (trabajo.resultado.casoId != null) {
                resumen.creados++;
            }
            if (trabajo.resultado.valido) {
                resumen.validos++;
            } else {
                resumen.conError++;
            }
        }
        return resumen;
    }

    private static void evaluarEdicion(FilaTrabajo trabajo) {
        FilaEntrada entrada = trabajo.entrada;
        trabajo.casoObjetivo = idCaso(entrada.idCaso);
        if (trabajo.casoObjetivo == null) {
            trabajo.motivo = String.isBlank(entrada.idCaso)
                ? 'El Id del Caso es obligatorio.'
                : 'El Id del Caso no es válido.';
            return;
        }

        String estado = valorOpcional(Case.Status, entrada.estado);
        if (estado == ERROR_PICKLIST) {
            trabajo.motivo = 'El Estado "' + entrada.estado.trim() + '" no es válido.';
            return;
        }
        String tipo = valorOpcional(Case.Type, entrada.tipo);
        if (tipo == ERROR_PICKLIST) {
            trabajo.motivo = 'El Tipo "' + entrada.tipo.trim() + '" no es válido.';
            return;
        }
        String tema = valorOpcional(Case.Tema__c, entrada.tema);
        if (tema == ERROR_PICKLIST) {
            trabajo.motivo = 'El Tema "' + entrada.tema.trim() + '" no es válido.';
            return;
        }
        String inicio = valorOpcional(Case.Inicio__c, entrada.inicio);
        if (inicio == ERROR_PICKLIST) {
            trabajo.motivo = 'Inicio debe ser Entrante o Saliente.';
            return;
        }
        String capsula = valorOpcional(Case.Capsula__c, entrada.capsula);
        if (capsula == ERROR_PICKLIST) {
            trabajo.motivo = 'La Cápsula "' + entrada.capsula.trim() + '" no es válida.';
            return;
        }
        if (!String.isBlank(entrada.idPropietario)) {
            trabajo.ownerId = idUsuario(entrada.idPropietario);
            if (trabajo.ownerId == null) {
                trabajo.motivo = 'El ID Propietario no corresponde a un usuario de Salesforce.';
                return;
            }
        }
        aplicarComentarios(trabajo);
        if (trabajo.motivo != null) {
            return;
        }
        trabajo.descripcion = String.isBlank(entrada.descripcion) ? null : entrada.descripcion.trim();
        if (estado == null && tipo == null && tema == null && inicio == null && capsula == null
            && trabajo.ownerId == null && trabajo.comentarioPrincipal == null && trabajo.descripcion == null) {
            trabajo.motivo = 'No hay datos para actualizar.';
            return;
        }
        trabajo.estado = estado;
        trabajo.tipo = tipo;
        trabajo.tema = tema;
        trabajo.inicio = inicio;
        trabajo.capsula = capsula;
    }

    private static void aplicarComentarios(FilaTrabajo trabajo) {
        FilaEntrada entrada = trabajo.entrada;
        String comentarioPrincipal = valorOpcional(Case.Comentario_Principal__c, entrada.comentarioPrincipal);
        if (comentarioPrincipal == ERROR_PICKLIST) {
            trabajo.motivo = 'El Comentario Principal "' + entrada.comentarioPrincipal.trim() + '" no es válido.';
            return;
        }
        String comentarioSecundario = valorOpcional(Case.Comentario_Secundario__c, entrada.comentarioSecundario);
        if (comentarioSecundario == ERROR_PICKLIST) {
            trabajo.motivo = 'El Comentario Secundario "' + entrada.comentarioSecundario.trim() + '" no es válido.';
            return;
        }
        if (comentarioSecundario != null && comentarioPrincipal == null) {
            trabajo.motivo = 'El Comentario Secundario no se actualiza si no viene el Comentario Principal.';
            return;
        }
        if (comentarioPrincipal != null && comentarioSecundario != null
            && !secundarioCorresponde(comentarioPrincipal, comentarioSecundario)) {
            trabajo.motivo = 'El Comentario Secundario no corresponde al Comentario Principal.';
            return;
        }
        trabajo.comentarioPrincipal = comentarioPrincipal;
        trabajo.comentarioSecundario = comentarioSecundario;
    }

    private static Case armarActualizacion(FilaTrabajo trabajo, Case actual) {
        Case caso = new Case(Id = trabajo.casoObjetivo);
        if (trabajo.tipo != null || trabajo.tema != null) {
            String tipoFinal = trabajo.tipo == null ? actual.Type : trabajo.tipo;
            String temaFinal = trabajo.tema == null ? actual.Tema__c : trabajo.tema;
            String nombre = actual.Account == null ? null : actual.Account.Name;
            caso.Subject = asuntoSe(nombre, tipoFinal, temaFinal, actual.CaseNumber);
        }
        if (trabajo.estado != null) {
            caso.Status = trabajo.estado;
        }
        if (trabajo.inicio != null) {
            caso.Inicio__c = trabajo.inicio;
        }
        if (trabajo.capsula != null) {
            caso.Capsula__c = trabajo.capsula;
        }
        if (trabajo.ownerId != null) {
            caso.OwnerId = trabajo.ownerId;
        }
        if (trabajo.tipo != null) {
            caso.Type = trabajo.tipo;
        }
        if (trabajo.tema != null) {
            caso.Tema__c = trabajo.tema;
        }
        if (trabajo.comentarioPrincipal != null) {
            caso.Comentario_Principal__c = trabajo.comentarioPrincipal;
        }
        if (trabajo.comentarioSecundario != null) {
            caso.Comentario_Secundario__c = trabajo.comentarioSecundario;
        }
        if (trabajo.descripcion != null) {
            caso.Description = trabajo.descripcion;
        }
        return caso;
    }

    private static Id idCaso(String raw) {
        String limpio = raw == null ? '' : raw.trim();
        if (limpio.length() != 15 && limpio.length() != 18) {
            return null;
        }
        try {
            Id candidato = (Id) limpio;
            return candidato.getSObjectType() == Case.SObjectType ? candidato : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static AuraHandledException errorUsuario(String mensaje) {
        AuraHandledException ex = new AuraHandledException(mensaje);
        ex.setMessage(mensaje);
        return ex;
    }

    private static Boolean cuitValido(String digitos) {
        if (digitos == null || digitos.length() != 11 || !digitos.isNumeric()) {
            return false;
        }
        List<Integer> pesos = new List<Integer>{ 5, 4, 3, 2, 7, 6, 5, 4, 3, 2 };
        Integer suma = 0;
        for (Integer i = 0; i < 10; i++) {
            suma += Integer.valueOf(digitos.substring(i, i + 1)) * pesos[i];
        }
        Integer resto = Math.mod(suma, 11);
        Integer verificador = 11 - resto;
        if (verificador == 11) {
            verificador = 0;
        } else if (verificador == 10) {
            verificador = 9;
        }
        return verificador == Integer.valueOf(digitos.substring(10, 11));
    }

    private static String cuitConGuiones(String digitos) {
        return digitos.substring(0, 2) + '-' + digitos.substring(2, 10) + '-' + digitos.substring(10);
    }

    private static Id idUsuario(String raw) {
        String limpio = raw == null ? '' : raw.trim();
        if (limpio.length() != 15 && limpio.length() != 18) {
            return null;
        }
        try {
            Id candidato = (Id) limpio;
            return candidato.getSObjectType() == User.SObjectType ? candidato : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static Schema.RecordTypeInfo resolverRecordType(String informado) {
        if (String.isBlank(informado)) {
            return null;
        }
        String buscado = clave(informado);
        Schema.RecordTypeInfo encontrado = null;
        for (Schema.RecordTypeInfo info : Schema.SObjectType.Case.getRecordTypeInfos()) {
            if (info.isMaster() || !info.isActive()) {
                continue;
            }
            if (clave(info.getDeveloperName()) == buscado || clave(info.getName()) == buscado) {
                if (info.isAvailable()) {
                    return info;
                }
                encontrado = info;
            }
        }
        return encontrado;
    }

    private static final String ERROR_PICKLIST = '__INVALID__';
    private static Map<String, Map<String, String>> cachePicklist = new Map<String, Map<String, String>>();

    private static String valorOpcional(Schema.SObjectField campo, String informado) {
        if (String.isBlank(informado)) {
            return null;
        }
        String valor = valorPicklist(campo, informado);
        return valor == null ? ERROR_PICKLIST : valor;
    }

    private static String valorPicklist(Schema.SObjectField campo, String informado) {
        if (String.isBlank(informado)) {
            return null;
        }
        String api = String.valueOf(campo);
        if (!cachePicklist.containsKey(api)) {
            Map<String, String> mapa = new Map<String, String>();
            for (Schema.PicklistEntry entrada : campo.getDescribe().getPicklistValues()) {
                if (!entrada.isActive()) {
                    continue;
                }
                mapa.put(clave(entrada.getValue()), entrada.getValue());
                mapa.put(clave(entrada.getLabel()), entrada.getValue());
            }
            cachePicklist.put(api, mapa);
        }
        return cachePicklist.get(api).get(clave(informado));
    }

    private static Map<String, Set<String>> secundariosPorPrincipal;

    private static Boolean secundarioCorresponde(String principal, String secundario) {
        if (secundariosPorPrincipal == null) {
            secundariosPorPrincipal = dependientes(Case.Comentario_Secundario__c);
        }
        Set<String> permitidos = secundariosPorPrincipal.get(principal);
        return permitidos != null && permitidos.contains(secundario);
    }

    private static Map<String, Set<String>> dependientes(Schema.SObjectField campo) {
        Map<String, Set<String>> porControl = new Map<String, Set<String>>();
        Schema.DescribeFieldResult describe = campo.getDescribe();
        Schema.SObjectField controlador = describe.getController();
        if (controlador == null) {
            return porControl;
        }
        List<Schema.PicklistEntry> controles = controlador.getDescribe().getPicklistValues();
        String base64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        for (Schema.PicklistEntry entrada : describe.getPicklistValues()) {
            if (!entrada.isActive()) {
                continue;
            }
            Map<String, Object> serializada = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(entrada));
            String validFor = (String) serializada.get('validFor');
            if (String.isBlank(validFor)) {
                continue;
            }
            for (Integer index = 0; index < controles.size(); index++) {
                if (!controles[index].isActive()) {
                    continue;
                }
                Integer bitIndex = index / 6;
                if (bitIndex >= validFor.length()) {
                    break;
                }
                Integer bitShift = 5 - Math.mod(index, 6);
                Integer bits = base64.indexOf(validFor.substring(bitIndex, bitIndex + 1));
                if (bits < 0 || (bits & (1 << bitShift)) == 0) {
                    continue;
                }
                String control = controles[index].getValue();
                if (!porControl.containsKey(control)) {
                    porControl.put(control, new Set<String>());
                }
                porControl.get(control).add(entrada.getValue());
            }
        }
        return porControl;
    }

    private static String clave(String valor) {
        if (valor == null) {
            return '';
        }
        String limpio = valor.trim().toLowerCase();
        limpio = limpio.replace('á', 'a').replace('é', 'e').replace('í', 'i').replace('ó', 'o').replace('ú', 'u');
        limpio = limpio.replace('ü', 'u').replace('ñ', 'n');
        return limpio.replaceAll('[^a-z0-9]', '');
    }

    private static String normalizarNombre(String valor) {
        return clave(valor);
    }

    private static String texto(String valor) {
        return valor == null ? '' : valor.trim();
    }

    private static String asuntoSe(String nombreCuenta, String tipo, String tema, String numero) {
        String nombre = nombreCuenta == null ? '' : nombreCuenta;
        if (nombre.length() > 20) {
            nombre = nombre.substring(0, 20);
        }
        String base = 'SE-' + nombre + '-' + (tipo == null ? '' : tipo) + '-' + (tema == null ? '' : tema) + '-' + (numero == null ? '' : numero);
        return base.length() > 255 ? base.substring(0, 255) : base;
    }

    private static String mensajeDml(Database.Error[] errores) {
        List<String> partes = new List<String>();
        for (Database.Error error : errores) {
            partes.add(error.getMessage());
        }
        return String.join(partes, ' ');
    }

    private class FilaTrabajo {
        private FilaEntrada entrada;
        private FilaResultado resultado;
        private String motivo;
        private String digitosCuit;
        private Id recordTypeId;
        private Id ownerId;
        private Account cuenta;
        private Id casoObjetivo;
        private String estado;
        private String tipo;
        private String tema;
        private String inicio;
        private String capsula;
        private String comentarioPrincipal;
        private String comentarioSecundario;
        private String descripcion;
    }

    public class FilaEntrada {
        @AuraEnabled public Integer nroFila { get; set; }
        @AuraEnabled public String cuit { get; set; }
        @AuraEnabled public String razonSocial { get; set; }
        @AuraEnabled public String tipoRegistro { get; set; }
        @AuraEnabled public String estado { get; set; }
        @AuraEnabled public String tipo { get; set; }
        @AuraEnabled public String tema { get; set; }
        @AuraEnabled public String inicio { get; set; }
        @AuraEnabled public String capsula { get; set; }
        @AuraEnabled public String idPropietario { get; set; }
        @AuraEnabled public String idCaso { get; set; }
        @AuraEnabled public String comentarioPrincipal { get; set; }
        @AuraEnabled public String comentarioSecundario { get; set; }
        @AuraEnabled public String descripcion { get; set; }
    }

    public class FilaResultado {
        @AuraEnabled public Integer nroFila { get; set; }
        @AuraEnabled public String cuit { get; set; }
        @AuraEnabled public String razonSocial { get; set; }
        @AuraEnabled public Id cuentaId { get; set; }
        @AuraEnabled public String cuentaNombre { get; set; }
        @AuraEnabled public Boolean valido { get; set; }
        @AuraEnabled public String motivo { get; set; }
        @AuraEnabled public Id casoId { get; set; }
        @AuraEnabled public String casoNumero { get; set; }
        @AuraEnabled public String idInformado { get; set; }
    }

    public class Resumen {
        @AuraEnabled public Integer procesados { get; set; }
        @AuraEnabled public Integer validos { get; set; }
        @AuraEnabled public Integer conError { get; set; }
        @AuraEnabled public Integer creados { get; set; }
        @AuraEnabled public List<FilaResultado> filas { get; set; }

        public Resumen() {
            this.procesados = 0;
            this.validos = 0;
            this.conError = 0;
            this.creados = 0;
            this.filas = new List<FilaResultado>();
        }
    }
}
