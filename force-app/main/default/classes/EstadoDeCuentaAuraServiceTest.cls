@IsTest
public with sharing class EstadoDeCuentaAuraServiceTest {
   
    @IsTest
    static void testGetInstructivo(){
        EstadoDeCuentaAuraService.getInstructivo('BUCK');
    }

    @IsTest
    static void testGetComprobantes(){
        EstadoDeCuentaAuraService.getComprobantes(null,null,null,null);
    }

    @IsTest
    static void testInnerClass(){

        Opportunity opp = new Opportunity();
        // opp.Id = UserInfo.getUserId();
        opp.N_de_Comprobante__c = '';
        opp.Fecha_Emision_Comprobante__c = Date.today();
        opp.Fecha_Vencimiento_Comprobante__c = Date.today();
        opp.Divisa_Comprobante__c = 'USD';
        // opp.Importe_Total__c = 1;
        opp.Saldo_a_Cobrar_Comprobante__c = 1;
        // opp.Saldo_Actualizado__c = 1;
        
        EstadoDeCuentaAuraService.Factura factura = new EstadoDeCuentaAuraService.Factura(opp);

        Case cse=new Case();
        insert cse;
 
        Attachment attach = new Attachment();   	
    	attach.Name='Unit Test Attachment';
    	Blob bodyBlob=Blob.valueOf('Unit Test Attachment Body');
    	attach.body=bodyBlob;
        attach.parentId=cse.id;
        insert attach;

        factura.file = new EstadoDeCuentaAuraService.File(attach);
        
        
    }

}