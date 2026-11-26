/**
 * Recrea la Tonelada__c de una HT restaurada desde la papelera (after undelete).
 * Los record-triggered flows no disparan en "undelete", por eso este trigger
 * delega en HtToneladaRecreador para regenerar la Tonelada perdida (SE-410).
 */
trigger tg_Hectareas_Tecnologicas_Recrear_Tonelada on Hectareas_Tecnologicas__c(
  after undelete
) {
  HtToneladaRecreador.recrearToneladas(Trigger.new);
}
