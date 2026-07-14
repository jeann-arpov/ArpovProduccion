public with sharing class ValidarLicenciasCuentaPrincipal {
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
        Set<Id> productoresIds = obtenerProductores(ventasObtenidas);

        Response res = new Response();
        res.productoresOk = new List<Id>(productoresIds);
        return new List<Response>{ res };
    }
    @TestVisible
    private static Set<Id> obtenerProductores(List<Venta__c> ventas) {
        List<Venta__c> vProductorOriginante = new List<Venta__c>(); //ventas de productores como originantes
        List<Venta__c> vProductorDestinatario = new List<Venta__c>();//ventas de productores como Destinatarios
        
        //Obtengo las ventas según su tipo
        List<Venta__c> vTipoCoVentasObtenidas = getVentasTipoCoVentas(ventas);
        List<Venta__c> vTipoVentasObtenidas = getVentasTipoVenta(ventas);
        List<Venta__c> vTipoTDSoDPObtenidas = getVentasTipoTDSoDPO(ventas);
        List<Venta__c> vTipoTDSObtenidas = getVentasTipoTDS(ventas);

        //Agrupo las ventas Por Destinatario y Originante
        vProductorDestinatario.addAll(vTipoCoVentasObtenidas);
        vProductorDestinatario.addAll(vTipoVentasObtenidas);
        vProductorOriginante.addAll(vTipoTDSoDPObtenidas);
        vProductorOriginante.addAll(vTipoTDSObtenidas);

        /*<<<<<Productor como Destinatario>>>>>*/
        //obtengo las ventas segun la tecnologia
        List<Venta__c> vTecnologiaEnlistDest = mapearTecnologiaEnlist(vProductorDestinatario);//ventas de tecnología Enlist o Conkesta
        List<Venta__c> vTecnologiaRRDest = mapearTecnologiaRR(vProductorDestinatario);//ventas de tecnología RR
        List<Venta__c> vTecnoOtraDest = mapearTecnologiaOtra(vProductorDestinatario);//lista de ventas de otras tecnologías
        
        //Obtengo las claves para productores Destinatarios según la tecnología para buscar las licencias
        Set<String> claveProductorEnlistDest = getClaveVentasRolDestinatario(vTecnologiaEnlistDest);
        Set<String> claveProductorRRDest = getClaveVentasRolDestinatario(vTecnologiaRRDest);
        Set<String> claveProductorOtraDest = getClaveVentasRolDestinatario(vTecnoOtraDest);

        //Obtengo las licencias según las claves obtenidas
        List<Licencia__c> licenciasEnlistDest = getLicencias(claveProductorEnlistDest, 'Enlist');
        List<Licencia__c> licenciasRRDest = getLicencias(claveProductorRRDest, 'RR');
        List<Licencia__c> licenciasOtraDest = getLicencias(claveProductorOtraDest, 'Otra');
        List<Licencia__c> licencias = new List<Licencia__c>();
        licencias.addAll(licenciasEnlistDest);  
        licencias.addAll(licenciasRRDest); 
        licencias.addAll(licenciasOtraDest);

        /*<<<<<Productor como Originante>>>>>*/
        //obtengo las ventas segun la tecnologia
        List<Venta__c> vTecnologiaEnlistOrig = mapearTecnologiaEnlist(vProductorOriginante);//ventas de tecnología Enlist o Conkesta
        List<Venta__c> vTecnologiaRROrig = mapearTecnologiaRR(vProductorOriginante);//ventas de tecnología RR
        List<Venta__c> vTecnoOtraOrig = mapearTecnologiaOtra(vProductorOriginante);//lista de ventas de otras tecnologías

        //Obtengo las claves para productores Destinatarios según la tecnología para buscar las licencias
        Set<String> claveProductorEnlistOrig = getClaveVentasRolDestinatario(vTecnologiaEnlistOrig);
        Set<String> claveProductorRROrig = getClaveVentasRolDestinatario(vTecnologiaRROrig);
        Set<String> claveProductorOtraOrig = getClaveVentasRolDestinatario(vTecnoOtraOrig);

        //Obtengo las licencias según las claves obtenidas
        List<Licencia__c> licenciasEnlistOrig = getLicencias(claveProductorEnlistOrig, 'Enlist');
        List<Licencia__c> licenciasRROrig = getLicencias(claveProductorRROrig, 'RR');
        List<Licencia__c> licenciasOtraOrig = getLicencias(claveProductorOtraOrig, 'Otra');
        licencias.addAll(licenciasEnlistOrig);  
        licencias.addAll(licenciasRROrig); 
        licencias.addAll(licenciasOtraOrig);

        //Obtengo los Ids de los productores con licencia
        Set<Id> productoresConLicencia = getProductoresConLicencia(licencias);//Ids de productores con licencia

        return productoresConLicencia;
    }

    public static Set<Id> getProductoresConLicencia(List<Licencia__c> licencias){

        Set<Id> prodIds = new Set<Id>();//Ids de productores con licencia
        for (Licencia__c l : licencias) {
            prodIds.add(l.Cuenta_Productor__c);
        }
        return prodIds;
    }

    public static List<Venta__c> mapearTecnologiaEnlist(List<Venta__c> ventas) {

        List<Venta__c> ventasEnlist = new List<Venta__c>();
        for (Venta__c v : ventas) {
            String tecnoLicencia = (v.Producto__r.Variedad2__r.Biotecnologia__c);
            if (tecnoLicencia.startsWith('Enlist') || tecnoLicencia == 'Conkesta E3') {
                ventasEnlist.add(v);
            }
        }
        return ventasEnlist;
    }

    public static List<Venta__c> mapearTecnologiaRR(List<Venta__c> ventas) {
        
        List<Venta__c> ventasRR = new List<Venta__c>();
        for (Venta__c v : ventas) {
            String tecnoLicencia = (v.Producto__r.Variedad2__r.Biotecnologia__c);
            if (tecnoLicencia.startsWith('RR') || tecnoLicencia == 'Convencional') {
                ventasRR.add(v);
            }
        }
        return ventasRR;
    }

    public static List<Venta__c> mapearTecnologiaOtra(List<Venta__c> ventas) {
        
        List<Venta__c> ventasOtras = new List<Venta__c>();
        for (Venta__c v : ventas) {
            String tecnoLicencia = (v.Producto__r.Variedad2__r.Biotecnologia__c);
            if (tecnoLicencia == 'BGRR' || tecnoLicencia == 'HB4') {
                ventasOtras.add(v);
            }
        }
        return ventasOtras;
    }

    public static List<Licencia__c> getLicencias(Set<String> claveLicencia, String tecno) {
        if (!Schema.sObjectType.Licencia__c.isAccessible()) {
            throw new AuraHandledException('No tiene permiso para acceder a Licencia__c');
        }
        return [
            SELECT Id, Cuenta_Productor__c, Cuenta_Obtentor__c, Tecnologia__c FROM Licencia__c WHERE Tipo_de_Licencia__c = 'Productor' AND Tecnologia__c = :tecno AND Estado__c = 'Aprobada' AND Clave_Licencia_Productor_Obtentor__c IN :claveLicencia ];
    }

    public static List<Venta__c> getVentas(Set<Id> productores, String rol){
        List<Venta__c> ventas = new List<Venta__c>();
        if (!Schema.sObjectType.Venta__c.isAccessible()) return ventas;

        if (rol == 'Destinatario') { 
            ventas = [SELECT Id, Tipo_de_Venta__c, Originante__c, Destinatario__c, Rol_Destinatario__c,Rol_Originante__c,
                            Producto__r.Variedad2__r.Biotecnologia__c, 
                            Producto__r.Variedad2__r.Obtentor_Comercializa__c, Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                    FROM Venta__c
                    WHERE Semba_Evolucion__c = true AND Destinatario__c IN :productores];
        } else {
            ventas = [SELECT Id, Tipo_de_Venta__c, Originante__c, Destinatario__c,Rol_Destinatario__c,Rol_Originante__c,
                            Producto__r.Variedad2__r.Biotecnologia__c,
                            Producto__r.Variedad2__r.Obtentor_Comercializa__c, Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId
                    FROM Venta__c
                    WHERE Semba_Evolucion__c = true AND Originante__c IN :productores];
        }
        return ventas;
    }
    @TestVisible
    private static Set<String> getClaveVentasRolDestinatario(List<Venta__c> ventas){

        Set<String> claves = new Set<String>();
        for (Venta__c v : ventas) {
            String obtentor = String.valueOf(v.Producto__r.Variedad2__r.Obtentor_Comercializa__c);
            if (v.Destinatario__c != null) {
                claves.add(v.Destinatario__c + obtentor);
            }
        }
        return claves;
    }
    @testVisible
    private static Set<String> getClaveVentasRolOriginante(List<Venta__c> ventas){

        Set<String> claves = new Set<String>();
        for (Venta__c v : ventas) {
            String obtentor = String.valueOf(v.Producto__r.Variedad2__r.Obtentor_Comercializa__c);
            
            if (v.Originante__c != null) {
                claves.add(v.Originante__c +  obtentor );
            }
        }
        return claves;
    }

    public static List<Venta__c> getVentasTipoCoVentas(List<Venta__c> ventas){

        List<Venta__c> ventasTipoCoVentas = new List<Venta__c>();
        for (Venta__c v : ventas) {
            if (v.Rol_Originante__c == 'Obtentor' && (v.Tipo_de_Venta__c == 'C'|| v.Tipo_de_Venta__c == 'Venta')) {
                ventasTipoCoVentas.add(v);
            }
        }
        return ventasTipoCoVentas;
    }
    
    public static List<Venta__c> getVentasTipoTDSoDPO(List<Venta__c> ventas){

        List<Venta__c> ventasTipoTDSoDPO = new List<Venta__c>();
        for (Venta__c v : ventas) {
            if (v.Rol_Destinatario__c == 'Obtentor' && (v.Tipo_de_Venta__c == 'TDS'|| v.Tipo_de_Venta__c == 'DPO')) {
                ventasTipoTDSoDPO.add(v);
            }
        }
        return ventasTipoTDSoDPO;
    }

    public static List<Venta__c> getVentasTipoVenta(List<Venta__c> ventas){

        List<Venta__c> ventasTipoVenta = new List<Venta__c>();
        for (Venta__c v : ventas) {
            if (v.Tipo_de_Venta__c == 'Venta') {
                ventasTipoVenta.add(v);
            }
        }
        return ventasTipoVenta;
    }

    public static List<Venta__c> getVentasTipoTDS(List<Venta__c> ventas){

        List<Venta__c> ventasTipoTDS = new List<Venta__c>();
        for (Venta__c v : ventas) {
            if (v.Tipo_de_Venta__c == 'DPD'|| v.Tipo_de_Venta__c == 'DPO') {
                ventasTipoTDS.add(v);
            }
        }
        return ventasTipoTDS;
    }
    
}