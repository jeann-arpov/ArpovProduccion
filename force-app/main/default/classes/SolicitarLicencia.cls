public without sharing class SolicitarLicencia {
    // public static List<Map<String, String>> getOptions(SobjectField field) {
    //     List<Map<String, String>> options = new List<Map<String, String>>();

    //     Schema.DescribeFieldResult objFieldDescribe = field.getDescribe();
    //     List<Schema.PicklistEntry> lstPickListValues = objFieldDescribe.getPickListValues();

    //     for (Schema.PicklistEntry objPickList : lstPickListValues) {
    //         options.add(new Map<String, String>{'value' => objPickList.getValue(), 'label' => objPickList.getLabel()});
    //     }

    //     return options;
    // }

    @AuraEnabled(Cacheable=true)
    public static List<LookupSearchResult> searchAccounts(String searchTerm, List<String> selectedIds) {
        String safeTerm = String.escapeSingleQuotes(searchTerm);
        String normalizedCuitTerm = UtilsVentaHt.normalizeCuit(searchTerm);
        String cuitCondition = String.isNotBlank(normalizedCuitTerm)
            ? ' or N_CUIT__c like \'%' + String.escapeSingleQuotes(normalizedCuitTerm) + '%\''
            : '';
        return CrearVentaController.accountsToLookup(Database.query(
            'select RecordType.DeveloperName, Name, N_CUIT__c, Owner.Name, Operador_de_Cobranza__r.Name, Provincia_Envio__c, Phone ' +
            'from account where (name like \'%' + safeTerm + '%\'' + cuitCondition + ') ' +
            'and recordType.DeveloperName in (\'Productor\', \'Comercio\', \'Distribuidor\') ' +
            'and id != \'' + String.escapeSingleQuotes(CrearCompraController.getAccount().id) + '\' and ParentId = null limit 5'
        ));
    }

    @AuraEnabled
    public static Map<String, Object> getButtonData() {
        Map<String, Object> data = new Map<String, Object>{};
        Boolean isPortalComercio = networkName == 'Sembrá Evolución Comercio';

        if (networkName == 'Sembrá Evolución Obtentor') {
            data.put('marcas', [select Nombre_Obtentor__c, N_CUIT__c, ParentId, Parent.N_CUIT__c from Account where id =: CrearCompraController.getAccount().id]);
        } else {
            Set<String> cuits = new Set<String>{'30616275905','30646328450', '30707285563', '33710831659', '30517486678'};
            data.put('marcas', [select Nombre_Obtentor__c, N_CUIT__c, ParentId, Parent.N_CUIT__c from Account where N_CUIT__c in :cuits or Parent.N_CUIT__c in :cuits order by Name asc]);
        }

        data.put('isPortalComercio', isPortalComercio);
        data.put('isPortalObtentor', networkName == 'Sembrá Evolución Obtentor');

        //licencias de comercio que tengo para manejar terceros, aporte genético (rr)
        if (isPortalComercio){
            data.put('licencias', [select Cuenta_Obtentor__r.N_CUIT__c from licencia__c where Cuenta_Productor__c =: CrearCompraController.getAccount().id and Estado__c = 'Aprobada' and Fecha_de_Vencimiento__c >=: System.today() AND Tipo_de_Licencia__c = 'Comercio' AND tecnologia__c = 'RR']);
        }

        return data;
    }

    public static String networkName {
        get {
            if (networkName == null && !Test.isRunningTest()) networkName = [SELECT Name FROM Network WHERE id =: Network.getNetworkId()].Name;
            return networkName;
        }
        set;
    }

    @AuraEnabled
    public static Map<String, Object> getData(Id recordId, Boolean firstLoad, Id tercero) {
        Map<String, Object> data = new Map<String, Object>{};
        Id accountId = CrearCompraController.getAccount().id;

        if (firstLoad) {
            data.put('account', getAccount(accountId));
            data.put('isPortalComercio', networkName == 'Sembrá Evolución Comercio');

            Set<String> cuits = new Set<String>{'30616275905','30646328450', '30707285563', '33710831659', '30517486678'};

            data.put('marcas', [select Parent.Id, Nombre_Obtentor__c, Proveedor__c, Parent.Proveedor__c from Account where (N_CUIT__c in :cuits or Parent.N_CUIT__c in :cuits)]);
            
            if (String.isNotBlank(tercero)) data.put('tercero', getAccount(tercero));
        }

        if (String.isNotBlank(recordId)) {
            Licencia__c licencia = [select Cuenta_Distribuidor__c, Tipo_de_Licencia__c, Cuenta_Productor__r.N_CUIT__c, Direccion_Fiscal_Firmante__c, Localidad__c, Codigo_Postal_Firmante__c, Provincia_Firmante__c, Firmante_Licencia__c, Firmante_First_Name__c, Firmante_Last_Name__c, Firmante_Cuit__c, Firmante_Celular__c, Firmante_Cargo__c, CreatedDate, Cuenta_Obtentor__r.Emite_Carta_de_Aceptacion__c, Cuenta_Obtentor__r.N_CUIT__c, Cuenta_Obtentor__r.Parent.N_CUIT__c, Metodo_firma__c, Cuenta_Obtentor__r.Name, Name, Estado__c, Nombres_Marcas__c, Tipo__c, Motivo_del_Rechazo__c from Licencia__c where id =: recordId and (Cuenta_Productor__c =: accountId or Cuenta_Distribuidor__c =: accountId or Cuenta_Obtentor__c =:accountId) and Origen__c = 'Portal'];

            data.put('licencia', licencia);
            data.put('files', getFiles(licencia));
            data.put('filesData', getFilesData(licencia.Id));
            data.put('needsPoder', needsPoder(licencia.Cuenta_Productor__r.N_CUIT__c, licencia.Firmante_Cuit__c));
            
            if (licencia.Cuenta_Distribuidor__c == accountId) { // caso gestion de tercero
                data.put('tercero', getAccount(licencia.Cuenta_Productor__c));
            }
        }

        return data;
    }

    //El without sharing no aplica a ContentVersion por lo que hay que obtener los ids primero y luego hacer la query
    private static Map<String, Map<String, String>> getFilesData(Id licenciaId){
        Map<String, Map<String, String>> filesData = new Map<String, Map<String, String>>();
        Set<Id> contentVersionIds = new Set<Id>();
        
        Licencia__c licencia = [SELECT Id, (SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersionId, ContentDocument.Title, LinkedEntityId FROM ContentDocumentLinks) FROM Licencia__c WHERE Id = :licenciaId];
        for(ContentDocumentLink cdl : licencia.ContentDocumentLinks){
            contentVersionIds.add(cdl.ContentDocument.LatestPublishedVersionId);
        }

        for(ContentVersion version : [SELECT VersionData, ContentDocumentId, ContentDocument.Title FROM ContentVersion WHERE Id IN :contentVersionIds]){
            filesData.put(version.ContentDocumentId, new Map<String, String>{'fileName' => version.ContentDocument.Title, 'data' => EncodingUtil.base64Encode(version.VersionData)});
        }

        return filesData;
    }

    private static Account getAccount(Id accountId) {
        return [select RecordType.DeveloperName, Name, N_CUIT__c, ERPvs__Direccion__c, ERPvs__Localidad__c, ERPvs__Codigo_Postal__c, Provincia_Facturacion__c from account where id =: accountId];
    }

    private static Boolean hasComercioLicence(Account obtentor) {
        return [select id from licencia__c where Cuenta_Productor__c =: CrearCompraController.getAccount().id and Estado__c = 'Aprobada' and Fecha_de_Vencimiento__c >=: System.today() AND Tipo_de_Licencia__c = 'Comercio' AND tecnologia__c = 'RR' AND Cuenta_Obtentor__r.N_CUIT__c =: obtentor.N_CUIT__c limit 1].isEmpty() == false;
    }

    @AuraEnabled
    public static Map<String, Object> solicitar(String js) {
        Data data = (Data) JSON.deserialize(js, Data.class);

        Set<String> cuits = new Set<String>{'30616275905','30646328450', '30707285563', '33710831659', '30517486678'};

        // 30616275905 = GDM
        Account obtentor = [select Parent.Opcion_Validacion__c, Parent.N_CUIT__c, Parent.Proveedor__c, Parent.Mail_Obtentor_Licencia__c, Parent.Obtentor_Prefix__c, Opcion_Validacion__c, N_CUIT__c, Proveedor__c, Mail_Obtentor_Licencia__c, Obtentor_Prefix__c from Account where id =: data.marca and (N_CUIT__c in :cuits or Parent.N_CUIT__c in :cuits)];
        Boolean isPortalComercio = networkName == 'Sembrá Evolución Comercio';
        Boolean isPortalObtentor = networkName == 'Sembrá Evolución Obtentor';
        Boolean isGestionTercero = isPortalComercio || isPortalObtentor;
        Account productor = String.isBlank(data.tercero) ? CrearCompraController.getAccount() : getAccount(data.tercero);
        String licenceType = data.licenceType;

        //algunas validaciones por seguridad
        if (String.isNotBlank(data.tercero) && isGestionTercero == false) throw new AuraHandledException('Sólo puede gestionarse una licencia de un tercero desde el portal de comercio');
        if (licenceType != 'Productor' && licenceType != 'Comercio') throw new AuraHandledException('Tipo de licencia Inválido');
        if (isGestionTercero == false && licenceType != 'Productor') throw new AuraHandledException('El portal productor sólo puede pedir una licencia de tipo productor');
        if (String.isNotBlank(data.tercero) && data.tercero == CrearCompraController.getAccount().id) throw new AuraHandledException('La cuenta tercera no puede ser uno mismo');
        if (isGestionTercero && String.isNotBlank(data.tercero) && isPortalComercio && hasComercioLicence(obtentor) == false) throw new AuraHandledException('No posee una licencia de comercio con la marca seleccionada para gestionar a un tercero');
        if (isGestionTercero && isPortalObtentor && CrearCompraController.getAccount().id != data.marca) throw new AuraHandledException('La marca debe ser uno mismo');

        Licencia__c licencia = new Licencia__c();

        if (data.id != null) {
            licencia = [select Name, Estado__c from Licencia__c where id =: data.id];
            if (licencia.Estado__c != 'Creada') throw new AuraHandledException('La solicitud ya no se puede editar');
        } else {
            if (Test.isRunningTest() || (UserInfo.getOrganizationId() != (ID) '00D8K0000008aLL')) {
                List<Id> accounts = new List<Id>{obtentor.id};
                if (obtentor.ParentId != null) accounts.add(obtentor.ParentId);
                
                List<Licencia__c> others = [select Estado__c from Licencia__c where (Cuenta_Obtentor__c in: accounts or Cuenta_Obtentor__r.ParentId in: accounts) and Estado__c != 'Rechazada' and Cuenta_Productor__c =: productor.id and Tipo_de_licencia__c =: licenceType and Tecnologia__c in: AdhesionPPH.tecnologiasEquivalentes(data.tecnologia) limit 1];
                if (others.isEmpty() == false) throw new AuraHandledException('Ya tiene una licencia ' + others[0].Estado__c + ' con ese obtentor');
            }
        }

        if (obtentor.Parent != null) obtentor = obtentor.Parent; // quieren que se use el parent siempre

        Account distribuidor = null;

        if (data.id == null) {
            licencia.Cuenta_Productor__c = productor.id;
            licencia.Estado__c = 'Creada';
            licencia.Cuenta_Obtentor__c = obtentor.id;
            licencia.Name = obtentor.Obtentor_Prefix__c + '54' + String.valueOf(System.today().year()).substring(2, 4) + 'G';
            licencia.LicenciaId__c = String.valueOf(Utils.getRandomLong(13));
            licencia.Cuenta_Distribuidor__c = Test.isRunningTest() ? null : (String.isBlank(data.tercero) ? CrearCompraController.getSembraEvolucionAccount().id : CrearCompraController.getAccount().Id);
            licencia.Opcion_Validacion__c = obtentor.Opcion_Validacion__c;
            licencia.Firmante_Carta_de_Aceptacion__c = obtentor.Mail_Obtentor_Licencia__c;
            licencia.Created__c = System.today();
            licencia.Origen__c = 'Portal';
            licencia.Fecha_de_creacion_de_licencia__c = System.today();
            licencia.Proveedor__c = obtentor.Proveedor__c;
            licencia.Tecnologia__c = data.tecnologia;
            licencia.Tipo_de_Licencia__c = licenceType;
            licencia.Fecha_de_Vencimiento__c = obtentor.N_CUIT__c == '30616275905' ? Date.newInstance(2032, 2, 28) : System.today().addYears(10);
        }

        licencia.Firmante_Licencia__c = data.email;
        licencia.Firmante_First_Name__c = data.nombre;
        licencia.Firmante_Last_Name__c = data.apellido;
        licencia.Firmante_Cuit__c = data.cuil;
        licencia.Firmante_Celular__c = data.celular;
        licencia.Metodo_firma__c = data.firma;
        licencia.Firmante_Cargo__c = data.cargo;
        licencia.Direccion_Fiscal_Firmante__c = data.direccion;
        licencia.Localidad__c = data.localidad;
        licencia.Codigo_Postal_Firmante__c = data.codigoPostal;
        licencia.Provincia_Firmante__c = data.provincia; 

        upsert licencia;

        if (data.id == null) {
            licencia.Name += [select Autonumerico__c from Licencia__c where id =: licencia.id].Autonumerico__c;
            update licencia;
        } else {
            ContentDocumentLink doc = getLicenciaFiles(licencia.id).get(licencia.Name + '-Licencia');
            if (doc != null) delete doc.ContentDocument;
        }

        generarPDFLicencia(licencia, obtentor, licenceType == 'Comercio');

        return getData(licencia.id, false, null);
    }

    @AuraEnabled
    public static void generarPDFLicenciaInterna(String licenciaId){
        Licencia__c licencia = [SELECT Id, Name, Cuenta_Obtentor__r.N_CUIT__c, Tipo_de_Licencia__c FROM Licencia__c WHERE Id = :licenciaId];
        Boolean isPdfComercio = licencia.Tipo_de_Licencia__c == 'Comercio';
        Set<String> cuitsNoPermitidos = new Set<String>{'30646328450', '30707285563', '33710831659'};
        //Set<String> cuitsNoPermitidos = new Set<String>{'30707285563', '33710831659'};
        if(isPdfComercio && cuitsNoPermitidos.contains(licencia.Cuenta_Obtentor__r.N_CUIT__c)){
            throw new AuraHandledException('No se puede generar el pdf de licencia Comercio para este obtentor');
        }

        String fileName = licencia.Name + '-Licencia';

        Pagereference ref = getPDFRef(licencia.Cuenta_Obtentor__r.N_CUIT__c, isPdfComercio);
        PagePDF pdf = new PagePDF(ref, fileName, licencia.id, new List<Id>{UserInfo.getUserId()}, true);
        pdf.reference.getParameters().put('licencia', PDFLicenciaController.serializeLicencia(licencia.id));

        List<ContentDocument> files = [SELECT Id FROM ContentDocument WHERE Title = :fileName LIMIT 1];

        if(!files.isEmpty()){
            ContentVersion version = [SELECT Id, Estado__c, Id_Documento_Proveedor__c FROM ContentVersion WHERE ContentDocumentId = :files[0].Id AND Title = :fileName AND IsLatest = true];
            if(String.isBlank(version.Estado__c) && String.isBlank(version.Id_Documento_Proveedor__c)){
                delete files;
            }else{
                throw new AuraHandledException('Este archivo ya se envió para firmar, no se puede generar nuevamente');
            }
        }
        createFiles(new List<PagePDF>{pdf});
    }

    private static void generarPDFLicencia(Licencia__c licencia, Account obtentor, Boolean isPdfComercio) {
        Pagereference ref = getPDFRef(obtentor.N_CUIT__c, isPdfComercio);
        PagePDF pdf = new PagePDF(ref, licencia.Name + '-Licencia', licencia.id, new List<Id>{/*licencia.Cuenta_Productor__c*/UserInfo.getUserId()});

        pdf.reference.getParameters().put('licencia', PDFLicenciaController.serializeLicencia(licencia.id));

        List<NetworkMember> users = [SELECT Id FROM NetworkMember WHERE MemberId =: UserInfo.getUserId() and NetworkId =: Network.getNetworkId()];
        setNetMemberFeedsEmail(users, true);

        createFiles(new List<PagePDF>{pdf});

        setNetMemberFeedsEmail(users, false);
    }

    private static PageReference getPDFRef(String cuit, Boolean isPdfComercio){
        PageReference ref;
        switch on cuit {
            when '30616275905' {
                ref = isPdfComercio ? Page.pdfLicenciaComercioGDM : Page.pdfLicencia;
            }
            when '30646328450' {
                //ref = isPdfComercio ? Page.pdfLicenciaComercioSyngenta : Page.pdfLicenciaSyng;
                ref = isPdfComercio ? Page.pdfLicenciaSyng : Page.pdfLicenciaSyng;
            }
            when '30707285563' {
                ref = isPdfComercio ? Page.pdfLicenciaMacroseed : Page.pdfLicenciaMacroseed;
            }
            when '33710831659' {
                ref = isPdfComercio ? Page.pdfLicenciaBioceres : Page.pdfLicenciaBioceres;
            }
            when '30517486678' {
                ref = isPdfComercio ? Page.pdfLicenciaComercioBasf : Page.pdfLicenciaBasf;
            }
        }
        return ref;
    }

    public static void generarPDFCartaAceptacion(List<Licencia__c> licencias) {
        //generar carta de aceptacion?
        //https://www.simplysfdc.com/2022/02/salesforce-file-privacy-on-records.html

        List<PagePDF> pdfs = new List<PagePDF>();

        for (Licencia__c licencia: licencias) {
            Boolean esInterno = licencia.Origen_SGL__c == false && String.isBlank(licencia.Origen__c);
            PagePDF pdf = new PagePDF(Page.pdfCartaAceptacion, licencia.Name + '-Carta de Aceptacion', licencia.id, new List<Id>{/*licencia.Cuenta_Obtentor__c*/}, esInterno);
            pdf.reference.getParameters().put('licencia', PDFLicenciaController.serializeLicencia(licencia.id));
            pdfs.add(pdf);
        }

        createFiles(pdfs);
    }

    public static Map<String, ContentDocumentLink> getLicenciaFiles(Id licenciaId) {
        Map<String, ContentDocumentLink> documents = new Map<String, ContentDocumentLink>();

        for(ContentDocumentLink doc: [select ContentDocument.Title, ContentDocument.Id from ContentDocumentLink where LinkedEntityId =: licenciaId]) {
            documents.put(doc.ContentDocument.Title, doc);
        }

        return documents;
    }

    public static User usuarioInterface {
        get {
            if (usuarioInterface == null) {
                usuarioInterface = [select id from user where profile.PermissionsCustomizeApplication = true and isActive = true and name = 'Usuario Interface' limit 1];
            }
            return usuarioInterface;
        }
        set;
    }

    public static List<ContentDocumentLink> getFiles(Licencia__c licencia) {
        return getLicenciaFiles(licencia.id).values();
    }

    @AuraEnabled
    public static void deleteFile(Id fileId, Id licenciaId) {
        Licencia__c licencia = [select id from Licencia__c where id =: licenciaId and (Cuenta_Productor__c =: CrearCompraController.getAccount().id or Cuenta_Distribuidor__c =: CrearCompraController.getAccount().id) and Origen__c = 'Portal']; //por seguridad valido que la licencia le pertenece
        ContentDocumentLink link = [select ContentDocument.Id from ContentDocumentLink where LinkedEntityId =: licenciaId and ContentDocument.Id =: fileId];
        delete link.ContentDocument;
    }

    @AuraEnabled
    public static Licencia__c enviar(Id licenciaId) {
        Licencia__c licencia;
        try {
            Id accountId = CrearCompraController.getAccount().Id;
            licencia = [select Firmante_Cuit__c, Metodo_firma__c, Name, Estado__c, Cuenta_Productor__r.N_CUIT__c, CreatedById from Licencia__c where id =: licenciaId and (Cuenta_Productor__c =: accountId or Cuenta_Distribuidor__c =: accountId or Cuenta_Obtentor__c = :accountId) and Origen__c = 'Portal'];
        } catch (Exception e) {
            throw new AuraHandledException('La licencia y sus archivos deben ser enviados por el productor, comercio u obtentor intervinientes');
        }

        if (licencia.Estado__c != 'Creada') throw new AuraHandledException('El estado de la licencia debe ser creada');
        validateFiles(licencia);

        Boolean validada = licencia.Metodo_firma__c == 'Electronica' && !needsPoder(licencia.Cuenta_Productor__r.N_CUIT__c, licencia.Firmante_Cuit__c);
        
        if (validada) licencia.Fecha_Validacion__c = system.today();
        licencia.Estado__c = validada ? 'Validada' : 'A validar'; // holografica => a validar. electronica y no necesita poder => validada
        
        update licencia;

        return licencia;
    }

    private static Boolean needsPoder(String cuit, String cuitFirmante) {
        return isPersonaJuridica(cuit) && cuit != cuitFirmante;
    }

    private static Boolean isPersonaJuridica(String cuit) {
        return cuit.startsWith('2') == false;
    }

    private static void validateFiles(Licencia__c licencia) {
        Map<String, ContentDocumentLink> files = getLicenciaFiles(licencia.id);

        if (licencia.Metodo_firma__c == 'Holografica' && files.containsKey(licencia.Name + '-Licencia-Firmada') == false) throw new AuraHandledException('Debes subir la licencia firmada');
        if (licencia.Metodo_firma__c == 'Electronica'){
            if(needsPoder(licencia.Cuenta_Productor__r.N_CUIT__c, licencia.Firmante_Cuit__c) && files.containsKey(licencia.Name + '-Poder') == false) throw new AuraHandledException('Debes subir el poder');
            if(needsResolucionSucesion(licencia) && files.containsKey(licencia.Name + '-Poder / Resolucion Judicial de Sucesion') == false) throw new AuraHandledException('Debes subir la resolución judicial de Sucesion');
        }
        
        if (licencia.Metodo_firma__c == 'Holografica' || Test.isRunningTest()) {
            Set<String> fileNames = files.keySet();

            fileNames.remove(licencia.Name + '-Licencia');
            fileNames.remove(licencia.Name + '-Licencia-Firmada');
            fileNames.remove(licencia.Name + '-Poder');
            fileNames.remove(licencia.Name + '-Carta de Aceptacion');
            
            if(isPersonaJuridica(licencia.Cuenta_Productor__r.N_CUIT__c) || licencia.Cuenta_Productor__r.N_CUIT__c != licencia.Firmante_Cuit__c){
                //if(fileNames.isEmpty() && !Test.isRunningTest()) throw new AuraHandledException('La certificación de firma es obligatoria');
            }else{
                if(fileNames.contains(licencia.Name + '-Frente DNI') == false) throw new AuraHandledException('El frente del DNI es obligatorio');
                if(fileNames.contains(licencia.Name + '-Dorso DNI') == false) throw new AuraHandledException('El dorso del DNI es obligatorio');
                if(fileNames.contains(licencia.Name + '-Constancia AFIP') == false) throw new AuraHandledException('La constancia de AFIP es obligatoria');
            }
        }
    }

    private static Boolean needsResolucionSucesion(Licencia__c licencia){
        return isPersonaJuridica(licencia.Cuenta_Productor__r.N_CUIT__c) == false && licencia.Cuenta_Productor__r.N_CUIT__c != licencia.Firmante_Cuit__c;
    }

    @AuraEnabled
    public static void renameFiles(List<Id> fileIds, Id licenciaId, String name) {
        try {
            Id accountId = CrearCompraController.getAccount().Id;
            Licencia__c licencia = [select id from Licencia__c where id =: licenciaId and (Cuenta_Productor__c =: accountId or Cuenta_Distribuidor__c =: accountId or Cuenta_Obtentor__c = :accountId) and Origen__c = 'Portal'];     
        } catch (Exception e) {
            throw new AuraHandledException('Los archivos de la licencia deben ser cargados por el productor, comercio u obtentor intervinientes');
        }

        List<ContentDocument> docs = new List<ContentDocument>();

        for (ContentDocumentLink link: [select ContentDocument.Id from ContentDocumentLink where LinkedEntityId =: licenciaId and ContentDocument.Id in: fileIds]) {
            docs.add(new ContentDocument(Id = link.ContentDocument.Id, Title = name));
        }

        update docs;
    }

    private static void createFiles(List<PagePDF> pdfs) {
        List<ContentVersion> contentDocuments = new List<ContentVersion>();

        for (PagePDF pdf: pdfs) {
            contentDocuments.add(pdf.createContentVersion());
        }

        insert contentDocuments;

        Map<Id, Id> versionToDocId = new Map<Id, Id>(); 

        for (ContentVersion version: [select contentdocumentid from contentversion where id in: contentDocuments]) {
            versionToDocId.put(version.id, version.contentdocumentid);
        }

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();

        for (PagePDF pdf: pdfs) {
            links.addAll(pdf.createContentDocumentLinks(versionToDocId.get(pdf.content.id)));
        }

        insert links;
    }

    private static void setNetMemberFeedsEmail(List<NetworkMember> users, Boolean value){
        for(NetworkMember user : users){
            user.PreferencesDisableAllFeedsEmail = value;
        }

        update users;
    }

    @AuraEnabled (cacheable=true)
    public static String getUrl(){
        Organization org = [SELECT IsSandbox FROM Organization];
        String entorno;
        if (org.IsSandbox) {
            entorno = 'Sandbox';
        } else {
            entorno = 'Prod';
        }

        Parametro_Portal_Licencias__mdt licParam = Parametro_Portal_Licencias__mdt.getInstance(entorno);

        return licParam.url__c;
    }


    @testVisible
    private static Data getTestData(Id marca, String cuil) {
        Data data = new Data();

        data.email = 'test@test.com';
        data.tecnologia = 'RR';
        data.firma = 'Electronica';
        data.nombre = 'test';
        data.apellido = 'test';
        data.celular = '11111111';
        data.cuil = cuil;
        data.cargo = 'Manager';
        data.marca = marca;
        data.licenceType = 'Productor';

        return Data;
    }

    @TestVisible
    private class Data {
        String email;
        String tecnologia;
        Id marca;
        String firma;
        String nombre;
        String apellido;
        String celular;
        String cuil;
        String cargo;
        String localidad;
        String direccion;
        String provincia;
        String codigoPostal;
        Id id;
        Id tercero;
        String licenceType;
    }

    private class PagePDF {
        Pagereference reference;
        String fileName;
        Id licenciaId;
        List<ID> accountsToShare;
        private ContentVersion content = new ContentVersion();
        private Boolean esInterno;
        
        PagePDF(Pagereference reference, String fileName, Id licenciaId, List<Id> accountsToShare) {
            this.reference = reference;
            this.fileName = fileName;
            this.licenciaId = licenciaId;
            this.accountsToShare = accountsToShare;
            this.esInterno = false;
        }

        PagePDF(Pagereference reference, String fileName, Id licenciaId, List<Id> accountsToShare, Boolean esInterno) {
            this.reference = reference;
            this.fileName = fileName;
            this.licenciaId = licenciaId;
            this.accountsToShare = accountsToShare;
            this.esInterno = esInterno;
        }

        public ContentVersion createContentVersion() {
            content.Title = fileName; 
            content.VersionData = Test.isRunningTest() ? Blob.valueOf('test') : reference.getContent();
            content.PathOnClient = fileName + '.pdf';
            if(this.esInterno == false) content.Estado__c = 'Solicitado';
            //content.SharingPrivacy = 'P'; //por ahora que lo vean todos, cuando se quejen vemos
            content.OwnerId = usuarioInterface.id;
            content.FirstPublishLocationId = licenciaId;

            return content;
        }

        public List<ContentDocumentLink> createContentDocumentLinks(Id contentDocumentId) {
            List<ContentDocumentLink> documentLinks = new List<ContentDocumentLink>();

            /*ContentDocumentLink recordLink = new ContentDocumentLink();
            recordLink.LinkedEntityId = licenciaId;
            recordLink.contentdocumentid = contentDocumentId;
            documentLinks.add(recordLink);*/

            for (Id accountId: accountsToShare) {
                ContentDocumentLink accountLink = new ContentDocumentLink();
                accountLink.LinkedEntityId = accountId;
                accountLink.contentdocumentid = contentDocumentId;
                accountLink.ShareType = 'V';
                accountLink.Visibility = 'AllUsers';
                documentLinks.add(accountLink);
            }

            return documentLinks;
        }
    }
}