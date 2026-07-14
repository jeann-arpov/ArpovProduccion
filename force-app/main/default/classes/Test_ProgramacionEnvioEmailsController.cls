/**
* @author Maximo Martinez
* @date 2/6/2014
* @description Clase de Test de la Clase ProgramacionEnvioEmailsController
*/
@isTest
public class Test_ProgramacionEnvioEmailsController{
    
      
    /*
    * @description Método de Test
    */
    public static testmethod void test(){
        
        //Creamos los datos de prueba
            

        //Obtenemos un email template
        List<EmailTemplate> templates = [SELECT Id FROM EmailTemplate LIMIT 1];
        
        if(templates.size() > 0){
            
            EmailTemplate et = templates.get(0);
            
            //Obtenemos una localidad
            Localidad__c localidad = Test_TestUtils.crearLocalidad('Test');

            //Obtenemos el RercordTypeId de Una Transacicon DUP    
            Id rtDUP =  RecordTypeTool.GetRecordTypeIdsByDeveloperName(Transaccion__c.SObjectType).get('DUP');
            
             //Creamos una cuenta de tipo Obtentor
            Account obtentor = Test_TestUtils.crearObtentor();
            
            //Creamos un distribuidor
            Account productor = Test_TestUtils.crearProductor();
               
            //Creamos un distribuidor
            Account distribuidor = Test_TestUtils.crearDistribuidor();
          
            
            //Creamos un cultivo
            Cultivo__c cultivo = Test_TestUtils.crearCultivo('Cultivo Test',75);
            
            //Fecha Inicio
            Date hoy = Date.today();
            
            //Fecha Fin
            Date manana = hoy.addDays(1);
            
            //Creamos una campaña agricola
            Campana_Agricola__c campanaAgricola = Test_TestUtils.crearCampanaAgricola('2014', cultivo, hoy, manana, '2014 - Test');
            
            //Seteamos la plantilla de email
            campanaAgricola.ID_Plantilla_Email__c = et.Id;
            
            update campanaAgricola;
            
            //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = True
            Transaccion__c t1 = Test_TestUtils.crearTransaccion(new RecordType(Id=rtDUP),'12345678', obtentor, cultivo, campanaAgricola, distribuidor, 'Creada', hoy);
            
            //Creamos una transaccion de tipo DUP con Obtentor con Factura Por Cuenta y Orden = False
            Transaccion__c t2 = Test_TestUtils.crearTransaccion(new RecordType(Id=rtDUP),'87654321', obtentor, cultivo, campanaAgricola, distribuidor, 'Creada', hoy);
           
            Lote__c lote = Test_TestUtils.crearLote(campanaAgricola, cultivo, 'Basico');

            //Seteamos la plantilla de email
            lote.ID_Plantilla_Email__c = et.Id;

            //Insertamos el lote en la BD
            insert lote;
            
            //Creamos una remesa
            Remesa__c remesa = Test_TestUtils.crearRemesa('Pendiente', 'Correo Electrónico', lote, productor);
            
            //Insertamos en la DB
            insert remesa;

            // Obtenemos el contacto del productor
            Contact contacto = [SELECT Id, Name FROM Contact WHERE Account.Id = :productor.Id];

            // Creamos el contacto Remesa
            Contacto_Remesa__c contactoRemesa = Test_TestUtils.crearContactoRemesa('Contacto Remesa', remesa, contacto, true);
            
            String a = 'Correo Electrónico';
            
            String b = 'Enviado';
            
            List<Contacto_Remesa__c> rs = Database.query('SELECT Name, Remesa__r.Productor__c, Estado__c, Remesa__r.Zona_Bolsa_de_Cereales__c, Id FROM Contacto_Remesa__c ');
            
            //Instanciamos el controllador standard
            ApexPages.StandardController std = new ApexPages.StandardController(lote);
            
            //Instanciamos el controlador custom
            ProgramacionEnvioEmailsController ctrl = new ProgramacionEnvioEmailsController(std);
            
            //Obtenemos las zonas de cereales
            List<SelectOption> zonas = ctrl.getZonas();
            
            //Metodos comunes del paginado
            ctrl.lastPage();
            ctrl.firstPage();
            ctrl.next();
            ctrl.prev();
            
            //Metodos comunes Controller
            ctrl.cancel();

            //Seleccionar la zona
            ctrl.selectedZona = localidad.Zona_Bolsa_Cereales__c;

            //Aplicamos el filtro
            ctrl.applyFilter();
            
            //Obtenemos las remesas (deberia ser solo una)
            List<ProgramacionEnvioEmailsController.ContactoRemesa> rows =  ctrl.getContactosRemesa();

            System.assertEquals(rows.size(),1);
            
            if(rows.size() > 0){
                
                //Setear la remesa seleccionada
                Contacto_Remesa__c row = rows.get(0).contacto;
                
                rows[0].setIsSelected(true);

                ctrl.selectedContactosIds.add(row.Id);
                
                //Setear la fecha de programacion
                ctrl.contactoRemesa.Fecha_programada_de_envio__c = Date.today();
                
                //Programamos las remesas seleccionadas para la fecha que seteamos
                ctrl.save();
                
                rs = Database.query('SELECT Name, Remesa__r.Productor__c, Estado__c, Remesa__r.Zona_Bolsa_de_Cereales__c, Id FROM Contacto_Remesa__c ');
            
                System.Debug(LoggingLevel.INFO,rs);
                
                ctrl.selectedContactosIds.add(row.Id);

                //Desprogramamos las remesas
                ctrl.desprogramar();

                ctrl.getTotalRemesasError();
                
            }
            
            //Selecionamos una zona y aplicamos un filtro
            ctrl.selectedZona = localidad.Zona_Bolsa_Cereales__c;
            
            //Aplicamos el filtro
            ctrl.applyFilter();
            
            
            //Test Batch Apex
            Test.startTest();
            BatchApexEnvioEmails ba = new BatchApexEnvioEmails();
            Database.executeBatch(ba);
            
            //Test Scheduler
            String jobId = System.schedule('Test SchdEnvioEmails',SchdEnvioEmails.CRON_EXP, new SchdEnvioEmails());
            
            CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered, NextFireTime FROM CronTrigger WHERE id = :jobId];

            //System.AssertEquals(SchdEnvioEmails.CRON_EXP,  ct.CronExpression);

            //System.AssertEquals(0, ct.TimesTriggered);
            
            Test.stopTest();
            
            Integer i = [SELECT COUNT() FROM Contacto_Remesa__c WHERE Estado__c = 'Programado'];
            //System.AssertEquals(i, 0);

            //Obtenemos los totales
            Integer totalRemesasPendientes = ctrl.getTotalRemesasCPPendientes();
            Integer totalRemesasProgramadas = ctrl.getTotalRemesasCPProgramadas();
            Integer totalRemesasProgramadasByFecha = ctrl.getTotalRemesasCPProgramadasByFecha();
            Integer totalRemesasEnviadas = ctrl.getTotalRemesasCPEnviadas();
            Integer totalesProgramadosByFecha = ctrl.getContactosRemesasProgramadosByFecha();
            Integer totalesSendEmail = ctrl.getEmailSendLimit();
            Integer contactosRemesasProgramadosByFecha = ctrl.getTotalContactosRemesaProgramadosByFecha();

            //Obtenemos la cantidad de remesas checkeadas
            Integer countChecked = ctrl.getCountCheckedIds();

            //Traemos los estados disponibles
            ctrl.getEstados();


            Boolean hasNext = ctrl.hasNext;

            Boolean hasPrevious = ctrl.hasPrevious;
        }
    }
    
    
    
}