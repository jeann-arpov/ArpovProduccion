@isTest
public class CesionPPHTest {
    public static testmethod void main() {
        Test_TestUtils.disableFlows();
        
        Date fechaInicioCesion = Date.today();
        Cultivo__c cultivo = new Cultivo__c(Name = 'SOJA', Densidad_de_Siembra__c = 5, Fecha_Vencimiento_Tonelada__c = Date.today().addDays(-2), Id_Externo__c = 'SOJA', Fecha_Inicio_Cesion__c = fechaInicioCesion, Fecha_Inicio_Cesion_Semilla_Original__c = fechaInicioCesion);
        insert cultivo;

        Account productor = Test_TestUtils.crearProductor();

        Variedad__c var = new Variedad__c(Name = 'test', Biotecnologia__c = 'Enlist E3');
        Variedad__c var2 = new Variedad__c(Name = 'test 2', Biotecnologia__c = 'Enlist E3');
        insert new List<Variedad__c>{var, var2};

        CesionPPH.getLoadData(null);
        CesionPPH.getNewCesionData(cultivo.Id, 'Explotacion Conjunta');

        Cesion_HT__c cesion = [select id from Cesion_HT__c];

        System.assertEquals(null, CesionPPH.getStockDisponible(cultivo.id, cesion.id, 'Explotacion Conjunta').get(var.id));

        Hectareas_Tecnologicas__c hectarea = new Hectareas_Tecnologicas__c(Signo__c = 1, Cantidad__c = 3, Productor__c = productor.id, Biotecnologia__c = 'Enlist E3', Cultivo__c = cultivo.id, Variedad__c = var.id, Origen__c = 'Compra HT', Valor_Conversion__c = 3000);
        Hectareas_Tecnologicas__c hectarea2 = new Hectareas_Tecnologicas__c(Signo__c = 1, Cantidad__c = 1, Productor__c = productor.id, Biotecnologia__c = 'Enlist E3', Cultivo__c = cultivo.id, Variedad__c = var2.id, Origen__c = 'Compra HT', Valor_Conversion__c = 3000);
        insert new List<Hectareas_Tecnologicas__c>{hectarea, hectarea2};

        Tonelada__c tonelada = new Tonelada__c(Productor__c = productor.id, Biotecnologia__c = 'Enlist E3', Signo__c = 1, Cantidad__c = 9, Cultivo__c = cultivo.id, Variedad__c = var.id, Origen__c = 'Compra HT', Fecha_Inicio__c = Date.today().addDays(-1), Fecha_Fin__c = Date.today().addDays(1), Etapa__c = 'Cobrada');
        Tonelada__c tonelada2 = new Tonelada__c(Productor__c = productor.id, Biotecnologia__c = 'Enlist E3', Signo__c = 1, Cantidad__c = 3, Cultivo__c = cultivo.id, Variedad__c = var2.id, Origen__c = 'Compra HT', Fecha_Inicio__c = Date.today().addDays(-1), Fecha_Fin__c = Date.today().addDays(1), Etapa__c = 'Cobrada');
        insert new List<Tonelada__c>{tonelada, tonelada2};

        Map<Id, Integer> stock = CesionPPH.getStockDisponible(cultivo.id, cesion.id, 'Explotacion Conjunta');

        System.assertEquals(9, stock.get(var.id));
        System.assertEquals(3, stock.get(var2.id));

        ContentVersion content = new ContentVersion(); 
        content.Title='Header_Picture1'; 
        content.VersionData = Blob.valueOf('Unit Test ContentVersion Body');
        content.PathOnClient = 'test';
        insert content;

        ContentDocumentLink contentlink=new ContentDocumentLink();
        contentlink.LinkedEntityId = cesion.id;
        contentlink.contentdocumentid=[select contentdocumentid from contentversion where id =: content.id].contentdocumentid;
        insert contentlink;

        CesionPPH.searchDestinatarios('123');
        Id newProductor = CesionPPH.registerCuit('33645022659', 'test@test.com')[0].Id;

        CesionPPH.Data data = new CesionPPH.Data();
        CesionPPH.addDestinatario(data, productor.id, var.id, 9);
        CesionPPH.addDestinatario(data, newProductor, var2.id, 3);
        
        CesionPPH.save(JSON.serialize(data), cesion.id);

        System.assertEquals(2, [select id from Destinatario_Cesion_HT__c].size());
        System.assertEquals(2, [select id from Linea_Cesion_HT__c].size());
        System.assertEquals('test; test 2', [select Variedades__c from Cesion_HT__c where id =: cesion.id].Variedades__c);

        stock = CesionPPH.getStockDisponible(cultivo.id, cesion.id, 'Explotacion Conjunta');

        System.assertEquals(9, stock.get(var.id));
        System.assertEquals(3, stock.get(var2.id));

        stock = CesionPPH.getStockDisponible(cultivo.id, null, 'Explotacion Conjunta');

        System.assertEquals(0, stock.get(var.id));
        System.assertEquals(0, stock.get(var2.id));
        
        Licencia__c licencia = new Licencia__c(Cuenta_Productor__c = productor.id, Estado__c = 'Aprobada', Fecha_de_Vencimiento__c = System.today(), Tipo_de_Licencia__c = 'Productor', LicenciaId__c = '123', Tecnologia__c = 'Enlist');
        insert licencia;

        Test.startTest();

        CesionPPH.sendCesion(cesion.id);
        System.assertEquals(1, [select Estado__c from Linea_Cesion_HT__c where Estado__c = 'Pendiente de Validación'].size());
        CesionPPH.backToEnCurso(cesion.id);
        System.assertEquals(2, [select Estado__c from Linea_Cesion_HT__c where Estado__c = 'En Curso'].size());
        CesionPPH.sendCesion(cesion.id);

        delete [select id from Destinatario_Cesion_HT__c where Destinatario__r.Name = 'A Gestionar'];
        System.assertEquals('test', [select Variedades__c from Cesion_HT__c where id =: cesion.id].Variedades__c);

        CesionPPH.validateRecord(cesion.id);
        CesionPPH.desvalidar(cesion.id);
        CesionPPH.anular(cesion.id);
        CesionPPH.deleteFile(contentlink.contentdocumentid, cesion.id);

        delete [select id from Linea_Cesion_HT__c];
        System.assertEquals(null, [select Variedades__c from Cesion_HT__c where id =: cesion.id].Variedades__c);

        // CesionPPH.deleteCesion(cesion.Id);
        // System.assertEquals(true, [select id from Cesion_HT__c where id = :cesion.Id].isEmpty());
    }
}