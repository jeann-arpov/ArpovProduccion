public with sharing class ContactosCortevaService {
    public static void validarCorreoUnico(
        List<UsuariosdeCorteva__c> registros,
        Map<Id, UsuariosdeCorteva__c> anteriores
    ) {
        Map<String, List<UsuariosdeCorteva__c>> porClave = new Map<String, List<UsuariosdeCorteva__c>>();
        Set<Id> cuentas = new Set<Id>();
        Set<String> correos = new Set<String>();

        for (UsuariosdeCorteva__c registro : registros) {
            if (String.isBlank(registro.Correo__c) || registro.Cuenta__c == null) {
                continue;
            }
            UsuariosdeCorteva__c anterior = anteriores == null ? null : anteriores.get(registro.Id);
            if (anterior != null
                && mismaClave(anterior.Cuenta__c, anterior.Correo__c, registro.Cuenta__c, registro.Correo__c)) {
                continue;
            }
            String clave = clave(registro.Cuenta__c, registro.Correo__c);
            if (!porClave.containsKey(clave)) {
                porClave.put(clave, new List<UsuariosdeCorteva__c>());
            }
            porClave.get(clave).add(registro);
            cuentas.add(registro.Cuenta__c);
            correos.add(registro.Correo__c.trim());
        }

        if (porClave.isEmpty()) {
            return;
        }

        Set<Id> idsEnTransaccion = new Set<Id>();
        for (UsuariosdeCorteva__c registro : registros) {
            if (registro.Id != null) {
                idsEnTransaccion.add(registro.Id);
            }
        }

        for (UsuariosdeCorteva__c existente : new ConsultaSinCompartir().buscar(cuentas, correos, idsEnTransaccion)) {
            List<UsuariosdeCorteva__c> nuevos = porClave.get(clave(existente.Cuenta__c, existente.Correo__c));
            if (nuevos == null) {
                continue;
            }
            for (UsuariosdeCorteva__c nuevo : nuevos) {
                nuevo.Correo__c.addError('Ya existe un Contacto Corteva con este correo en la misma cuenta.');
            }
        }

        for (List<UsuariosdeCorteva__c> mismos : porClave.values()) {
            if (mismos.size() < 2) {
                continue;
            }
            for (Integer i = 1; i < mismos.size(); i++) {
                mismos[i].Correo__c.addError('Ya existe un Contacto Corteva con este correo en la misma cuenta.');
            }
        }
    }

    private static Boolean mismaClave(Id cuentaAnterior, String correoAnterior, Id cuentaNueva, String correoNuevo) {
        return cuentaAnterior == cuentaNueva
            && clave(cuentaAnterior, correoAnterior) == clave(cuentaNueva, correoNuevo);
    }

    private static String clave(Id cuentaId, String correo) {
        return String.valueOf(cuentaId) + '|' + correo.trim().toLowerCase();
    }

    private without sharing class ConsultaSinCompartir {
        List<UsuariosdeCorteva__c> buscar(Set<Id> cuentas, Set<String> correos, Set<Id> idsEnTransaccion) {
            return [
                SELECT Cuenta__c, Correo__c
                FROM UsuariosdeCorteva__c
                WHERE Cuenta__c IN :cuentas
                AND Correo__c IN :correos
                AND Id NOT IN :idsEnTransaccion
            ];
        }
    }
}
