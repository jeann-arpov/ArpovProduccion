public without sharing class EstadoDeCuentaAuraService {

    @AuraEnabled(cacheable=true)
    public static Instructivo getInstructivo(String obtentor){
        
        List<Configuracion_Instructivos_de_Pago__mdt> config = [SELECT Id, Id_Instructivo__c, MasterLabel FROM Configuracion_Instructivos_de_Pago__mdt WHERE MasterLabel = :obtentor];
        
        return (!config.isEmpty()) ? new Instructivo(config[0]) : null;
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Factura> getComprobantes(Date fechaDesde, Date fechaHasta, Date fechaVencimientoDesde, Date fechaVencimientoHasta){
        
        List<Factura> facturasList = new List<Factura>();

        Set<Id> idsFacturas = new Set<Id>();

        String qryOrder;

        String sortDirection = 'DESC';
    
        String sortExpression = 'Saldo_a_Cobrar_Comprobante__c';

        String idObject = [SELECT Contact.AccountId,Account.N_Cuit__c FROM User WHERE Id = :UserInfo.getUserId()].Contact.AccountId;

        Set<String> statusToFilter = new Set<String>{'Facturada'};

        String qry = 'SELECT RecordType.DeveloperName, Id, Account.N_Cuit__c, (SELECT Id FROM Comprobantes_Venta__r), Saldo_Actualizado__c, N_de_Comprobante__c, Transaccion__r.Obtentor__r.Nombre_Obtentor__c, Transaccion__r.Obtentor__r.Acepta_Pago_Electronico__c, Transaccion__r.Id, Transaccion__r.Name, Fecha_Emision_Comprobante__c, Fecha_Vencimiento_Comprobante__c, Divisa_Comprobante__c, Importe_Total__c, Saldo_a_Cobrar_Comprobante__c FROM Opportunity';

        String qryFilter = 'Tipo_de_Comprobante__c IN (\'FC\',\'NC\',\'ND\') AND StageName IN :statusToFilter AND RecordType.DeveloperName = \'Regalia_Extendida\' ';  

        if(!String.isBlank(idObject)){
            qryFilter += ' AND AccountId = :idObject ';
        }

        if(fechaDesde!=null && fechaHasta!=null){
            qryFilter += (qryFilter.length() > 0 ? 'AND ' : '') + 'Fecha_Emision_Comprobante__c >= :fechaDesde AND Fecha_Emision_Comprobante__c <= :fechaHasta ';
        }

        if(fechaVencimientoDesde!=null && fechaVencimientoHasta!=null){
            qryFilter += (qryFilter.length() > 0 ? 'AND ' : '') + 'Fecha_Vencimiento_Comprobante__c >= :fechaVencimientoDesde AND Fecha_Vencimiento_Comprobante__c <= :fechaVencimientoHasta ';
        }

        qryFilter = !String.isBlank(qryFilter) ? ' WHERE ' + qryFilter : '';
        
        if(sortExpression != 'N_de_Comprobante__c' && sortExpression != 'Transaccion__r.Obtentor__r.Nombre_Obtentor__c' && sortExpression != 'Transaccion__r.Name' && sortExpression != 'Fecha_Vencimiento_Comprobante__c' && sortExpression != 'Divisa_Comprobante__c' && sortExpression != 'Importe_Total__c'){
            qryOrder = ' ORDER BY ' + sortExpression + ' ' + sortDirection;
        }else{ 
            qryOrder = '';
        }

        for(Opportunity fact : (List<Opportunity>)Database.query(qry+qryFilter+qryOrder)){
            facturasList.add(new Factura(fact));
            idsFacturas.add(fact.Id);

            for(ERPvs__Comprobante_Venta__c comp : fact.Comprobantes_Venta__r){
                idsFacturas.add(comp.Id);
            }

        }

        Map<Id,File> filesByCompId = new Map<Id,File>();

        for(Attachment at : [SELECT Id, ParentId, Body, Name, ContentType FROM Attachment WHERE ParentId IN :idsFacturas AND Name LIKE 'Factura%']){
            filesByCompId.put(at.ParentId,new File(at));
        }

        for(Factura fact : facturasList){

            if(filesByCompId.containsKey(fact.id)){
                fact.file =  filesByCompId.get(fact.id);
                continue;
            }

            for(ERPvs__Comprobante_Venta__c comp : fact.op.Comprobantes_Venta__r){

                if(filesByCompId.containsKey(comp.id)){
                    fact.file =  filesByCompId.get(comp.id);
                    continue;
                }

            }

        }

        return facturasList;
    }

    public class Factura{

        public Opportunity op;

        @AuraEnabled
        public Id id;

        @AuraEnabled
        public String cuit {get; set;}

        @AuraEnabled
        public String numero {get; set;}
        
        @AuraEnabled
        public String shortNameSemillero {get; set;}
        
        @AuraEnabled
        public String transaccion {get; set;}
        
        @AuraEnabled
        public String transaccionUrl {get; set;}
        
        @AuraEnabled
        public Date fechaEmisionComprobante {get; set;}
        
        @AuraEnabled
        public Date fechaVencimientoComprobante {get; set;}
        
        @AuraEnabled
        public String moneda {get; set;}
        
        @AuraEnabled
        public Decimal importeTotal {get; set;}
        
        @AuraEnabled
        public Decimal saldo {get;set;}
        
        @AuraEnabled
        public Decimal saldoActualizado {get;set;}
        
        @AuraEnabled
        public File file {get; set;}

        @AuraEnabled
        public Id opportunityId {get; set;}

        @AuraEnabled
        public Boolean showPaymentButton {get; set;}

        @AuraEnabled
        public Boolean showInformPayment {get;set;}

        public Factura(Opportunity comp){
            this.op = comp;
            this.id = comp.Id;
            this.numero = comp.N_de_Comprobante__c;
            this.shortNameSemillero = (comp.Transaccion__r != null) ? comp.Transaccion__r.Obtentor__r.Nombre_Obtentor__c : null;
            this.transaccion = (comp.Transaccion__r != null) ? comp.Transaccion__r.Name : null;
            this.transaccionUrl = (comp.Transaccion__r != null) ? '/s/transaccion/' + comp.Transaccion__r.Id : null;
            this.fechaEmisionComprobante = comp.Fecha_Emision_Comprobante__c;
            this.fechaVencimientoComprobante = comp.Fecha_Vencimiento_Comprobante__c;
            this.moneda = comp.Divisa_Comprobante__c;
            this.importeTotal = comp.Importe_Total__c;
            this.saldo = comp.Saldo_a_Cobrar_Comprobante__c;
            this.saldoActualizado = comp.Saldo_Actualizado__c;
            this.opportunityId = comp.Id;
            this.showPaymentButton = comp.Saldo_Actualizado__c > 0 && comp.Transaccion__r.Obtentor__r.Acepta_Pago_Electronico__c == true;
            this.showInformPayment = comp.Saldo_Actualizado__c > 0;
            this.cuit = (comp.Account != null) ? comp.Account.N_Cuit__c : null;

            if (comp.RecordType.DeveloperName == 'Sembra_Evolucion') {
                this.showInformPayment = true;
                this.showPaymentButton = true;
            }
        }

    }

    public class File{
        @AuraEnabled
        public String name {get;set;}
        @AuraEnabled
        public String body {get;set;}
        @AuraEnabled
        public String contentType {get;set;}
        @AuraEnabled
        public String id {get;set;}
        

        public File(Attachment at){
            this.name = at.Name;
            this.body = EncodingUtil.base64Encode(at.Body);
            this.contentType = at.ContentType;
            this.id = at.Id;
        }

    }

    public class Instructivo{

        @AuraEnabled
        public Id documentId {get;set;}
        
        @AuraEnabled
        public String obtentor {get;set;}

        public Instructivo(Configuracion_Instructivos_de_Pago__mdt config){
            this.obtentor = config.MasterLabel;
            this.documentId = config.Id_Instructivo__c;
        }

    }

}