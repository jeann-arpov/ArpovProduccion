/**
* @author Maximo Martinez
* @date 18/01/2017
* @description Clase que contiene Web Services SOAP para logica de Desaplicaciones
*/
global without sharing class ws_Desaplicar {

    /**
    * Dada una lista de aplicaciones, aplica el proceso de desaplicacion de las mismas
    * el cual consiste en eliminar Movimientos__c, Aplicacion_Item_DUP__c y Aplicacion_Item_AUD__c
    * de las Aplicaciones pasadas como parametro, asi como estas tambien. Para luego hacer actualizacion de 
    * las Oportunidades relacionadas.
    *
    * @author Maximo Martinez
    * @date 18/01/2017
    */
	webservice static String desaplicarFromAplicaciones(List<Id> idsAplicaciones){
        return JSON.serialize(desaplicarFromAplicaciones(idsAplicaciones,null));
    }

     /**
    * Dada una lista de aplicaciones, aplica el proceso de desaplicacion de las mismas
    * el cual consiste en eliminar Movimientos__c, Aplicacion_Item_DUP__c y Aplicacion_Item_AUD__c
    * de las Aplicaciones pasadas como parametro, asi como estas tambien. Para luego hacer actualizacion de 
    * las Oportunidades relacionadas.
    *
    * @author Maximo Martinez
    * @date 18/01/2017
    */
    @AuraEnabled
    public static Result desaplicarFromAplicaciones(List<Id> idsAplicaciones, Map<String,Object> formValuesByFieldName){
        // Map de listas usado para eliminar los registros
        Map<Integer,List<SObject>> mapsObjectToDelete = new Map<Integer,List<SObject>>{ 0 => new List<SObject>(), 1=>new List<SObject>(), 2=>new List<SObject>()};

        // Map de Importes por Facturas
        Map<Id, Decimal> importesByOppId = new Map<Id, Decimal>();

        List<Aplicacion> aplicaciones = new List<Aplicacion>();

        Set<Id> aplicacionesToNC = new Set<Id>();

        List<SObject> sobjectToInsert = new List<SObject>(); 

        // Resultado
        Result result = new Result();

        result.errors = new List<String>();

        // Por defecto indicamos que fallo
        result.isSuccess = false;

        // Lo primero sera verificar si el usuario tiene permisos para desaplicar
        if([SELECT COUNT() FROM User WHERE Id = :UserInfo.getUserId() AND Puede_Desaplicar__c = true] == 0){
            result.errors.add('No tiene permisos para realizar esta acción.');
            return result;
        }

        // Iniciamos una transaccion, de manera de que si la transaccion no es exitosa, entonces podamos
        // hacer un rollback de la misma y volver todo atrás.
        Savepoint sp = Database.setSavepoint();

        // Variable usada para indicar que hay que bloquear la accion para una aplicacion determinada
        Boolean stopAction = false;

        // PASO 1: Eliminar los Movimientos__c relacionados con las Aplicaciones

        // Buscamos los registros movimientos de la Aplicacion
        for(Aplicacion__c a : [SELECT Id, Tipo_de_Cambio_Vigente__c, Tipo_de_Cambio__c, Cuenta_Originante__c, Valor_Aplicado__c, Factura__c, Importe__c, Importe_Aplicar__c, Name, Comprobante_de_Pago__r.Estado_ERP__c, Comprobante_de_Pago__r.Cuenta_y_Orden__c, CV_Comisiones__c, (SELECT Id, Oportunidad__c, Cuenta__c, Importe__c, Tipo_de_Cambio__c, Moneda__c, Comprobante__c FROM Movimientos__r), (SELECT Id, Pago_Comisionado__c, Item_de_Auditoria__c FROM Apliciones_Item_de_AUD__r), (SELECT Id, Pago_Comisionado__c, Item_de_DUP__c FROM Aplicaciones__r) FROM Aplicacion__c WHERE Id IN :idsAplicaciones AND Comprobante_de_Pago__c != null]){

            // Reseteamos la varible que indica si hay que parar la accion para evitar desaplicación
            stopAction = false;

            if(a.Importe__c > 0 && a.Comprobante_de_Pago__r.Estado_ERP__c == 'PROCESADO' && a.Comprobante_de_Pago__r.Cuenta_y_Orden__c){
                
                stopAction = true;
                // Cargamos el error
                result.errors.add(String.format('No es posible desaplicar la Aplicación {0} ya que el Comprobante de Pago tiene Estado ERP igual a \'PROCESADO\'.', new List<String>{a.Name}));
                break;

            }else if(      
                
                        (a.Importe__c > 0 && a.Comprobante_de_Pago__r.Estado_ERP__c == 'SIN PROCESAR' && a.Comprobante_de_Pago__r.Cuenta_y_Orden__c ) 
                        || (a.Importe__c > 0 && !a.Comprobante_de_Pago__r.Cuenta_y_Orden__c && String.isEmpty(a.CV_Comisiones__c)) 
                        || (a.Importe__c < 0 && String.isEmpty(a.CV_Comisiones__c))
                        
                    ){

                mapsObjectToDelete.get(2).add(a);

                // Si tenemos movimientos los marcamos para eliminar
                if(!a.Movimientos__r.isEmpty()){
                    mapsObjectToDelete.get(0).addAll((List<SObject>)a.Movimientos__r);
                }

                // Si tenemos Items de Aplicaciones los marcamos para eliminar
                if(!a.Apliciones_Item_de_AUD__r.isEmpty()){
                    mapsObjectToDelete.get(1).addAll((List<SObject>)a.Apliciones_Item_de_AUD__r);
                }

                if(!a.Aplicaciones__r.isEmpty()){
                    mapsObjectToDelete.get(1).addAll((List<SObject>)a.Aplicaciones__r);
                }

            }else if(a.Importe__c > 0 && !a.Comprobante_de_Pago__r.Cuenta_y_Orden__c && String.isNotEmpty(a.CV_Comisiones__c)){

                Aplicacion app = new Aplicacion(a,a.Movimientos__r,a.Apliciones_Item_de_AUD__r,a.Aplicaciones__r,formValuesByFieldName);

                aplicaciones.add(app);

                sobjectToInsert.add(app.a);

            }else if(a.Importe__c < 0 && String.isNotEmpty(a.CV_Comisiones__c)){ // Caso donde la aplicacion es negativa y tiene cv
                
                //2020-07-17 FL Ahora entre las aplicaciones, las hay que tienen importe negativo, por lo tanto con ellas se debería generar una nc de comisiones.
                /*
                stopAction = true;
                // Cargamos el error
                result.errors.add(String.format('No es posible desaplicar la Aplicación {0} ya que la misma se encuentra comisionada.', new List<String>{a.Name}));
                break;
                */

                aplicacionesToNC.add(a.Id);
            
            }else{ // No cumple ninguna de las reglas pasadas

                continue;

            }


            // Guardamos la Aplicacion segun su factura
            if(!importesByOppId.containsKey(a.Factura__c)){
                importesByOppId.put(a.Factura__c, 0);
            }

            // Sumarizamos al importe
            importesByOppId.put(a.Factura__c, importesByOppId.get(a.Factura__c) + a.Importe_Aplicar__c);
        
        }

        // Si hay que detener el proceso, retornamos el error informado
        if(stopAction){
            return result;
        }

        // Intentamos Eliminar (en este orden): 
        // 1) Movimientos 
        // 2) Aplicacion_Item_DUP__c y Aplicacion_Item_AUD__c
        // 3) Aplicacion__c
        // si nos tira un error, hacemos rollback de la transaccion e indicamos el error
        // que estamos recibiendo
        
        Integer step;

        for(step=0; step < 3; step++){
            
            // Intentamos hacer la eliminacion
            try {
                
                delete mapsObjectToDelete.get(step);

            } catch(DmlException e) { // Ocurrio un error

                // Hacemos el rollback de la Transaccion
                Database.rollback(sp);
                
                // Marcamos el error
                for (Integer i = 0; i < e.getNumDml(); i++) {
                    result.errors.add(e.getDmlMessage(i));
                }

                // Salimos del ciclo
                break;

            }

        }

        // Si se completaro los tres pasos entonces ahora intentamos actualizar las oportunidades
        if(step!=3){
            return result;
        }

        // Insertamos las Aplicaciones clonadas
        try {

            insert sobjectToInsert;

            // Limpiamos la variable y marcamos los movimientos e items de app clonados para insertar
            sobjectToInsert.clear();

            for(Aplicacion a : aplicaciones){
                sobjectToInsert.addAll(a.doClone());
            }

            // intentamos insertar los items clonados
            insert sobjectToInsert;
            
        } catch(DmlException e) { // Ocurrio un error

            // Hacemos el rollback de la Transaccion
            Database.rollback(sp);
            
            // Marcamos el error
            for (Integer i = 0; i < e.getNumDml(); i++) {
                result.errors.add(e.getDmlMessage(i));
            }

            return result;

        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        // Intentamos actualizar las Oportunidades
        for(Opportunity o : [SELECT Id, Saldo_a_Cobrar_Comprobante__c, Saldo_a_Gestionar__c, Total_Comprobante__c FROM Opportunity WHERE Id IN :importesByOppId.keySet()]){
        
            // Revisamos si el importe esta en el map
            if(!importesByOppId.containsKey(o.Id)){
                continue;
            }    
        
            // Obtenemos el importe del map
            Decimal importe = importesByOppId.get(o.Id);
            
            // Sumarizamos a los campos
            o.Saldo_a_Cobrar_Comprobante__c += importe;
            o.Saldo_a_Gestionar__c += importe;

            // Controlamos que los Saldos no Superen Total_Comprobante__c si esto ocurre cargamos el Total Comprobante en lugar del saldo
            o.Saldo_a_Cobrar_Comprobante__c = (o.Saldo_a_Cobrar_Comprobante__c > o.Total_Comprobante__c) ? o.Total_Comprobante__c : o.Saldo_a_Cobrar_Comprobante__c;
            o.Saldo_a_Gestionar__c = (o.Saldo_a_Gestionar__c > o.Total_Comprobante__c) ? o.Total_Comprobante__c : o.Saldo_a_Gestionar__c;

            // Pasamos la Oportunidad a Facturada
            o.StageName = 'Facturada';
            
            // Marcamos la Opportunity para actualizar
            oppsToUpdate.add(o);
            
        }

        // Intentamos actualizar las Oportunidades, el cual sería el ultimo paso
        // Intentamos hacer la eliminacion
        try {
            
            update oppsToUpdate;

            // Si el resultado fue positivo lo indicamos en el objeto result
            result.isSuccess = true;

        } catch(DmlException e) { // Ocurrio un error

            // Hacemos el rollback de la Transaccion
            Database.rollback(sp);
            
            // Marcamos el error
            for (Integer i = 0; i < e.getNumDml(); i++) {
                result.errors.add(e.getDmlMessage(i));
            }

        }

        //2020-07-17 FL Ahora entre las aplicaciones, las hay que tienen importe negativo, por lo tanto con ellas se debería generar una nc de comisiones.
        if(!aplicacionesToNC.isEmpty()){
            // Enviamos a procesar por el batch
            BatchApexGenerarCVComisiones b = new BatchApexGenerarCVComisiones(aplicacionesToNC, true);
            Database.executebatch(b, BatchApexGenerarCVComisiones.BATCH_SIZE);
        }

        return result;
    }

    public class Aplicacion{

        public Aplicacion__c a {get; set;}
        
        public List<Movimientos__c> movimientos = new List<Movimientos__c>();
        public List<Aplicacion_Item_de_AUD__c> itemsAUD = new List<Aplicacion_Item_de_AUD__c>();
        public List<Aplicacion_Item_DUP__c> itemsDUP = new List<Aplicacion_Item_DUP__c>();
        
        public Aplicacion(Aplicacion__c a, List<Movimientos__c> movimientos, List<Aplicacion_Item_de_AUD__c> itemsAUD, List<Aplicacion_Item_DUP__c> itemsDUP,Map<String,Object> formValuesByFieldName){
            
            this.a = a.clone();
            
            this.a.Importe__c = this.a.Importe__c * -1;
            this.a.CV_Comisiones__c = null;

            if(formValuesByFieldName != null){
                for(String fieldName : formValuesByFieldName.keySet()){
                    this.a.put(fieldName,formValuesByFieldName.get(fieldName));
                }
            }
            
            this.movimientos = movimientos;
            this.itemsAUD = itemsAUD;
            this.itemsDUP = itemsDUP;

        }

        public List<SObject> doClone(){

            List<SObject> clonedItems = new List<SObject>();

            for(Movimientos__c mv : movimientos){
                Movimientos__c mvCloned = mv.clone();
                mvCloned.Tipo_de_Movimiento__c = 'DAP';
                mvCloned.Aplicacion__c = a.Id;
                clonedItems.add(mvCloned);
            }

            for(Aplicacion_Item_de_AUD__c aida : itemsAUD){
                Aplicacion_Item_de_AUD__c aidaCloned = aida.clone();
                aidaCloned.Aplicacion__c = a.Id;
                clonedItems.add(aidaCloned);
            }

            for(Aplicacion_Item_DUP__c aidu : itemsDUP){
                Aplicacion_Item_DUP__c aiduCloned = aidu.clone();
                aiduCloned.Aplicacion__c = a.Id;
                clonedItems.add(aiduCloned);
            }

            return clonedItems;
        }

    }

	/**
    * @author Maximo Martinez
    * @date 18/01/2017
    * @description Clase Auxiliar que representa un resultado de la operacion
    */
    public class Result{
        @AuraEnabled
    	public List<String> errors {get; set;}
        
        @AuraEnabled
        public Boolean isSuccess {get; set;}

    }

}