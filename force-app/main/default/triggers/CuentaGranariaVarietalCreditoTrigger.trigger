trigger CuentaGranariaVarietalCreditoTrigger on Hectareas_Tecnologicas__c(
  after insert,
  after update,
  after delete,
  after undelete
) {
  List<Hectareas_Tecnologicas__c> registros = Trigger.new != null
    ? Trigger.new
    : Trigger.old;

  Set<String> cultivosVarietales = new Set<String>();
  for (
    Configuracion_Varietal__mdt cfg : Configuracion_Varietal__mdt.getAll()
      .values()
  ) {
    if (String.isNotBlank(cfg.Cultivos_Varietales__c)) {
      for (String nombre : cfg.Cultivos_Varietales__c.split(',')) {
        if (String.isNotBlank(nombre)) {
          cultivosVarietales.add(nombre.trim().toUpperCase());
        }
      }
    }
  }

  Set<Id> cultivoIds = new Set<Id>();
  for (Hectareas_Tecnologicas__c ht : registros) {
    if (ht.Cultivo__c != null) {
      cultivoIds.add(ht.Cultivo__c);
    }
  }

  Set<Id> cultivosVarietalesIds = new Set<Id>();
  if (!cultivoIds.isEmpty() && !cultivosVarietales.isEmpty()) {
    for (Cultivo__c c : [
      SELECT Id
      FROM Cultivo__c
      WHERE Id IN :cultivoIds AND Name IN :cultivosVarietales
    ]) {
      cultivosVarietalesIds.add(c.Id);
    }
  }

  Set<String> claves = new Set<String>();
  for (Hectareas_Tecnologicas__c ht : registros) {
    if (
      ht.Productor__c != null &&
      ht.Cultivo__c != null &&
      ht.Campania__c != null &&
      cultivosVarietalesIds.contains(ht.Cultivo__c)
    ) {
      claves.add(
        String.valueOf(ht.Productor__c) +
          '|' +
          String.valueOf(ht.Cultivo__c) +
          '|' +
          String.valueOf(ht.Campania__c)
      );
    }
  }

  for (String clave : claves) {
    List<String> partes = clave.split('\\|');
    CuentaGranariaVarietalCreditoService.recalcularCreditos(
      partes[0],
      partes[1],
      partes[2]
    );
  }
}
