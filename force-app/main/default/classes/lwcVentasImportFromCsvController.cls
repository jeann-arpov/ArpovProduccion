public inherited sharing class lwcVentasImportFromCsvController {
  
    @AuraEnabled
    public static void saveFile(String base64Data){
        String data = JSON.deserializeUntyped(base64Data).toString();
        process(data);       
    }

    public static void process(String data) {
        String timeStamp = String.valueOf(System.now());

        List<Ventas_Informadas__c> ventasToInsert = createVentasInformesFromCsv(data, 'test', timeStamp);

        for(Integer i = 0; i < 10; i++){
            if( ventasToInsert.size() >= i ) break;
                System.debug(ventasToInsert[i]);
            
        }
		BatchApexVentasInformeFromCsvFile b = new BatchApexVentasInformeFromCsvFile(ventasToInsert);

		Id idJob = Database.executeBatch(b, BatchApexVentasInformeFromCsvFile.SCOPE_SIZE);

		BatchJobsStatus bj = new BatchJobsStatus();

		bj.idJob = idJob;

		bj.getBatchJobs();
    }



    public static  List<Ventas_Informadas__c> createVentasInformesFromCsv(String csvFile, String fileName, String timeStamp){


        //Map que contendra las lineas que estas duplicadas luego de la importaccion
        Map<String, List<Integer>> ventasDuplicadasError = new Map<String, List<Integer>>(); 

        //Map que contiene los posibles errores en las lineas de venta
       // ventasCSVErrores = new Map<Integer, VentaCSVErrores>();


        Integer blankLineCounter = 0;
        
        Integer ventasExitosas = 0;

        Integer errores = 0;

        Integer ventasSinCuenta = 0;


     //Lista que contendra las ventas a insertar
     List<Ventas_Informadas__c> ventasToInsert = new List<Ventas_Informadas__c>();

     //Recorremos las lineas del archivo

     Iterator<String> csvLines = new CSVIterator(csvFile).iterator(); 
     Integer i = 0;
     while(csvLines.hasNext()){

         //Obtenemos la linea actual del archivo
         String csvLine = csvLines.next();
       
         if(isEmptyLine(csvLine, ',')){
             blankLineCounter++;
             continue;
         }	
         
        // System.debug(LoggingLevel.INFO, String.valueOf((i))+' '+csvLine);

         //Verificamos si esta la entrada en el map
         if(!ventasDuplicadasError.containsKey(csvLine.trim())){
             ventasDuplicadasError.put(csvLine.trim(),new List<Integer>());
         }

         //Obtengo la lista de lineas duplicadas
         List<Integer> listaLineasDuplicadas = ventasDuplicadasError.get(csvLine.trim());

         //Agregamos la linea a la lista
         listaLineasDuplicadas.add((i));

         //Por el momento la linea no esta duplicada, procesamos la venta
         if(listaLineasDuplicadas.size() == 1){ 

            Ventas_Informadas__c venta = getVentaInformeCSVFromLine(csvLine);
            ventasToInsert.add(venta);

         }else{

            /*
            //Verifico si esta la entrada en el map
            if(!ventasCSVErrores.containsKey((i+offset))){
                ventasCSVErrores.put((i+offset),new VentaCSVErrores());
            }

            //Indico que es una venta duplicada
            ventasCSVErrores.get((i+offset)).ventaDuplicada = true;

            errores++;
            
            */
            } 

            i++;
        }

        return ventasToInsert;

    }

    public static Ventas_Informadas__c getVentaInformeCSVFromLine(String line){

        //Obtenemos los elementos de la linea
        List<String> lineElements = CSVFileManager.getLineElements(line, ',');

        //Instanciamos una nueva venta
        Ventas_Informadas__c ventaICSV = new Ventas_Informadas__c();

        //Recorremos los elementos de una linea del CSV
        for(Integer j = 0; j < lineElements.size() ; j++){

            String valor = lineElements[j].replaceAll('"','');

            if(j == 0){
                ventaICSV.Campana_de_Ventas__c = valor;
            }else if(j == 1){    
                ventaICSV.Cantidad_de_Bolsas__c = Double.valueOf(valor.replaceAll('"',''));
            }else if(j == 2){    
                ventaICSV.Categoria__c = valor;
            }else if(j == 3){    
                ventaICSV.CUIT_Destinatario__c = valor;
            }else if(j == 4){    
                ventaICSV.CUIT_Originante__c = valor;
            }else if(j == 5){    
                Date fecha = Utils.stringToDate(valor);
                if(fecha == null){
                    String[] stringDate = valor.split('-');
                    Integer d =  Integer.valueOf(stringDate[2]);
                    Integer m = Integer.valueOf(stringDate[1]);
                    Integer y = Integer.valueOf(stringDate[0]);     
                    fecha = Date.newInstance(y,m,d);
                }

                ventaICSV.Fecha_de_Facturacion__c = fecha;
            }else if(j == 6){    
                ventaICSV.Kilos_por_Bolsa__c = Double.valueOf(valor.replaceAll('"',''));
            }else if(j == 7){    
                ventaICSV.Linea_Facturacion__c = Double.valueOf(valor.replaceAll('"',''));
            }else if(j == 8){    
                ventaICSV.N_de_Comprobante__c = valor;
            }else if(j == 9){    
                ventaICSV.Razon_Social_Destinatario__c = valor;
            }else if(j == 10){    
                ventaICSV.Tipo_de_Comprobante__c = valor;
            }else if(j == 11){    
                ventaICSV.Variedad__c = valor;
            }

        }

        return ventaICSV;
    }

    private static Boolean isEmptyLine(String line, String separator){

        List<String> values = line.split(separator);

        Integer i = 0;

        while(i < values.size() && values.get(i).trim().length() == 0){
            i++;
        }

        return i == values.size();

    }


}