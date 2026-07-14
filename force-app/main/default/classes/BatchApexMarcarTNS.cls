public with sharing class BatchApexMarcarTNS implements Database.Batchable<sObject>, Database.Stateful{

    private Date fechaVencimientoTNs;
    private Map<Id, Map<Id, Decimal>> cantidadPorCultivoYProductor;
    private Map<Id, Date> vencimientoPorCultivo;
    private Map<Id, String> cuitPorProductor;
    
    public BatchApexMarcarTNS() {
        cantidadPorCultivoYProductor = new Map<Id, Map<Id, Decimal>>();
        vencimientoPorCultivo = new Map<Id, Date>();
        cuitPorProductor = new Map<Id, String>();
    }

    public BatchApexMarcarTNS(String fecha){
        this.fechaVencimientoTNs = getDateFromString(fecha);
        cantidadPorCultivoYProductor = new Map<Id, Map<Id, Decimal>>();
        vencimientoPorCultivo = new Map<Id, Date>();
        cuitPorProductor = new Map<Id, String>();
    }

    public Iterable<Tonelada__c> start(Database.BatchableContext BC){
        System.debug('=== START BATCH ===');
        Date fechaInicio = Date.newInstance(Date.today().year(), 03, 01);
        Date fechahoy = Test.isRunningTest() ? Date.newInstance(Date.today().year(), 03, 15) : Date.newInstance(Date.today().year(), 03, 1);
        System.debug('Buscando cultivos con vencimiento entre: ' + fechaInicio + ' y ' + fechahoy);

        for(Cultivo__c cultivo : [SELECT Id, Fecha_Vencimiento_de_Tonelada__c FROM Cultivo__c WHERE Sembra_Evolucion__c = true]){
            if(cultivo.Fecha_Vencimiento_de_Tonelada__c >= fechaInicio && cultivo.Fecha_Vencimiento_de_Tonelada__c <= fechahoy){
                vencimientoPorCultivo.put(cultivo.Id, cultivo.Fecha_Vencimiento_de_Tonelada__c);
                System.debug('Cultivo encontrado: ' + cultivo.Id + ' - Vencimiento: ' + cultivo.Fecha_Vencimiento_de_Tonelada__c);
            }
        }

        if(!vencimientoPorCultivo.isEmpty()){
            System.debug('Total cultivos con vencimiento encontrados: ' + vencimientoPorCultivo.size());
            // PRUEBA: Filtrar solo por productor específico
            Id productorPrueba = '001G000001XYlIDIA1';
            System.debug('*** MODO PRUEBA: Solo procesando productor ' + productorPrueba + ' ***');
            return (Iterable<Tonelada__c>) Database.getQueryLocator([
                SELECT Id, Cultivo__c, Productor__c, Productor__r.N_CUIT__c, Cantidad_con_Signo__c 
                FROM Tonelada__c 
                WHERE Fecha_Fin__c >= :Date.newInstance(Date.today().year(), 03, 01) 
                AND Fecha_Fin__c <= :fechahoy
                AND Tonelada_Anterior__c = false 
                AND Cultivo__c IN :vencimientoPorCultivo.keySet() 
                AND Biotecnologia__c IN ('Enlist E3', 'Conkesta E3')
            ]);
        }

        System.debug('No se encontraron cultivos con vencimiento');
        return new Tonelada__c[0];
    }

    public void execute(Database.BatchableContext BC, List<Tonelada__c> scope){
        System.debug('=== EXECUTE BATCH - Procesando ' + scope.size() + ' toneladas ===');
        Set<Id> tnIds = new Map<Id, Tonelada__c>(scope).keySet();

        for(AggregateResult ag : [SELECT Cultivo__c cultivo, Productor__c productor, Productor__r.N_CUIT__c cuit, SUM(Cantidad_con_Signo__c) cantidad 
                                  FROM Tonelada__c WHERE Id IN :tnIds 
                                  GROUP BY Cultivo__c, Productor__c, Productor__r.N_CUIT__c 
                                  ORDER BY Cultivo__c, Productor__c]){
            Id cultivo = (Id) ag.get('cultivo');
            Id productor = (Id) ag.get('productor');
            Decimal cantidad = (Decimal) ag.get('cantidad');

            if(!cantidadPorCultivoYProductor.containsKey(cultivo)){
                cantidadPorCultivoYProductor.put(cultivo, new Map<Id, Decimal>());
            }
             if(!cantidadPorCultivoYProductor.get(cultivo).containsKey(productor)){
                cantidadPorCultivoYProductor.get(cultivo).put(productor, cantidad);
             } else {
                Decimal cantActual = cantidadPorCultivoYProductor.get(cultivo).get(productor);
                cantidadPorCultivoYProductor.get(cultivo).put(productor, cantidad + cantActual);
             }

            cuitPorProductor.put(productor, (String) ag.get('cuit'));
        }

        List<Tonelada__c> tnsToUpdate = new List<Tonelada__c>();
        for(Id tnId : tnIds){
            tnsToUpdate.add(new Tonelada__c(Id = tnId, Tonelada_Anterior__c = true));
        }
        
        System.debug('Marcando ' + tnsToUpdate.size() + ' toneladas como anteriores');
        update tnsToUpdate;
    }

    public void finish(Database.BatchableContext BC){
        System.debug('=== FINISH BATCH MARCAR TNS ===');
        System.debug('Total cultivos procesados: ' + cantidadPorCultivoYProductor.size());
        
        if(!cantidadPorCultivoYProductor.isEmpty()){
            Account sembraEvolucion = [SELECT Id FROM Account WHERE Name = 'Sembrá Evolución'];
            System.debug('Canal Sembrá Evolución obtenido: ' + sembraEvolucion.Id);
            
            // Encadenar batch para insertar las nuevas toneladas
            System.debug('Lanzando batch de inserción de toneladas...');
            BatchApexInsertarToneladasTNS batchInsertar = new BatchApexInsertarToneladasTNS(
                cantidadPorCultivoYProductor,
                cuitPorProductor,
                sembraEvolucion.Id
            );
            Database.executeBatch(batchInsertar, 200);
            System.debug('*** BATCH DE INSERCIÓN LANZADO ***');
        } else {
            System.debug('No hay datos para procesar en finish');
        }
        
        System.debug('=== END BATCH MARCAR TNS ===');
    }

    private static Date getDateFromString(String fecha){
        List<String> parts = fecha.split('-');
        return Date.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), Integer.valueOf(parts[2]));
    }
}