public with sharing class ValidarLicenciasAction {
    public class Request {
        @InvocableVariable(required=true)
        public List<Id> productores;

        @InvocableVariable(required=true)
        public String rol;
    }

    public class Response {
        @InvocableVariable
        public List<Id> productoresOk;
    }

    @InvocableMethod(label='Buscar Licencias de Productores' description='Devuelve lista de productores con licencias válidas según su rol')
    public static List<Response> execute(List<Request> requests) {
        Set<Id> productoresOk = new Set<Id>();
        Request parametros = requests[0];
        Set<Id> productores = new Set<Id>(parametros.productores);
        String rol = parametros.rol;

        List<Venta__c> ventasObtenidas = getVentas(productores, rol);
        Set<Id> obtentores = getObtentores(ventasObtenidas);      
        Set<Id> productoresSinLicencia = obtenerProductoresLicenciasObtentoComercializa(ventasObtenidas, productores, obtentores);

        if (!productoresSinLicencia.isEmpty()) {
            Set<Id> adicionales = obtenerProductoresCuentaPrincipal(ventasObtenidas, productoresSinLicencia);
            productoresSinLicencia.addAll(adicionales);
        }

        productores.removeAll(productoresSinLicencia);

        Response res = new Response();
        res.productoresOk = new List<Id>(productores);
        return new List<Response>{ res };
    }

    @TestVisible
    private static List<Venta__c> getVentas(Set<Id> productores, String rol){
        List<Venta__c> ventas = new List<Venta__c>();
        if (!Schema.sObjectType.Venta__c.isAccessible()) return ventas;

        if (rol == 'Destinatario') {
            ventas = [SELECT Id, Tipo_de_Venta__c, Originante__c, Destinatario__c,
                            Producto__r.Variedad2__r.Biotecnologia__c,
                            Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                            Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                      FROM Venta__c
                      WHERE Semba_Evolucion__c = true AND Destinatario__c IN :productores];
        } else {
            ventas = [SELECT Id, Tipo_de_Venta__c, Originante__c, Destinatario__c,
                            Producto__r.Variedad2__r.Biotecnologia__c,
                            Producto__r.Variedad2__r.Obtentor_Comercializa__c,
                            Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                      FROM Venta__c
                      WHERE Semba_Evolucion__c = true AND Originante__c IN :productores];
        }
        return ventas;
    }
    @TestVisible
    private static Set<Id> getObtentores(List<Venta__c> ventas) {
        Set<Id> obtentores = new Set<Id>();
        for (Venta__c v : ventas) {
            if (v.Producto__r.Variedad2__r.Obtentor_Comercializa__c != null) {
                obtentores.add(v.Producto__r.Variedad2__r.Obtentor_Comercializa__c);
            }
        }
        return obtentores;
    }

    @TestVisible
    private static Set<Id> obtenerProductoresLicenciasObtentoComercializa(List<Venta__c> ventas, Set<Id> productores, Set<Id> obtentores) {
        Set<Id> productoresPorRol = getProductoresPorRol(ventas);
        List<Licencia__c> licencias = getLicencias(new List<Id>(productoresPorRol), obtentores);
        Set<String> clavesLicencias = getClaveVentas(ventas);
        return getProductoresSinLicencia(licencias, clavesLicencias);
    }

    @TestVisible
    private static Set<Id> obtenerProductoresCuentaPrincipal(List<Venta__c> ventas, Set<Id> productores) {
        Set<Id> cuentasPadres = getProductoresPorCuenta(ventas);
        List<Licencia__c> licencias = getLicencias(new List<Id>(productores), cuentasPadres);
        Set<String> claves = getClaveVentasPorCuenta(ventas);
        return getProductoresSinLicencia(licencias, claves);
    }

    @TestVisible
    private static Set<Id> getProductoresPorRol(List<Venta__c> ventas) {
        Set<Id> productores = new Set<Id>();
        for (Venta__c v : ventas) {
            if (v.Tipo_de_Venta__c == 'C' || v.Tipo_de_Venta__c == 'Obtentor' || v.Tipo_de_Venta__c == 'Venta') {
                if (v.Destinatario__c != null) productores.add(v.Destinatario__c);
            }
            if (v.Originante__c != null) productores.add(v.Originante__c);
        }
        return productores;
    }

    @TestVisible
    private static Set<Id> getProductoresPorCuenta(List<Venta__c> ventas) {
        Set<Id> cuentas = new Set<Id>();
        for (Venta__c v : ventas) {
            Id cuenta = v.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId != null ?
                v.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId :
                v.Producto__r.Variedad2__r.Obtentor_Comercializa__c;
            cuentas.add(cuenta);
        }
        return cuentas;
    }

    @TestVisible
    private static Set<String> getClaveVentas(List<Venta__c> ventas){
        Set<String> claves = new Set<String>();
        for (Venta__c v : ventas) {
            String obtentor = String.valueOf(v.Producto__r.Variedad2__r.Obtentor_Comercializa__c);
            String tecnoLicencia = mapearTecnologia(v.Producto__r.Variedad2__r.Biotecnologia__c);
            if (v.Destinatario__c != null && (v.Tipo_de_Venta__c == 'C' || v.Tipo_de_Venta__c == 'Obtentor' || v.Tipo_de_Venta__c == 'Venta')) {
                claves.add(v.Destinatario__c + '|' + obtentor + '|' + tecnoLicencia);
            }
            if (v.Originante__c != null) {
                claves.add(v.Originante__c + '|' + obtentor + '|' + tecnoLicencia);
            }
        }
        return claves;
    }

    @TestVisible
    private static Set<String> getClaveVentasPorCuenta(List<Venta__c> ventas){
        Set<String> claves = new Set<String>();
        for (Venta__c v : ventas) {
            String obtentor = String.valueOf(
                v.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId != null ?
                v.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId :
                v.Producto__r.Variedad2__r.Obtentor_Comercializa__c
            );
            String tecnoLicencia = mapearTecnologia(v.Producto__r.Variedad2__r.Biotecnologia__c);
            if (v.Destinatario__c != null && (v.Tipo_de_Venta__c == 'C' || v.Tipo_de_Venta__c == 'Obtentor' || v.Tipo_de_Venta__c == 'Venta')) {
                claves.add(v.Destinatario__c + '|' + obtentor + '|' + tecnoLicencia);
            }
            if (v.Originante__c != null) {
                claves.add(v.Originante__c + '|' + obtentor + '|' + tecnoLicencia);
            }
        }
        return claves;
    }

    @TestVisible
    private static Set<Id> getProductoresSinLicencia(List<Licencia__c> licencias, Set<String> clavesValidas){
        Set<Id> sinLicencia = new Set<Id>();
        for (Licencia__c l : licencias) {
            String clave = l.Cuenta_Productor__c + '|' + l.Cuenta_Obtentor__c + '|' + l.Tecnologia__c;
            if (!clavesValidas.contains(clave)) {
                sinLicencia.add(l.Cuenta_Productor__c);
            }
        }
        return sinLicencia;
    }

    @TestVisible
    private static List<Licencia__c> getLicencias(List<Id> productores, Set<Id> obtentores){
        if (!Schema.sObjectType.Licencia__c.isAccessible()) {
            throw new AuraHandledException('No tiene permiso para acceder a Licencia__c');
        }
        return [
            SELECT Id, Cuenta_Productor__c, Cuenta_Obtentor__c, Tecnologia__c
            FROM Licencia__c
            WHERE Tipo_de_Licencia__c = 'Productor'
              AND Estado__c = 'Aprobada'
              AND Cuenta_Productor__c IN :productores
              AND Cuenta_Obtentor__c IN :obtentores
        ];
    }
    @TestVisible
    private static String mapearTecnologia(String tecnoVenta) {
        switch on tecnoVenta {
            when 'Enlist E3', 'Conkesta E3' { return 'Enlist'; }
            when 'RR1','RR2 - BT','Convencional' { return 'RR'; }
            when else { return tecnoVenta; }
        }
    }
}