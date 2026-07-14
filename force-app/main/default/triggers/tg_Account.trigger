trigger tg_Account on Account (after insert, after update) {
    
    if(Trigger.isAfter){

        if(Trigger.isInsert || Trigger.isUpdate){
            
            //Lista de Cuentas a actualizar contacto remesa
            List<UtilsAccount.WrapperAccountEmail> cuentasToUpdateCR = new List<UtilsAccount.WrapperAccountEmail>();
        
            Utils.setearTokenProductores(Trigger.new);
            
            //Recorremos las cuentas
            for(Account cuenta : Trigger.new){
                
                if(Trigger.isInsert){

                    cuentasToUpdateCR.add(new UtilsAccount.WrapperAccountEmail(cuenta, null));

                }else if(Trigger.isUpdate){ 
                    
                    if(cuenta.Direccion_de_Correo_electronico_del_CUIT__c != Trigger.oldmap.get(cuenta.Id).Direccion_de_Correo_electronico_del_CUIT__c){

                        cuentasToUpdateCR.add(new UtilsAccount.WrapperAccountEmail(cuenta, Trigger.oldmap.get(cuenta.Id).Direccion_de_Correo_electronico_del_CUIT__c));
                    
                    }

                }
                
            }    

            if(cuentasToUpdateCR.size() > 0){
                UtilsAccount.gestionarContactoRemesa(cuentasToUpdateCR);
            }

        }
        
    }
    
}