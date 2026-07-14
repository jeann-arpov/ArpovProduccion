trigger tg_RestrictAuditoriaDeletion on Transaccion__c (before delete) {
    // Error si se trata de eliminar una auditoría con líneas asociadas.
    
    Transaccion__c Auditorias_1 = [SELECT Id, Estado__c FROM Transaccion__c WHERE Id = :Trigger.old];
    if( Auditorias_1.Estado__c <> 'Borrador' && Auditorias_1.Estado__c <> 'Creada' ){
       Trigger.oldMap.get(Auditorias_1.Id).addError('<br><br><b><font size="3" color="red">[AUD-1001D]: No se puede borrar una Trasacción en estado ' + Auditorias_1.Estado__c + '.</b></font><br><font size="3"><hr>Verifique la operación que desea realizar.</font><br><br><font size="2">En caso de error por favor comunicarse con sistemas de</font><font size="3"><b> Ar</font><font size="3"color="green">POV</font></b> - <font size="2"><A HREF="mailto:soporte@arpov.org.ar"><i>soporte@arpov.org.ar</i></A></font>');
    }  else {              
        for (Transaccion__c Auditorias : 
                        [SELECT Id
                        FROM Transaccion__c
                        WHERE Id IN (SELECT Auditoria__c FROM Item_Auditoria__c) AND
                        Id IN :Trigger.old]){
            Trigger.oldMap.get(Auditorias.Id).addError('<br><br><b><font size="3" color="red">[AUD-1002D]: No se puede borrar una Transacción con líneas de variedad asociadas.</b></font><br><font size="3"><hr>Verifique las líneas de variedad ingresadas y en caso de corresponder deberá eliminarlas primero.</font><br><br><font size="2">En caso de error por favor comunicarse con sistemas de</font><font size="3"><b> Ar</font><font size="3"color="green">POV</font></b> - <font size="2"><A HREF="mailto:soporte@arpov.org.ar"><i>soporte@arpov.org.ar</i></A></font>');
        }
    }
}