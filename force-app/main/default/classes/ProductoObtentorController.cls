public with sharing class ProductoObtentorController {

    @AuraEnabled(cacheable=true)
    public static ProductoWrapper getProductoObtentorData(String productId) {
        if (String.isBlank(productId)) {
            throw new AuraHandledException('El parámetro IdProduct es obligatorio.');
        }

        Producto_Obtentor__c producto = [
            SELECT Name,
                   Obtentor__r.Name,
                   Nombre_Variedad__c,
                   Tipo_de_Compra__c,
                   Marca__c,
                   Vigente__c
            FROM Producto_Obtentor__c
            WHERE Id = :productId
            LIMIT 1
        ];

        List<Entrada_Precio_Obtentor__c> preciosRaw = [
            SELECT Name,
                   Precio_Unitario__c,
                   Fecha_Inicio__c,
                   Fecha_Fin__c,
                   Estado__c,
                   CreatedDate
            FROM Entrada_Precio_Obtentor__c
            WHERE Producto_Obtentor__r.Id = :productId
            ORDER BY Fecha_Inicio__c ASC
        ];

        List<Map<String, Object>> precios = new List<Map<String, Object>>();

        for (Entrada_Precio_Obtentor__c ep : preciosRaw) {
            Map<String, Object> row = new Map<String, Object>();

            row.put('Id', ep.Id);
            row.put('Name', ep.Name);
            row.put('Precio_Unitario__c', ep.Precio_Unitario__c);
            row.put('Fecha_Inicio__c', ep.Fecha_Inicio__c);
            row.put('Fecha_Fin__c', ep.Fecha_Fin__c);
            row.put('Estado__c', ep.Estado__c);
            row.put('CreatedDate', ep.CreatedDate);
            row.put('estadoClass', ep.Estado__c == 'Procesada' ? 'estado ok' : 'estado no');

            precios.add(row);
        }

        return new ProductoWrapper(producto, precios);
    }

    @AuraEnabled
public static Map<String, Object> createEntrada(Entrada_Precio_Obtentor__c entrada) {
    insert entrada;

    // Re-query para obtener CreatedDate y otros campos calculados si es necesario
    Entrada_Precio_Obtentor__c ep = [
        SELECT Id, Name, Precio_Unitario__c, Fecha_Inicio__c, Fecha_Fin__c, Estado__c, CreatedDate
        FROM Entrada_Precio_Obtentor__c
        WHERE Id = :entrada.Id
        LIMIT 1
    ];

    Map<String, Object> row = new Map<String, Object>();
    row.put('Id', ep.Id);
    row.put('Name', ep.Name);
    row.put('Precio_Unitario__c', ep.Precio_Unitario__c);
    row.put('Fecha_Inicio__c', ep.Fecha_Inicio__c);
    row.put('Fecha_Fin__c', ep.Fecha_Fin__c);
    row.put('Estado__c', ep.Estado__c);
    row.put('CreatedDate', ep.CreatedDate);
    row.put('estadoClass', ep.Estado__c == 'Procesada' ? 'estado ok' : 'estado no');

    return row;
}


    public class ProductoWrapper {
        @AuraEnabled public Producto_Obtentor__c producto;
        @AuraEnabled public List<Map<String, Object>> precios;

        public ProductoWrapper(Producto_Obtentor__c p, List<Map<String, Object>> pr) {
            producto = p;
            precios = pr;
        }
    }
}