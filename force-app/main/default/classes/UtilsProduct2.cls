/**
* @author Maximo Martinez
* @date 06/08/2014
* @description Clase con diferentes metodos auxiliares para el objeto Product2
*/ 
public with sharing class UtilsProduct2 {
	
	/**
	* @author Maximo Martinez
	* @date 06/08/2014
	* @description Metodo que asigna a crea para c/ Producto un PriceBookEntry para la actual PriceBook2
	*/ 
	public static void cargarPrecioStandard(List<Product2> lista){


		//Variable que contendra el Id de la lista de Precios
		Id idListaPrecios = null;

		if(!Test.isRunningTest()){

			//Obtenemos la lista de precios standard
			List<Pricebook2> listasDePrecios = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1];

			//Verificamos si obtuvimos la lista de precios standard
			if(listasDePrecios.size() == 0)
				return;

			//Seteamos la lista de precios standard
			Pricebook2 listaDePrecios = listasDePrecios.get(0);

			idListaPrecios = listaDePrecios.Id;

		}else{

			idListaPrecios = Test.getStandardPricebookId();

		}	
		//Obtenemos los Ids de los Productos Intervinientes en la Operacionb

		//Set para contener los Ids de los Productos Intervinientes
		Set<Id> idsProductos = new Set<Id>();

		for(Product2 producto : lista){

			idsProductos.add(producto.Id);

		}


		


		//Verificamos si los productos creados ya tienen una entrada para esta lista de precios
		//con un precio determinado, a fin de no crear una entrada lo que causara un error

		//Set que contendra los ids de los productos que ya tienen un PriceBookENtry creado
		Set<Id> idsProductosConPBE = new Set<Id>();

		//Comenzamos a recorrer los PriceBookEntry y vamos coleccionando los ids de los productos
		//que ya tienen una entrada si los hay
		for(PricebookEntry pbe : [SELECT Pricebook2Id, Product2Id FROM PricebookEntry WHERE Pricebook2Id =:idListaPrecios AND Product2Id IN :idsProductos]){

			idsProductosConPBE.add(pbe.Product2Id);

		}

		//Finalmente recorremos los productos y para aquellos que no se creo aún una PriceBookEntry,
		//la damos de alta
		
		//Lista que contendra los PriceBookEntry a crear
		List<PricebookEntry> toInsert = new List<PricebookEntry>();

		for(Product2 producto : lista){

			//Si no tiene una PriceBookEntry, ya
			if(!idsProductosConPBE.contains(producto.Id)){

				//Creamos un PriceBookEntry
				PricebookEntry pbe = new PricebookEntry();

				//Seteamos los datos necesarios
				pbe.Pricebook2Id = idListaPrecios;
	            pbe.Product2Id = producto.Id;
	            pbe.UnitPrice = 0;
	            pbe.IsActive = true;

	            //Agregamos a la lista de PBE a insertar
	            toInsert.add(pbe);
			}

		}

		//Si tenemos datos a insertar, insertamos
		if(toInsert.size() > 0)
			insertList(toInsert);
		
	}


	/**
    * @author Maximo Martinez
    * @date 5/08/2014
    * @description Metodo Auxiliar de Insercion por lotes
    */ 
    private static void insertList(List<PricebookEntry> lista){
        
        List<PricebookEntry> toInsert = new List<PricebookEntry>();
        for(PricebookEntry c : lista){
            toInsert.add(c);
        
            if(toInsert.size() == 200){
                insert toInsert;
                toInsert.clear();
            }
        }
        
        if(toInsert.size() > 0){
            insert toInsert;
            toInsert.clear();
        }

        
    }

}