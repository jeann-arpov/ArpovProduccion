trigger AperturaCorreo on Apertura_Correo__e (after insert) {
    Set<String> tokens = new Set<String>();
    for (Apertura_Correo__e evento : Trigger.new) {
        tokens.add(evento.Token__c);
    }
    EnvioCorreoAperturaService.registrar(tokens);
}
