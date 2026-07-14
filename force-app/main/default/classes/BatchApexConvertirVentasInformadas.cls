public with sharing class BatchApexConvertirVentasInformadas implements Database.Batchable<sObject>, Database.Stateful{

    // Ticket 1916: no convertir ventas con 0 bolsas SF; dejar en Preprocesado para revisión del operador.
    @TestVisible
    private static final String MSG_CANTIDAD_BOLSAS_CERO =
        ConvertirVentasInformadasResumenUtil.MSG_CANTIDAD_BOLSAS_CERO;

    public List<String> errors = new List<String>();
    public Integer convertedCount = 0;
    public Integer skippedBolsasCeroCount = 0;
    public Integer insertErrorCount = 0;
    private Lote__c lote;
    private Set<Id> recordIds;

    public BatchApexConvertirVentasInformadas(Lote__c lote){
        this.lote = lote;
    }

    public BatchApexConvertirVentasInformadas(Lote__c lote, Set<Id> recordIds) {
        this.lote = lote;
        this.recordIds = recordIds;
        System.debug(this.recordIds);
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String qry = 'SELECT Campana_Agricola__c,Campana_de_Ventas__c,Cantidad_de_Bolsas__c,Cantidad_Bolsas_40__c,Categoria__c,Categoria_Portal__c,CreatedById,CreatedDate,CUIT_Destinatario__c,CUIT_Originante__c,Cultivo__c,Destinatario__c,Estado__c,Fecha_de_Facturacion__c,Id,IsDeleted,Kilos_por_Bolsa__c,LastActivityDate,LastModifiedById,LastModifiedDate,Linea_Facturacion__c,Name,N_de_Comprobante__c,Originante__c,OwnerId,Producto__c,Razon_Social_Destinatario__c,Resultado__c,SystemModstamp,Tipo_de_Comprobante__c,Variedad__c,Venta__c,Venta_Interna__c,Rol_Destinatario__c,Rol_Originante__c FROM Ventas_Informadas__c WHERE Venta__c = null and (Estado__c = null OR Estado__c =\'Preprocesado\') AND Resultado__c = \'OK\' AND Estado__c != \'Pendiente de Validar\' ';

        if (recordIds != null) qry += ' AND id in: recordIds';

        return Database.getQueryLocator(qry);
    
    }

    public void execute(Database.BatchableContext BC, List<Ventas_Informadas__c> scope) {

        List<Venta__c> ventasToInsert = new List<Venta__c>();

        List<Ventas_Informadas__c> ventasInformadasToUpdate = new List<Ventas_Informadas__c>();

        for(Ventas_Informadas__c vInformadas : scope){
            if (
                VentasInformadasExclusionUtil.esPendienteValidarAutoventa(vInformadas)
                || VentasInformadasExclusionUtil.esAutoventaCategoriaNoConvertible(vInformadas)
            ) {
                continue;
            }
            if (ConvertirVentasInformadasResumenUtil.tieneBolsasCero(vInformadas)) {
                skippedBolsasCeroCount++;
                ventasInformadasToUpdate.add(
                    new Ventas_Informadas__c(
                        Id = vInformadas.Id,
                        Estado__c = 'Preprocesado',
                        Resultado__c = MSG_CANTIDAD_BOLSAS_CERO
                    )
                );
                continue;
            }

            Venta__c venta = new Venta__c();
            venta.Lote__c = lote.Id;
            venta.Campana_Agricola__c = vInformadas.Campana_Agricola__c;
            venta.Canal__c = 'Interfaz';
            venta.Cantidad__c = vInformadas.Cantidad_Bolsas_40__c;
            venta.Cargado_desde_Archivo__c = false;
            venta.Cultivo__c = vInformadas.Cultivo__c;
            venta.Estado__c = 'Completa';
            venta.Fecha__c = Date.newInstance(vInformadas.CreatedDate.year(),vInformadas.CreatedDate.month(),vInformadas.CreatedDate.day());
            venta.Fecha_Facturacion__c = vInformadas.Fecha_de_Facturacion__c;
            venta.Gestor__c = 'ARPOV';
            venta.Nro_de_Comprobante__c = vInformadas.N_de_Comprobante__c;
            venta.Plataforma_Interface__c = vInformadas.CreatedById;
            venta.Producto__c = vInformadas.Producto__c;
            venta.Destinatario__c = (vInformadas.Tipo_de_Comprobante__c == 'NC') ? vInformadas.Originante__c : vInformadas.Destinatario__c;
            venta.Originante__c = (vInformadas.Tipo_de_Comprobante__c == 'NC') ? vInformadas.Destinatario__c : vInformadas.Originante__c;
            venta.Rol_Destinatario__c = (vInformadas.Tipo_de_Comprobante__c == 'NC') ? vInformadas.Rol_Originante__c : vInformadas.Rol_Destinatario__c;
            venta.Rol_Originante__c = (vInformadas.Tipo_de_Comprobante__c == 'NC') ? vInformadas.Rol_Destinatario__c : vInformadas.Rol_Originante__c;
            //venta.Tipo_de_Comprobante__c = vInformadas.Tipo_de_Comprobante__c;
            venta.Origen__c = vInformadas.Id;
            venta.Tipo_de_Comprobante__c = vInformadas.Tipo_de_Comprobante__c;
            venta.Linea_Facturacion__c = vInformadas.Linea_Facturacion__c;
            ventasToInsert.add(venta);
        }

        List<Database.SaveResult> svsrs = Database.insert(ventasToInsert,false);

        Integer i = 0;

        for(Database.SaveResult svr : svsrs){

            Venta__c venta = ventasToInsert.get(i);            

            if(!svr.isSuccess()){
                insertErrorCount++;
                this.errors.add(String.format('Record {0} : Error {1}', new List<String>{venta.Origen__c,svr.getErrors()[0].getMessage()}));
            
            }else{
                convertedCount++;
                ventasInformadasToUpdate.add(
                    new Ventas_Informadas__c(
                        Estado__c = 'Procesado',
                        Id = venta.Origen__c,
                        Venta__c = svr.getId()
                    )
                );

            }

            i++;
                
        }

        update ventasInformadasToUpdate;

    }

    public void finish(Database.BatchableContext BC) {
        BatchErrorHelper.sendEmail(BC.getJobId(), errors, 'Arpov: Errores en BatchApexConvertirVentasInformadas');
    }
}