/**
* @author Maximo Martinez
* @date 03/02/2016
* @description Clase controladora de la vista printSalesElectronicInvoice
*/
global with sharing class PrintSalesElectronicInvoiceController {
    
    private String opportunityId;
    public Liquidacion liquidacion {get; set;}

    public PrintSalesElectronicInvoiceController(){
        opportunityId = ApexPages.currentpage().getparameters().get('id');
        System.Debug('PrintSalesElectronicInvoiceController()');
        System.Debug('opportunityId: ' + opportunityId);
        init();
    }

    public void init(){

        // Obtenemos los datos de la opportunidad
        Opportunity opportunity = [SELECT Fecha_Pedido_Facturacion__c, Transaccion__r.Name , Id, Moneda__r.Name, Moneda__r.ERPvs__Simbolo__c, Tipo_de_Cambio_del_Comprobante__c, Total_Comprobante_ARS__c, Total_Comprobante__c, Divisa_Comprobante__c, Fecha_Vencimiento_Comprobante__c, N_de_Comprobante__c, Fecha_de_Facturacion__c, Account.ERPvs__Identificacion_Tributaria__c, Account.ERPvs__Categoria_IVA__r.Name, Account.ERPvs__Localidad__c, Account.ERPvs__Direccion__c, Account.ERPvs__Denominacion_Y_Razon_Social__c, Account.ERPvs__Provincia_Departamento__r.Name, Account.ERPvs__Codigo_Postal__c, CreatedDate,(SELECT Id, Quantity, Product2.Name, UnitPrice, TotalPrice, Item_de_DUP__r.Tipo_de_Cambio__c, Item_Auditoria__r.Tipo_de_Cambio__c, Item_de_DUP__r.Unidad_de_Medida_de_Facturacion_TXT__c, Item_Auditoria__r.Unidad_de_Medida_de_Facturacion_TXT__c FROM OpportunityLineItems) FROM Opportunity WHERE Id =:opportunityId];
        
        liquidacion = new Liquidacion(opportunity);
        
    }


    /**
    * @author Maximo Martinez
    * @date 12/02/2016
    * @description Clase Wrapper Opportunity
    */
    public class Liquidacion {
        
        public Opportunity o {get; set;}
        public String totalFormated {get; set;}
        public String totalText {get; set;}
        public String tipoCambioFormated {get; set;}
        public String totalIVA {get; set;}
        public String totalGravado {get; set;}
        public List<ItemLiquidacion> items {get; set;}

        public Liquidacion(Opportunity o){

            this.o = o;

            Decimal t = 0;
            Decimal tIVA = 0;
            
            // Recorremos los items
            this.items = new List<ItemLiquidacion>();

            for(OpportunityLineItem ol : o.OpportunityLineItems){

                ItemLiquidacion il = new ItemLiquidacion(ol);
                this.items.add(il);

                t += il.total;

            }

            if(t != null){
                this.totalGravado = Utils.formatNumber(t.setScale(2));
                tIVA = t * 0.21;
                this.totalIVA = Utils.formatNumber(tIVA.setScale(2));
                t = (t*1.21).setScale(2);
                this.totalFormated = Utils.formatNumber(t);
                this.totalText = Utils.convertirTotalAPalabras(t).toUpperCase();
            }

            if(o.Tipo_de_Cambio_del_Comprobante__c != null){
                this.tipoCambioFormated = Utils.formatNumber(o.Tipo_de_Cambio_del_Comprobante__c.setScale(2));
            }

        }

    }

    /**
    * @author Maximo Martinez
    * @date 12/02/2016
    * @description Clase Wrapper OpportunityLineItem
    */
    public class ItemLiquidacion {
        
        public OpportunityLineItem ol {get; set;}
        public String totalFormated {get; set;}
        public String unitPriceFormated {get; set;}
        public String measureUnit {get; set;}
        public Decimal total {get; set;}
        public Decimal unitPrice {get;set;}

        public ItemLiquidacion(OpportunityLineItem ol){

            this.ol = ol;

            Decimal tipoDeCambio = Helper.getExchangeRate('USD');

            this.measureUnit =  (ol.Item_de_DUP__r != null) ? ol.Item_de_DUP__r.Unidad_de_Medida_de_Facturacion_TXT__c : ol.Item_Auditoria__r.Unidad_de_Medida_de_Facturacion_TXT__c;

            if(ol.TotalPrice != null){
                this.total = (ol.TotalPrice/tipoDeCambio).setScale(2);
                this.totalFormated = Utils.formatNumber(this.total);
            }

            if(ol.UnitPrice != null){
                this.unitPrice = (ol.UnitPrice/tipoDeCambio).setScale(2);
                this.unitPriceFormated = Utils.formatNumber(this.unitPrice);
            }

        }

    }

}