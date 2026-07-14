trigger tg_Caso_Gestionado on Caso_Gestionado__c (after insert, after update) {

    if(Trigger.isAfter){

        if(Trigger.isInsert || Trigger.isUpdate){

            UtilsCasoGestionado.postGestionTT(Trigger.new);

        }

    }

}