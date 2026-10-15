public with sharing class CargaMasivaGestionesSE {

    public static final Integer LIMITE_FILAS = 100;
    public static final String PERMISO = 'Carga_Masiva_Gestiones_SE';

    private static final String RT_SEMBRA = 'Sembra_Evolucion';
    private static final String TIPO_VENTA_HT = 'Venta HT';
    private static final String TEMA_FUTURA_SOJA = 'Futura Soja';
    private static final String OPERADOR_CASO = 'Caso';
    private static final String OPERADOR_CASO_VHT = 'Caso VHT';

    private static final Map<String, String> MEDIOS = new Map<String, String>{
        'whatsapp' => 'WhatsApp',
        'email' => 'Email',
        'llamada' => 'Llamada'
    };
    private static final Map<String, String> TIPOS = new Map<String, String>{
        'entrante' => 'Entrante',
        'saliente' => 'Saliente'
    };

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
        Set<Id> casoIds = new Set<Id>();
        Set<Id> propietarios = new Set<Id>();
        for (Integer i = 0; i < filas.size(); i++) {
            FilaEntrada entrada = filas[i] == null ? new FilaEntrada() : filas[i];
            FilaTrabajo trabajo = new FilaTrabajo();
            trabajo.entrada = entrada;
            trabajo.resultado = new FilaResultado();
            trabajo.resultado.nroFila = entrada.nroFila == null ? i + 1 : entrada.nroFila;
            trabajo.resultado.casoIdTexto = texto(entrada.casoId);
            trabajo.resultado.medio = texto(entrada.medio);
            trabajo.resultado.tipoGestion = texto(entrada.tipoGestion);
            trabajo.resultado.valido = false;
            trabajos.add(trabajo);

            evaluarFila(trabajo);
            if (trabajo.casoId != null) {
                casoIds.add(trabajo.casoId);
            }
            if (trabajo.ownerId != null) {
                propietarios.add(trabajo.ownerId);
            }
        }
        Map<Id, User> usuarios = propietarios.isEmpty()
            ? new Map<Id, User>()
            : new Map<Id, User>([SELECT Id, IsActive FROM User WHERE Id IN :propietarios]);

        Map<Id, Case> casos = casoIds.isEmpty()
            ? new Map<Id, Case>()
            : new Map<Id, Case>([
                SELECT Id, CaseNumber, Type, Tema__c, RecordType.DeveloperName
                FROM Case
                WHERE Id IN :casoIds
            ]);

        List<Gestion_Expedientes__c> aInsertar = new List<Gestion_Expedientes__c>();
        List<FilaTrabajo> pendientes = new List<FilaTrabajo>();
        for (FilaTrabajo trabajo : trabajos) {
            if (trabajo.motivo != null) {
                trabajo.resultado.motivo = trabajo.motivo;
                continue;
            }
            completarCaso(trabajo, casos);
            if (trabajo.motivo != null) {
                trabajo.resultado.motivo = trabajo.motivo;
                continue;
            }
            completarDatos(trabajo);
            if (trabajo.motivo != null) {
                trabajo.resultado.motivo = trabajo.motivo;
                continue;
            }
            if (!propietarioActivo(usuarios, trabajo.ownerId)) {
                trabajo.resultado.motivo = 'El propietario no existe o no está activo.';
                continue;
            }
            trabajo.resultado.valido = true;
            trabajo.resultado.casoId = trabajo.caso.Id;
            trabajo.resultado.casoNumero = trabajo.caso.CaseNumber;
            trabajo.resultado.medio = trabajo.medio;
            trabajo.resultado.tipoGestion = trabajo.tipoGestion;
            if (insertar) {
                aInsertar.add(armarGestion(trabajo));
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
                    trabajo.resultado.gestionId = resultados[i].getId();
                    creados.add(trabajo.resultado.gestionId);
                } else {
                    trabajo.resultado.valido = false;
                    trabajo.resultado.gestionId = null;
                    trabajo.resultado.motivo = mensajeDml(resultados[i].getErrors());
                }
            }
            if (!creados.isEmpty()) {
                Map<Id, Gestion_Expedientes__c> nombres = new Map<Id, Gestion_Expedientes__c>([
                    SELECT Id, Name FROM Gestion_Expedientes__c WHERE Id IN :creados
                ]);
                for (FilaTrabajo trabajo : pendientes) {
                    if (trabajo.resultado.gestionId != null && nombres.containsKey(trabajo.resultado.gestionId)) {
                        trabajo.resultado.gestionNombre = nombres.get(trabajo.resultado.gestionId).Name;
                    }
                }
            }
        }

        Resumen resumen = new Resumen();
        for (FilaTrabajo trabajo : trabajos) {
            resumen.filas.add(trabajo.resultado);
            resumen.procesados++;
            if (trabajo.resultado.valido) {
                resumen.validos++;
            } else {
                resumen.conError++;
            }
            if (trabajo.resultado.gestionId != null) {
                resumen.creados++;
            }
        }
        return resumen;
    }

    private static void evaluarFila(FilaTrabajo trabajo) {
        trabajo.casoId = idCaso(trabajo.resultado.casoIdTexto, trabajo);
        if (trabajo.motivo != null) {
            return;
        }
        trabajo.medio = valorPermitido(trabajo.resultado.medio, MEDIOS);
        if (trabajo.medio == null) {
            trabajo.motivo = String.isBlank(trabajo.resultado.medio)
                ? 'El Medio es obligatorio.'
                : 'El Medio tiene que ser WhatsApp, Email o Llamada.';
            return;
        }
        trabajo.tipoGestion = valorPermitido(trabajo.resultado.tipoGestion, TIPOS);
        if (trabajo.tipoGestion == null) {
            trabajo.motivo = String.isBlank(trabajo.resultado.tipoGestion)
                ? 'El Tipo de Gestión es obligatorio.'
                : 'El Tipo de Gestión tiene que ser Entrante o Saliente.';
            return;
        }
        if (String.isBlank(trabajo.entrada.idPropietario)) {
            trabajo.motivo = 'El ID Propietario es obligatorio.';
            return;
        }
        trabajo.ownerId = idUsuario(trabajo.entrada.idPropietario);
        if (trabajo.ownerId == null) {
            trabajo.motivo = 'El ID Propietario no corresponde a un usuario de Salesforce.';
        }
    }

    private static void completarCaso(FilaTrabajo trabajo, Map<Id, Case> casos) {
        Case caso = casos.get(trabajo.casoId);
        if (caso == null) {
            trabajo.motivo = 'No existe un Caso con este Id o no tiene acceso.';
            return;
        }
        if (caso.RecordType == null || caso.RecordType.DeveloperName != RT_SEMBRA) {
            trabajo.motivo = 'El Caso no es de Sembrá Evolución.';
            return;
        }
        trabajo.caso = caso;
    }

    private static void completarDatos(FilaTrabajo trabajo) {
        String operador = operadorDeCaso(trabajo.caso);
        trabajo.respuesta = valorOpcional(Gestion_Expedientes__c.Respuesta__c, trabajo.entrada.respuesta);
        if (trabajo.respuesta == ERROR_PICKLIST) {
            trabajo.motivo = 'La Respuesta "' + trabajo.entrada.respuesta.trim() + '" no es válida.';
            return;
        }
        if (trabajo.respuesta != null && !respuestaCorresponde(operador, trabajo.respuesta)) {
            trabajo.motivo = 'La Respuesta no corresponde al operador del caso.';
            return;
        }
        trabajo.efectividad = valorOpcional(Gestion_Expedientes__c.Efectividad__c, trabajo.entrada.efectividad);
        if (trabajo.efectividad == ERROR_PICKLIST) {
            trabajo.motivo = 'La Efectividad "' + trabajo.entrada.efectividad.trim() + '" no es válida.';
            return;
        }
        trabajo.celular = textoOpcional(trabajo.entrada.celular);
        trabajo.comentario = textoOpcional(trabajo.entrada.comentario);
    }

    private static Gestion_Expedientes__c armarGestion(FilaTrabajo trabajo) {
        Gestion_Expedientes__c gestion = new Gestion_Expedientes__c(
            Caso__c = trabajo.caso.Id,
            Medio__c = trabajo.medio,
            Tipo_Gestion__c = trabajo.tipoGestion,
            Operador__c = operadorDeCaso(trabajo.caso),
            OwnerId = trabajo.ownerId
        );
        if (trabajo.respuesta != null) {
            gestion.Respuesta__c = trabajo.respuesta;
        }
        if (trabajo.efectividad != null) {
            gestion.Efectividad__c = trabajo.efectividad;
        }
        if (trabajo.celular != null) {
            gestion.Celular__c = trabajo.celular;
        }
        if (trabajo.comentario != null) {
            gestion.Comentario__c = trabajo.comentario;
        }
        return gestion;
    }

    private static String operadorDeCaso(Case caso) {
        if (caso.Type == TIPO_VENTA_HT && caso.Tema__c == TEMA_FUTURA_SOJA) {
            return OPERADOR_CASO_VHT;
        }
        return OPERADOR_CASO;
    }

    private static Id idCaso(String valor, FilaTrabajo trabajo) {
        if (String.isBlank(valor)) {
            trabajo.motivo = 'El Caso_ID es obligatorio.';
            return null;
        }
        String limpio = valor.trim();
        String prefijo = Case.SObjectType.getDescribe().getKeyPrefix();
        if ((limpio.length() != 15 && limpio.length() != 18) || !limpio.startsWith(prefijo)) {
            trabajo.motivo = 'El Caso_ID no es un Id de Caso válido.';
            return null;
        }
        try {
            return (Id) limpio;
        } catch (Exception ex) {
            trabajo.motivo = 'El Caso_ID no es un Id de Caso válido.';
            return null;
        }
    }

    private static String valorPermitido(String valor, Map<String, String> permitidos) {
        if (String.isBlank(valor)) {
            return null;
        }
        return permitidos.get(valor.trim().toLowerCase());
    }

    private static Boolean autorizado() {
        return FeatureManagement.checkPermission(PERMISO)
            && Schema.sObjectType.Gestion_Expedientes__c.isCreateable();
    }

    private static void exigirAutorizado() {
        if (!FeatureManagement.checkPermission(PERMISO)) {
            throw errorUsuario('No está autorizado a usar la carga masiva de Gestiones.');
        }
        if (!Schema.sObjectType.Gestion_Expedientes__c.isCreateable()) {
            throw errorUsuario('No tiene permisos para crear Gestiones.');
        }
    }

    private static void exigirEdicion() {
        if (!FeatureManagement.checkPermission(PERMISO)) {
            throw errorUsuario('No está autorizado a usar la carga masiva de Gestiones.');
        }
        if (!Schema.sObjectType.Gestion_Expedientes__c.isUpdateable()) {
            throw errorUsuario('No tiene permisos para editar Gestiones.');
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
        Set<String> nombres = new Set<String>();
        Set<Id> propietarios = new Set<Id>();
        for (Integer i = 0; i < filas.size(); i++) {
            FilaEntrada entrada = filas[i] == null ? new FilaEntrada() : filas[i];
            FilaTrabajo trabajo = new FilaTrabajo();
            trabajo.entrada = entrada;
            trabajo.resultado = new FilaResultado();
            trabajo.resultado.nroFila = entrada.nroFila == null ? i + 1 : entrada.nroFila;
            trabajo.resultado.idInformado = texto(entrada.idGestion);
            trabajo.resultado.medio = texto(entrada.medio);
            trabajo.resultado.tipoGestion = texto(entrada.tipoGestion);
            trabajo.resultado.valido = false;
            trabajos.add(trabajo);
            evaluarEdicion(trabajo);
            if (trabajo.ownerId != null) {
                propietarios.add(trabajo.ownerId);
            }
            if (trabajo.motivo == null && trabajo.gestionObjetivo == null && trabajo.nombreGestion != null) {
                nombres.add(trabajo.nombreGestion);
            }
        }

        Map<String, Id> idPorNombre = new Map<String, Id>();
        if (!nombres.isEmpty()) {
            for (Gestion_Expedientes__c gestion : [
                SELECT Id, Name FROM Gestion_Expedientes__c WHERE Name IN :nombres
            ]) {
                idPorNombre.put(gestion.Name, gestion.Id);
            }
        }

        Map<Id, Integer> repeticiones = new Map<Id, Integer>();
        for (FilaTrabajo trabajo : trabajos) {
            if (trabajo.motivo != null) {
                continue;
            }
            if (trabajo.gestionObjetivo == null) {
                trabajo.gestionObjetivo = idPorNombre.get(trabajo.nombreGestion);
                if (trabajo.gestionObjetivo == null) {
                    trabajo.motivo = 'No existe una Gestión con este número o no tiene acceso.';
                    continue;
                }
            }
            Integer veces = repeticiones.containsKey(trabajo.gestionObjetivo) ? repeticiones.get(trabajo.gestionObjetivo) : 0;
            repeticiones.put(trabajo.gestionObjetivo, veces + 1);
        }

        for (FilaTrabajo trabajo : trabajos) {
            if (trabajo.motivo == null && trabajo.gestionObjetivo != null && repeticiones.get(trabajo.gestionObjetivo) > 1) {
                trabajo.motivo = 'La Gestión está repetida en el archivo.';
            }
        }

        Map<Id, User> usuarios = propietarios.isEmpty()
            ? new Map<Id, User>()
            : new Map<Id, User>([SELECT Id, IsActive FROM User WHERE Id IN :propietarios]);
        Set<Id> idsGestion = repeticiones.keySet();
        Map<Id, Gestion_Expedientes__c> gestiones = idsGestion.isEmpty()
            ? new Map<Id, Gestion_Expedientes__c>()
            : new Map<Id, Gestion_Expedientes__c>([
                SELECT Id, Name, Operador__c, Caso__c, Caso__r.CaseNumber, Caso__r.RecordType.DeveloperName
                FROM Gestion_Expedientes__c
                WHERE Id IN :idsGestion
            ]);

        List<Gestion_Expedientes__c> aActualizar = new List<Gestion_Expedientes__c>();
        List<FilaTrabajo> pendientes = new List<FilaTrabajo>();
        for (FilaTrabajo trabajo : trabajos) {
            if (trabajo.motivo != null) {
                trabajo.resultado.motivo = trabajo.motivo;
                continue;
            }
            Gestion_Expedientes__c gestion = gestiones.get(trabajo.gestionObjetivo);
            if (gestion == null) {
                trabajo.resultado.motivo = 'No existe una Gestión con este Id o no tiene acceso.';
                continue;
            }
            trabajo.resultado.gestionNombre = gestion.Name;
            trabajo.resultado.casoNumero = gestion.Caso__r == null ? null : gestion.Caso__r.CaseNumber;
            if (gestion.Caso__c == null || gestion.Caso__r.RecordType == null
                || gestion.Caso__r.RecordType.DeveloperName != RT_SEMBRA) {
                trabajo.resultado.motivo = 'La Gestión no pertenece a un Caso de Sembrá Evolución.';
                continue;
            }
            if (trabajo.respuesta != null && !respuestaCorresponde(gestion.Operador__c, trabajo.respuesta)) {
                trabajo.resultado.motivo = 'La Respuesta no corresponde al operador de la Gestión.';
                continue;
            }
            if (trabajo.ownerId != null && !propietarioActivo(usuarios, trabajo.ownerId)) {
                trabajo.resultado.motivo = 'El propietario no existe o no está activo.';
                continue;
            }
            trabajo.resultado.casoId = gestion.Caso__c;
            trabajo.resultado.medio = trabajo.medio == null ? trabajo.resultado.medio : trabajo.medio;
            trabajo.resultado.tipoGestion = trabajo.tipoGestion == null ? trabajo.resultado.tipoGestion : trabajo.tipoGestion;
            trabajo.resultado.valido = true;
            if (actualizar) {
                aActualizar.add(armarActualizacion(trabajo));
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
                    trabajo.resultado.gestionId = trabajo.gestionObjetivo;
                } else {
                    trabajo.resultado.valido = false;
                    trabajo.resultado.gestionId = null;
                    trabajo.resultado.motivo = mensajeDml(resultados[i].getErrors());
                }
            }
        }

        Resumen resumen = new Resumen();
        for (FilaTrabajo trabajo : trabajos) {
            resumen.filas.add(trabajo.resultado);
            resumen.procesados++;
            if (trabajo.resultado.valido) {
                resumen.validos++;
            } else {
                resumen.conError++;
            }
            if (trabajo.resultado.gestionId != null) {
                resumen.creados++;
            }
        }
        return resumen;
    }

    private static void evaluarEdicion(FilaTrabajo trabajo) {
        String informado = texto(trabajo.entrada.idGestion);
        if (String.isBlank(informado)) {
            trabajo.motivo = 'El Id o el número de la Gestión es obligatorio.';
            return;
        }
        trabajo.gestionObjetivo = idGestion(informado);
        if (trabajo.gestionObjetivo == null) {
            trabajo.nombreGestion = numeroGestion(informado);
            if (trabajo.nombreGestion == null) {
                trabajo.motivo = 'El Id o el número de la Gestión no es válido.';
                return;
            }
        }
        if (!String.isBlank(trabajo.entrada.medio)) {
            trabajo.medio = valorPermitido(trabajo.entrada.medio, MEDIOS);
            if (trabajo.medio == null) {
                trabajo.motivo = 'El Medio tiene que ser WhatsApp, Email o Llamada.';
                return;
            }
        }
        if (!String.isBlank(trabajo.entrada.tipoGestion)) {
            trabajo.tipoGestion = valorPermitido(trabajo.entrada.tipoGestion, TIPOS);
            if (trabajo.tipoGestion == null) {
                trabajo.motivo = 'El Tipo de Gestión tiene que ser Entrante o Saliente.';
                return;
            }
        }
        trabajo.respuesta = valorOpcional(Gestion_Expedientes__c.Respuesta__c, trabajo.entrada.respuesta);
        if (trabajo.respuesta == ERROR_PICKLIST) {
            trabajo.motivo = 'La Respuesta "' + trabajo.entrada.respuesta.trim() + '" no es válida.';
            return;
        }
        trabajo.efectividad = valorOpcional(Gestion_Expedientes__c.Efectividad__c, trabajo.entrada.efectividad);
        if (trabajo.efectividad == ERROR_PICKLIST) {
            trabajo.motivo = 'La Efectividad "' + trabajo.entrada.efectividad.trim() + '" no es válida.';
            return;
        }
        trabajo.celular = textoOpcional(trabajo.entrada.celular);
        trabajo.comentario = textoOpcional(trabajo.entrada.comentario);
        if (!String.isBlank(trabajo.entrada.idPropietario)) {
            trabajo.ownerId = idUsuario(trabajo.entrada.idPropietario);
            if (trabajo.ownerId == null) {
                trabajo.motivo = 'El ID Propietario no corresponde a un usuario de Salesforce.';
                return;
            }
        }
        if (trabajo.medio == null && trabajo.tipoGestion == null && trabajo.respuesta == null
            && trabajo.efectividad == null && trabajo.celular == null && trabajo.comentario == null
            && trabajo.ownerId == null) {
            trabajo.motivo = 'No hay datos para actualizar.';
        }
    }

    private static Boolean propietarioActivo(Map<Id, User> usuarios, Id ownerId) {
        User propietario = usuarios.get(ownerId);
        return propietario != null && propietario.IsActive;
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

    private static Gestion_Expedientes__c armarActualizacion(FilaTrabajo trabajo) {
        Gestion_Expedientes__c gestion = new Gestion_Expedientes__c(Id = trabajo.gestionObjetivo);
        if (trabajo.medio != null) {
            gestion.Medio__c = trabajo.medio;
        }
        if (trabajo.tipoGestion != null) {
            gestion.Tipo_Gestion__c = trabajo.tipoGestion;
        }
        if (trabajo.respuesta != null) {
            gestion.Respuesta__c = trabajo.respuesta;
        }
        if (trabajo.efectividad != null) {
            gestion.Efectividad__c = trabajo.efectividad;
        }
        if (trabajo.celular != null) {
            gestion.Celular__c = trabajo.celular;
        }
        if (trabajo.comentario != null) {
            gestion.Comentario__c = trabajo.comentario;
        }
        if (trabajo.ownerId != null) {
            gestion.OwnerId = trabajo.ownerId;
        }
        return gestion;
    }

    private static String numeroGestion(String valor) {
        String limpio = valor.trim().toUpperCase();
        String numero = limpio.startsWith('GE-') ? limpio.substring(3) : limpio;
        if (String.isBlank(numero) || !numero.isNumeric()) {
            return null;
        }
        return 'GE-' + numero.leftPad(5, '0');
    }

    private static Id idGestion(String raw) {
        String limpio = raw == null ? '' : raw.trim();
        if (limpio.length() != 15 && limpio.length() != 18) {
            return null;
        }
        try {
            Id candidato = (Id) limpio;
            return candidato.getSObjectType() == Gestion_Expedientes__c.SObjectType ? candidato : null;
        } catch (Exception ex) {
            return null;
        }
    }

    private static AuraHandledException errorUsuario(String mensaje) {
        AuraHandledException ex = new AuraHandledException(mensaje);
        ex.setMessage(mensaje);
        return ex;
    }

    private static String texto(String valor) {
        return valor == null ? '' : valor.trim();
    }

    private static String textoOpcional(String valor) {
        String limpio = texto(valor);
        return String.isBlank(limpio) ? null : limpio;
    }

    private static final String ERROR_PICKLIST = '__INVALID__';
    private static Map<String, Map<String, String>> cachePicklist = new Map<String, Map<String, String>>();
    private static Map<String, Set<String>> respuestasPorOperador;

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

    private static Boolean respuestaCorresponde(String operador, String respuesta) {
        if (String.isBlank(operador) || String.isBlank(respuesta)) {
            return false;
        }
        if (respuestasPorOperador == null) {
            respuestasPorOperador = dependientes(Gestion_Expedientes__c.Respuesta__c);
        }
        Set<String> permitidas = respuestasPorOperador.get(operador);
        return permitidas != null && permitidas.contains(respuesta);
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
        private Id casoId;
        private Case caso;
        private Id gestionObjetivo;
        private String nombreGestion;
        private String medio;
        private String tipoGestion;
        private String respuesta;
        private String efectividad;
        private String celular;
        private String comentario;
        private Id ownerId;
    }

    public class FilaEntrada {
        @AuraEnabled public Integer nroFila { get; set; }
        @AuraEnabled public String casoId { get; set; }
        @AuraEnabled public String medio { get; set; }
        @AuraEnabled public String tipoGestion { get; set; }
        @AuraEnabled public String respuesta { get; set; }
        @AuraEnabled public String efectividad { get; set; }
        @AuraEnabled public String celular { get; set; }
        @AuraEnabled public String comentario { get; set; }
        @AuraEnabled public String idPropietario { get; set; }
        @AuraEnabled public String idGestion { get; set; }
    }

    public class FilaResultado {
        @AuraEnabled public Integer nroFila { get; set; }
        @AuraEnabled public String casoIdTexto { get; set; }
        @AuraEnabled public Id casoId { get; set; }
        @AuraEnabled public String casoNumero { get; set; }
        @AuraEnabled public String medio { get; set; }
        @AuraEnabled public String tipoGestion { get; set; }
        @AuraEnabled public Boolean valido { get; set; }
        @AuraEnabled public String motivo { get; set; }
        @AuraEnabled public Id gestionId { get; set; }
        @AuraEnabled public String gestionNombre { get; set; }
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
