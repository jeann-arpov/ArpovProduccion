@IsTest
public with sharing class BatchApexMonitorAuraServiceTest {
    
    @IsTest
    static void test(){
        
        Destinatarios_Errores_Batchs__c deb = new Destinatarios_Errores_Batchs__c();
        deb.Name = 'Test';
        deb.Email__c = 'test@email.com';
        insert deb;

        Lote__c lote = new Lote__c();
        lote.Descripcion__c = 'Generacion Ventas a Partir de Ventas Informadas ' + String.valueOf(Date.today());
        lote.Tipo__c = 'Ventas';
        lote.Tipo_de_Lote__c = 'Ventas';
        insert lote;
        
        Ventas_Informadas__c vInformadas = new Ventas_Informadas__c();
        vInformadas.Campana_Agricola__c = null;
        vInformadas.Campana_de_Ventas__c = null;
        vInformadas.Cantidad_de_Bolsas__c = 1;
        vInformadas.Cantidad_Bolsas_40__c = 1;
        vInformadas.Categoria__c = 'TEST';
        vInformadas.CUIT_Destinatario__c = '';
        vInformadas.CUIT_Originante__c = '';
        vInformadas.Cultivo__c = null;
        vInformadas.Destinatario__c = null;
        vInformadas.Estado__c = null;
        vInformadas.Fecha_de_Facturacion__c = Date.todaY();
        vInformadas.Kilos_por_Bolsa__c = 1;
        vInformadas.Linea_Facturacion__c = 1;
        // vInformadas.Name = '';
        vInformadas.N_de_Comprobante__c = '';
        vInformadas.Originante__c = null;
        vInformadas.Producto__c = null;
        vInformadas.Razon_Social_Destinatario__c = null;
        vInformadas.Resultado__c = 'OK';
        vInformadas.Tipo_de_Comprobante__c = null;
        vInformadas.Variedad__c = '';
        vInformadas.Venta__c = null;
        vInformadas.Rol_Destinatario__c = null;
        vInformadas.Rol_Originante__c = null;
        insert vInformadas;

        Test.startTest();
        
        BatchApexConvertirVentasInformadas b = new BatchApexConvertirVentasInformadas(lote);
        b.errors.add('Test');
        Id batchId = Database.executeBatch(b);

        BatchApexMonitorAuraService.getBatchJobs(batchId);

        Test.stopTest();
        
    }

}