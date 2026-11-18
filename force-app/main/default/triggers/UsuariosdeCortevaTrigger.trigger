trigger UsuariosdeCortevaTrigger on UsuariosdeCorteva__c (before insert, before update) {
    ContactosCortevaService.validarCorreoUnico(Trigger.new, Trigger.oldMap);
}
