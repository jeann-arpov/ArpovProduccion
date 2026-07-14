public with sharing class BatchApexInsertarToneladasTNS implements Database.Batchable<String> {
    
    private Map<Id, Map<Id, Decimal>> cantidadPorCultivoYProductor;
    private Map<Id, String> cuitPorProductor;
    private Id sembraEvolucionId;
    
    public BatchApexInsertarToneladasTNS(Map<Id, Map<Id, Decimal>> cantidadPorCultivoYProductor, 
                                         Map<Id, String> cuitPorProductor,
                                         Id sembraEvolucionId) {
        this.cantidadPorCultivoYProductor = cantidadPorCultivoYProductor;
        this.cuitPorProductor = cuitPorProductor;
        this.sembraEvolucionId = sembraEvolucionId;
    }
    
    public Iterable<String> start(Database.BatchableContext BC) {
        System.debug('=== START BATCH INSERTAR TONELADAS ===');
        
        // Crear lista de pares cultivo-productor que necesitan inserción
        List<String> paresAInsertar = new List<String>();
        
        for(Id cultivoId : cantidadPorCultivoYProductor.keySet()) {
            for(Id productorId : cantidadPorCultivoYProductor.get(cultivoId).keySet()) {
                Decimal cantidad = cantidadPorCultivoYProductor.get(cultivoId).get(productorId);
                if(cantidad < 0) {
                    // Formato: "cultivoId|productorId"
                    paresAInsertar.add(cultivoId + '|' + productorId);
                }
            }
        }
        
        System.debug('Total pares cultivo-productor a insertar: ' + paresAInsertar.size());
        return paresAInsertar;
    }
    
    public void execute(Database.BatchableContext BC, List<String> pares) {
        System.debug('=== EXECUTE BATCH INSERTAR - Procesando ' + pares.size() + ' pares cultivo-productor ===');
        
        List<Tonelada__c> tnsToInsert = new List<Tonelada__c>();
        Date fechaInicio = Date.newInstance(Date.today().year(), 03, 01);
        Date fechaFin = Date.newInstance(Date.today().year() + 1, 03, 01);
        
        for(String par : pares) {
            // Parsear "cultivoId|productorId"
            List<String> ids = par.split('\\|');
            Id cultivoId = ids[0];
            Id productorId = ids[1];
            
            Decimal cantidad = cantidadPorCultivoYProductor.get(cultivoId).get(productorId);
            
            Tonelada__c tnToInsert = new Tonelada__c();
            tnToInsert.Cultivo__c = cultivoId;
            tnToInsert.Productor__c = productorId;
            tnToInsert.N_CUIT__c = cuitPorProductor.get(productorId);
            tnToInsert.Canal_de_Venta__c = sembraEvolucionId;
            tnToInsert.Fecha_Inicio__c = fechaInicio;
            tnToInsert.Fecha_Fin__c = fechaFin;
            tnToInsert.Fecha_Fin_Original__c = fechaFin;
            tnToInsert.Cantidad__c = cantidad * -1;
            tnToInsert.Signo__c = -1;
            tnToInsert.Biotecnologia__c = 'Enlist E3';
            tnToInsert.Etapa__c = 'Aplicada';
            tnToInsert.Origen__c = 'Balance Anual';
            tnToInsert.Tipo_de_Movimiento__c = 'D';
            tnToInsert.Tonelada_Anterior__c = false;
            
            tnsToInsert.add(tnToInsert);
        }
        
        if(!tnsToInsert.isEmpty()) {
            insert tnsToInsert;
            System.debug('Insertadas ' + tnsToInsert.size() + ' toneladas en este lote');
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        System.debug('=== FINISH BATCH INSERTAR TONELADAS ===');
        System.debug('*** PROCESO DE INSERCIÓN COMPLETADO ***');
    }
}