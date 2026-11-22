trigger ToneladaHTSyncTrigger on Hectareas_Tecnologicas__c(after update) {
  Map<Id, Decimal> toneladasPorHT = new Map<Id, Decimal>();

  for (Hectareas_Tecnologicas__c ht : Trigger.new) {
    Hectareas_Tecnologicas__c viejo = (Hectareas_Tecnologicas__c) Trigger.oldMap
      .get(ht.Id);
    if (viejo != null && ht.Toneladas__c != viejo.Toneladas__c) {
      toneladasPorHT.put(ht.Id, ht.Toneladas__c);
    }
  }

  if (toneladasPorHT.isEmpty()) {
    return;
  }

  List<Tonelada__c> aActualizar = new List<Tonelada__c>();
  for (Tonelada__c tn : [
    SELECT Id, HT_Id__c
    FROM Tonelada__c
    WHERE HT_Id__c IN :toneladasPorHT.keySet()
  ]) {
    aActualizar.add(
      new Tonelada__c(Id = tn.Id, Cantidad__c = toneladasPorHT.get(tn.HT_Id__c))
    );
  }

  if (!aActualizar.isEmpty()) {
    update aActualizar;
  }
}
