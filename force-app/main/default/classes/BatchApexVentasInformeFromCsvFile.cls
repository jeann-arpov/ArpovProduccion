public class BatchApexVentasInformeFromCsvFile implements Database.Batchable<Ventas_Informadas__c>, Database.Stateful {

    private List<Ventas_Informadas__c> ventasInformeToInsert;
    private Lote__c lote;

    
    public static final Integer SCOPE_SIZE = 100;

    public BatchApexVentasInformeFromCsvFile( List<Ventas_Informadas__c> ventasInformeToInsert ) {
            this.ventasInformeToInsert = ventasInformeToInsert;
            //this.lote = lote;
    }

    public List<Ventas_Informadas__c> start(Database.batchableContext batchableContext){
		// Obtenemos las lineas del archivo
		//return new CSVIterator(csvFile, introValue);
        System.debug('Start');
        return ventasInformeToInsert;
	}

    public void execute(Database.BatchableContext BC, List<Ventas_Informadas__c> ventasInformadas){

        System.debug('Execute');
        System.debug(ventasInformadas);
        List<Database.SaveResult> svrs = new List<Database.SaveResult>();
        List<Ventas_Informadas__c> toInsert = new List<Ventas_Informadas__c>();
        for(Ventas_Informadas__c v : ventasInformadas){
            toInsert.add(v);
        
            if(toInsert.size() == 200){
                svrs.addAll(Database.insert(toInsert,false));
                toInsert.clear();
            }
        }
        
        if(toInsert.size() > 0){
            svrs.addAll(Database.insert(toInsert,false));
            toInsert.clear();
        }
        System.debug(svrs);
        for(Integer i = 0 ; i < svrs.size() ; i++){
            Database.SaveResult svr = svrs.get(i);
            for(Database.Error err : svr.getErrors()) {                   
            System.debug(err);
            }

        }
       // List<Database.SaveResult> ventasSaveResult = UtilsVentas.insertPartialList(ventasToInsert);
    
    }
    public void finish(Database.BatchableContext BC){
        System.debug('Finish');

            // Mandar mail con los errores
    }

    

}