public with sharing class RevertirVentasCreadasController {

    @AuraEnabled
    public static Id procesar(Id recordId) {

        List<PermissionSetAssignment> pSetAssignments = [SELECT Id, PermissionSetId, PermissionSet.Name, PermissionSet.ProfileId, PermissionSet.Profile.Name, AssigneeId, Assignee.Name FROM PermissionSetAssignment WHERE PermissionSet.Name = 'Reversar_Ventas_Creadas' AND AssigneeId = :UserInfo.getUserid()];

        if(pSetAssignments.isEmpty() && !Test.isRunningTest()){
            throw new AuraHandledException(Label.GENERAL_No_Permisos_Operacion);
        }

        return Database.executeBatch(new BatchApexRevertirVentasCreadas(recordId),1000);

    }

}