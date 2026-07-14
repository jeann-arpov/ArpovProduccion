/**
* @author Facundo Luna
* @date 29/09/2015
* @description Clase controladora de la Vista CustomLookup
*/
public with sharing class CustomLookupSOSLController{
    
    static final String QUERY_FORMAT = 'FIND :searchTextInternal IN ALL FIELDS RETURNING {0}({1} {2})';
                                    
    
    public String searchText {get; set;}
    private String searchTextInternal {get; set;}
    public String sObjectName {get; set;}
    public Integer filterId {get; set;}
    public String query {get; set;}
    public String fieldSet {get; set;}
    public String movimientoId {get; set;}
    public String cCompraId {get; set;}
    public String tarjetaId {get; set;}
    public String empresaId {get; set;}
    private String searchQuery;
    
    public CustomLookupSOSLController(){
        
        // Obtenemos los parametros de la pagina
        sObjectName = ApexPages.currentPage().getParameters().get('sObject');
        filterId = Integer.valueOf(ApexPages.currentPage().getParameters().get('filterId'));
        fieldSet = ApexPages.currentPage().getParameters().get('fieldSet');
        movimientoId = ApexPages.currentPage().getParameters().get('movimientoId');
        cCompraId = ApexPages.currentPage().getParameters().get('cCompraId');
        tarjetaId = ApexPages.currentPage().getParameters().get('tarjetaId');
        empresaId = ApexPages.currentPage().getParameters().get('empresaId');
        
        // get the current search string
        searchText = System.currentPageReference().getParameters().get('lksrch');
        
        // Si se paso el movimientoId, obtenemos los datos que necesitamos
        if(validateId(movimientoId) != null){
            List<ERPvs__Movimiento_Fondo__c> movimiento = [SELECT ERPvs__Sucursal__r.ERPvs__Empresa__c FROM ERPvs__Movimiento_Fondo__c WHERE Id = :movimientoId LIMIT 1];
            if(!movimiento.isEmpty()){
                
                if(movimiento.get(0).ERPvs__Sucursal__r != null){
                    
                    empresaId = movimiento.get(0).ERPvs__Sucursal__r.ERPvs__Empresa__c;
                    
                }
                
            }
        }
        
        if(validateId(cCompraId) != null){
            List<ERPvs__Comprobante_Compra__c> comprobanteCompra = [SELECT ERPvs__Sucursal_Empresa__r.ERPvs__Empresa__c FROM ERPvs__Comprobante_Compra__c WHERE Id = :cCompraId LIMIT 1];
            if(!comprobanteCompra.isEmpty()){
                
                if(comprobanteCompra.get(0).ERPvs__Sucursal_Empresa__r != null){
                    
                    empresaId = comprobanteCompra.get(0).ERPvs__Sucursal_Empresa__r.ERPvs__Empresa__c;
                    
                }
                
            }
        }
        
        // Armamos la Query
        buildQuery();    
        
    }
    
    // used by the visualforce page to send the link to the right dom element
    public string getFormTag() {
        return System.currentPageReference().getParameters().get('frm');
    }

      // used by the visualforce page to send the link to the right dom element for the text box
    public string getTextBox() {
        return System.currentPageReference().getParameters().get('txt');
    }
    
    public void buildQuery(){
    
        
        // Obtenemos los campos del fieldset del objeto
        List<String> fields = readFieldSet(fieldSet, sObjectName);
        
        String queryWhere = '';
        
        if(validateId(empresaId)!=null){
            queryWhere = 'WHERE ERPvs__Empresa__c = :empresaId';
        }
        
        if(sObjectName == 'ERPvs__Cuenta_Contable__c'){
            
            if(filterId == 1){
                
                if(String.isEmpty(queryWhere)){
                    queryWhere = 'WHERE ERPvs__Cuenta_Contable_en_Fondos__c = true';
                }else{
                    queryWhere = queryWhere + ' AND ERPvs__Cuenta_Contable_en_Fondos__c = true';
                }
                
            }else if(filterId == 2){
                
                if(String.isEmpty(queryWhere)){
                    queryWhere = 'WHERE AND ERPvs__Percepciones_IB__c = true';
                }else{
                    queryWhere = queryWhere + ' AND ERPvs__Percepciones_IB__c = true';
                }
            }
            
        } else if(sObjectName == 'ERPvs__Centro_de_Costo__c'){
            
            if(filterId == 1){
                
            }
            
        } else if(sObjectName == 'ERPvs__Clasificacion_Centro_Costo__c'){
           
            if(filterId == 1){
                
            }
            
        } else if(sObjectName == 'ERPvs__Cuenta_Bancaria__c'){
        
            if(filterId == 1){
                
            }
        
        } else if(sObjectName == 'ERPvs__Concepto_de_Compra__c'){
            
            if(filterId == 1){
                
            }
        
        } else if(sObjectName == 'ERPvs__Centro_de_Costo__c'){
            
            if(filterId == 1){
                
            }
        
        } else if(sObjectName == 'ERPvs__Producto__c' ){
            
            if(filterId == 1){
                
            }

            // FL 2017-09-27 Nuevo filtro de productos para pantalla de armado de kits
            if(filterId == 2){
                String filterWhere = 'ERPvs__Activo__c = true AND Tipo_de_Producto__c = \'Individual\' AND ERPvs__Empresa__c = \'' + empresaId + '\'';
                if(String.isEmpty(queryWhere)){
                    queryWhere = 'WHERE ' + filterWhere;
                }else{
                    queryWhere = queryWhere + ' AND ' + filterWhere;
                }
            }
        
        } else if(sObjectName == 'ERPvs__Tasa_de_Iva__c' ){
            
            if(filterId == 1){
                
            }
        
        } else if(sObjectName == 'ERPvs__Documento_Recibido__c'){
            
            if(filterId == 1){
                
            }
        
        } else if(sObjectName == 'ERPvs__Tarjeta_de_Credito__c'){
            
            if(filterId == 1){
                
            }
        
        } else if(sObjectName == 'ERPvs__Plan_Tarjetas__c'){
            
            if(filterId == 1){
                if(validateId(tarjetaId)==null){
                    queryWhere = '';
                }else{
                    queryWhere = ' WHERE ERPvs__Tarjeta_Credito__c = \''+tarjetaId+'\'';
                }
            }
        
        }  else if(sObjectName == 'ERPvs__Lista_de_precios__c'){
            
            if(filterId == 1){
                queryWhere = ' WHERE Name != null AND ERPvs__Empresa__c = :empresaId';
            }
        
        }       
        
        if(sObjectName == 'ERPvs__Lista_de_precios__c'){
            queryWhere = queryWhere + ' ORDER BY ERPvs__Activa__c DESC, ERPvs__Vigencia_Desde__c DESC NULLS LAST, Name ASC LIMIT 50';
        } else {
            queryWhere = queryWhere + ' ORDER BY Name LIMIT 10';
        }
        
        
        searchquery = String.format(QUERY_FORMAT, new List<String> {sObjectName, String.join(fields,','), queryWhere});
        
    }
    
    
    /**
    * @author Facundo Luna
    * @date 21/07/2014
    * @description Metodo que aplica el filtro por nombre al objeto
    */ 
    public void doSearch(){
        
        // Armamos de nuevo la query
        buildQuery();
        
    }
    
    /**
    * @author Facundo Luna
    * @date 29/09/2015
    * @description Metodo que elimina el filtro introducido
    */ 
    public void doDeleteFilter(){
        
        // Reseteamos el filtro
        searchText = null;
            
        // Armamos de nuevo la query
        buildQuery();
        
    }
    
    /**
    * @author Facundo Luna
    * @date 29/09/2015
    * @description Metodo que devuelve los campos a usar
    */ 
    public Integer getColumns(){
        
        // Obtenemos los campos
        List<String> fields = readFieldSet(fieldSet,sObjectName);
        
        //Seteamos los campos necesarios
        fields.add('Id');
        
        // Devolvemos los campos
        return fields.size();
        
    }
    
    /**
    * @author Facundo Luna
    * @date 29/09/2015
    * @description Metodo auxiliar para obtener los campos de un field set dinamicamente
    * @param fieldSetName : nombre del field set
    * @param objectName : nombre del objeto al que pertenece el field set
    */ 
    public static List<String> readFieldSet(String fieldSetName, String objectName){
        
        Map<String, Schema.SObjectType> GlobalDescribeMap = Schema.getGlobalDescribe(); 
        
        Schema.SObjectType SObjectTypeObj = GlobalDescribeMap.get(ObjectName);
        
        Schema.DescribeSObjectResult DescribeSObjectResultObj = SObjectTypeObj.getDescribe();
    
        Schema.FieldSet fieldSetObj = DescribeSObjectResultObj.FieldSets.getMap().get(fieldSetName);
        
        // Recorremos sus campos y los almacenamos en una lista
        List<String> campos = new List<String>();
        
        if(fieldSetObj==null){
            return campos;
        }

        for(Schema.FieldSetMember fsm : fieldSetObj.getFields()){

            if(fsm.getFieldPath().toLowerCase() != 'id'){
                campos.add(fsm.getFieldPath());
            }

        } 
        
        return campos;

    }
    
    /**
    * @author Facundo Luna
    * @date 29/09/2015
    * @description Devuelve los registros del paginador
    */
    public List<SObject> getSObjects(){
        ERPvs.ApexLogger.Debug(LoggingLevel.WARN,' >> searchquery: ' + searchquery);
        if(ApexPages.getMessages() != null){
            ApexPages.getMessages().clear();
        }
        if(searchText == null || searchText.equals('') || searchText.replace('*', '').length() < 3){
            searchTextInternal = '* OR *';
            if(searchText != null && !searchText.equals('') && searchText.replace('*', '').length() < 3){
                ApexPages.addmessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'El texto de búsqueda debe tener 3 o más caracteres'));
            }
        } else {
            searchTextInternal = searchText;
        }
        List<List<SObject>> results = search.query(searchquery);  
        return results[0];
    }

     /**
    * @author Maximo Martinez
    * @date 5/10/2015
    * @description Verifica si un id es un id valido
    */
    public static String validateId(String idParam) {
        if(String.isEmpty(idParam)){
            return idParam;
        }
        String id = String.escapeSingleQuotes(Idparam);
        if((id.length() == 15 || id.length() == 18) && Pattern.matches('^[a-zA-Z0-9]*$', id) && !Pattern.matches('^[0]*$', id) ) {
            return id;
        }
        return null;
    }
    
    
}