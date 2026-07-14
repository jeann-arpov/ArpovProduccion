public without sharing class ProductTableController {

    public class ProductRow {
        @AuraEnabled public Id Id;
        @AuraEnabled public String Marca;
        @AuraEnabled public String ProductoObtentor;
        @AuraEnabled public String Variedad;
        @AuraEnabled public String TipoCompra;
        @AuraEnabled public Boolean Vigente;
        @AuraEnabled public Date FechaCreacion;
    }

    @AuraEnabled(cacheable=true)
    public static List<ProductRow> getProducts(Integer pageNumber, Integer pageSize, String searchTerm) {

        Integer offsetSize = (pageNumber - 1) * pageSize;

        String search = '%' + (searchTerm == null ? '' : searchTerm) + '%';
        Id obtentorId = CrearCompraController.getAccount().Id;

        String query = 'SELECT Id, Marca__c, Name, Nombre_Variedad__c, ' +
                       'Tipo_de_Compra__c, Vigente__c, CreatedDate ' +
                       'FROM Producto_Obtentor__c WHERE Obtentor__c = :obtentorId ';

        // Filtro de búsqueda por variedad
        if (String.isNotBlank(searchTerm)) {
            query += 'AND Nombre_Variedad__c LIKE :search ';
        }

        query += 'ORDER BY CreatedDate DESC LIMIT :pageSize OFFSET :offsetSize';

        List<Producto_Obtentor__c> productos = Database.query(query);

        List<ProductRow> result = new List<ProductRow>();

        for (Producto_Obtentor__c p : productos) {
            ProductRow row = new ProductRow();
            row.Id = p.Id;
            row.Marca = p.Marca__c;
            row.ProductoObtentor = p.Name;
            row.Variedad = p.Nombre_Variedad__c;
            row.TipoCompra = p.Tipo_de_Compra__c;
            row.Vigente = p.Vigente__c;
            row.FechaCreacion = Date.valueOf(p.CreatedDate);
            result.add(row);
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static Integer getTotalProducts(String searchTerm) {

        String search = '%' + (searchTerm == null ? '' : searchTerm) + '%';
        Id obtentorId = CrearCompraController.getAccount().Id;

        String query = 'SELECT COUNT() FROM Producto_Obtentor__c WHERE Obtentor__c = :obtentorId ';

        // Filtro de búsqueda por variedad
        if (String.isNotBlank(searchTerm)) {
            query += 'AND Nombre_Variedad__c LIKE :search';
        }

        return Database.countQuery(query);
    }
}