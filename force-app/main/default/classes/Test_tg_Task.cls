/**
* @author Facundo Luna
* @date 16/07/2014
* @description Clase de Test de Task
*/
@isTest
public class Test_tg_Task{
    
    public static testmethod void test(){
    
        //Creamos un productor
        Account productor = Test_TestUtils.crearProductor();
        
        //Creamos un cultivo
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
        
        //Fecha Inicio
        Date hoy = Date.today();
        
        //Fecha Fin
        Date manana = hoy.addDays(1);
        
        //Creamos una campaña agricola
        Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
    
        Lote__c lote = Test_TestUtils.crearLote();
        lote.Campana__c = campanaAgricola.Id;
        lote.Cultivo__c = cultivo.Id;
        lote.Tipo__c = 'Basico';
        insert lote;
        
        //Creamos una remesa
        Remesa__c remesa = new Remesa__c();
        
        //Seteamos algunos datos
        remesa.Estado__c = 'Pendiente';
        remesa.Modo_de_Envio__c = 'Correo Electrónico';
        remesa.Lote__c = lote.Id;
        remesa.Productor__c = productor.Id;
        insert remesa;
        
        Attachment a = new Attachment();
        a.ParentId = remesa.Id;
        a.Name = 'Name';
        a.body = Blob.valueOf('test');
        insert a;
        
        Id casoDUP = RecordTypeTool.GetRecordTypeIdsByDeveloperName(Case.SObjectType).get('DUP');
        
        Case cP = new Case();
        cP.RecordTypeId = casoDUP;
        insert cP;
        
        Case c = new Case();
        c.RecordTypeId = casoDUP;
        c.ParentId = cP.ID;
        insert c;
    
        Task t = new Task();
        
        t.WhatId = remesa.ID;
        t.Status = 'Cerrada';
        t.Subject = 'Llamada';
        t.ActivityDate = Date.today();
        t.Description = 'Description';
        
        insert t;
        
        t = new Task();
        
        t.WhatId = c.ID;
        t.Status = 'Cerrada';
        t.Subject = 'Llamada';
        t.ActivityDate = Date.today();
        t.Description = 'Description';
        
        insert t;
    
    }
    

}