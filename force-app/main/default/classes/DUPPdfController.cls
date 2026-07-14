public with sharing class DUPPdfController {
    
    public Remesa__c remesa{get;set;}
    private Transaccion__c transaccion;
    private String remesaId;
    private String transaccionId;
    public Boolean modoEnvioEmail{get;set;}
    public Account productor{get;set;}
    public Boolean showLogo {get; set;}
    public String cartaRemesa{get; set;}
    public Map<String, List<Hoja>> hojasByObtentor {get; set;}
    public Integer currentYear {get; set;}
    public String campaniaName {get;set;}


    public static final Integer MAX_ITEMS_PER_PAGE = 4;
    
    public DUPPdfController() {

        currentYear = Date.today().year();

        cartaRemesa = 'CartaLoteCorreoPostal';        
        
        remesaId = apexpages.currentpage().getparameters().get('remesaId');
        
        transaccionId = apexpages.currentpage().getparameters().get('transaccionId');
        
        String token = apexpages.currentpage().getparameters().get('token');
        
        if(token != null){
           transaccionId = Utils.decryptToken(token.trim());
        }
        modoEnvioEmail = false;
        
        showLogo = true;

        if(remesaId != null){
            //Cuando imprimo desde remesa
            //Obtengo la remesa
            remesa = [SELECT ID, Name, Lote__r.Enviar_Letterhead_Siempre__c, Lote__r.Carta_Remesa__c, Productor__c, Productor__r.Localidad_Envio__c, Productor__r.Calle_Envio__c,Productor__r.Name, Productor__r.Codigo_Postal_Envio__c, Productor__r.Provincia_Envio__c, Lote__r.Name, Lote__r.Campana__r.Name, Modo_de_Envio__c, Lote__r.Cultivo__r.Name FROM Remesa__c WHERE Id = :remesaId];
            campaniaName = remesa.Lote__r.Campana__r.Name;
            cartaRemesa = (String.isEmpty(remesa.Lote__r.Carta_Remesa__c))?cartaRemesa:remesa.Lote__r.Carta_Remesa__c;    
            
            productor = [SELECT Name, Provincia_Envio__c, Numero_Depto_Piso_Envio__c, Calle_Envio__c, ShippingStreet, Localidad_Envio__r.Name, N_CUIT__c, Codigo_Postal_Envio__c, Correo_Electronico_para_Facturacion__c, Frase_Obtentor__c, Phone FROM Account WHERE Id = :remesa.Productor__c ];
            
            hojasByObtentor = buildHojasByObtentor(remesaId);
            
            if(remesa.Modo_de_Envio__c == 'Correo Postal' && !remesa.Lote__r.Enviar_Letterhead_Siempre__c){
                showLogo = false;
            }

            modoEnvioEmail = (remesa.Modo_de_Envio__c == 'Correo Electrónico') ? true : false;

        } else if(transaccionId != null) {

            //Cuando imprimo desde DUP/Caso/Productor
            Transaccion__c t = [SELECT Apellido_y_Nombre__c, Tipo_de_Documento__c, Numero_de_Documento__c, Id, Name, Obtentor__r.Nombre_Obtentor__c, Obtentor__c, Obtentor__r.Frase_Obtentor__c, Obtentor__r.Name, Campana__c, Cultivo__r.Name, Campana__r.Name, Fecha_de_Vencimiento__c, Nombre_de_la_cuenta__c FROM Transaccion__c WHERE ID = :transaccionId ];
            
            hojasByObtentor = buildHojasByObtentor(transaccionId);
            
            productor = [SELECT Name, Calle_Envio__c, ShippingStreet, Localidad_Envio__r.Name, N_CUIT__c, Codigo_Postal_Envio__c, Correo_Electronico_para_Facturacion__c, Frase_Obtentor__c, Phone FROM Account WHERE Id = :t.Nombre_de_la_cuenta__c ];
             
        }

        
    }


    public Map<String, List<Hoja>> buildHojasByObtentor(Id inputId){


        String rtTransaccionDUP = RecordTypeTool.getRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');

        String query = null;

        if(Utils.getObjectTypeById(inputId) == Utils.getObjectTypeByObjectName('Remesa__c')){
            
            query = 'SELECT Numero_de_Documento__c, Tipo_de_Documento__c, Apellido_y_Nombre__c, ID, Name, Obtentor__c, Obtentor__r.Nombre_Obtentor__c, Obtentor__r.Name, Obtentor__r.Frase_Obtentor__c,Campana__c, Cultivo__c, Cultivo__r.Name, Campana__r.Name, Fecha_de_Vencimiento__c, (SELECT ID, Transaccion__c, Transaccion__r.Campana__c, Transaccion__r.Cultivo__c, Transaccion__r.Cultivo__r.Name,  Producto__r.Variedad__c, Obtentor__c, Hectareas_Declaradas__c, Kilos_Totales__c, Cantidad_Declarada__c, Densidad_de_Siembra__c, Lugar_de_Siembra__r.Name FROM Item_de_DUP__r) FROM Transaccion__c WHERE RecordTypeId = :rtTransaccionDUP AND Remesa__c = :inputId';

        }else if(Utils.getObjectTypeById(inputId) == Utils.getObjectTypeByObjectName('Transaccion__c')){

            query = 'SELECT Numero_de_Documento__c, Tipo_de_Documento__c, Apellido_y_Nombre__c, ID, Name, Obtentor__c, Obtentor__r.Name, Obtentor__r.Nombre_Obtentor__c, Obtentor__r.Frase_Obtentor__c,Campana__c, Cultivo__c, Campana__r.Name, Fecha_de_Vencimiento__c, Cultivo__r.Name, (SELECT ID, Transaccion__c, Transaccion__r.Campana__c, Transaccion__r.Cultivo__c, Transaccion__r.Cultivo__r.Name,  Producto__r.Variedad__c, Obtentor__c, Hectareas_Declaradas__c, Kilos_Totales__c, Cantidad_Declarada__c, Densidad_de_Siembra__c, Lugar_de_Siembra__r.Name FROM Item_de_DUP__r) FROM Transaccion__c WHERE RecordTypeId = :rtTransaccionDUP AND Id = :inputId';

        }

        // Creamos un Map para ordenar las hojas por obtentor   
        Map<String, List<Hoja>> hojasByObtentor = new Map<String, List<Hoja>>();

        if(query == null)
            return hojasByObtentor;

        Hoja last = null;    

        for(Transaccion__c transaccion : Database.query(query)){

            String key = String.valueOf(transaccion.Campana__c)+String.valueOf(transaccion.Obtentor__c);

            if(!hojasByObtentor.containsKey(key))
                hojasByObtentor.put(key, new List<Hoja>());

            List<Item_de_DUP__c> items = new List<Item_de_DUP__c>();
                
            for(Item_de_DUP__c item : transaccion.Item_de_DUP__r ){

                items.add(item);

                if(items.size() == MAX_ITEMS_PER_PAGE){

                    // Creamos una hoja cada una cantidad de lineas definidas en MAX_ITEMS_PER_PAGE
                    Hoja h = new Hoja();

                    h.transaccion = transaccion;

                    h.items = new List<Item_de_DUP__c>();

                    h.items.addAll(items);

                    h.isLast = false;

                    items.clear();

                    hojasByObtentor.get(key).add(h);

                    last = h;

                }   

            }   

            if(!items.isEmpty()){

                // Creamos una hoja con la cantidad de itens remantes menores a MAX_ITEMS_PER_PAGE
                Hoja h = new Hoja();

                h.transaccion = transaccion;

                h.items = new List<Item_de_DUP__c>();

                h.items.addAll(items);

                h.isLast = false;

                items.clear();

                hojasByObtentor.get(key).add(h);

                last = h;

            }   


            if(transaccion.Item_de_DUP__r.isEmpty()){
                // Creamos una hoja cada una cantidad de lineas definidas en MAX_ITEMS_PER_PAGE
                Hoja h = new Hoja();

                h.transaccion = transaccion;

                h.items = new List<Item_de_DUP__c>();

                h.isLast = false;

                hojasByObtentor.get(key).add(h);

                last = h;
            }

        }   

        if(last != null)
            last.isLast = true;


        return hojasByObtentor;

    }


    public class Hoja{

        public Transaccion__c transaccion {get; set;}
        public List<Item_de_DUP__c> items {get; set;}
        public Boolean isLast {get; set;}

    }

}