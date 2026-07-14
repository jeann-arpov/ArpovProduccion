public class EntradaPrecioObtentorHandler {

    static Boolean isRecursive = false;
    @TestVisible
    private static Set<Id> productosObtentorPrimeraEntrada = new Set<Id>();
    private static final String PRICEBOOK_SEMBRA_EVOLUCION = 'Lista de Precios Sembrá Evolución';
    
    public static void run(){
        switch on Trigger.operationType {
            when BEFORE_INSERT {
                beforeInsert();
            }
            when AFTER_INSERT {
                afterInsert();
            }
            when BEFORE_UPDATE {
                beforeUpdate();
            }
            when AFTER_UPDATE {
                afterUpdate();
            }
            when AFTER_DELETE {
                afterDelete();
            }
        }
    }

    public static void beforeInsert(){
        List<Entrada_Precio_Obtentor__c> entradas = getEntradasNew();
        for(Entrada_Precio_Obtentor__c e : entradas){
            epologDisparador('BEFORE_INSERT (valores que van a insertarse)', e);
        }

        Set<Id> productoIds = new Set<Id>();
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            if(entrada.Producto_Obtentor__c != null){
                productoIds.add(entrada.Producto_Obtentor__c);
            }
        }

        Set<Id> productosConEntradasExistentes = new Set<Id>();
        if(!productoIds.isEmpty()){
            for(AggregateResult ar : [
                SELECT Producto_Obtentor__c productoId
                FROM Entrada_Precio_Obtentor__c
                WHERE Producto_Obtentor__c IN :productoIds
                GROUP BY Producto_Obtentor__c
            ]){
                productosConEntradasExistentes.add((Id) ar.get('productoId'));
            }
        }

        Set<Id> productosPrimeraEntradaEnLote = new Set<Id>();
        List<Entrada_Precio_Obtentor__c> entradasConFechaFuturaObligatoria = new List<Entrada_Precio_Obtentor__c>();

        for(Entrada_Precio_Obtentor__c entrada : entradas){
            Boolean esPrimeraEntrada = entrada.Producto_Obtentor__c != null
                && !productosConEntradasExistentes.contains(entrada.Producto_Obtentor__c)
                && !productosPrimeraEntradaEnLote.contains(entrada.Producto_Obtentor__c);

            if(esPrimeraEntrada){
                productosPrimeraEntradaEnLote.add(entrada.Producto_Obtentor__c);
                productosObtentorPrimeraEntrada.add(entrada.Producto_Obtentor__c);
                entrada.Fecha_Inicio__c = Date.today();
            } else {
                entradasConFechaFuturaObligatoria.add(entrada);
            }
        }

        validarFechaInicioFutura(entradasConFechaFuturaObligatoria);
        validarFechaInicioDuplicada(entradas);
    }

    public static void afterInsert(){
        if(isRecursive){
            return;
        }
        List<Entrada_Precio_Obtentor__c> inserted = getEntradasNew();
        for(Entrada_Precio_Obtentor__c e : inserted){
            epologDisparador('AFTER_INSERT Trigger.new (post-commit mismo request)', e);
        }
        Set<Id> insertedIds = new Map<Id, Entrada_Precio_Obtentor__c>(inserted).keySet();
        for(Entrada_Precio_Obtentor__c e : [SELECT Id, Producto_Obtentor__c, Fecha_Inicio__c, Fecha_Fin__c, Precio_Unitario__c, PrecioUnitario__c FROM Entrada_Precio_Obtentor__c WHERE Id IN :insertedIds]){
            epologDisparador('AFTER_INSERT requery SOQL (estado en BD antes de updateFechasFin)', e);
        }
        updateFechasFin(inserted);
        procesarPrimerasEntradas(inserted);
    }

    public static void beforeUpdate(){
        List<Entrada_Precio_Obtentor__c> entradasNew = getEntradasNew();
        Map<Id, Entrada_Precio_Obtentor__c> entradasOld = new Map<Id, Entrada_Precio_Obtentor__c>(getEntradasOld());
        for(Entrada_Precio_Obtentor__c entrada : entradasNew){
            if(entrada.Estado__c == 'Procesada' && entradasOld.get(entrada.Id).Estado__c == entrada.Estado__c){
                if(entrada.Trigger_Update__c == false){
                    entrada.addError('No se puede modificar una entrada procesada');
                }else{
                    entrada.Trigger_Update__c = false;
                }
            }
        }

        if(!isRecursive) validarFechaInicioDuplicada(entradasNew);
    }

    public static void afterUpdate(){
        List<Entrada_Precio_Obtentor__c> toProcess = new List<Entrada_Precio_Obtentor__c>();
        Map<Id, Entrada_Precio_Obtentor__c> entradasOld = new Map<Id, Entrada_Precio_Obtentor__c>(getEntradasOld());
        for(Entrada_Precio_Obtentor__c entrada : getEntradasNew()){
            if(entrada.Estado__c == 'Creada' && entradasOld.get(entrada.Id).Fecha_Inicio__c != entrada.Fecha_Inicio__c) toProcess.add(entrada);
        }

        if(!toProcess.isEmpty() && !isRecursive) updateFechasFin(toProcess);
    }

    public static void afterDelete(){
        updateFechasFin(getEntradasOld(), true);
    }

    public static List<Entrada_Precio_Obtentor__c> getEntradasNew(){
        return (List<Entrada_Precio_Obtentor__c>) Trigger.new;
    }

    public static List<Entrada_Precio_Obtentor__c> getEntradasOld(){
        return (List<Entrada_Precio_Obtentor__c>) Trigger.old;
    }

    private static void epologDisparador(String contexto, Entrada_Precio_Obtentor__c e){
        Integer mes = e.Fecha_Inicio__c != null ? e.Fecha_Inicio__c.month() : null;
        System.debug(LoggingLevel.INFO, 'EPO DISPARADOR[' + contexto + '] Id=' + e.Id + ' Producto_Obtentor__c=' + e.Producto_Obtentor__c
            + ' Fecha_Inicio__c=' + e.Fecha_Inicio__c + ' MONTH=' + mes
            + ' Precio_Unitario__c=' + e.Precio_Unitario__c + ' PrecioUnitario__c=' + e.PrecioUnitario__c
            + ' Fecha_Fin__c=' + e.Fecha_Fin__c);
    }

    private static void procesarPrimerasEntradas(List<Entrada_Precio_Obtentor__c> entradas){
        if(productosObtentorPrimeraEntrada.isEmpty()){
            return;
        }

        Set<Id> entradaIds = new Set<Id>();
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            if(productosObtentorPrimeraEntrada.contains(entrada.Producto_Obtentor__c)){
                entradaIds.add(entrada.Id);
            }
        }
        productosObtentorPrimeraEntrada.clear();

        if(entradaIds.isEmpty()){
            return;
        }

        List<Entrada_Precio_Obtentor__c> entradasAProcesar = [
            SELECT Id, Precio_Unitario__c, PrecioUnitario__c, Producto_Obtentor__c, Producto_Obtentor__r.ProductoId__c
            FROM Entrada_Precio_Obtentor__c
            WHERE Id IN :entradaIds
        ];

        Id pricebookId = getSembraEvolucionPricebookId();
        Set<Id> product2Ids = new Set<Id>();
        for(Entrada_Precio_Obtentor__c entrada : entradasAProcesar){
            if(entrada.Producto_Obtentor__r.ProductoId__c != null){
                product2Ids.add(entrada.Producto_Obtentor__r.ProductoId__c);
            }
        }

        Map<Id, PricebookEntry> pbeByProduct2Id = new Map<Id, PricebookEntry>();
        if(pricebookId != null && !product2Ids.isEmpty()){
            for(PricebookEntry pbe : [
                SELECT Id, Product2Id
                FROM PricebookEntry
                WHERE Pricebook2Id = :pricebookId
                AND Product2Id IN :product2Ids
            ]){
                pbeByProduct2Id.put(pbe.Product2Id, pbe);
            }
        }

        List<PricebookEntry> pbesToUpdate = new List<PricebookEntry>();
        List<Entrada_Precio_Obtentor__c> entradasToUpdate = new List<Entrada_Precio_Obtentor__c>();

        for(Entrada_Precio_Obtentor__c entrada : entradasAProcesar){
            entradasToUpdate.add(new Entrada_Precio_Obtentor__c(
                Id = entrada.Id,
                Estado__c = 'Procesada',
                Trigger_Update__c = true
            ));

            Id product2Id = entrada.Producto_Obtentor__r.ProductoId__c;
            PricebookEntry pbe = product2Id != null ? pbeByProduct2Id.get(product2Id) : null;
            if(pbe == null){
                continue;
            }

            pbesToUpdate.add(new PricebookEntry(
                Id = pbe.Id,
                UnitPrice = entrada.Precio_Unitario__c,
                Unit_Price__c = entrada.PrecioUnitario__c
            ));
        }

        if(entradasToUpdate.isEmpty()){
            return;
        }

        isRecursive = true;
        if(!pbesToUpdate.isEmpty()){
            update pbesToUpdate;
        }
        update entradasToUpdate;
        isRecursive = false;
    }

    private static Id getSembraEvolucionPricebookId(){
        List<Pricebook2> pricebooks = [
            SELECT Id
            FROM Pricebook2
            WHERE Name = :PRICEBOOK_SEMBRA_EVOLUCION
            AND IsActive = true
            LIMIT 1
        ];
        return pricebooks.isEmpty() ? null : pricebooks[0].Id;
    }

    private static void validarFechaInicioFutura(List<Entrada_Precio_Obtentor__c> entradas){
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            if(entrada.Fecha_Inicio__c <= Date.today()){
                entrada.addError('La Fecha Inicio debe ser futura');
            }
        }
    }

    private static void updateFechasFin(List<Entrada_Precio_Obtentor__c> entradas){
        updateFechasFin(entradas, false);
    }

    private static void updateFechasFin(List<Entrada_Precio_Obtentor__c> entradas, Boolean isDelete){
        System.debug(LoggingLevel.INFO, 'EPO updateFechasFin start isDelete=' + isDelete + ' triggerOp=' + Trigger.operationType + ' size=' + entradas.size());
        Map<Id, Entrada_Precio_Obtentor__c> mapEntradasPrevias = getEntradasPrevias(entradas);
        Map<Id, Entrada_Precio_Obtentor__c> mapEntradasSiguientes = getEntradasSiguientes(entradas);
        List<Entrada_Precio_Obtentor__c> toUpdate = new List<Entrada_Precio_Obtentor__c>();

        for(Entrada_Precio_Obtentor__c entrada : entradas){
            Entrada_Precio_Obtentor__c entradaToUpdate = mapEntradasPrevias.get(entrada.Id);
            Entrada_Precio_Obtentor__c entradaSiguiente = mapEntradasSiguientes.get(entrada.Id);
            epologDisparador('updateFechasFin lista disparadora', entrada);
            if(entradaToUpdate != null){
                Date newFechaFin = isDelete ? (entradaSiguiente != null ? entradaSiguiente.Fecha_Inicio__c.addDays(-1) : null) : entrada.Fecha_Inicio__c.addDays(-1);
                Integer mesPrevia = entradaToUpdate.Fecha_Inicio__c != null ? entradaToUpdate.Fecha_Inicio__c.month() : null;
                Boolean mesSepOct = mesPrevia == 9 || mesPrevia == 10;
                Boolean precioUnitarioVacioOCero = entradaToUpdate.Precio_Unitario__c == null || entradaToUpdate.Precio_Unitario__c == 0;
                Boolean vr001ComoFormula = mesSepOct && precioUnitarioVacioOCero;
                System.debug(LoggingLevel.INFO, 'EPO entrada PREVIA a actualizar Id=' + entradaToUpdate.Id + ' Fecha_Inicio=' + entradaToUpdate.Fecha_Inicio__c + ' MONTH=' + mesPrevia
                    + ' PrecioUnitario__c(campo trigger)=' + entradaToUpdate.PrecioUnitario__c + ' Precio_Unitario__c(VR)=' + entradaToUpdate.Precio_Unitario__c
                    + ' newFechaFin=' + newFechaFin + ' vr001AND(sepOct,precioU_vacio0)=' + vr001ComoFormula);
                if(newFechaFin == null || newFechaFin >= entradaToUpdate.Fecha_Inicio__c){
                    Entrada_Precio_Obtentor__c stub = new Entrada_Precio_Obtentor__c(Id = entradaToUpdate.Id, Fecha_Fin__c = newFechaFin, Trigger_Update__c = true);
                    System.debug(LoggingLevel.INFO, 'EPO DML update fila PREVIA Id=' + stub.Id + ' (no es el disparador ' + entrada.Id + '). Campos en el stub: ' + stub.getPopulatedFieldsAsMap().keySet());
                    System.debug(LoggingLevel.INFO, 'EPO VR_001 usa Precio_Unitario__c de la fila PREVIA en BD; el precio del disparador no se copia al stub. Previa Precio_Unitario__c=' + entradaToUpdate.Precio_Unitario__c);
                    System.debug(LoggingLevel.INFO, 'EPO stub valores Fecha_Fin__c=' + stub.Fecha_Fin__c + ' Trigger_Update__c=' + stub.Trigger_Update__c + ' PrecioUnitario__c=' + stub.PrecioUnitario__c);
                    toUpdate.add(stub);
                }else{
                    entrada.addError('La fecha de inicio de la entrada no puede ser menor a la fecha de inicio de la entrada previa');
                }
            } else {
                System.debug(LoggingLevel.INFO, 'EPO sin entrada previa para Id=' + entrada.Id);
            }
        }

        if(toUpdate.isEmpty() == false){
            isRecursive = true;
            update toUpdate;
            isRecursive = false;
            System.debug(LoggingLevel.INFO, 'EPO updateFechasFin update OK count=' + toUpdate.size());
        } else {
            System.debug(LoggingLevel.INFO, 'EPO updateFechasFin sin filas a actualizar');
        }
    }

    private static Map<Id, Entrada_Precio_Obtentor__c> getEntradasPrevias(List<Entrada_Precio_Obtentor__c> entradas){
        Set<Id> productosObtentores = new Set<Id>();
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            productosObtentores.add(entrada.Producto_Obtentor__c);
        }

        Map<Id, Entrada_Precio_Obtentor__c> mapEntradasPrevias = new Map<Id, Entrada_Precio_Obtentor__c>();
        List<Entrada_Precio_Obtentor__c> entradasPrevias = [SELECT Id, Fecha_Inicio__c, Fecha_Fin__c, Producto_Obtentor__c, PrecioUnitario__c, Precio_Unitario__c FROM Entrada_Precio_Obtentor__c WHERE Producto_Obtentor__c IN :productosObtentores ORDER BY Fecha_Inicio__c desc];
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            for(Entrada_Precio_Obtentor__c entradaPrevia : entradasPrevias){
                if(entradaPrevia.Id != entrada.Id && entradaPrevia.Producto_Obtentor__c == entrada.Producto_Obtentor__c && entradaPrevia.Fecha_Inicio__c < entrada.Fecha_Inicio__c){
                    mapEntradasPrevias.put(entrada.Id, entradaPrevia);
                    break;
                }
            }
        }

        return mapEntradasPrevias;
    }

    private static Map<Id, Entrada_Precio_Obtentor__c> getEntradasSiguientes(List<Entrada_Precio_Obtentor__c> entradas){
        Set<Id> productosObtentores = new Set<Id>();
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            productosObtentores.add(entrada.Producto_Obtentor__c);
        }

        Map<Id, Entrada_Precio_Obtentor__c> mapEntradasSiguientes = new Map<Id, Entrada_Precio_Obtentor__c>();
        List<Entrada_Precio_Obtentor__c> entradasSiguientes = [SELECT Id, Fecha_Inicio__c, Fecha_Fin__c, Producto_Obtentor__c FROM Entrada_Precio_Obtentor__c WHERE Producto_Obtentor__c IN :productosObtentores ORDER BY Fecha_Inicio__c asc];
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            for(Entrada_Precio_Obtentor__c entradaSiguiente : entradasSiguientes){
                if(entradaSiguiente.Id != entrada.Id && entradaSiguiente.Producto_Obtentor__c == entrada.Producto_Obtentor__c && entradaSiguiente.Fecha_Inicio__c > entrada.Fecha_Inicio__c){
                    mapEntradasSiguientes.put(entrada.Id, entradaSiguiente);
                    break;
                }
            }
        }

        return mapEntradasSiguientes;
    }

    private static void validarFechaInicioDuplicada(List<Entrada_Precio_Obtentor__c> entradas){
        System.debug('validar fecha inicio duplicada');
        List<Date> fechasInicio = new List<Date>();
        Set<Id> productosObtentores = new Set<Id>();
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            fechasInicio.add(entrada.Fecha_Inicio__c);
            productosObtentores.add(entrada.Producto_Obtentor__c);
        }

        Map<String, Entrada_Precio_Obtentor__c> mapEntradas = new Map<String, Entrada_Precio_Obtentor__c>();
        for(Entrada_Precio_Obtentor__c entrada : [SELECT Producto_Obtentor__c, Fecha_Inicio__c FROM Entrada_Precio_Obtentor__c WHERE Fecha_Inicio__c IN :fechasInicio AND Producto_Obtentor__c IN :productosObtentores]){
            String key = (String) entrada.Producto_Obtentor__c + entrada.Fecha_Inicio__c;
            System.debug('key: ' + key);
            mapEntradas.put(key, entrada);
        }
        
        for(Entrada_Precio_Obtentor__c entrada : entradas){
            String key = (String) entrada.Producto_Obtentor__c + entrada.Fecha_Inicio__c;
            System.debug('key: ' + key);
            if(mapEntradas.containsKey(key) && mapEntradas.get(key).Id != entrada.Id) entrada.addError('No puede haber más de una entrada para un producto obtentor con la misma fecha de inicio');
        }
    }
}