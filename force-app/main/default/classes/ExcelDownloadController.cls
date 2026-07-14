/* Nombre: ExcelDownloadController
* Autor: Rodrigo Lopez
* Proyecto: ArPOV 
* Descripción: Contrller utilizado para obtener los datos necesarios para armar el archivo excel. 
* --------------------------------------------------------------------------
* Versión      Fecha           Autor                      Desripción<p />
* --------------------------------------------------------------------------
* 1.0.0        01/09/2025      Rodrigo Lopez         Creación.
*--------------------------------------------------------------------------
*/
public without sharing class ExcelDownloadController {
    
    public class ExcelDataWrapper {
        @AuraEnabled public Object mainRecord { get; set; }
        @AuraEnabled public List<Object> relatedRecords { get; set; }
    }
    
    @AuraEnabled(cacheable=false)
    public static ExcelDataWrapper getRecordDataForExcel(Id recordId) {
        try {
            
            ExcelDataWrapper wrapper = new ExcelDataWrapper();
            String objectType = recordId.getSObjectType().getDescribe().getName();
            System.debug('ExcelDownloadController - Tipo de objeto: ' + objectType);
            
            if (objectType == 'Venta_HT__c') {
                wrapper.mainRecord = getVentaHTData(recordId);
                wrapper.relatedRecords = getLineasCompraHTByVenta(recordId);
                
                System.debug('ExcelDownloadController - Venta obtenida: ' + wrapper.mainRecord);
                System.debug('ExcelDownloadController - Líneas obtenidas: ' + wrapper.relatedRecords?.size());
            } else {
                throw new AuraHandledException('Tipo de objeto no soportado: ' + objectType);
            }
            
            return wrapper;
        } catch (Exception e) {
            System.debug('ExcelDownloadController - Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error obteniendo datos: ' + e.getMessage());
        }
    }
    
    private static Object getVentaHTData(Id ventaId) {
        System.debug('ExcelDownloadController - Obteniendo datos de Venta_HT__c: ' + ventaId);
        
        List<Venta_HT__c> ventasHT = [ SELECT Id FROM Venta_HT__c WHERE Id = :ventaId LIMIT 1];
        
        System.debug('ExcelDownloadController - Ventas encontradas: ' + ventasHT.size());
        return ventasHT.isEmpty() ? null : ventasHT[0];
    }
    
    private static List<Object> getLineasCompraHTByVenta(Id ventaId) {
        
        List<Linea_de_Compra_HT__c> lineasdeCompraHT = [SELECT Id, Name,CreatedDate,Estado__c,Precio_de_Lista__c,Compra_HT__c,Producto__r.Id_Obtentor__c,Cantidad__c,Variedad__c,Precio__c,Linea_de_Oportunidad__c,Id_Producto_de_Lista_de_Precio__c,Linea_de_Oportunidad__r.Tipo_de_Cambio__c,Fecha_de_Activacion__c,Licencia__c,Licencia__r.Name,Linea_de_Venta_HT__r.Venta_HT__r.Comercio__r.N_CUIT__c,Linea_de_Venta_HT__r.Venta_HT__r.Comercio__r.Name,Producto__r.Tipo_de_Compra__c,Producto__r.Name,Producto__r.Variedad2__r.Cultivo__r.Name,Compra_HT__r.Name,Compra_HT__r.Cuenta_Productor__r.N_CUIT__c,Compra_HT__r.Cuenta_Productor__r.Name,Compra_HT__r.Cuenta_Productor__r.Direccion_de_Correo_electronico_del_CUIT__c,Compra_HT__r.Oportunidad__c,Compra_HT__r.Compra_Original__r.Name,Compra_HT__r.Es_NC__c,Compra_HT__r.Obtentor__r.Comision_Comercio__c,Compra_HT__r.Obtentor__r.Es_porcentaje_Enlist__c,Compra_HT__r.Obtentor__r.Comision_Comercio_AG__c,Compra_HT__r.Obtentor__r.Es_porcentaje_AG__c,Producto__r.Variedad2__r.Biotecnologia__c,CreatedBy.Name, Compra_HT__r.Obtentor__r.Nombre_Obtentor__c FROM Linea_de_Compra_HT__c WHERE Compra_HT__r.Venta_HT__c  = :ventaId ORDER BY CreatedDate DESC];
        System.debug('ExcelDownloadController - Líneas de compra encontradas: ' + lineasdeCompraHT.size());
        
        List<Object> result = new List<Object>();
        for (Linea_de_Compra_HT__c linea : lineasdeCompraHT) {
            result.add((Object) linea);
        }
        
        return result;
    }
}