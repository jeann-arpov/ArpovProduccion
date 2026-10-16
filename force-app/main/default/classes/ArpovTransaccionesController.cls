/**
 * @description Controller para la gestión de transacciones e ítems DUP en el portal de socios de ArPOV.
 * @author       Nerio Alvarado
 * @date         Julio 2026
 */
public without sharing class ArpovTransaccionesController {
    
    @AuraEnabled(cacheable=true)
    public static List<Transaccion__c> getTransaccionesByCuenta(String idCuentaLogueada) {
        try {
            if (String.isBlank(idCuentaLogueada) || idCuentaLogueada.length() < 14) {
                return new List<Transaccion__c>();
            }
            
            Id cuentaId = (Id)idCuentaLogueada;
            
            return [
                SELECT Id, 
                Name,
                CreatedDate, 
                Cultivo__c,
                Cultivo__r.Name, 
                Campana__c,
                Campana__r.Name, 
                Obtentor__c,
                Obtentor__r.Name, 
                Estado__c 
                FROM Transaccion__c 
                WHERE Nombre_de_la_cuenta__c = :cuentaId
                ORDER BY CreatedDate DESC
            ];
            
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener las transacciones de ArPOV: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getObtentores() {
        List<Map<String, String>> opciones = new List<Map<String, String>>();
        
        for(ObtentoresSREList__mdt obt : [
            SELECT Id__c, ObtentorName__c, Label 
            FROM ObtentoresSREList__mdt 
            ORDER BY Label ASC
        ]) {
            if (String.isNotBlank(obt.Id__c)) {
                Map<String, String> opcion = new Map<String, String>();
                opcion.put('label', obt.ObtentorName__c);
                opcion.put('value', obt.Id__c);
                opciones.add(opcion);
            }
        }
        return opciones;
    }
    
    @AuraEnabled
    public static List<Map<String, String>> getRelatedFiles(String transaccionId) {
        List<Map<String, String>> archivos = new List<Map<String, String>>();
        try {
            for(ContentDocumentLink cdl : [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension 
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :transaccionId
            ]) {
                Map<String, String> archivo = new Map<String, String>();
                archivo.put('documentId', cdl.ContentDocumentId);
                archivo.put('title', cdl.ContentDocument.Title + '.' + cdl.ContentDocument.FileExtension);
                archivos.add(archivo);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener archivos: ' + e.getMessage());
        }
        return archivos;
    }
    
    
 /**
 * @description Obtiene las últimas 3 campañas agrícolas por cada cultivo,
 * agrupadas por cultivo y ordenadas alfabéticamente por el nombre del cultivo.
 */
@AuraEnabled(cacheable=true)
public static List<Map<String, String>> getTodasLasCampanas() {
    List<Map<String, String>> opciones = new List<Map<String, String>>();
    
    try {
        // 1. Obtenemos los cultivos ordenados alfabéticamente
        List<Cultivo__c> cultivos = [
            SELECT Id, Name 
            FROM Cultivo__c 
            ORDER BY Name ASC
        ];

        if (cultivos.isEmpty()) {
            return opciones;
        }

        Set<Id> cultivoIds = new Map<Id, Cultivo__c>(cultivos).keySet();

        // 2. Traemos las campañas de esos cultivos
        // Ordenamos por Name ASC dentro de cada cultivo para que queden ej: 2024, 2025, 2026
        List<Campana_Agricola__c> todasLasCampanas = [
            SELECT Id, Name, Cultivo__c 
            FROM Campana_Agricola__c 
            WHERE Cultivo__c IN :cultivoIds
            ORDER BY Cultivo__c, Name DESC
        ];

        // 3. Agrupamos y limitamos a 3 campañas por cultivo
        Map<Id, List<Campana_Agricola__c>> campanasPorCultivo = new Map<Id, List<Campana_Agricola__c>>();
        
        for (Campana_Agricola__c cam : todasLasCampanas) {
            if (!campanasPorCultivo.containsKey(cam.Cultivo__c)) {
                campanasPorCultivo.put(cam.Cultivo__c, new List<Campana_Agricola__c>());
            }
            
            // Solo tomamos un máximo de 3 campañas por cultivo
            if (campanasPorCultivo.get(cam.Cultivo__c).size() < 3) {
                campanasPorCultivo.get(cam.Cultivo__c).add(cam);
            }
        }

        // 4. Construimos la lista final respetando el orden alfabético de los cultivos
        for (Cultivo__c cul : cultivos) {
            if (campanasPorCultivo.containsKey(cul.Id)) {
                
                List<Campana_Agricola__c> listaCampanas = campanasPorCultivo.get(cul.Id);
                
                // Opcional: Invertir la lista si quieres que los años queden en orden ascendente (2024, 2025, 2026)
                // Si prefieres de más reciente a más antigua (2026, 2025, 2024), elimina el bucle inverso.
                for (Integer i = listaCampanas.size() - 1; i >= 0; i--) {
                    Campana_Agricola__c cam = listaCampanas.get(i);
                    
                    Map<String, String> opcion = new Map<String, String>();
                    opcion.put('label', cam.Name);
                    opcion.put('value', cam.Id);
                    opciones.add(opcion);
                }
            }
        }

    } catch (Exception e) {
        throw new AuraHandledException('Error al obtener las campañas agrupadas: ' + e.getMessage());
    }

    return opciones;
}

    /**
     * @description Obtiene los cultivos asociados a un Obtentor específico a través de sus Variedades.
     * Agrupa por ID y Nombre del cultivo para retornar opciones únicas de picklist.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getCultivosPorObtentor(String obtentorId) {
        List<Map<String, String>> opciones = new List<Map<String, String>>();
        if (String.isBlank(obtentorId)) {
            return opciones;
        }
        try {
            // Agrupamos por ID y Name del Cultivo para evitar duplicados y retornar el Value (Id) correcto
            for(AggregateResult ar : [
                SELECT Cultivo__c cultivoId, Cultivo__r.Name cultivoName 
                FROM Variedad__c 
                WHERE Obtentor_Comercializa__c = :obtentorId 
                   OR Obtentor_Propietario__c = :obtentorId 
                GROUP BY Cultivo__c, Cultivo__r.Name
                ORDER BY Cultivo__r.Name ASC
            ]) {
                String idCultivo = (String)ar.get('cultivoId');
                String nombreCultivo = (String)ar.get('cultivoName');
                
                if (String.isNotBlank(idCultivo)) {
                    Map<String, String> opcion = new Map<String, String>();
                    opcion.put('label', nombreCultivo);
                    opcion.put('value', idCultivo);
                    opciones.add(opcion);
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener los cultivos filtrados: ' + e.getMessage());
        }
        return opciones;
    }

   /**
 * @description Obtiene las campañas agrícolas de los últimos 3 años para un Cultivo determinado.
 * Formato esperado en Name: "YYYY - CULTIVO"
 */
@AuraEnabled(cacheable=true)
public static List<Map<String, String>> getCampanasPorCultivo(String cultivoId) {
    List<Map<String, String>> opciones = new List<Map<String, String>>();
    if (String.isBlank(cultivoId)) {
        return opciones;
    }
    
    try {
        // Calcular el límite de los últimos 3 años dinámicamente
        Integer currentYear = Date.today().year();
        Integer minYear = currentYear - 2; // Ejemplo: 2026 - 2 = 2024 (Abarca 2024, 2025, 2026)
        
        for (Campana_Agricola__c cam : [
            SELECT Id, Name 
            FROM Campana_Agricola__c 
            WHERE Cultivo__c = :cultivoId 
            ORDER BY Name DESC
        ]) {
            // Extraer los primeros 4 caracteres para obtener el año
            if (String.isNotBlank(cam.Name) && cam.Name.length() >= 4) {
                String anioStr = cam.Name.substring(0, 4);
                
                if (anioStr.isNumeric()) {
                    Integer anioCampana = Integer.valueOf(anioStr);
                    
                    // Solo agregamos las campañas dentro de la ventana de los últimos 3 años
                    if (anioCampana >= minYear && anioCampana <= currentYear) {
                        Map<String, String> opcion = new Map<String, String>();
                        opcion.put('label', cam.Name);
                        opcion.put('value', cam.Id);
                        opciones.add(opcion);
                    }
                }
            }
        }
    } catch (Exception e) {
        throw new AuraHandledException('Error al obtener las campañas filtradas: ' + e.getMessage());
    }
    
    return opciones;
}
    @AuraEnabled
    public static String crearTransaccionDUP(String cuentaId, String obtentorId, String cultivoId, String campanaId, String comentarios, String documentId) {
        try {
            Id recordTypeId = Schema.SObjectType.Transaccion__c.getRecordTypeInfosByDeveloperName()
                .get('DUP')
                .getRecordTypeId();
            
            Transaccion__c nuevaTx = new Transaccion__c();
            nuevaTx.RecordTypeId = recordTypeId;
            nuevaTx.Nombre_de_la_cuenta__c = cuentaId;
            nuevaTx.Obtentor__c = obtentorId;
            nuevaTx.Cultivo__c = cultivoId;
            nuevaTx.Campana__c = campanaId;
            nuevaTx.Comentarios__c = comentarios;
            nuevaTx.Estado__c = 'Creada';
            nuevaTx.Respondida_via_Minisitio__c = true;
            
            insert nuevaTx;
            
            if (String.isNotBlank(documentId)) {
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = documentId;
                cdl.LinkedEntityId = nuevaTx.Id;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                insert cdl;
            }
            
            return nuevaTx.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error al procesar la declaración: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getProductosPorObtentor(String obtentorId, string cultivoId) {
        List<Map<String, String>> opciones = new List<Map<String, String>>();
        try {
            if (String.isBlank(obtentorId)) {
                return opciones;
            }
            for (Product2 prod : [
                SELECT Id, Cultivar_Inase__c 
                FROM Product2 
                WHERE Categoria__c = 'Uso Propio' 
                  AND Family = 'Regalía Extendida' 
                  AND Cultivo__c = : cultivoId
                  AND Obtentor_Comercializa__c = :obtentorId 
                ORDER BY Cultivar_Inase__c ASC
            ]) {
                Map<String, String> opcion = new Map<String, String>();
                opcion.put('label', prod.Cultivar_Inase__c);
                opcion.put('value', prod.Id);
                opciones.add(opcion);
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener los productos: ' + e.getMessage());
        }
        return opciones;
    }

    @AuraEnabled
    public static void guardarVariedadesDeclaradas(List<Item_de_DUP__c> items) {
        try {
            if (items != null && !items.isEmpty()) {
                insert items;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al guardar las variedades: ' + e.getMessage());
        }
    }
}