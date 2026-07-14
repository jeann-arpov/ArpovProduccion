global class BatchApexCargaPrecioStandard implements Database.Batchable<sObject> {
	
	//Atributos
	private Set<Id> idsProductos {get; set;}

	global BatchApexCargaPrecioStandard(Set<Id> idsProductos) {
		this.idsProductos = idsProductos;
	}
	
	global Database.QueryLocator start(Database.BatchableContext BC) {
		
		//Armamos la query

		String query = 'SELECT Id FROM Product2 WHERE Id IN :idsProductos';

		return Database.getQueryLocator(query);
	}

   	global void execute(Database.BatchableContext BC, List<Product2> scope) {
		
		UtilsProduct2.cargarPrecioStandard(scope);

	}
	
	global void finish(Database.BatchableContext BC) {
		
	}
	
}