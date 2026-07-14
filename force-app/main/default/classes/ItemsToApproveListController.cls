/**
* @author Maximo Martinez
* @date 29/04/2020
* @description 
*/
public with sharing class ItemsToApproveListController {

    
    /**
    * @author Maximo Martinez
    * @date 29/04/2020
    * @description Devuelve los items a aprovar
    */
    @AuraEnabled
    public static List<SObject> getItemsToApprove(String objectApiName, String fieldSetApiName){

        Set<Id> targetObjectIds = new Set<Id>();

        for(ProcessInstanceWorkitem pInstanceWorkItem : ApprovalProcessServices.getItemsToApprove(UserInfo.getUserId(), ApprovalProcessServices.STATUS.PENDING)){

            if(String.isEmpty(objectApiName) || (Utils.getObjectTypeById(pInstanceWorkItem.ProcessInstance.TargetObjectId).getDescribe().getName().toLowerCase() == objectApiName.toLowerCase())){
                targetObjectIds.add(pInstanceWorkItem.ProcessInstance.TargetObjectId);
            }

        }

        return new QueryBuilder()
        .get(objectApiName)
        .filteringByIds(targetObjectIds)
        .usingFieldSet(fieldSetApiName)
        .getRecords();

    }

    /**
    * @author Maximo Martinez
    * @date 30/04/2020
    * @description Aprueba/Rejecta/Reasigna elemenos
    */
    @AuraEnabled
    public static String processApproveRejectReasign(List<Id> idsToProcess, String comments, String reasignTo, String action){
        
        if(action.toLowerCase() == ApprovalProcessServices.ACTIONS.APPROVE.name().toLowerCase()){
            return JSON.serialize(ApprovalProcessServices.approve(idsToProcess,comments));
        }else if(action.toLowerCase() == ApprovalProcessServices.ACTIONS.REJECT.name().toLowerCase()){
            return JSON.serialize(ApprovalProcessServices.reject(idsToProcess,comments));
        }else if(action.toLowerCase() == ApprovalProcessServices.ACTIONS.REASIGN.name().toLowerCase()){
            return JSON.serialize(ApprovalProcessServices.reasign(idsToProcess,reasignTo));
        }

        return null;

    }
    
}