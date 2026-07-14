public without sharing class BatchApexVentasInformeFromExcel implements Database.Batchable<Map<String,Object>>, Database.Stateful{
   
    private List<Map<String,Object>> fileRows;

    public static final Integer BATCH_SIZE = 200;

    private static final Set<String> CAMPOS_CUIT = new Set<String>{
        'CUIT_Destinatario__c', 'CUIT_Originante__c'
    };

    Lote__c lote;

    String ColumaError = 'ERROR';

    private Boolean hasErrors = false;

    private Map<String,Ventas_Informadas__c>  ventasInformadasByKey = new Map<String,Ventas_Informadas__c>();

    private Map<String, FileRow>  rowventasInformadasByKey = new Map<String, FileRow> ();


    public BatchApexVentasInformeFromExcel(List<Map<String,Object>> fileRows){
        this.fileRows = fileRows;
        System.debug('Start');
    }

    public Iterable<Map<String,Object>> start(Database.batchableContext batchableContext){
        this.lote = crearLote();
        insert lote;
        return new MapIterator(fileRows);
    }

    public void execute(Database.BatchableContext bc, List<Map<String,Object>> scope){

        List<Ventas_Informadas__c> ventasInformadasAInsertar = new List<Ventas_Informadas__c>();

        for (Map<String,Object> fr : scope) {
            lwcVentasImportFromExcel.normalizeColumnAliases(fr);
            lwcVentasImportFromExcel.normalizeNComprobanteField(fr);
            lwcVentasImportFromExcel.normalizeCuitFields(fr);
            lwcVentasImportFromExcel.normalizeLineaFacturacionField(fr);
            lwcVentasImportFromExcel.normalizeCampanaAgricolaPreDeserialize(fr);
            lwcVentasImportFromExcel.normalizeCategoriaField(fr);
            lwcVentasImportFromExcel.normalizeTipoComprobanteField(fr);
            lwcVentasImportFromExcel.applyNComprobantePrefijoRemito(fr);
            lwcVentasImportFromExcel.normalizeVariedadField(fr);
            lwcVentasImportFromExcel.normalizeKilosTotalesField(fr);
        }
        Map<String, Variedad__c> variedadByName = lwcVentasImportFromExcel.getVariedadesPorNombre(scope);
        Map<String, Campana_Agricola__c> campanaByCultivoAno = lwcVentasImportFromExcel.getCampanasPorCultivoYAno(scope, variedadByName);
        VentasInformadasCuitResolver.CuitResolverCache cuitCache = VentasInformadasCuitResolver.buildCuitResolverCache(
            lwcVentasImportFromExcel.collectCuitsDesdeFilas(scope, true),
            lwcVentasImportFromExcel.collectObtentorComercializaIds(variedadByName)
        );

        for(Map<String,Object> fileRow : scope){
            
                Object fechaRaw = fileRow.remove('Fecha_de_Facturacion__c');
                Date fechaFact = lwcVentasImportFromExcel.parseFlexibleDate(fechaRaw);

                String cObjJsonDrunk = JSON.serialize(lwcVentasImportFromExcel.stripRowForDeserialize(fileRow));
                Ventas_Informadas__c venta =(Ventas_Informadas__c)JSON.deserialize(cObjJsonDrunk , Ventas_Informadas__c.class);
                venta.Fecha_de_Facturacion__c = fechaFact;
                if(venta.Fecha_de_Facturacion__c == null){
                    AddError(fileRow, 'Falta Fecha Comprobante');
                }
                if(venta.Cantidad_de_Bolsas__c == null){
                    AddError(fileRow, 'Falta Kilos Totales');
                }  if(venta.Categoria__c == null){
                    AddError(fileRow, 'Falta Categoria__c');
                }  if(venta.CUIT_Destinatario__c == null){
                    AddError(fileRow, 'Falta CUIT_Destinatario__c');
                }  if(venta.CUIT_Originante__c == null){
                    AddError(fileRow, 'Falta CUIT_Originante__c');
                }
                venta.Kilos_por_Bolsa__c = 1;
                if(venta.Linea_Facturacion__c == null){
                    AddError(fileRow, 'Falta Línea del Comprobante');
                }  if(venta.Tipo_de_Comprobante__c == null){
                    AddError(fileRow, 'Falta Tipo_de_Comprobante__c');
                } else if (new List<String>{'FC', 'NC'}.contains(venta.Tipo_de_Comprobante__c) == false){
                    AddError(fileRow, 'El Tipo de Comprobante debe ser FC, NC, Remito o Remito de Devolución');
                }  if(venta.Variedad__c == null){
                    AddError(fileRow, 'Falta Variedad__c');
                } else {
                    Variedad__c vRefBatch = variedadByName.get(lwcVentasImportFromExcel.variedadKey(venta.Variedad__c));
                    if (vRefBatch == null) {
                        AddError(fileRow, 'La Variedad "' + venta.Variedad__c + '" no existe en Salesforce. Verificá el nombre exacto del cultivar INASE.');
                    } else {
                        venta.Variedad_INASE__c = vRefBatch.Id;
                        if (vRefBatch.Cultivo__c != null) venta.Cultivo__c = vRefBatch.Cultivo__c;
                        if (String.isNotBlank(vRefBatch.Cultivar_Inase__c)) {
                            venta.Variedad__c = vRefBatch.Cultivar_Inase__c;
                        }
                        VentasInformadasCuitResolver.aplicarOriginanteYDestinatario(
                            venta,
                            vRefBatch.Obtentor_Comercializa__c,
                            cuitCache
                        );
                        VentasInformadasCuitResolver.aplicarVentaInterna(venta, cuitCache.accountsById);
                        if (String.isBlank(venta.Campana_de_Ventas__c)) {
                            AddError(fileRow, 'Falta Campaña Agrícola (año)');
                        } else {
                            lwcVentasImportFromExcel.applyCampanaAgricola(venta, campanaByCultivoAno, vRefBatch);
                            if (venta.Campana_Agricola__c == null) {
                                AddError(fileRow, 'No existe Campaña Agrícola para el cultivo de la variedad y el año ' + venta.Campana_de_Ventas__c);
                            }
                        }
                    }
                }  if(venta.N_de_Comprobante__c == null){
                    AddError(fileRow, 'Falta N_de_Comprobante__c');
                }
                if (!fileRow.containsKey(ColumaError)) {
                    ventasInformadasAInsertar.add(venta);
                    venta.Lote__c = lote.Id;
                }
              
             
            }

            if(checkErrors(ventasInformadasAInsertar)){
                publishBatchEvent(bc, false, JSON.serialize(scope));
                hasErrors = true;
            }else {
                publishBatchEvent(bc, !hasErrors, JSON.serialize(scope));
            }
    }

    @TestVisible
    private static void publishBatchEvent(Database.BatchableContext bc, Boolean isSuccess, String body) {
        String jobId = bc != null ? bc.getJobId() : null;
        EventBus.publish(new Notificacion_Batch_Apex__e(
            Job_Id__c = jobId,
            IsSuccess__c = isSuccess,
            Body__c = body
        ));
    }

    public void finish(Database.BatchableContext bc){

        System.debug('Finish');

        String systemErrors = BatchErrorHelper.getBatchClassErrors(bc);

           EventBus.publish(new Notificacion_Batch_Apex__e(
                    Job_Id__c = bc.getJobId(),
                    IsSuccess__c = String.isEmpty(systemErrors),
                    Body__c = systemErrors,
                    IsFinish__c = true
                )
        );
    }

    private Lote__c crearLote(){
        Lote__c lote = new Lote__c(
            Tipo_de_Lote__c = 'Ventas Informadas',
            Tipo__c = 'Ventas Informadas',
            Descripcion__c = 'Generación Ventas Informadas a través del Portal de Distribuidores ' + String.valueOf(Date.today())
            );
            return lote;
    }

    private void AddError(Map<String,Object> row , String error){
        if(row.get(ColumaError) == null){
            row.put(ColumaError, new List<String>());
        }
        
       List<string> l = (List<String>)row.get(ColumaError);
       l.add(error);
    }

    private static Boolean checkErrors(List<Ventas_Informadas__c> venta){

        Boolean hasErrors = false;

        List<Database.SaveResult> svrs = Utils.insertList(venta,false);

        Integer i = 0;

        for(Database.SaveResult svr : svrs){
            
            if(!svr.isSuccess()){
                hasErrors = true;
            }
            i++;

        }

        return hasErrors;

    }

    private class FileRow{
        public Map<String,Object> row;
        public FileRow(Map<String,Object> newrow){
            row = newrow;
        }
    }

}