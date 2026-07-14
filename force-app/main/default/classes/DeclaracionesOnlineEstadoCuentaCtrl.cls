public without sharing class DeclaracionesOnlineEstadoCuentaCtrl {

	public final Integer MAX_NUMBER_REGISTERS = 1000;
	public final Integer RECORDS_PER_PAGE = 5;
    

	public Erpvs__Util_Formulario__c filtroFecha {get;set;}
    public Erpvs__Util_Formulario__c filtroFechaVencimiento {get;set;}
    public Integer currentPageNumber {get;set;}
    public Integer currentPageNumber2 {get;set;}
    public Integer rows {get;set;}
    public Integer pages {get;set;}
    public Integer totalRegistros {get;set;}
    public List<Wrapper> comprobantes {get;set;}
    private String qry;
    private String qryFilter;
    private String qryOrder;
    public String idObject {get; set;}
    public Integer offset {get;set;}
    public Map<Id,Id> attachemntsByCV {get; set;}

    private String sortDirection = 'DESC';
    
    private String sortExp = 'Oportunidad__r.Fecha_Emision_Comprobante__c';
    
    public String sortExpression{
        get{
            return sortExp;
        }
        set{
            //if the column is clicked on then switch between Ascending and Descending modes
            if (value == sortExp)
                sortDirection = (sortDirection == 'ASC')? 'DESC' : 'ASC';
            else
                sortDirection = 'ASC';
            sortExp = value;
        }
    }

    public String getSortDirection(){
        //if not column is selected 
        if (sortExpression == null || sortExpression == ''){
            return 'ASC';
        }else{
            return sortDirection;
        }
    }

    public void setSortDirection(String value){  
        sortDirection = value;
    }

	public DeclaracionesOnlineEstadoCuentaCtrl() {

		//Obtenemos el token pasado a la pagina 
       String token = ApexPages.currentPage().getParameters().get('token');
       
       //Si el token no es null lo desencriptamos
       if(token != null){
           
           	idObject = Utils.decryptToken(token.trim());
          
			filtroFecha = new Erpvs__Util_Formulario__c();
	        filtroFechaVencimiento = new Erpvs__Util_Formulario__c();

	        rows = RECORDS_PER_PAGE;

	        attachemntsByCV = new Map<Id, Id>();

	        qry = 'SELECT Id, Oportunidad__r.N_de_Comprobante__c, Oportunidad__r.Transaccion__r.Obtentor__r.Nombre_Obtentor__c, Oportunidad__r.Transaccion__r.Name, Oportunidad__r.Fecha_Emision_Comprobante__c, Oportunidad__r.Fecha_Vencimiento_Comprobante__c, Oportunidad__r.Divisa_Comprobante__c, Oportunidad__r.Importe_Total__c, Oportunidad__r.Saldo_a_Cobrar_Comprobante__c FROM ERPvs__Comprobante_Venta__c';

             if(!String.isBlank(idObject)){
	            String prefixObject = idObject.substring(0,3);
	            Schema.SObjectType so = Schema.getGlobalDescribe().get('Account');
	            Schema.DescribeSObjectResult describe = so.getDescribe();
	            if(prefixObject == describe.getKeyPrefix()){
	               doSearch();
	            }
	        }


	    }

	}

	public void doSearch(){
		
		qryFilter = 'Oportunidad__r.Tipo_de_Comprobante__c IN (\'FC\',\'NC\',\'ND\') AND ERPvs__A_cuenta_y_orden_de__c != NULL AND ERPvs__CAE__c != NULL';
        
        Date fechaDesde = filtroFecha.ERPvs__Fecha_Desde__c;
        Date fechaHasta = filtroFecha.ERPvs__Fecha_Hasta__c;
        Date fechaVencimientoDesde = filtroFechaVencimiento.ERPvs__Fecha_Desde__c;
        Date fechaVencimientoHasta = filtroFechaVencimiento.ERPvs__Fecha_Hasta__c;
        

        if(!String.isBlank(idObject)){
            qryFilter += ' AND ERPvs__Cliente__c = :idObject ';
        }

        if(fechaDesde!=null && fechaHasta!=null){
            qryFilter += (qryFilter.length() > 0 ? 'AND ' : '') + 'Oportunidad__r.Fecha_Emision_Comprobante__c >= :fechaDesde AND Oportunidad__r.Fecha_Emision_Comprobante__c <= :fechaHasta ';
        }

        if(fechaVencimientoDesde!=null && fechaVencimientoHasta!=null){
            qryFilter += (qryFilter.length() > 0 ? 'AND ' : '') + 'Oportunidad__r.Fecha_Vencimiento_Comprobante__c >= :fechaVencimientoDesde AND Oportunidad__r.Fecha_Vencimiento_Comprobante__c <= :fechaVencimientoHasta ';
        }

        qryFilter = !String.isBlank(qryFilter) ? ' WHERE ' + qryFilter : '';
        
        if(sortExpression != 'Oportunidad__r.N_de_Comprobante__c' && sortExpression != 'Oportunidad__r.Transaccion__r.Obtentor__r.Nombre_Obtentor__c' && sortExpression != 'Oportunidad__r.Transaccion__r.Name' && sortExpression != 'Oportunidad__r.Fecha_Vencimiento_Comprobante__c' && sortExpression != 'Oportunidad__r.Divisa_Comprobante__c' && sortExpression != 'Oportunidad__r.Importe_Total__c' && sortExpression != 'Oportunidad__r.Saldo_a_Cobrar_Comprobante__c'){
            qryOrder = ' ORDER BY ' + sortExpression + ' ' + sortDirection;
        }else{ 
            qryOrder = '';
        }

        System.debug(LoggingLevel.DEBUG, qry+qryFilter+qryOrder);

        List<ERPvs__Comprobante_Venta__c> comprobantesAux = Database.query(qry+qryFilter+qryOrder);
        
        offset = 0;
        
        currentPageNumber = 1;
        currentPageNumber2 = currentPageNumber;
        
        comprobantes = new List<Wrapper>();

        getComprobantes(comprobantesAux);
        
        totalRegistros = comprobantesAux.size();

        pages = calculatePages();

        System.debug(LoggingLevel.DEBUG, totalRegistros);
        
        // Ordenamiento manual para las columnas especiales
        if(sortExpression == 'Oportunidad__r.N_de_Comprobante__c' || sortExpression == 'Oportunidad__r.Transaccion__r.Obtentor__r.Nombre_Obtentor__c' || sortExpression == 'Oportunidad__r.Transaccion__r.Name' || sortExpression == 'Oportunidad__r.Fecha_Emision_Comprobante__c' || sortExpression == 'Oportunidad__r.Fecha_Vencimiento_Comprobante__c' || sortExpression == 'Oportunidad__r.Divisa_Comprobante__c' || sortExpression == 'Oportunidad__r.Importe_Total__c' || sortExpression == 'Oportunidad__r.Saldo_a_Cobrar_Comprobante__c'){
            
            comprobantes.sort();

        }
	
	}


	private void getComprobantes(List<ERPvs__Comprobante_Venta__c> comprobantesAux){

        attachemntsByCV.clear();

        if(comprobantesAux != null){
            
            Map<String,Wrapper> mapAux = new Map<String,Wrapper>();
            
            Wrapper wAux;
            
            for(ERPvs__Comprobante_Venta__c cv : comprobantesAux){
                
                wAux = new Wrapper(this, cv);
                
                comprobantes.add(wAux);

                attachemntsByCV.put(cv.Id, null);

                if(comprobantes.size() == MAX_NUMBER_REGISTERS){
                	break;
                }

            }

            // Hago la busqueda de los attachemn
            for(Attachment a : [Select ParentId, Id FROM Attachment Where ParentId IN :attachemntsByCV.keySet() AND Name = 'Factura_electronica.pdf' ORDER BY CreatedDate DESC]){
            	if(attachemntsByCV.get(a.ParentId) == null){
                    attachemntsByCV.put(a.ParentId, a.Id);
                }
            }

        }
    }

    public Integer calculatePages(){
    	Decimal d = Decimal.valueOf(totalRegistros);
        d = d.divide(rows, 0, System.RoundingMode.DOWN);
        return Integer.valueOf(String.valueOf(d));
    }

	public Boolean getHasNext(){
        System.debug(LoggingLevel.DEBUG, currentPageNumber);
        System.debug(LoggingLevel.DEBUG, pages);
        System.debug(LoggingLevel.DEBUG, currentPageNumber < pages);
        return currentPageNumber < pages;
    }
    
    public Boolean getHasPrevious(){
        return currentPageNumber > 1;
    }


    public void doFirst(){
        offset = 0;
        currentPageNumber = 1;
        currentPageNumber2 = 1;
  	}


  	public void doPrevious(){

        if( offset - rows > 0 ){
            offset = offset - rows;
            currentPageNumber = (offset / rows)+1;
            currentPageNumber2 = currentPageNumber;
        }else{
            doFirst();
        }
    
    }
  
    public void doNext(){

        if( offset + rows < comprobantes.size() ){
            offset = offset + rows;
        }else{
            doLast();
        }

        currentPageNumber = (offset / rows)+1;
        currentPageNumber2 = currentPageNumber;
    	
    }
  
    public void doLast(){
        offset = (pages - 1) * rows;
        currentPageNumber = pages;
        currentPageNumber2 = currentPageNumber;
    }

    public Integer getRecordViewFrom(){
        return 1 + (RECORDS_PER_PAGE * (currentPageNumber - 1));
    }
    
    public Integer getRecordViewTo(){
        Integer records = RECORDS_PER_PAGE + (RECORDS_PER_PAGE * (currentPageNumber - 1));
        return totalRegistros < records ? totalRegistros : records;
    }


    public class Wrapper implements Comparable{
    	
    	public ERPvs__Comprobante_Venta__c cv {get;set;}
    	public DeclaracionesOnlineEstadoCuentaCtrl outerClass {get; set;}
        public Opportunity op {get; set;}

        public Wrapper(DeclaracionesOnlineEstadoCuentaCtrl outerClass, ERPvs__Comprobante_Venta__c cv){
            this.cv = cv;
            this.outerClass = outerClass;
            this.op = cv.Oportunidad__r;
        }

    	public Integer compareTo(Object compareTo) {

    		Wrapper compareToDetalle = (Wrapper)compareTo;
            
            Integer returnValue = 0;

            if(this.outerClass.sortExpression == 'Oportunidad__r.N_de_Comprobante__c'){
                
                if (this.op.N_de_Comprobante__c > compareToDetalle.op.N_de_Comprobante__c) {
                    
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }
                
                } else if (this.op.N_de_Comprobante__c < compareToDetalle.op.N_de_Comprobante__c) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }
                }

            }else if(this.outerClass.sortExpression == 'Oportunidad__r.Transaccion__r.Obtentor__r.Nombre_Obtentor__c'){
                
                if (this.op.Transaccion__r.Obtentor__r.Nombre_Obtentor__c > compareToDetalle.op.Transaccion__r.Obtentor__r.Nombre_Obtentor__c) {
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }

                } else if (this.op.Transaccion__r.Obtentor__r.Nombre_Obtentor__c < compareToDetalle.op.Transaccion__r.Obtentor__r.Nombre_Obtentor__c) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }

                }

            }else if(this.outerClass.sortExpression == 'Oportunidad__r.Transaccion__r.Name'){
                
                if (this.op.Transaccion__r.Name > compareToDetalle.op.Transaccion__r.Name) {
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }

                } else if (this.op.Transaccion__r.Name < compareToDetalle.op.Transaccion__r.Name) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }

                }

            }else if(this.outerClass.sortExpression == 'Oportunidad__r.Fecha_Emision_Comprobante__c'){
                
                if (this.op.Fecha_Emision_Comprobante__c > compareToDetalle.op.Fecha_Emision_Comprobante__c) {
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }

                } else if (this.op.Fecha_Emision_Comprobante__c < compareToDetalle.op.Fecha_Emision_Comprobante__c) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }

                }

            }else if(this.outerClass.sortExpression == 'Oportunidad__r.Fecha_Vencimiento_Comprobante__c'){
                
                if (this.op.Fecha_Vencimiento_Comprobante__c > compareToDetalle.op.Fecha_Vencimiento_Comprobante__c) {
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }

                } else if (this.op.Fecha_Vencimiento_Comprobante__c < compareToDetalle.op.Fecha_Vencimiento_Comprobante__c) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }

                }

            }else if(this.outerClass.sortExpression == 'Oportunidad__r.Divisa_Comprobante__c'){
                
                if (this.op.Divisa_Comprobante__c > compareToDetalle.op.Divisa_Comprobante__c) {
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }

                } else if (this.op.Divisa_Comprobante__c < compareToDetalle.op.Divisa_Comprobante__c) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }

                }

            }else if(this.outerClass.sortExpression == 'Oportunidad__r.Importe_Total__c'){
                
                if (this.op.Importe_Total__c > compareToDetalle.op.Importe_Total__c) {
                    
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }

                } else if (this.op.Importe_Total__c < compareToDetalle.op.Importe_Total__c) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }

                }

            }else if(this.outerClass.sortExpression == 'Oportunidad__r.Saldo_a_Cobrar_Comprobante__c'){
                
                if (this.op.Saldo_a_Cobrar_Comprobante__c > compareToDetalle.op.Saldo_a_Cobrar_Comprobante__c) {
                    
                    // Set return value to a positive value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = 1;
                    }else{
                        returnValue = -1;
                    }

                } else if (this.op.Saldo_a_Cobrar_Comprobante__c < compareToDetalle.op.Saldo_a_Cobrar_Comprobante__c) {

                    // Set return value to a negative value.
                    if(this.outerClass.sortDirection == 'ASC'){
                        returnValue = -1;
                    }else{
                        returnValue = 1;
                    }

                }

            }

            
            return returnValue;
    	
        }


        public Id getAttachmentId(){

            if(cv != null){
                if(outerClass.attachemntsByCV.containsKey(cv.Id)){
				    return outerClass.attachemntsByCV.get(cv.Id);
                }
            }

			return null;
        }
    

    }
  


}