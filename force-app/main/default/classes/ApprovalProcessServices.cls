/**
* @author Maximo Martinez
* @date 29/04/2020
* @description capa de servicios relacionados con los approval process
*/
public with sharing class ApprovalProcessServices {

    /**
    * @author Maximo Martinez
    * @date 29/04/2020
    * @description Estado de los Items a Aprobar
    */
    public enum STATUS {PENDING}

    /**
    * @author Maximo Martinez
    * @date 29/04/2020
    * @description Acciones a realizar
    */
    public enum ACTIONS {APPROVE,REJECT,REASIGN}


    /**
    * @author Maximo Martinez
    * @date 29/04/2020
    * @description Acciones a realizar
    */
    public static List<ProcessInstanceWorkitem> getItemsToApprove(Id userId, STATUS status){
        return [SELECT ActorId,CreatedById,CreatedDate,ElapsedTimeInDays,ElapsedTimeInHours,ElapsedTimeInMinutes,Id,IsDeleted,OriginalActorId,ProcessInstanceId,SystemModstamp, ProcessInstance.TargetObjectId FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId != null AND ProcessInstance.Status = :status.name() AND ActorId = :userId];
    }
    

    /**
    * @author Maximo Martinez
    * @date 30/04/2020
    * @description Aprueba/Rejecta elementos
    */
    private static Approval.ProcessResult[] process(List<Id> idsToProcess, String comments, ACTIONS action){

        Set<Id> pInstanceWorkitems = (new Map<Id, ProcessInstanceWorkitem>([SELECT Id, ActorId, OriginalActorId, ProcessInstance.TargetObjectId FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId IN :idsToProcess])).keySet();

        List<Approval.ProcessWorkitemRequest> allReq = new List<Approval.ProcessWorkitemRequest>(); 
        
        for (Id pInstanceWorkitemsId:pInstanceWorkitems){
            
                Approval.ProcessWorkitemRequest req2 = new Approval.ProcessWorkitemRequest();
                req2.setComments(comments);
                req2.setAction(action.name().toLowerCase().capitalize()); //to approve use 'Approve'
                // req2.setNextApproverIds(new Id[] {UserInfo.getUserId()});

                // Use the ID from the newly created item to specify the item to be worked
                req2.setWorkitemId(pInstanceWorkitemsId);

                // Add the request for approval
                allReq.add(req2);

        }
        
        return Approval.process(allReq,false);
        
    }

    /**
    * @author Maximo Martinez
    * @date 30/04/2020
    * @description Aprueba elementos
    */
    public static Approval.ProcessResult[] approve(List<Id> idsToProcess, String comments){
        return process(idsToProcess, comments, ACTIONS.APPROVE);
    }

    /**
    * @author Maximo Martinez
    * @date 30/04/2020
    * @description Rejecta elementos
    */
    public static Approval.ProcessResult[] reject(List<Id> idsToProcess, String comments){
        return process(idsToProcess, comments, ACTIONS.REJECT);
    }

    /**
    * @author Maximo Martinez
    * @date 30/04/2020
    * @description Reasigna elementos
    */
    public static Database.SaveResult[] reasign(List<Id> idsToProcess, Id reasignTo){
        
        List<ProcessInstanceWorkitem> piWorkItemsUpdate = new List<ProcessInstanceWorkitem>();

        List<ProcessInstanceWorkitem> piWorkItems = [SELECT Id, ActorId, OriginalActorId, ProcessInstance.TargetObjectId FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId IN :idsToProcess];

        for(ProcessInstanceWorkitem piWorkItem: piWorkItems){
            piWorkItem.ActorId = reasignTo;
            piWorkItem.OriginalActorId = UserInfo.getUserId();
            piWorkItemsUpdate.add(piWorkItem);
        }

        return Database.update(piWorkItemsUpdate, false);

    }

}