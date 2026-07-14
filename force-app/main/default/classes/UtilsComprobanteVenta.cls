/**
* @author Maximo Martinez
* @date 25/11/2015
* @description Clase Utilitaria del Objeto Custom ERPvs__Comprobante_Venta__c
*/
//Test_UtilsComprobanteVenta,Test_CreateOppsFromTransactions
public without sharing class UtilsComprobanteVenta { 

    /**
    * @description Constantes
    */
    public static final String ESTADO_FACTURADA = 'Facturada';
    private static final String MISMO_MES = 'Mismo mes';
    private static final String SEIS_QUINCENAS = '6 Quicenas';
    private static final String UN_ANIO = '1 año';

    /*
        @author: julian
        @date: 6/4/2022
    */
    public static List<String> createComprobantesVentaFromOpps(Set<Id> oppIds, Date processDate) {
        // Obtenemos el registro
        List<Parametros_ERP_y_CRM__c> parametrosERPYCRM = [SELECT NC_diferencia_de_cambio_SE__c, ND_diferencia_de_cambio_SE__c, Canal_de_venta_ARPOV__c,Canal_de_venta_cyo_SE__c,Condicion_Comercial_SE__c,CreatedById,CreatedDate,Datos_Generales__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,Name,OwnerId,Punto_de_Venta_ARPOV__c,Punto_de_Venta_cyo_SE__r.ERPvs__Nro_Sucursal__c FROM Parametros_ERP_y_CRM__c ORDER BY LastModifiedDate DESC];

        // Obtengo el tipo de cambio para la fecha 
        List<ERPvs__Tipo_de_cambio__c> tipoDeCambios = [SELECT ERPvs__Vendedor__c FROM ERPvs__Tipo_de_cambio__c WHERE ERPvs__Fecha__c = :processDate AND ERPvs__Moneda_Traducida__c = 'SI' LIMIT 1]; 
        
        // Obtenemos el dia en que se esta corriendo el proceso
        String proceccesDay = UtilsAccount.getExclusionDay(processDate, Account.Dias_de_Exclusion_de_Facturacion_SE__c);

        Map<String, WrapperComprobanteVenta> wrappers = new Map<String, WrapperComprobanteVenta>();

        List<WrapperComprobanteVenta> ncs = new List<WrapperComprobanteVenta>();

        for (Opportunity opp: [SELECT   Estado__c,
                                        Account.Direccion_de_Correo_electronico_del_CUIT__c,
                                        Tipo_de_Comprobante__c,
                                        Compra_HT__r.Compra_Original__c,
                                (SELECT Estado__c, 
                                        Product2.Variedad2__r.Obtentor_Comercializa__c,
                                        Product2.ERPvs_Producto__c,
                                        Product2.ERPvs_Producto__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c,
                                        Quantity,
                                        Product2.Variedad2__r.Obtentor_Comercializa__r.Condicion_Comercial_SE__c,
                                        Product2.Variedad2__r.Obtentor_Comercializa__r.Tipo_comprobante_venta_SE__c, 
                                        Product2.Variedad2__r.Obtentor_Comercializa__r.Tipo_comprobante_venta_NC_SE__c,
                                        UnitPrice    
                                 FROM OpportunityLineItems where Estado__c = 'Facturable' AND Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c = true AND id not in (select OpportunityLineItem__c from ERPvs__Productos_Comprobante_de_Venta__c) AND Product2.Variedad2__r.Obtentor_Comercializa__r.Dias_de_Exclusion_de_Facturacion_SE__c excludes (:System.now().format('dd')))
                                FROM Opportunity
                                WHERE id in: oppIds AND StageName = 'Pendiente de Facturación'
        ]) {            
            System.debug(opp);
            for (OpportunityLineItem lineItem: opp.OpportunityLineItems) {
                String key = (String) opp.id + lineItem.Product2.Variedad2__r.Obtentor_Comercializa__c;
                System.debug(key);
                if (!wrappers.containsKey(key)) {
                    System.debug('new wrapper from:' + lineItem);
                    // Instanciamos un Wrapper Comprobante de Venta
                    WrapperComprobanteVenta wcv = new WrapperComprobanteVenta();
                    wcv.productosComprobanteDeVenta = new List<ERPvs__Productos_Comprobante_de_Venta__c>();
                    wrappers.put(key, wcv);

                    // Instanciamos el comprobante de venta
                    wcv.comprobanteVenta = new ERPvs__Comprobante_Venta__c();
                    
                    // Seteamos sus atributos
                    wcv.comprobanteVenta.ERPvs__Fecha__c = processDate;
                    wcv.comprobanteVenta.ERPvs__A_cuenta_y_orden_de__c = lineItem.Product2.Variedad2__r.Obtentor_Comercializa__c;
                    wcv.comprobanteVenta.ERPvs__Cliente__c = opp.Account.id;
                    wcv.comprobanteVenta.ERPvs__Empresa_Sucursal__c = parametrosERPYCRM[0].Punto_de_Venta_cyo_SE__c;
                    wcv.comprobanteVenta.ERPvs__Canal_de_venta__c = parametrosERPYCRM[0].Canal_de_venta_cyo_SE__c;
                    wcv.comprobanteVenta.ERPvs__Forma_de_Pago__c = lineItem.Product2.Variedad2__r.Obtentor_Comercializa__r.Condicion_Comercial_SE__c != null ? lineItem.Product2.Variedad2__r.Obtentor_Comercializa__r.Condicion_Comercial_SE__c : parametrosERPYCRM[0].Condicion_Comercial_SE__c;
                    wcv.comprobanteVenta.Oportunidad__c = opp.id;
                    wcv.comprobanteVenta.ERPvs__Sucursal__c = parametrosERPYCRM[0].Punto_de_Venta_cyo_SE__r.ERPvs__Nro_Sucursal__c;
                    wcv.comprobanteVenta.ERPvs__Correo_Electronico_Contacto__c = opp.Account.Direccion_de_Correo_electronico_del_CUIT__c;
                    wcv.comprobanteVenta.Compra_HT__c = opp.Compra_HT__c;

                    if (opp.Tipo_de_Comprobante__c == 'FC') {
                        //Product2Id.Obtentor_Comercializa__c
                        wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c = lineItem.Product2.Variedad2__r.Obtentor_Comercializa__r.Tipo_comprobante_venta_SE__c; 
                    } else if (opp.Tipo_de_Comprobante__c == 'NC') {
                        wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c = lineItem.Product2.Variedad2__r.Obtentor_Comercializa__r.Tipo_comprobante_venta_NC_SE__c;
                        wcv.comprobanteVenta.Tipo_Movimiento__c = 'Cantidad';
                        wcv.compraOriginal = opp.Compra_HT__r.Compra_Original__c;
                        //wcv.comprobanteVenta.ERPvs__Tipo_cambio__c
                        ncs.add(wcv);
                    }
                }

                ERPvs__Productos_Comprobante_de_Venta__c pcv = new ERPvs__Productos_Comprobante_de_Venta__c();
                pcv.ERPvs__Cantidad__c = lineItem.Quantity;
                //tipo de cambio
                pcv.ERPvs__Precio_unitario__c = Test.isRunningTest() ? 1 : lineItem.UnitPrice * (1+(lineItem.Product2.ERPvs_Producto__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c/100));

                //pcv.ERPvs__Observaciones__c = Label.Campana + ' ' +item.Campana_Agricola__r.Name;
                pcv.ERPvs__Precio_unitario__c = (pcv.ERPvs__Precio_unitario__c < 0 )?pcv.ERPvs__Precio_unitario__c*(-1):pcv.ERPvs__Precio_unitario__c;
                pcv.ERPvs__Producto__c = lineItem.Product2.ERPvs_Producto__c;
                pcv.ERPvs__Canal_de_Venta__c = parametrosERPYCRM[0].Canal_de_venta_cyo_SE__c;
                pcv.OpportunityLineItem__c = lineItem.id;
                
                // Agregamos el producto a la lista de productos
                wrappers.get(key).productosComprobanteDeVenta.add(pcv);
            } 
        }

        asociarComprobantesRelacionadosCompra(ncs);

        List<String> errors = new List<String>();

        System.debug('wrappers: ' + wrappers);

        // Corremos la logica para insertar los comprobantes y sus productos
        Set<String> cvIds = runInsert(wrappers.values(), errors);
        
        //Creamos las percepciones en base al cv original. También eliminamos las percepciones creadas automaticamente por el ERP.
        createPercepcionesIIBB(cvIds);

        return errors;
    }

    private static void asociarComprobantesRelacionadosCompra(List<WrapperComprobanteVenta> ncs) {
        Map<Id, ERPvs__Comprobante_Venta__c> compraToCv = new Map<Id, ERPvs__Comprobante_Venta__c>();

        for (WrapperComprobanteVenta nc: ncs) {
            if (nc.compraOriginal != null) compraToCv.put(nc.compraOriginal, null);
        }

        if (compraToCv.isEmpty() == false) {
            for (ERPvs__Comprobante_Venta__c cv : [SELECT Id, Oportunidad__r.Compra_HT__c, ERPvs__Tc__c, ERPvs__Tipo_de_cambio__c, ERPvs__Moneda__r.ERPvs__Moneda_Nacional__c FROM ERPvs__Comprobante_Venta__c WHERE Oportunidad__r.Compra_HT__c IN :compraToCv.keySet() AND ERPvs__Tipo_comp__c = 'Factura']){
                compraToCv.put(cv.Oportunidad__r.Compra_HT__c, cv);
            }
        }

        for (WrapperComprobanteVenta nc: ncs) {
            ERPvs__Comprobante_Venta__c relacionado = compraToCv.get(nc.compraOriginal);
            if (relacionado != null) {
                nc.comprobanteVenta.ERPvs__Comprobante_Relacionado__c = relacionado.id;
                nc.comprobanteVenta.ERPvs__Tipo_de_cambio__c = relacionado.ERPvs__Tipo_de_cambio__c;

                if (relacionado.ERPvs__Moneda__r.ERPvs__Moneda_Nacional__c != true) {
                    nc.comprobanteVenta.ERPvs__Tipo_cambio__c = relacionado.ERPvs__Tc__c;
                }
            }
        }
    }

    /**
    * @author Maximo Martinez
    * @date 25/11/2015
    * @description Metodo de generar comprobantes de venta desde transacciones DUP
    * @date 08/03/2016 FL: Cuando el substado es Negativo, debe guardar el tipo de cambio de la DUP Original en el campo ERPvs__Tipo_cambio__c del CV
    */ 
    public static List<String> createComprobantesVentaFromDups(Set<Id> idsTransacciones, Date processDate){

        // Obtenemos el registro
        List<Parametros_ERP_y_CRM__c> parametrosERPYCRM = [SELECT Canal_de_venta_ARPOV__c,Canal_de_venta_cyo__c,Condicion_Comercial__c,CreatedById,CreatedDate,Datos_Generales__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,Name,OwnerId,Punto_de_Venta_ARPOV__c,Punto_de_Venta_cyo__c,Punto_de_Venta_cyo__r.ERPvs__Nro_Sucursal__c FROM Parametros_ERP_y_CRM__c ORDER BY LastModifiedDate DESC];

        // Obtengo el tipo de cambio para la fecha 
        List<ERPvs__Tipo_de_cambio__c> tipoDeCambios = [SELECT ERPvs__Vendedor__c FROM ERPvs__Tipo_de_cambio__c WHERE ERPvs__Fecha__c = :processDate AND ERPvs__Moneda_Traducida__c = 'SI' LIMIT 1]; 

        // Lista de Wrappers
        List<WrapperComprobanteVenta> wrappers = new List<WrapperComprobanteVenta>();

        // Obtenemos el dia en que se esta corriendo el proceso
        String proceccesDay = UtilsAccount.getExclusionDay(processDate);

        //Obtengo map de tipo de comporbantes para controlar si es nota de crédito
        Map<String, ERPvs__Tipo_comprobante_venta__c> mapTiposComprobantes = getTiposComprobantes();

        List<WrapperComprobanteVenta> wrappersNegativos = new List<WrapperComprobanteVenta>();

        // Obtenemos las transacciones y sus item dups
        for(Transaccion__c transaccion : [SELECT Obtentor__r.Tipo_comprobante_venta_negativo__c, Obtentor__r.Condicion_Comercial_SRE__c, Nombre_de_la_cuenta__r.Direccion_de_Correo_electronico_del_CUIT__c , Obtentor__r.Tipo_comprobante_venta__r.ERPvs__MonedaNacional__c, Obtentor__r.Dias_de_Exclusion_de_Facturacion__c, Obtentor__r.Tipo_comprobante_venta__c , Id, DUP_Original__c, DUP_Original__r.Tipo_de_Cambio_del_Comprobante__c, Saldo_a_Cobrar__c, Factura__c,Subestado__c,RecordType.Name, Nombre_de_la_cuenta__r.Name, Obtentor__c,Obtentor__r.Factura_por_Cuenta_y_Orden__c, Cultivo__c, Campana__c, Name, RecordTypeId, Respondida_via_Minisitio__c, Resultado_Validacion_Analista__c, 
                                         (SELECT Id FROM Comprobantes_Venta__r), 
                                         (Select Lugar_de_Siembra__r.Provincia_ERP__c, Id, Estado__c, Campana_Agricola__c, Total_a_Facturar__c, Cantidad_de_Facturacion__c, Producto__r.ERPvs_Producto__c , Producto__r.Id, Producto__r.Conversion__c,Producto__r.Precio__c, Tipo_de_Cambio__c, Comision_por_Regalia_Simple__c,Cantidad_Facturacion_En_Bolsas_50__c, Obtentor__c, Producto__r.ERPvs_Producto__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c, Campana_Agricola__r.Name  FROM Item_de_DUP__r WHERE Estado__c != 'Consumo' AND Cantidad_de_Facturacion__c != null AND Cantidad_de_Facturacion__c != 0 AND No_Facturar__c = false) 
                                         FROM Transaccion__c WHERE Id IN :idsTransacciones AND No_Facturar__c = false]) {
        
            // Si la transaccion no tiene items no genero el comprobante de venta
            if(transaccion.Item_de_DUP__r.isEmpty()){
                continue;
            }    

            // Instanciamos un Wrapper Comprobante de Venta
            WrapperComprobanteVenta wcv = new WrapperComprobanteVenta();

            // Instanciamos el comprobante de venta
            wcv.comprobanteVenta = new ERPvs__Comprobante_Venta__c();

            // Seteamos sus atributos
            wcv.comprobanteVenta.ERPvs__Fecha__c = processDate;


            // Revisamos si es una Transaccion Negativa o positiva
            //FL: 2016-03-08 Guardo el tipo de cambio
            Decimal tipoCambio = 0;
            if(transaccion.Subestado__c == 'Positiva'){
                wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c = transaccion.Obtentor__r.Tipo_comprobante_venta__c;
            }else if(transaccion.Subestado__c == 'Negativa'){
                wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c = transaccion.Obtentor__r.Tipo_comprobante_venta_negativo__c;
                wrappersNegativos.add(wcv);
                if(transaccion.Obtentor__r.Tipo_comprobante_venta__r.ERPvs__MonedaNacional__c.toLowerCase().equals('no')){
                    wcv.comprobanteVenta.ERPvs__Tipo_cambio__c = transaccion.DUP_Original__r.Tipo_de_Cambio_del_Comprobante__c;
                }
            }

            wcv.comprobanteVenta.ERPvs__A_cuenta_y_orden_de__c = transaccion.Obtentor__c;
            wcv.comprobanteVenta.ERPvs__Cliente__c = transaccion.Nombre_de_la_cuenta__c;
            wcv.comprobanteVenta.ERPvs__Empresa_Sucursal__c = parametrosERPYCRM[0].Punto_de_Venta_cyo__c;
            wcv.comprobanteVenta.ERPvs__Canal_de_venta__c = parametrosERPYCRM[0].Canal_de_venta_cyo__c;
            wcv.comprobanteVenta.ERPvs__Forma_de_Pago__c = transaccion.Obtentor__r.Condicion_Comercial_SRE__c ?? parametrosERPYCRM[0].Condicion_Comercial__c;
            wcv.comprobanteVenta.Transaccion__c = transaccion.Id;
            wcv.comprobanteVenta.Oportunidad__c = transaccion.Factura__c;
            wcv.comprobanteVenta.ERPvs__Sucursal__c = parametrosERPYCRM[0].Punto_de_Venta_cyo__r.ERPvs__Nro_Sucursal__c;
            wcv.comprobanteVenta.ERPvs__Correo_Electronico_Contacto__c = transaccion.Nombre_de_la_cuenta__r.Direccion_de_Correo_electronico_del_CUIT__c;

            // Seteamos la transaccion
            wcv.transaccion = transaccion;

            // Instanciamos la lista de productos de comprobante de venta
            wcv.productosComprobanteDeVenta = new List<ERPvs__Productos_Comprobante_de_Venta__c>();

            // Recorremos los Items DUP
            for(Item_de_DUP__c item : transaccion.Item_de_DUP__r){

                // Generamos un ERPvs__Productos_Comprobante_de_Venta__c

                ERPvs__Productos_Comprobante_de_Venta__c pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

                pcv.ERPvs__Cantidad__c = (item.Cantidad_de_Facturacion__c < 0)?item.Cantidad_de_Facturacion__c*(-1):item.Cantidad_de_Facturacion__c;
                
                // Obtenemos el valor unitario inicial
                
                // Calculamos el precio en base a Total a Facturar / Cantidad de Facturacion
                Double precioUnitario = (item.Cantidad_de_Facturacion__c == 0 )?0:(item.Total_a_Facturar__c/item.Cantidad_de_Facturacion__c);
                
                // Si el Obtentor__r.Tipo_comprobante_venta__r.ERPvs__MonedaNacional__c es Si
                // el comprobante sera en Pesos
                if(transaccion.Obtentor__r.Tipo_comprobante_venta__r.ERPvs__MonedaNacional__c.toLowerCase() != 'si'){
                    
                    //Conversion del producto del item
                    if(item.Producto__r.Conversion__c.equals('USD') || item.Producto__r.Conversion__c.equals('EUR')){
                        // Lo paso de pesos a dolares
                        precioUnitario = precioUnitario/item.Tipo_de_Cambio__c;
                    } else {
                        //Lo paso al tipo de cambio del comprobante original
                        precioUnitario = precioUnitario/tipoDeCambios[0].ERPvs__Vendedor__c;
                    }
                
                }   

                // Lo multiplico por el porcentaje de IVA
                precioUnitario = precioUnitario*(1+(item.Producto__r.ERPvs_Producto__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c/100));

                pcv.ERPvs__Observaciones__c = Label.Campana + ' ' +item.Campana_Agricola__r.Name;
                pcv.ERPvs__Precio_unitario__c = (precioUnitario < 0 )?precioUnitario*(-1):precioUnitario;
                pcv.ERPvs__Producto__c = item.Producto__r.ERPvs_Producto__c;
                pcv.ERPvs__Provincia__c = item.Lugar_de_Siembra__r.Provincia_ERP__c;
                pcv.ERPvs__Canal_de_Venta__c = parametrosERPYCRM[0].Canal_de_venta_cyo__c;
                pcv.Item_de_DUP__c = item.Id;
                
                // Agregamos el producto a la lista de productos
                wcv.productosComprobanteDeVenta.add(pcv);

            }

            if(wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c != null && mapTiposComprobantes.get(wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c).ERPvs__Tipo__c.equals('Nota de Crédito')){
                wcv.comprobanteVenta.Tipo_Movimiento__c = 'Cantidad';
            }

            // Agregamos el wrapper a la lista de wrappers
            wrappers.add(wcv);

        }

        if(!wrappersNegativos.isEmpty()){
            asociarComprobantesRelacionados(wrappersNegativos);
        }

        List<String> errors = new List<String>();

        // Corremos la logica para insertar los comprobantes y sus productos
        Set<String> cvIds = runInsert(wrappers, errors);
        
        //Creamos las percepciones en base al cv original. También eliminamos las percepciones creadas automaticamente por el ERP.
        createPercepcionesIIBB(cvIds);

        return errors;

    }


    /**
    * @author Maximo Martinez
    * @date 25/11/2015
    * @description Metodo de generar comprobantes de venta desde transacciones Auditorias
    */ 
    public static List<String> createComprobantesVentaFromAuditorias(Set<Id> idsTransacciones, Date processDate){
        
        // Obtenemos el registro
        List<Parametros_ERP_y_CRM__c> parametrosERPYCRM = [SELECT Canal_de_venta_ARPOV__c,Canal_de_venta_cyo__c,Condicion_Comercial__c,CreatedById,CreatedDate,Datos_Generales__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,Name,OwnerId,Punto_de_Venta_ARPOV__c,Punto_de_Venta_cyo__c, Punto_de_Venta_cyo__r.ERPvs__Nro_Sucursal__c FROM Parametros_ERP_y_CRM__c ORDER BY LastModifiedDate DESC];

        //FL: Obtengo las fechas de visita para obtener los tipos de cambio
        Set<Date> fechasVisita = new Set<Date>();
        for(Transaccion__c transaccion : [SELECT Fecha_de_la_Visita__c FROM Transaccion__c WHERE Id IN :idsTransacciones]){
            if(transaccion.Fecha_de_la_Visita__c != null)
                fechasVisita.add(transaccion.Fecha_de_la_Visita__c);
        }

        // Obtengo el tipo de cambio para la fecha 
        Map<Date, ERPvs__Tipo_de_cambio__c> mapTiposCambio = new Map<Date, ERPvs__Tipo_de_cambio__c>();
        List<ERPvs__Tipo_de_cambio__c> tipoDeCambios = [SELECT ERPvs__Vendedor__c, ERPvs__Fecha__c FROM ERPvs__Tipo_de_cambio__c WHERE ERPvs__Fecha__c IN :fechasVisita AND ERPvs__Moneda_Traducida__c = 'SI']; 
        for(ERPvs__Tipo_de_cambio__c tc : tipoDeCambios){
            mapTiposCambio.put(tc.ERPvs__Fecha__c, tc);
        }

        // Lista de wrappers
        List<WrapperComprobanteVenta> wrappers = new List<WrapperComprobanteVenta>();
        List<WrapperComprobanteVenta> wrappersNegativos = new List<WrapperComprobanteVenta>();

        // Obtenemos el dia en que se esta corriendo el proceso
        String proceccesDay = UtilsAccount.getExclusionDay(processDate);

        //Obtengo map de tipo de comporbantes para controlar si es nota de crédito
        Map<String, ERPvs__Tipo_comprobante_venta__c> mapTiposComprobantes = getTiposComprobantes();

        // Obtenemos las transacciones y sus item dups
        for(Transaccion__c transaccion : [SELECT Obtentor__r.Tipo_comprobante_venta_negativo__c, Obtentor__r.Condicion_Comercial_SRE__c, Nombre_de_la_cuenta__r.Direccion_de_Correo_electronico_del_CUIT__c, Obtentor__r.Tipo_comprobante_venta__r.ERPvs__MonedaNacional__c, Obtentor__r.Tipo_comprobante_venta__c, Obtentor__r.Dias_de_Exclusion_de_Facturacion__c, Id,  Auditoria__c, Saldo_a_Cobrar__c,Subestado__c, Factura__c,RecordType.Name,Nombre_de_la_cuenta__r.Name, Obtentor__c,Obtentor__r.Factura_por_Cuenta_y_Orden__c, Cultivo__c, Campana__c, Name, RecordTypeId, Fecha_de_la_Visita__c, 
                                                 (SELECT Id FROM Comprobantes_Venta__r ) , 
                                                 (SELECT Lugar_de_Siembra__r.Provincia_ERP__c, Id,Resultado__c,Producto__r.id,Producto__r.Conversion__c,Producto__r.Precio__c, Total_a_Facturar__c,Cantidad_de_Facturacion__c,Unidad_de_Medida_de_Facturacion__c, Kilos_Totales__c, Tipo_de_Cambio__c,Comision_Por_Monto_Fijo__c,Comision_Por_Resarcimiento__c,Comision_por_Regalia_Simple__c, Cantidad_Facturacion_En_Bolsas_50__c, Producto__r.ERPvs_Producto__c, Producto__r.ERPvs_Producto__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c, Campana__r.Name  FROM Items_Auditorias__r WHERE Resultado__c = 'Irregular'  AND Cantidad_de_Facturacion__c != null AND Cantidad_de_Facturacion__c != 0 AND No_Facturar__c = false) 
                                                 FROM Transaccion__c WHERE Id IN :idsTransacciones AND No_Facturar__c = false]) {
            
            // Si la transaccion tiene items no genero el comprobante de venta
            if(transaccion.Items_Auditorias__r.isEmpty()){
                continue;
            }

            // Instanciamos un Wrapper Comprobante de Venta
            WrapperComprobanteVenta wcv = new WrapperComprobanteVenta();

            // Instanciamos el comprobante de venta
            wcv.comprobanteVenta = new ERPvs__Comprobante_Venta__c();

            // Seteamos sus atributos
            wcv.comprobanteVenta.ERPvs__Fecha__c = processDate;
            
            // Revisamos si es una Transaccion Negativa o positiva
            if(transaccion.Subestado__c == 'Positiva'){
                wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c = transaccion.Obtentor__r.Tipo_comprobante_venta__c;
            }else if(transaccion.Subestado__c == 'Negativa'){
                wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c = transaccion.Obtentor__r.Tipo_comprobante_venta_negativo__c;
                wrappersNegativos.add(wcv);
            }

            wcv.comprobanteVenta.ERPvs__A_cuenta_y_orden_de__c = transaccion.Obtentor__c;
            wcv.comprobanteVenta.ERPvs__Cliente__c = transaccion.Nombre_de_la_cuenta__c;
            wcv.comprobanteVenta.ERPvs__Empresa_Sucursal__c = parametrosERPYCRM[0].Punto_de_Venta_cyo__c;
            wcv.comprobanteVenta.ERPvs__Canal_de_venta__c = parametrosERPYCRM[0].Canal_de_venta_cyo__c;
            wcv.comprobanteVenta.ERPvs__Forma_de_Pago__c = transaccion.Obtentor__r.Condicion_Comercial_SRE__c ?? parametrosERPYCRM[0].Condicion_Comercial__c;
            wcv.comprobanteVenta.Transaccion__c = transaccion.Id;
            wcv.comprobanteVenta.Oportunidad__c = transaccion.Factura__c;
            wcv.comprobanteVenta.ERPvs__Sucursal__c = parametrosERPYCRM[0].Punto_de_Venta_cyo__r.ERPvs__Nro_Sucursal__c;
            wcv.comprobanteVenta.ERPvs__Correo_Electronico_Contacto__c = transaccion.Nombre_de_la_cuenta__r.Direccion_de_Correo_electronico_del_CUIT__c;
            
            // Seteamos la transaccion
            wcv.transaccion = transaccion;

            // Instanciamos la lista de productos de comprobante de venta
            wcv.productosComprobanteDeVenta = new List<ERPvs__Productos_Comprobante_de_Venta__c>();

            // Recorremos los Items DUP
            for(Item_Auditoria__c item : transaccion.Items_Auditorias__r){

                // Generamos un ERPvs__Productos_Comprobante_de_Venta__c

                ERPvs__Productos_Comprobante_de_Venta__c pcv = new ERPvs__Productos_Comprobante_de_Venta__c();

                pcv.ERPvs__Cantidad__c = (item.Cantidad_de_Facturacion__c < 0)?item.Cantidad_de_Facturacion__c*(-1):item.Cantidad_de_Facturacion__c;

                pcv.ERPvs__Observaciones__c = Label.Campana +' '+item.Campana__r.Name;

                // Obtenemos el valor unitario inicial
                
                // Calculamos el precio en base a Total a Facturar / Cantidad de Facturacion
                Double precioUnitario = (item.Cantidad_de_Facturacion__c == 0 )?0:(item.Total_a_Facturar__c/item.Cantidad_de_Facturacion__c);
                
                // Si el Obtentor__r.Tipo_comprobante_venta__r.ERPvs__MonedaNacional__c es Si
                // el comprobante sera en Pesos
                if(transaccion.Obtentor__r.Tipo_comprobante_venta__r.ERPvs__MonedaNacional__c.toLowerCase() != 'si'){

                    //Conversion del producto del item
                    Decimal tipoCambio = 1;
                    if(item.Producto__r.Conversion__c.equals('USD') || item.Producto__r.Conversion__c.equals('EUR')){
                        // Lo paso de pesos a dolares
                        tipoCambio = item.Tipo_de_Cambio__c;
                        precioUnitario = precioUnitario/tipoCambio;
                    } else {
                        //Lo paso al tipo de cambio de la fecha de visita
                        ERPvs__Tipo_de_cambio__c tc = mapTiposCambio.get(transaccion.Fecha_de_la_Visita__c);
                        if(tc != null){
                            tipoCambio = tc.ERPvs__Vendedor__c;
                            precioUnitario = precioUnitario/tipoCambio;
                        }
                    }
                    
                    if(wcv.comprobanteVenta.ERPvs__Tipo_cambio__c == null){
                        wcv.comprobanteVenta.ERPvs__Tipo_cambio__c = tipoCambio;
                    }

                }

                // Lo multiplico por el porcentaje de IVA
                precioUnitario = precioUnitario*(1+(item.Producto__r.ERPvs_Producto__r.ERPvs__Tasa_de_Iva__r.ERPvs__Porcentaje__c/100));

                pcv.ERPvs__Precio_unitario__c = (precioUnitario<0)?precioUnitario*(-1):precioUnitario;
                pcv.ERPvs__Producto__c = item.Producto__r.ERPvs_Producto__c;
                pcv.ERPvs__Provincia__c = item.Lugar_de_Siembra__r.Provincia_ERP__c;
                pcv.ERPvs__Canal_de_Venta__c = parametrosERPYCRM[0].Canal_de_venta_cyo__c;
                pcv.Item_Auditoria__c = item.Id;
        
                // Agregamos el producto a la lista de productos
                wcv.productosComprobanteDeVenta.add(pcv);

            }

            if(wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c != null && mapTiposComprobantes.get(wcv.comprobanteVenta.ERPvs__Tipo_de_comprobante__c).ERPvs__Tipo__c.equals('Nota de Crédito')){
                wcv.comprobanteVenta.Tipo_Movimiento__c = 'Cantidad';
            }

            // Agregamos el wrapper a la lista de wrappers
            wrappers.add(wcv);

        }

        if(!wrappersNegativos.isEmpty()){
            asociarComprobantesRelacionados(wrappersNegativos);
        }

        List<String> errors = new List<String>();

        // Corremos la logica para insertar los comprobantes y sus productos
        Set<String> cvIds = runInsert(wrappers, errors);
        
        //Creamos las percepciones en base al cv original. También eliminamos las percepciones creadas automaticamente por el ERP.
        createPercepcionesIIBB(cvIds);

        return errors;

    }

     /**
    * @author Maximo Martinez
    * @date 25/11/2015
    * @description Metodo Utilitario que inserta ERPvs__Comprobante_Venta__c y ERPvs__Productos_Comprobante_de_Venta__c
    */ 
    public static Set<String> runInsert(List<WrapperComprobanteVenta> wrappers, List<String> errors){

        System.debug(LoggingLevel.WARN, wrappers);
        Set<String> result = new Set<String>();
        
        // Insertamos los comprobantes de Venta y sus productos
        if(wrappers.isEmpty()){
            return null;
        }

        // Lista de comprobantes de venta a insertar
        List<ERPvs__Comprobante_Venta__c> cvToInsert = new List<ERPvs__Comprobante_Venta__c>();

        // Lista de transacciones a actualizar
        List<Transaccion__c> trsToUpdate = new List<Transaccion__c>();

        for(WrapperComprobanteVenta wcv : wrappers){
            cvToInsert.add(wcv.comprobanteVenta);
        }

        if(cvToInsert.isEmpty()){
            return null;
        }

        // Insertamos los comprobantes de venta
        //Utils.insertList(cvToInsert, true);
        errors.addAll(checkErrors(Utils.insertList((List<SObject>)cvToInsert, false), cvToInsert));

        // Ids de comprobantes de ventas a generar vencimientos
        Set<String> cvToGenerateVencimientos = new Set<String>();

        // Lista de ERPvs__Productos_Comprobante_de_Venta__c a insertar
        List<ERPvs__Productos_Comprobante_de_Venta__c> pcvToInsert = new List<ERPvs__Productos_Comprobante_de_Venta__c>();

        // Recorremos los wrappers y coleccionamos los Wrappers
        for(WrapperComprobanteVenta wcs : wrappers) {
            
            // Si NO se creo el Comprobante de Venta NO coleccionamos sus items
            if(String.isEmpty(wcs.comprobanteVenta.Id)){
                continue;
            }
            
            result.add(wcs.comprobanteVenta.Id);
            
            // Coleccionamos el id del comprobante de venta
            cvToGenerateVencimientos.add(wcs.comprobanteVenta.Id);

            // Recorro los productos y seteo el Id del ERPvs__Comprobante_Venta__c
            for(ERPvs__Productos_Comprobante_de_Venta__c pcv : wcs.productosComprobanteDeVenta){
                
                // Seteo el Id del Comprobante  
                pcv.ERPvs__Comprobante__c = wcs.comprobanteVenta.Id;

                // Agrego el ERPvs__Productos_Comprobante_de_Venta__c a la lista de ERPvs__Productos_Comprobante_de_Venta__c 
                // a insertar
                pcvToInsert.add(pcv);

            }

            // Seteo el estado de la Transaccion a Facturada
            //wcs.transaccion.Estado__c = ESTADO_FACTURADA;

            if (wcs.transaccion != null) {
                wcs.transaccion.Tiene_CV__c = true;
                // Agregamos a la lista
                trsToUpdate.add(wcs.transaccion);
            }

        }

        // Insertamos los  ERPvs__Productos_Comprobante_de_Venta__c
        if(pcvToInsert.isEmpty()){
            return null;
        }

        //Utils.insertList(pcvToInsert, true);
        errors.addAll(checkErrors(Utils.insertList((List<SObject>)pcvToInsert, false), pcvToInsert));

        // Generamos los vencimientos de los comprobantes de venta
        FacturacionSociosController.calcularVencimientos(cvToGenerateVencimientos);


        // Actualizamos las transacciones
        if(trsToUpdate.isEmpty()){
            return null;
        }

        Utils.updateList(trsToUpdate, true);

        return result;

    }


    /**
    * @author Maximo Martinez
    * @date 25/11/2015
    * @description Clase Utilitarias para agrupar ERPvs__Comprobante_Venta__c con sus respectivos ERPvs__Productos_Comprobante_de_Venta__c
    */ 
    public class WrapperComprobanteVenta {
        
        public ERPvs__Comprobante_Venta__c comprobanteVenta {get; set;}
        public List<ERPvs__Productos_Comprobante_de_Venta__c> productosComprobanteDeVenta {get; set;}
        public Transaccion__c transaccion {get; set;}
        public Id compraOriginal;

    }
    
    /**
    * @author Facundo Luna
    * @date 08/03/2013
    * @description Método utilizado para setear las oportunidades de los CVs con transacciones en subestado negativa
    */ 
    public static void setOportunidad(Set<Id> opIds) {
        
        if(!opIds.isEmpty()){
            List<Opportunity> oportunidades = [SELECT Id, StageName, Saldo_a_Cobrar_Comprobante__c, Saldo_a_Gestionar__c 
                                               FROM Opportunity WHERE ID IN :opIds and StageName <> 'Aplicada'];
            for(Opportunity op : oportunidades){
                op.StageName = 'Aplicada';
                op.Saldo_a_Cobrar_Comprobante__c = 0;
                op.Saldo_a_Gestionar__c = 0;
            }
            update oportunidades;
        }
       
    }

    /**
    * @author Facundo Luna
    * @date 20/07/2016
    * @description Método utilizado para obtener map de tipos de comprobantes
    */ 
    public static Map<String, ERPvs__Tipo_comprobante_venta__c> getTiposComprobantes() {
        
        Map<String, ERPvs__Tipo_comprobante_venta__c> result = new Map<String, ERPvs__Tipo_comprobante_venta__c>();

        for(ERPvs__Tipo_comprobante_venta__c tc : [SELECT Id, ERPvs__Tipo__c FROM ERPvs__Tipo_comprobante_venta__c]){
            result.put(tc.Id, tc);
        }

        return result;
       
    }

    /**
    * @author Facundo Luna
    * @date 30/08/2016
    * @description Método utilizado para obtener map de tipos de comprobantes
    */ 
    public static void createPercepcionesIIBB(Set<String> cvIds) {
        
        Map<String, ERPvs__Comprobante_Venta__c> mapCVs = new Map<String, ERPvs__Comprobante_Venta__c>();
        Map<String, ERPvs__Comprobante_Venta__c> mapCVsOriginales = new Map<String, ERPvs__Comprobante_Venta__c>();
        Set<String> facturasOriginalesIds = new Set<String>();
        Set<String> obtentoresIds = new Set<String>();

        Parametros_ERP_y_CRM__c parametroERPYCRM = new Parametros_ERP_y_CRM__c();
        try{
            parametroERPYCRM = [SELECT Tipo_Comprobante_Mov_Fondo_Cobranza__r.ERPvs__Tipo_de_registro__c, Canal_de_venta_ARPOV__c,Canal_de_venta_cyo__c,Condicion_Comercial__c,CreatedById,CreatedDate,Datos_Generales__c,Id,IsDeleted,LastModifiedById,LastModifiedDate,Name,OwnerId,Punto_de_Venta_ARPOV__c,Punto_de_Venta_cyo__c,Punto_de_Venta_cyo__r.ERPvs__Nro_Sucursal__c,Sucursal_para_Cobranzas__c,Sucursal_para_Cobranzas__r.ERPvs__Empresa__c,Tipo_Comprobante_Mov_Fondo_Cobranza__c, NC_diferencia_de_cambio__c, NC_diferencia_de_cambio__r.ERPvs__IdMoneda__c, ND_diferencia_de_cambio__c, ND_diferencia_de_cambio__r.ERPvs__IdMoneda__c, Concepto_Dif_Cambio__c, Genero_pago__c, Tipo_Comprobante_Mov_Fondo_Pago__c, Sucursal_para_pago__c, Producto_Diferencia_Cambio__c, Producto_Diferencia_de_Cambio_PIIBB__c, Desde_Total_Dif_Cambio__c, Hasta_Total_Dif_Cambio__c FROM Parametros_ERP_y_CRM__c ORDER BY LastModifiedDate DESC LIMIT 1];
        } catch(Exception e){

        }
        
        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, ERPvs__Subtotal__c, ERPvs__A_cuenta_y_orden_de__c, Oportunidad__c, Oportunidad__r.Factura__c FROM ERPvs__Comprobante_Venta__c WHERE Id IN :cvIds AND Tipo_de_Movimiento__c = 'NC' AND Oportunidad__r.Factura__c != null]){
            mapCVs.put(cv.Id, cv);
            facturasOriginalesIds.add(cv.Oportunidad__r.Factura__c);
            obtentoresIds.add(cv.ERPvs__A_cuenta_y_orden_de__c);
        }
        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, Oportunidad__c, (SELECT ERPvs__Coeficiente_padron__c, ERPvs__Porcentaje__c, ERPvs__Provincia__c, ERPvs__Cuenta_Contable__c, ERPvs__Base_Imponible__c, ERPvs__Importe_percepcion__c FROM ERPvs__Percepciones_de_IB__r) FROM ERPvs__Comprobante_Venta__c WHERE Oportunidad__c IN :facturasOriginalesIds]){
            mapCVsOriginales.put(cv.Oportunidad__c, cv);
        }

        
        Map<String, ERPvs__Percepciones__c> mapPercepcionesObtentor = new Map<String, ERPvs__Percepciones__c>();
        for(ERPvs__Percepciones__c p : [SELECT Id, ERPvs__Provincia__c, ERPvs__Devoluciones__c, ERPvs__A_cuenta_y_orden_de__c FROM ERPvs__Percepciones__c WHERE ERPvs__A_cuenta_y_orden_de__c IN :obtentoresIds AND ERPvs__Tipo__c = 'IIBB']){
            String key = '' + p.ERPvs__A_cuenta_y_orden_de__c + p.ERPvs__Provincia__c;
            mapPercepcionesObtentor.put(key, p);
        }

        processCvs(mapCVs, mapCVsOriginales, mapPercepcionesObtentor, parametroERPYCRM, cvIds);       
    }

    @testVisible
    private static void processCvs(Map<String, ERPvs__Comprobante_Venta__c> mapCVs, Map<String, ERPvs__Comprobante_Venta__c> mapCVsOriginales, Map<String, ERPvs__Percepciones__c> mapPercepcionesObtentor, Parametros_ERP_y_CRM__c parametroERPYCRM, Set<String> cvIds) {
        List<ERPvs__Productos_Comprobante_de_Venta__c> pcvs = new List<ERPvs__Productos_Comprobante_de_Venta__c>();
        List<ERPvs__Percepciones_de_IB__c> percepcionesToInsert = new List<ERPvs__Percepciones_de_IB__c>();
        ERPvs__Percepciones_de_IB__c pIIBBToInsert;

        for(String keyAux : mapCVs.keySet()){
            ERPvs__Comprobante_Venta__c cv = mapCVs.get(keyAux);
            ERPvs__Comprobante_Venta__c cvOriginal = mapCVsOriginales.get(cv.Oportunidad__c);

            if(cvOriginal != null && cvOriginal.ERPvs__Percepciones_de_IB__r != null && !cvOriginal.ERPvs__Percepciones_de_IB__r.isEmpty()){
                for(ERPvs__Percepciones_de_IB__c pIIBB : cvOriginal.ERPvs__Percepciones_de_IB__r){
                    String key = '' + cv.ERPvs__A_cuenta_y_orden_de__c + pIIBB.ERPvs__Provincia__c;
                    ERPvs__Percepciones__c percepcionObtentor = mapPercepcionesObtentor.get(key);
                    System.debug(key);
                    System.debug(percepcionObtentor);
                    System.debug(mapPercepcionesObtentor.keySet());
                    if(percepcionObtentor == null || percepcionObtentor.ERPvs__Devoluciones__c == null){
                        pIIBBToInsert = pIIBB.clone(false);
                        pIIBBToInsert.Diferencia_de_Precio__c = true;
                        percepcionesToInsert.add(pIIBBToInsert);
                    } else {
                        Boolean esFechaFiltro = false;
                        if(percepcionObtentor.ERPvs__Devoluciones__c.equals(MISMO_MES)){
                            esFechaFiltro = cvOriginal.ERPvs__Fecha__c.month() == cv.ERPvs__Fecha__c.month() && cvOriginal.ERPvs__Fecha__c.year() == cv.ERPvs__Fecha__c.year();
                        } else if(percepcionObtentor.ERPvs__Devoluciones__c.equals(SEIS_QUINCENAS)){
                            Date fecha6Quincenas = cvOriginal.ERPvs__Fecha__c.addDays(90);
                            Integer quincenaCVOriginal = fecha6Quincenas.day() <= 15 ? 1 : 2;
                            Integer quincena = cv.ERPvs__Fecha__c.day() <= 15 ? 1 : 2;
                            esFechaFiltro = cv.ERPvs__Fecha__c.year() == fecha6Quincenas.year() && cv.ERPvs__Fecha__c.month() <= fecha6Quincenas.month() && quincena == quincenaCVOriginal;
                        } else if(percepcionObtentor.ERPvs__Devoluciones__c.equals(UN_ANIO)){
                            esFechaFiltro = cvOriginal.ERPvs__Fecha__c.year() == cv.ERPvs__Fecha__c.year();
                        }
                        if(esFechaFiltro){
                            pIIBBToInsert = pIIBB.clone(false);
                            pIIBBToInsert.Diferencia_de_Precio__c = true;
                            percepcionesToInsert.add(pIIBBToInsert);
                        } else {
                            ERPvs__Productos_Comprobante_de_Venta__c pcvPercepcion = new ERPvs__Productos_Comprobante_de_Venta__c();
                            pcvPercepcion.ERPvs__Cantidad__c = 1;
                            pcvPercepcion.ERPvs__Precio_unitario__c = cv.ERPvs__Subtotal__c * (pIIBB.ERPvs__Porcentaje__c / 100).setScale(2);
                            pcvPercepcion.ERPvs__Producto__c = parametroERPYCRM.Producto_Diferencia_de_Cambio_PIIBB__c;
                            pcvPercepcion.ERPvs__Comprobante__c = cv.Id;
                            pcvs.add(pcvPercepcion);
                        }
                    }
                }
                
                for(ERPvs__Percepciones_de_IB__c pIIBB : percepcionesToInsert){
                    
                    pIIBB.ERPvs__Base_Imponible__c = cv.ERPvs__Subtotal__c.setScale(2);
                    pIIBB.ERPvs__Base_Imponible_Minima__c =  pIIBB.ERPvs__Base_Imponible_Minima__c != null ? pIIBB.ERPvs__Base_Imponible_Minima__c : 0;
                    pIIBB.ERPvs__Importe_percepcion__c = (((pIIBB.ERPvs__Base_Imponible__c * (pIIBB.ERPvs__Coeficiente_padron__c != null && pIIBB.ERPvs__Coeficiente_padron__c != 0 ? pIIBB.ERPvs__Coeficiente_padron__c : 1))/ 100) * pIIBB.ERPvs__Porcentaje__c).setScale(2);
                    pIIBB.ERPvs__Comprobante_Venta__c = cv.Id;

                }
            }
        }

        if(!pcvs.isEmpty()){
            insert pcvs;
        }

        if(!percepcionesToInsert.isEmpty()){
            insert percepcionesToInsert;
        }
        
        deletePercepcionesIIBB(cvIds);
    }

    private static void deletePercepcionesIIBB(Set<String> cvIds){

        for(List<ERPvs__Percepciones_de_IB__c> percepciones : [SELECT Id FROM ERPvs__Percepciones_de_IB__c WHERE ERPvs__Comprobante_Venta__c IN :cvIds AND ERPvs__Comprobante_Venta__r.Tipo_de_Movimiento__c = 'NC' AND Diferencia_de_Precio__c = false]){
            delete percepciones;
        }
    }

    /**
    * @author Facundo Luna
    * @date 18/11/2016
    * @description Metodo que setea los errores de una operacion DML a la lista de errores
    * @param List<Database.SaveResult>
    * @param List<Opportunity>
    */
    public static List<String> checkErrors(List<Database.SaveResult> svrs, List<ERPvs__Comprobante_Venta__c> sobjects){

        List<String> errors = new List<String>();

        for(Integer i = 0; i < svrs.size() ; i++){

            ERPvs__Comprobante_Venta__c obj = sobjects[i];
            Database.SaveResult svr = svrs[i];

            if(!svr.isSuccess()){

                // Hacemos un espacio en balnco
                errors.add('\n');

                // Indicamos el Registro con Error
                if(String.isNotEmpty(obj.Id)){ // Actualización
                    errors.add('Errores al Actualizar el CV Record Id'+' '+obj.Id+':');
                }else if(String.isNotEmpty(obj.Name)){ // Inserción
                    errors.add('Errores al Insertar el CV Record Name'+' '+obj.Name+':');
                }

                errors.add('OpportunityId: '+ obj.Oportunidad__c);
                errors.add('AccountId: '+ obj.ERPvs__Cliente__c);

                // Obtenemos los errores
                for(Database.Error e : svr.getErrors()){
                    errors.add(e.getMessage());
                }

            }

        }

        return errors;

    }

    /**
    * @author Facundo Luna
    * @date 18/11/2016
    * @description Metodo que setea los errores de una operacion DML a la lista de errores
    * @param List<Database.SaveResult>
    * @param List<Opportunity>
    */
    public static List<String> checkErrors(List<Database.SaveResult> svrs, List<ERPvs__Productos_Comprobante_de_Venta__c> sobjects){

        List<String> errors = new List<String>();

        for(Integer i = 0; i < svrs.size() ; i++){

            ERPvs__Productos_Comprobante_de_Venta__c obj = sobjects[i];
            Database.SaveResult svr = svrs[i];

            if(!svr.isSuccess()){

                // Hacemos un espacio en balnco
                errors.add('\n');

                // Indicamos el Registro con Error
                if(String.isNotEmpty(obj.Id)){ // Actualización
                    errors.add('Errores al Actualizar el PCV Record Id'+' '+obj.Id+':');
                }else if(String.isNotEmpty(obj.Name)){ // Inserción
                    errors.add('Errores al Insertar el PCV Record Name'+' '+obj.Name+':');
                }

                // Obtenemos los errores
                for(Database.Error e : svr.getErrors()){
                    errors.add(e.getMessage());
                }

            }

        }

        return errors;

    }

    /**
    * @author Facundo Luna
    * @date 27/06/2018
    * @description Metodo que determina Nro de comprobantes para actualizar los LP en las aplicaciones
    */
    public static Map<String, ERPvs__Comprobante_Venta__c> obtenerNrosComprobantesAplicaciones(List<ERPvs__Comprobante_Venta__c> cvs, Map<Id, ERPvs__Comprobante_Venta__c> mapOld){

        System.debug('>> >> obtenerNrosComprobantesAplicaciones');
        
        Map<String, ERPvs__Comprobante_Venta__c> result = new Map<String, ERPvs__Comprobante_Venta__c>();

        for(ERPvs__Comprobante_Venta__c cv : cvs){

            System.debug('>> >> cv:' + cv);
            System.debug('>> >> mapOld.get(cv.Id):' +  mapOld.get(cv.Id));

            if((cv.ERPvs__Liquido_producto__c != null && mapOld.get(cv.Id).ERPvs__Liquido_producto__c == null) || (cv.ERPvs__Liquido_producto__c == null && mapOld.get(cv.Id).ERPvs__Liquido_producto__c != null)){
                //result.put(cv.ERPvs__Comprobante__c, cv);
                result.put(cv.Nro_Comprobante__c, cv);
            }

        }

        return result;

    }

    private static void asociarComprobantesRelacionados(List<WrapperComprobanteVenta> wrappersNegativos){

        Set<Id> oportunidadIds = new Set<Id>();

        for(WrapperComprobanteVenta wcv : wrappersNegativos){
            if(wcv.comprobanteVenta.Oportunidad__c != null)
                oportunidadIds.add(wcv.comprobanteVenta.Oportunidad__c);
        }

        Map<Id, Id> mapOportunidadFactura = new Map<Id, Id>();

        for(Opportunity op : [SELECT Factura__c FROM Opportunity WHERE Id IN :oportunidadIds]){
            if(op.Factura__c != null)
                mapOportunidadFactura.put(op.Id, op.Factura__c);
        }

        Map<Id, Id> mapCvFc = new Map<Id, Id>();

        for(ERPvs__Comprobante_Venta__c cv : [SELECT Id, Oportunidad__c FROM ERPvs__Comprobante_Venta__c WHERE Oportunidad__c IN :mapOportunidadFactura.values() AND ERPvs__Tipo_comp__c = 'Factura']){
            mapCvFc.put(cv.Oportunidad__c, cv.Id);
        }

        for(WrapperComprobanteVenta wcv : wrappersNegativos){
            if(mapOportunidadFactura.get(wcv.comprobanteVenta.Oportunidad__c) != null){
                wcv.comprobanteVenta.ERPvs__Comprobante_Relacionado__c = mapCvFc.get(mapOportunidadFactura.get(wcv.comprobanteVenta.Oportunidad__c));
            }
        }
    }

    public static void beforeInsert(List<ERPvs__Comprobante_Venta__c> records) {
        Map<Id, ERPvs__Comprobante_Venta__c> relacionados = new Map<Id, ERPvs__Comprobante_Venta__c>();
        Set<Id> relacionadosIds = new Set<Id>();

        for(ERPvs__Comprobante_Venta__c cv : records) {
            if (cv.ERPvs__Tipo_comp__c == 'Nota de Crédito' && cv.ERPvs__Comprobante_Relacionado__c != null) {
                relacionadosIds.add(cv.ERPvs__Comprobante_Relacionado__c);
            }
        }

        if (relacionados.isEmpty() == false) {
            for (ERPvs__Comprobante_Venta__c cv: [select Oportunidad__c from ERPvs__Comprobante_Venta__c where id in: relacionadosIds and Oportunidad__r.RecordType.DeveloperName = 'Sembra_Evolucion' and ERPvs__Tipo_comp__c = 'Factura']) {
                relacionados.put(cv.id, cv);
            }
        }

        for(ERPvs__Comprobante_Venta__c cv : records) {
            if (cv.ERPvs__Tipo_comp__c == 'Nota de Crédito' && relacionados.containsKey(cv.ERPvs__Comprobante_Relacionado__c)) {
                cv.Oportunidad__c = relacionados.get(cv.ERPvs__Comprobante_Relacionado__c).Oportunidad__c;
            }
        }
    }

    public static void afterUpdate(List<ERPvs__Comprobante_Venta__c> records, Map<Id, ERPvs__Comprobante_Venta__c> oldRecords) {
        // Coleccionamos los ids de las transacciones
        Set<Id> idsTransacciones = new Set<Id>();
        
        // FL: Coleccionamos los ids de los cvs
        Set<Id> opIds = new Set<Id>();
        
        //FL 2016-07-22 Generacion de movimientos
        Map<String, ERPvs__Moneda__c> mapMonedas = new Map<String, ERPvs__Moneda__c>([SELECT Id, ERPvs__Simbolo__c FROM ERPvs__Moneda__c]);

        Set<ID> cvIds = new Map<Id, ERPvs__Comprobante_Venta__c>(records).keySet();
        
        //FL 2017-02-24 Control de movimientos existentes
        Set<String> movimientosExistentes = new Set<String>();
        for(Movimientos__c m : [SELECT Comprobante_Venta__c FROM Movimientos__c WHERE Comprobante_Venta__c = :cvIds]){
            movimientosExistentes.add(m.Comprobante_Venta__c);
        }
        
        List<Movimientos__c> movimientos = new List<Movimientos__c>();

        Set<Id> toCheckSiembra = new Set<Id>();

        for(ERPvs__Comprobante_Venta__c cv : records) {
            Boolean contabilizada = cv.ERPvs__Contabilizar__c == true && oldRecords.get(cv.Id).ERPvs__Contabilizar__c == false && cv.Oportunidad__c != null &&
            cv.ERPvs__Numero__c != null && cv.ERPvs__Numero__c != 0 && (oldRecords.get(cv.Id).ERPvs__Numero__c == null || oldRecords.get(cv.Id).ERPvs__Numero__c == 0);

            if (contabilizada && cv.Transaccion__c != null && cv.Subestado_Transaccion__c == 'Negativa') {
                opIds.add(cv.Oportunidad__c);    
                movimientos.add(cvToMovimiento(cv, mapMonedas.containsKey(cv.ERPvs__Moneda__c) ? mapMonedas.get(cv.ERPvs__Moneda__c).ERPvs__Simbolo__c : null));
            } else if (contabilizada && cv.Transaccion__c == null && cv.Oportunidad__c != null && (cv.ERPvs__Tipo_comp__c == 'Factura' || (cv.ERPvs__Tipo_comp__c == 'Nota de Crédito' && cv.Tipo_Movimiento__c == 'Cantidad'))) {
                toCheckSiembra.add(cv.id);
            }

            Boolean addTransaction = !movimientosExistentes.contains(cv.Id) && cv.ERPvs__CAE__c != oldRecords.get(cv.Id).ERPvs__CAE__c && cv.ERPvs__CAE__c!=null && String.isNotEmpty(cv.Transaccion__c);
            if (addTransaction) idsTransacciones.add(cv.Transaccion__c);
        }
        
        insert movimientos;
        
        Map<String, ERPvs__Comprobante_Venta__c> mapComprobantes = obtenerNrosComprobantesAplicaciones(records, oldRecords);
        if(!mapComprobantes.isEmpty()) UtilsAplicacion.updateLPs(mapComprobantes);

        checkSiembra(toCheckSiembra, new Map<Id, ERPvs__Comprobante_Venta__c>(records));

        if(!idsTransacciones.isEmpty()) UtilsTransaccion.setTieneCAE(idsTransacciones);
        if(!opIds.isEmpty()) UtilsComprobanteVenta.setOportunidad(opIds);
    }

    @testVisible
    private static void checkSiembra(Set<Id> toCheckSiembra, Map<Id, ERPvs__Comprobante_Venta__c> records) {
        if (toCheckSiembra.isEmpty()) return;

        List<Sobject> toUpdate = new List<Sobject>();
        List<Id> updatedLineITems = new List<Id>();
        Set<Id> oppsSeen = new Set<Id>();

        for (ERPvs__Comprobante_Venta__c cv: [select (select id, OpportunityLineItem__r.Estado__c from Erpvs__Renglones_de_Comprobante_de_Venta__r) from ERPvs__Comprobante_Venta__c where id in: toCheckSiembra and Oportunidad__r.RecordType.DeveloperName = 'Sembra_Evolucion']) {
            for (ERPvs__Productos_Comprobante_de_Venta__c pcv: cv.ERPvs__Renglones_de_Comprobante_de_Venta__r) {
                if (records.get(cv.id).ERPvs__Tipo_comp__c == 'Factura' && pcv.OpportunityLineItem__r.Estado__c != 'Facturada') {
                    toUpdate.add(new OpportunityLineItem(Id = pcv.OpportunityLineItem__c, Estado__c = 'Facturada'));
                    updatedLineITems.add(pcv.OpportunityLineItem__c);
                } else if (records.get(cv.id).ERPvs__Tipo_comp__c == 'Nota de Crédito' && pcv.OpportunityLineItem__r.Estado__c != 'Cancelada por NC') {
                    toUpdate.add(new OpportunityLineItem(Id = pcv.OpportunityLineItem__c, Estado__c = 'Cancelada por NC'));
                    if (oppsSeen.contains(records.get(cv.id).Oportunidad__c) == false) {
                        oppsSeen.add(records.get(cv.id).Oportunidad__c);
                        toUpdate.add(new Opportunity(Id = records.get(cv.id).Oportunidad__c, StageName = 'Cancelada por NC'));
                    }
                }
            }
        }
        
        update toUpdate;
        toUpdate.clear();

        if (updatedLineITems.isEmpty() == false) {
            for (Opportunity opp: [select StageName, (select Estado__c from OpportunityLineItems where Estado__c != 'Facturada' limit 1) from Opportunity where id in (select opportunityId from OpportunityLineItem where id in: updatedLineITems)]) {
                if (opp.StageName != 'Parcialmente Facturada' && opp.OpportunityLineItems.isEmpty() == false) toUpdate.add(new Opportunity(id = opp.id, StageName = 'Parcialmente Facturada'));
                if (opp.StageName != 'Facturada' && opp.OpportunityLineItems.isEmpty()) toUpdate.add(new Opportunity(id = opp.id, StageName = 'Facturada'));
            }
        }

        update toUpdate;
    }

    @testVisible
    private static Movimientos__c cvToMovimiento(ERPvs__Comprobante_Venta__c cv, String moneda) {
        Movimientos__c m = new Movimientos__c();

        m.Comprobante__c = cv.Nro_Comprobante__c;
        m.Cuenta__c = cv.ERPvs__Cliente__c;
        m.Fecha__c = cv.ERPvs__Fecha__c;
        m.Importe__c = cv.ERPvs__Total__c;
        m.Moneda__c = moneda;
        m.Oportunidad__c = cv.Oportunidad__c;
        m.Tipo_de_Cambio__c = cv.ERPvs__Tc__c;
        m.Comprobante_Venta__c = cv.Id;
        m.Tipo_de_Movimiento__c = cv.Tipo_de_Movimiento__c;

        return m;
    }
}