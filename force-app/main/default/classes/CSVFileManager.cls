/**
* @author Maximo Martinez
* @date 16/09/2014
* @description Clase encargada de manejar archivos CSV
*/
public with sharing class CSVFileManager {


	/**
	* @author Maximo Martinez
	* @date 16/09/2014
	* @description Metodo que retorna el body de un file en formato de lista de lineas
	*/
	public static List<String> getBody(Blob cvsFile,Boolean skipHeader){
		
		//Obtengo las lineas del archivo
		List<String> lineas = getFileLines(cvsFile);

		if(!skipHeader)
			lineas.remove(0);

		return lineas;	

	}

	/**
	* @author Maximo Martinez
	* @date 16/09/2014
	* @description Metodo que retorna el body de un file en formato de lista de lineas con elementos 
	*/
	public static List<List<String>> getBody(Blob cvsFile,Boolean skipHeader, String separador){
		
		//Obtengo las lineas del archivo
		List<List<String>> lineas = getFileLines(cvsFile, separador);

		if(!skipHeader)
			lineas.remove(0);

		return lineas;	

	}


	/**
	* @author Maximo Martinez
	* @date 16/09/2014
	* @description Metodo que toma el contenido del file CSV y lo devuelve en una 
	* @description lista de lineas sin hacer split de los elementos de la misma
	*/ 
    public static List<String> getFileLines(Blob cvsFile){

    	//Instanciamos una clase CSVFile

        //Obtenemos el cuerpo del archivo
        String bodyFile = cvsFile.toString();
        
        //Obtenemos la lineas del archiv
        List<String> lines = bodyFile.split('\n');
        
        //Devolvemos los datos procesados
        return lines;
    }

	/**
	* @author Maximo Martinez
	* @date 16/09/2014
	* @description Metodo que toma el contenido del file CSV y lo devuelve en una lista de lineas
	*/ 
    public static List<List<String>> getFileLines(Blob cvsFile, String separador){

    	//Instanciamos una clase CSVFile

        //Obtenemos el cuerpo del archivo
        String bodyFile = cvsFile.toString();
        
        //Obtenemos la lineas del archiv
        String[] filelines = bodyFile.split('\n');
        
        List<List<String>> lineas = new List<List<String>>();
        
        //Recorremos cada linea
        for (Integer i=0;i<filelines.size();i++){
            //Obtenemos los valores del renglon
            List<String> linea = filelines[i].split(separador);
            
            lineas.add(linea);
        }
        
        //Devolvemos los datos procesados
        return lineas;
    }

    /**
	* @author Maximo Martinez
	* @date 16/09/2014
	* @description Metodo que devuelve los elementos de una linea especifica
	*/ 
	public static List<String> getLineElements(String lines, String separador){
		return lines.split(separador);

	}

}