/**
* @author Maximo Martinez
* @date 17/02/2020
* @description Clase controladora de la vista excelUploader
*/
public with sharing class UploadItemDupExcelController {

    /**
    * @author Maximo Martinez
    * @date 17/02/2020
    * @description Crea Items de DUP y transacciones a partir de filas del archivo
    */
    @AuraEnabled
    public static Id processFileRows(List<Map<String,Object>> fileRows, Id campaignId,Id deslintadoraId, String description){
        return Database.executeBatch(new BatchApexProcessItemsDupsFromExcel(fileRows,campaignId,deslintadoraId,description),BatchApexProcessItemsDupsFromExcel.BATCH_SIZE);
    }

}