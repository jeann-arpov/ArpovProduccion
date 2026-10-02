@isTest
public class AdhesionPPHHomeTest {
    
    @isTest static void test(){

        Account productor = Test_TestUtils.crearProductor();
        
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Parametro_PPH__c param = new Parametro_PPH__c();
        param.Cultivo__c = cultivo.Id;
        param.Fecha_Inicio_Adhesion_PPH__c = Date.today();
        param.Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2);
        param.Fecha_Inicio_Rectificacion_1__c = Date.today().addDays(30);
        param.Fecha_Inicio_Rectificacion_2__c = Date.today().addDays(50);
        param.Fecha_Fin_Rectificacion_1__c = Date.today().addDays(40);
        param.Fecha_Fin_Rectificacion_2__c = Date.today().addDays(60);
        param.Fecha_Vencimiento_PPH__c = Date.today().addMonths(6);
        insert param;

        Plan_de_Siembra__c plan = new Plan_de_Siembra__c();
        plan.Productor__c = productor.Id;
        plan.Parametro_PPH__c = param.Id;
        plan.Estado__c = 'En Preparación';
        plan.Version__c = 'Original';
        plan.Name = param.name + ' ' + productor.N_CUIT__c + ' Original';
        insert plan;

        List<AdhesionPPHHome.CultivoParametro> results =  AdhesionPPHHome.getLoadData();

        System.assertEquals(1, results.size());

        AdhesionPPHHome.AccountContext context = AdhesionPPHHome.getContext();
        System.assertNotEquals(null, context.accountId);
        System.assertNotEquals(null, context.cuit);
    }

    @isTest static void testTycDocumentos() {
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Parametro_PPH__c param = new Parametro_PPH__c(
            Name = 'Plan de Siembra 2025/2026 - SOJA',
            Cultivo__c = cultivo.Id,
            Fecha_Inicio_Adhesion_PPH__c = Date.today(),
            Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2)
        );
        insert param;
        insert new List<ContentVersion>{
            new ContentVersion(
                Title = 'TyC SOJA 25-26.pdf',
                PathOnClient = 'tyc.pdf',
                VersionData = Blob.valueOf('pdf'),
                FirstPublishLocationId = param.Id
            ),
            new ContentVersion(
                Title = 'TyC - GC - SOJA 25-26',
                PathOnClient = 'tyc-gc.pdf',
                VersionData = Blob.valueOf('pdf'),
                FirstPublishLocationId = param.Id
            )
        };
        Id generalDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Title = 'TyC SOJA 25-26.pdf'].ContentDocumentId;

        List<AdhesionPPHHome.TycDocumento> docs = AdhesionPPHHome.getTycDocumentos();
        System.assertEquals(1, docs.size());
        System.assertEquals('SOJA', docs[0].cultivo);
        System.assertEquals(generalDocId, docs[0].contentDocumentId, 'Sin Grandes Cuentas usa el T&C general');
    }

    @isTest static void testTycPorParametro() {
        Cultivo__c cultivo = Test_TestUtils.crearCultivo('SOJA', 75, false);
        cultivo.Sembra_Evolucion__c = true;
        insert cultivo;

        Parametro_PPH__c conTyc = new Parametro_PPH__c(Name = 'Plan de Siembra 2026 - SOJA', Cultivo__c = cultivo.Id,
            Fecha_Inicio_Adhesion_PPH__c = Date.today(), Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2));
        Parametro_PPH__c sinTyc = new Parametro_PPH__c(Name = 'Plan de Siembra 2026 - TRIGO', Cultivo__c = cultivo.Id,
            Fecha_Inicio_Adhesion_PPH__c = Date.today(), Fecha_Fin_Adhesion_PPH__c = Date.today().addMonths(2));
        insert new List<Parametro_PPH__c>{ conTyc, sinTyc };

        insert new List<ContentVersion>{
            new ContentVersion(Title = 'TyC - Plan de Siembra 2026 - SOJA', PathOnClient = 'a.pdf', VersionData = Blob.valueOf('pdf'), FirstPublishLocationId = conTyc.Id),
            new ContentVersion(Title = 'TyC - GC - Plan de Siembra 2026 - SOJA.pd', PathOnClient = 'b.pdf', VersionData = Blob.valueOf('pdf'), FirstPublishLocationId = conTyc.Id),
            new ContentVersion(Title = 'Terminos 2026 trigo', PathOnClient = 'c.pdf', VersionData = Blob.valueOf('pdf'), FirstPublishLocationId = sinTyc.Id)
        };
        Map<String, Id> docPorTitulo = new Map<String, Id>();
        for (ContentVersion cv : [SELECT Title, ContentDocumentId FROM ContentVersion]) {
            docPorTitulo.put(cv.Title, cv.ContentDocumentId);
        }
        Set<Id> ids = new Set<Id>{ conTyc.Id, sinTyc.Id };

        Map<Id, Id> general = AdhesionPPHHome.getTycPorParametro(ids, false);
        System.assertEquals(docPorTitulo.get('TyC - Plan de Siembra 2026 - SOJA'), general.get(conTyc.Id));
        System.assertEquals(docPorTitulo.get('Terminos 2026 trigo'), general.get(sinTyc.Id));

        Map<Id, Id> gc = AdhesionPPHHome.getTycPorParametro(ids, true);
        System.assertEquals(docPorTitulo.get('TyC - GC - Plan de Siembra 2026 - SOJA.pd'), gc.get(conTyc.Id));

        System.assert(AdhesionPPHHome.getTycPorParametro(new Set<Id>(), true).isEmpty());
    }
}