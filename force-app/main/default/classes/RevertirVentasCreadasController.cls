public with sharing class RevertirVentasCreadasController {

    @AuraEnabled
    public static Id procesar(Id recordId) {

        List<PermissionSetAssignment> pSetAssignments = [SELECT Id, PermissionSetId, PermissionSet.Name, PermissionSet.ProfileId, PermissionSet.Profile.Name, AssigneeId, Assignee.Name FROM PermissionSetAssignment WHERE PermissionSet.Name = 'Reversar_Ventas_Creadas' AND AssigneeId = :UserInfo.getUserid()];

        if(pSetAssignments.isEmpty() && !Test.isRunningTest()){
            throw new AuraHandledException('No tiene permisos para realizar esta operación. Contacte a su administrador.');
        }

        return Database.executeBatch(new BatchApexRevertirVentasCreadas(recordId),1000);

    }

}