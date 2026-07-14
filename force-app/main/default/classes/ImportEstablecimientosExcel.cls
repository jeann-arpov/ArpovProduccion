public without sharing class ImportEstablecimientosExcel {
    
    @AuraEnabled
    public static List<Map<String, Object>> doImport(List<Map<String, Object>> fileRows){
        Id accountId = CrearCompraController.getAccount().Id;
        List<Establecimiento__c> toInsert = new List<Establecimiento__c>();
        
        Boolean error = false;

        for(Map<String, Object> row : fileRows){
            Establecimiento__c establecimiento;

            try {
                establecimiento = (Establecimiento__c) JSON.deserializeStrict(JSON.serialize(row), Establecimiento__c.class);
            } catch (Exception e) {
                addError(row, e.getMessage());
            }

            if(establecimiento != null){
                establecimiento.Vigente__c = true;
                establecimiento.Productor__c = accountId;
                establecimiento.Origen__c = 'Propio';
    
                if(String.isBlank(establecimiento.Name)) addError(row, 'Falta el valor de Name');
                if(establecimiento.Coordenadas__longitude__s == null) addError(row, 'Falta el valor de Coordenadas__longitude__s');
                if(establecimiento.Coordenadas__latitude__s == null) addError(row, 'Falta el valor de Coordenadas__latitude__s');
            }

            if(!row.containsKey('Error')){
                toInsert.add(establecimiento);
            }else{
                error = true;
            }
        }

        List<Database.SaveResult> dmlResults = Database.insert(toInsert, true);
        integer offset = 0;

        for(Integer i = 0; i < fileRows.size(); i++){
            if(fileRows[i].containsKey('Error')){
                offset ++;
                continue;
            }
            if(dmlResults.size() <= (i - offset)){
                break;
            }
            if(!dmlResults[i - offset].isSuccess()){
                for(Database.Error err: dmlResults[i - offset].getErrors()) {
                    String errorMessage =  err.getMessage();
                    addError(fileRows[i], errorMessage);
                }
                error = true;
            }
        }

        for(Map<String,Object> fileRow : fileRows){
            List<String> errores = (List<String>) fileRow.get('Error');
            if(errores != null){
                fileRow.put('Error', String.join(errores, ', '));
            }
        }

        if(!fileRows.isEmpty()){
            fileRows[0].put('isSuccess', !error);
        }

        return fileRows;
    }

    private static void addError(Map<String,Object> row , String error){
        if(row.get('Error') == null){
            row.put('Error', new List<String>());
        }
        
       List<String> l = (List<String>) row.get('Error');
       l.add(error);
    }
}