public with sharing class ValidarLicenciaCuentaRelacionada {
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

    @InvocableMethod(label='Buscar Licencias de Cuenta relacionada' description='Busca licencias de productores como Originante o Destinatario con cuentas relacionadas al obtentor original y devuelve lista de productores con licencias válidas ')
    public static List<Response> execute(List<Request> requests) {
        Set<Id> productoresOk = new Set<Id>();
        Request parametros = requests[0];
        Set<Id> productores = new Set<Id>(parametros.productores);
        String rol = parametros.rol;

        List<Venta__c> ventasObtenidas = ValidarLicenciasCuentaPrincipal.getVentas(productores, rol);
        Set<Id> productoresIds = getProductores(ventasObtenidas);

        Response res = new Response();
        res.productoresOk = new List<Id>(productoresIds);
        return new List<Response>{ res };
    }
    @TestVisible
    private static Set<Id> getProductores(List<Venta__c> ventas) {
        List<Venta__c> vProductorOriginante = new List<Venta__c>(); //ventas de productores como originantes
        List<Venta__c> vProductorDestinatario = new List<Venta__c>();//ventas de productores como Destinatarios
        
        //Obtengo las ventas según su tipo
        List<Venta__c> vTipoCoVentasObtenidas = ValidarLicenciasCuentaPrincipal.getVentasTipoCoVentas(ventas);
        List<Venta__c> vTipoVentasObtenidas = ValidarLicenciasCuentaPrincipal.getVentasTipoVenta(ventas);
        List<Venta__c> vTipoTDSoDPObtenidas = ValidarLicenciasCuentaPrincipal.getVentasTipoTDSoDPO(ventas);
        List<Venta__c> vTipoTDSObtenidas = ValidarLicenciasCuentaPrincipal.getVentasTipoTDS(ventas);

        //Agrupo las ventas Por Destinatario y Originante
        vProductorDestinatario.addAll(vTipoCoVentasObtenidas);
        vProductorDestinatario.addAll(vTipoVentasObtenidas);
        vProductorOriginante.addAll(vTipoTDSoDPObtenidas);
        vProductorOriginante.addAll(vTipoTDSObtenidas);

        /*<<<<<Productor como Destinatario>>>>>*/
        //obtengo las ventas segun la tecnologia
        List<Venta__c> vTecnologiaEnlistDest = ValidarLicenciasCuentaPrincipal.mapearTecnologiaEnlist(vProductorDestinatario);//ventas de tecnología Enlist o Conkesta
        List<Venta__c> vTecnologiaRRDest = ValidarLicenciasCuentaPrincipal.mapearTecnologiaRR(vProductorDestinatario);//ventas de tecnología RR
        List<Venta__c> vTecnoOtraDest = ValidarLicenciasCuentaPrincipal.mapearTecnologiaOtra(vProductorDestinatario);//lista de ventas de otras tecnologías
        
        //Obtengo las claves para productores Destinatarios según la tecnología para buscar las licencias
        Set<String> claveProductorEnlistDest = getClaveRolDestinatario(vTecnologiaEnlistDest);
        Set<String> claveProductorRRDest = getClaveRolDestinatario(vTecnologiaRRDest);
        Set<String> claveProductorOtraDest = getClaveRolDestinatario(vTecnoOtraDest);

        //Obtengo las licencias según las claves obtenidas
        List<Licencia__c> licenciasEnlistDest = ValidarLicenciasCuentaPrincipal.getLicencias(claveProductorEnlistDest, 'Enlist');
        List<Licencia__c> licenciasRRDest = ValidarLicenciasCuentaPrincipal.getLicencias(claveProductorRRDest, 'RR');
        List<Licencia__c> licenciasOtraDest = ValidarLicenciasCuentaPrincipal.getLicencias(claveProductorOtraDest, 'Otra');
        List<Licencia__c> licencias = new List<Licencia__c>();
        licencias.addAll(licenciasEnlistDest);  
        licencias.addAll(licenciasRRDest); 
        licencias.addAll(licenciasOtraDest);

        /*<<<<<Productor como Originante>>>>>*/
        //obtengo las ventas segun la tecnologia
        List<Venta__c> vTecnologiaEnlistOrig = ValidarLicenciasCuentaPrincipal.mapearTecnologiaEnlist(vProductorOriginante);//ventas de tecnología Enlist o Conkesta
        List<Venta__c> vTecnologiaRROrig = ValidarLicenciasCuentaPrincipal.mapearTecnologiaRR(vProductorOriginante);//ventas de tecnología RR
        List<Venta__c> vTecnoOtraOrig = ValidarLicenciasCuentaPrincipal.mapearTecnologiaOtra(vProductorOriginante);//lista de ventas de otras tecnologías

        //Obtengo las claves para productores Destinatarios según la tecnología para buscar las licencias
        Set<String> claveProductorEnlistOrig = getClaveRolDestinatario(vTecnologiaEnlistOrig);
        Set<String> claveProductorRROrig = getClaveRolDestinatario(vTecnologiaRROrig);
        Set<String> claveProductorOtraOrig = getClaveRolDestinatario(vTecnoOtraOrig);

        //Obtengo las licencias según las claves obtenidas
        List<Licencia__c> licenciasEnlistOrig = ValidarLicenciasCuentaPrincipal.getLicencias(claveProductorEnlistOrig, 'Enlist');
        List<Licencia__c> licenciasRROrig = ValidarLicenciasCuentaPrincipal.getLicencias(claveProductorRROrig, 'RR');
        List<Licencia__c> licenciasOtraOrig = ValidarLicenciasCuentaPrincipal.getLicencias(claveProductorOtraOrig, 'Otra');
        licencias.addAll(licenciasEnlistOrig);  
        licencias.addAll(licenciasRROrig); 
        licencias.addAll(licenciasOtraOrig);

        //Obtengo los Ids de los productores con licencia
        Set<Id> productoresConLicencia = ValidarLicenciasCuentaPrincipal.getProductoresConLicencia(licencias);//Ids de productores con licencia

        return productoresConLicencia;
    }
    @TestVisible
    private static Set<String> getClaveRolDestinatario(List<Venta__c> ventas){

        Set<String> claves = new Set<String>();
        for (Venta__c v : ventas) {
            String obtentor = String.valueOf(v.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId);
            if (v.Destinatario__c != null && obtentor != null) {
                claves.add(v.Destinatario__c + obtentor);
            }
        }
        return claves;
    }
    @TestVisible
    private static Set<String> getClaveRolOriginante(List<Venta__c> ventas){

        Set<String> claves = new Set<String>();
        for (Venta__c v : ventas) {
            String obtentor = String.valueOf(v.Producto__r.Variedad2__r.Obtentor_Comercializa__r.ParentId);
            
            if (v.Originante__c != null && obtentor != null) {
                claves.add(v.Originante__c +  obtentor );
            }
        }
        return claves;
    }

}