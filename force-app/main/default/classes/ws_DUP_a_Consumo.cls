/**
* @author Maximo Martinez
* @date 12/07/2019
* @description Clase que contiene WebServices la operatoria del Boton DUP a Consumo
*/
global class ws_DUP_a_Consumo {
    
    /**
	* @author Maximo Martinez
	* @date 12/07/2019
	* @description  barre todos lo ítems de la transacción poniendo el campo [ Item_de_DUP__c:Cantidad_Declarada__c ] en 0 en cada registro asociado a esa transacción
	* @param idTransaccion : id de la Transaccion 
	*/
    @AuraEnabled
    WebService static Result dupAConsumo(Id idTransaccion){
        
        Result r = new Result();

        List<Item_de_DUP__c> itemsToUpdate = new List<Item_de_DUP__c>();

        for(Transaccion__c t : [SELECT Id, Estado__c, (SELECT Id FROM Item_de_DUP__r) FROM Transaccion__c WHERE Id = :idTransaccion]){
            
            if(t.Estado__c != 'Creada'){
                r.error = 'La transacción debe estar en Estado Creada.';
                continue;
            }

            for(Item_de_DUP__c idd : t.Item_de_DUP__r){

                idd.Cantidad_Declarada__c = 0;
                
                itemsToUpdate.add(idd);
            
            }

        }

        if(itemsToUpdate.isEmpty()){
            r.success = r.error == null || r.error.length() == 0;
            return r;
        }

        List<Database.SaveResult> svrs = Utils.updateList(itemsToUpdate, false);

        Integer i = 0;

        for(Database.SaveResult svr : svrs){
            if(!svr.isSuccess()){
                r.error += String.format('Error al actualizar el registro {0}. Error {1}.'+'\n', new List<String>{itemsToUpdate[i].Id,svr.getErrors()[0].getMessage()});
            }
            i++;
        }

        r.success = r.error == null || r.error.length() == 0;

        return r;

    }


	/**
    * @author Maximo Martinez
    * @date 24/10/2014
    * @description Clase Auxiliar que representa el resultado que envia el WebServices
    */
    global class Result{
		@AuraEnabled
        WebService String error {get; set;}
        @AuraEnabled
        WebService Boolean success {get; set;}
    }

}