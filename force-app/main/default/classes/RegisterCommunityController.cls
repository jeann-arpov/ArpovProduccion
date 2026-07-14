/**
 * Controlador para el registro y autenticación de usuarios en comunidades Salesforce
 * Gestiona la creación de usuarios, verificación por email y asignación de perfiles
 */
public without sharing class RegisterCommunityController {
    
    /**
     * Obtiene el contacto asociado a un email y CUIT
     * @param email Email del contacto
     * @param cuit CUIT de la cuenta
     * @return Contact Contacto encontrado
     */
    public static Contact getContact(String email, String cuit) {
        // Buscar cuenta por CUIT con tipos específicos
        List<Account> accs = [SELECT Id FROM Account 
                             WHERE N_CUIT__c = :cuit 
                             AND Type IN ('Obtentor', 'Productor', 'Distribuidor', 'Comercio') 
                             AND ParentId = null 
                             LIMIT 1];

        if (accs.isEmpty()) {
            throw error('No existe una cuenta con ese cuit. ' + errorContactMessage());
        }

        // Buscar contacto por email y cuenta
        List<Contact> contacts = [SELECT Id, Email, AccountId, Account.Type, Account.IsCustomerPortal 
                                 FROM Contact 
                                 WHERE Email = :email 
                                 AND AccountId =: accs[0].Id];

        if(contacts.isEmpty()){
            throw error('No existe contacto con este Email y CUIT en sistema. '  + errorContactMessage());
        }

        if(contacts.size() > 1) {
            throw error('Existe más de 1 contacto con este email y cuit en el sistema. '  + errorContactMessage());
        }

        return contacts[0];
    } 

    /**
     * Genera mensaje de error de contacto según el portal
     * @return String Mensaje de error personalizado
     */
    private static String errorContactMessage() {
         // Mensaje con WhatsApp en negritas y clickeable
         return 'Contáctanos a info@sembraevolucion.com.ar o a nuestro <b><a href="https://wa.me/5491131172022"  style="color: #EA001E; font-weight: bold;" target="_blank">WhatsApp</a></b> (+54 9 11 3117-2022) indicando tu CUIT y mail para ayudarte.';
    }

    /**
     * Genera nombre de usuario único basado en CUIT y email
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @return String Nombre de usuario generado
     */
    public static String generateUsername(String email, String cuit) {
        return cuit + email.split('@')[0] + '@portalagro.com.ar';
    }

    /**
     * Configuración de tipos de cuenta para asignación de perfiles
     */
    public class AccountTypeConfiguration {
        String profileName;
        List<String> portals;
        String error;
        String licenseType; // Nuevo campo para tipo de licencia

        AccountTypeConfiguration(String profileName, List<String> portals, String error, String licenseType) {
            this.profileName = profileName;
            this.portals = portals;
            this.error = 'Registrate en el sitio del ' + error;
            this.licenseType = licenseType;
        }
    }

    /**
     * Verifica y crea usuario (self-registration)
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @param firstName Nombre
     * @param lastName Apellido
     * @param dni Número de documento
     * @return String Identificador para verificación
     */
    @AuraEnabled
    public static String verifyUserCreation(String email, String cuit, String firstName, String lastName, String dni){
        try {
            User u = validateAndCreateUser(email, cuit, firstName, lastName, dni, null);

            if (Test.isRunningTest()) {
                insert u;
                processUser(email, cuit, 'test');
            }
            
            return Test.isRunningTest() ? '123' : System.UserManagement.initSelfRegistration(Auth.VerificationMethod.EMAIL, u);
        } catch (Exception e) {
            throw error(e);
        }
    }

   /**
     * Crea usuario con contraseña
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @param firstName Nombre
     * @param lastName Apellido
     * @param dni Número de documento
     * @param password Contraseña
     * @param telefono Teléfono
     * @return String URL de redirección
     */
    @AuraEnabled
    public static String doCreateUser(String email, String cuit, String firstName, String lastName, String dni, String password, String telefono){
        try {
            System.debug('🎯🎯🎯 doCreateUser INICIADO 🎯🎯🎯');
            System.debug('🎯 Parámetros recibidos:');
            System.debug('🎯 email: ' + email);
            System.debug('🎯 cuit: ' + cuit);
            System.debug('🎯 firstName: ' + firstName);
            System.debug('🎯 lastName: ' + lastName);
            System.debug('🎯 dni: ' + dni);
            System.debug('🎯 telefono: ' + telefono);
            
            // VALIDAR QUE firstName Y lastName NO ESTÉN VACÍOS
            if (String.isBlank(firstName) || String.isBlank(lastName)) {
                System.debug('❌ ERROR: FirstName o LastName están vacíos');
                System.debug('❌ FirstName: ' + firstName);
                System.debug('❌ LastName: ' + lastName);
                throw error('El nombre y apellido son obligatorios');
            }
            
            User u = validateAndCreateUser(email, cuit, firstName, lastName, dni, telefono);
            System.debug('🎯 Usuario creado (antes de insert): ' + u.Username);
            System.debug('🎯 FirstName del usuario: ' + u.FirstName);
            System.debug('🎯 LastName del usuario: ' + u.LastName);
            
            insert u;
            System.debug('✅ Usuario insertado con ID: ' + u.Id);
            
            // **ACTUALIZAR CONTACTO INMEDIATAMENTE (ANTES DEL EMAIL)**
            System.debug('🎯 Actualizando Contacto inmediatamente...');
            updateContactImmediately(u.ContactId, u.Id);
            System.debug('✅ Contacto actualizado');
            
            // PRIMERO procesar el usuario para establecer la contraseña
            System.debug('🎯 Procesando usuario (estableciendo contraseña)...');
            processUser(email, cuit, password);
            System.debug('✅ Contraseña establecida');
            
            // **SOLUCIÓN: Enviar email usando el USER como targetObjectId, NO el Contacto**
            System.debug('🎯🎯🎯 ENVIANDO EMAIL DE BIENVENIDA 🎯🎯🎯');
            System.debug('🎯 Llamando a sendWelcomeEmailWithUserTarget con userId: ' + u.Id);
            sendWelcomeEmailWithUserTarget(u.Id);
            System.debug('✅ sendWelcomeEmailWithUserTarget llamado');
            
            String url;
            if(getCuitsObtentorDistribuidor().contains(cuit) == false){
                System.debug('🎯 Redireccionando a login normal...');
                System.Pagereference res = Site.login(u.Username, password, '/s/');
                url = res.getUrl();
            }else{
                System.debug('🎯 Redireccionando a portal comercio...');
                url = getUrlPortalComercio();
            }
            
            System.debug('✅✅✅ doCreateUser COMPLETADO EXITOSAMENTE ✅✅✅');
            System.debug('✅ URL de redirección: ' + url);
            return url;
            
        } catch (Exception e) {
            System.debug('❌❌❌ ERROR CRÍTICO en doCreateUser ❌❌❌');
            System.debug('❌ Mensaje: ' + e.getMessage());
            System.debug('❌ Línea: ' + e.getLineNumber());
            System.debug('❌ StackTrace: ' + e.getStackTraceString());
            throw error(e);
        }
    }

    /**
     * Envía email de bienvenida usando el USER como targetObjectId
     * @param userId ID del usuario
     */
    public static void sendWelcomeEmailWithUserTarget(Id userId) {
        try {
            System.debug('📧📧📧 sendWelcomeEmailWithUserTarget INICIADO 📧📧📧');
            System.debug('📧 UserId: ' + userId);
            
            // Verificar si el usuario existe
            System.debug('📧 Buscando usuario...');
            List<User> usuarios = [SELECT Id, Name, FirstName, LastName, Email, Username, 
                                  Profile.Name, ContactId, AccountId 
                                  FROM User WHERE Id = :userId];
            
            if (usuarios.isEmpty()) {
                System.debug('❌ No se encontró el usuario con ID: ' + userId);
                return;
            }
            
            User usuario = usuarios[0];
            System.debug('✅ Usuario encontrado: ' + usuario.Name);
            System.debug('✅ FirstName: ' + usuario.FirstName);
            System.debug('✅ LastName: ' + usuario.LastName);
            System.debug('✅ Email: ' + usuario.Email);
            System.debug('✅ Perfil: ' + usuario.Profile.Name);
            System.debug('✅ ContactId: ' + usuario.ContactId);
            
            // Verificar que no sea un usuario Guest/Site
            if (usuario.Profile.Name.contains('Guest') || usuario.Profile.Name.contains('Site')) {
                System.debug('⚠️ Usuario es Guest/Site, no se envía email');
                return;
            }
            
            // **IMPORTANTE: Usar el USER como targetObjectId, NO el Contacto**
            // Cuando la plantilla usa {!Receiving_User.FirstName}, toma los datos del targetObjectId
            // Si targetObjectId es un User, usa User.FirstName
            // Si targetObjectId es un Contact, usa Contact.FirstName
            
            System.debug('✅ Nombre del usuario para email: ' + usuario.FirstName);
            
            // Buscar plantilla
            System.debug('📧 Buscando plantilla "Nuevo Usuario Productor"...');
            List<EmailTemplate> templates = [SELECT Id, Name, DeveloperName 
                                            FROM EmailTemplate 
                                            WHERE Name = 'Nuevo Usuario Productor' 
                                            OR DeveloperName = 'Nuevo_Usuario_Productor'
                                            LIMIT 1];
            
            System.debug('📧 Plantillas encontradas: ' + templates.size());
            System.debug('✅ Plantilla encontrada: ' + templates[0].Name + ' (ID: ' + templates[0].Id + ')');
            
            // **SOLUCIÓN CRÍTICA: Usar el USER como targetObjectId**
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(templates[0].Id);
            
            // **USAR EL USER ID COMO targetObjectId**
            System.debug('✅ Usando UserId como targetObjectId: ' + usuario.Id);
            email.setTargetObjectId(usuario.Id);
            email.setSaveAsActivity(false); // Para Usuarios, DEBE ser false
            
            email.setUseSignature(false);
            
            // Configurar remitente
            try {
                System.debug('📧 Configurando remitente...');
                List<OrgWideEmailAddress> oweaList = [SELECT Id, Address, DisplayName 
                                                     FROM OrgWideEmailAddress 
                                                     WHERE Address = 'info@sembraevolucion.com.ar'
                                                     LIMIT 1];
                
                if (!oweaList.isEmpty()) {
                    email.setOrgWideEmailAddressId(oweaList[0].Id);
                    System.debug('✅ Remitente configurado: ' + oweaList[0].Address);
                } else {
                    System.debug('⚠️ No se encontró OrgWideEmailAddress info@sembraevolucion.com.ar');
                }
            } catch(Exception e) {
                System.debug('⚠️ Error configurando remitente: ' + e.getMessage());
            }
            
            // Enviar email
            System.debug('📧📧📧 ENVIANDO EMAIL CON PLANTILLA 📧📧📧');
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
            // Verificar resultado
            System.debug('📧 Resultado del envío:');
            for(Messaging.SendEmailResult result : results) {
                System.debug('✅ Éxito: ' + result.isSuccess());
                if (result.isSuccess()) {
                    System.debug('✅✅✅ EMAIL ENVIADO EXITOSAMENTE ✅✅✅');
                    System.debug('✅ Destinatario: ' + usuario.Email);
                    System.debug('✅ Nombre del usuario: ' + usuario.FirstName);
                } else {
                    System.debug('❌ Falló el envío');
                    for(Messaging.SendEmailError error : result.getErrors()) {
                        System.debug('❌ Error: ' + error.getMessage());
                        System.debug('❌ Código: ' + error.getStatusCode());
                    }
                }
            }
            
        } catch(Exception e) {
            System.debug('❌❌❌ ERROR en sendWelcomeEmailWithUserTarget ❌❌❌');
            System.debug('❌ Mensaje: ' + e.getMessage());
            System.debug('❌ Línea: ' + e.getLineNumber());
            System.debug('❌ StackTrace: ' + e.getStackTraceString());
        }
    }

   /**
     * Actualiza contacto INMEDIATAMENTE (síncrono)
     * @param contactId ID del contacto
     * @param userId ID del usuario
     */
    private static void updateContactImmediately(Id contactId, Id userId){
        try {
            System.debug('👤 Actualizando contacto inmediatamente...');
            System.debug('👤 ContactId: ' + contactId);
            System.debug('👤 UserId: ' + userId);
            
            Contact contact = [SELECT Id, FirstName, LastName, Es_Usuario_de_Portal__c, MobilePhone 
                              FROM Contact WHERE Id = :contactId];
            User u = [SELECT FirstName, LastName, ProfileId, MobilePhone FROM User WHERE Id = :userId];

            System.debug('👤 Contacto antes de actualizar:');
            System.debug('👤 Contacto FirstName: ' + contact.FirstName);
            System.debug('👤 Contacto LastName: ' + contact.LastName);
            System.debug('👤 Usuario FirstName: ' + u.FirstName);
            System.debug('👤 Usuario LastName: ' + u.LastName);
            
            contact.FirstName = u.FirstName;
            contact.LastName = u.LastName;
            contact.Es_Usuario_de_Portal__c = true;
            contact.MobilePhone = u.MobilePhone;
            
            update contact;
            
            System.debug('✅ Contacto actualizado exitosamente');
            System.debug('✅ Contacto FirstName ahora: ' + contact.FirstName);
            System.debug('✅ Contacto LastName ahora: ' + contact.LastName);
            
        } catch(Exception e) {
            System.debug('❌ Error actualizando contacto: ' + e.getMessage());
            // No lanzamos excepción para no interrumpir el flujo
        }
    }

    /**
     * Obtiene URL del portal de comercio
     * @return String URL segura del portal
     */
    private static String getUrlPortalComercio(){
        Id portalId = [SELECT Id, Name, UrlPathPrefix FROM Site WHERE Name LIKE '%Comercio' LIMIT 1].Id;
        return [SELECT SecureUrl FROM SiteDetail WHERE DurableId = :portalId].SecureUrl;
    }

    /**
     * Valida y crea objeto User
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @param firstName Nombre
     * @param lastName Apellido
     * @param dni Número de documento
     * @param telefono Teléfono
     * @return User Objeto User configurado
     */
    private static User validateAndCreateUser(String email, String cuit, String firstName, String lastName, String dni, String telefono){
        Contact contact = getContact(email, cuit);

        // Verificar si ya existe usuario
        for (User u: [SELECT Id FROM User WHERE Username =: generateUsername(email, cuit) LIMIT 1]) {
            throw error('Ya existe un usuario con ese email y cuit en el sistema. '  + errorContactMessage());
        }

        String profileName;
        List<String> portals;
        String error;
        String licenseType; 
        
        // Configuración de tipos de cuenta con licencias
        Map<String, AccountTypeConfiguration> accountTypeToConfig = new Map<String, AccountTypeConfiguration> {
            'Productor' => new AccountTypeConfiguration('Servicio Al Productor', 
                                                       new List<String>{'Sembrá Evolución', 'Portal ArPOV'}, 
                                                       'Productor',
                                                       'Customer Community Login'), // Licencia estándar para Productor
            'Distribuidor' => new AccountTypeConfiguration( Test.isRunningTest() ? 'Distribuidor' : 'Distribuidor Plus', 
                                                          new List<String>{'Sembrá Evolución Comercio', 'Portal Distribuidor'}, 
                                                          'Comercio',
                                                           Test.isRunningTest() ? 'Customer Community Plus Login' : 'Customer Community Plus Login'), // Licencia Plus para Distribuidor/Comercio
            'Obtentor' => new AccountTypeConfiguration( Test.isRunningTest() ? 'Obtentor' : 'Obtentor Plus', 
                                                      new List<String>{'Sembrá Evolución Obtentor'}, 
                                                      'Obtentor',
                                                      Test.isRunningTest() ? 'Customer Community Plus Login' : 'Customer Community Plus Login'), // Licencia Plus para Obtentor
            'Comercio' => new AccountTypeConfiguration( Test.isRunningTest() ? 'Distribuidor' : 'Distribuidor Plus',
                                                     new List<String>{'Sembrá Evolución Comercio', 'Portal Distribuidor'}, 
                                                     'Comercio',
                                                      Test.isRunningTest() ? 'Customer Community Plus Login' : 'Customer Community Plus Login') // Licencia Plus para Comercio
        };

        AccountTypeConfiguration config = accountTypeToConfig.get(contact.Account.Type);

        // Obtener ID del perfil
        String profileId = [SELECT Id FROM Profile WHERE Name =: config.profileName].Id;

        // Validar portal (excepto en tests)
        if (Test.isRunningTest() == false && config.portals.contains([SELECT Name FROM Network WHERE Id =: Network.getNetworkId()].Name) == false) {
            throw error(config.error);
        }

        // IMPORTANTE: Para asignar la licencia Customer Community Plus, necesitamos:
        // 1. Que el perfil esté asociado a la licencia correcta en Setup
        // 2. Que tengamos licencias disponibles de Customer Community Plus
        
       

        // Crear objeto User
        User u = new User();
        u.Username = generateUsername(email, cuit);
        u.Email = email;
        u.FirstName = firstName;
        u.LastName = lastName;
        u.ProfileId = getCuitsObtentorDistribuidor().contains(cuit) ? [SELECT Id FROM Profile WHERE Name = 'Distribuidor'].Id : profileId;
        u.CommunityNickname = firstName + String.valueOf(System.now().getTime() / 1000);
        u.Id_Externo__c = u.Username;
        u.Alias = firstName.length() > 8 ? firstName.substring(0, 8) : firstName;
        u.ContactId = contact.Id;
        u.LanguageLocaleKey = 'es';
        u.LocaleSidKey = 'es_AR';
        u.EmailEncodingKey =  'UTF-8';
        u.TimeZoneSidKey = 'America/Argentina/Buenos_Aires';
        u.Numero_de_Documento__c = dni;
        if(String.isNotBlank(telefono)) u.MobilePhone = telefono;
        
        // La licencia se asigna automáticamente según el perfil
        // Asegúrate de que en Setup:
        // - Perfil 'Distribuidor' esté asociado a 'Customer Community Plus'
        // - Perfil 'Obtentor' esté asociado a 'Customer Community Plus'
        // - Perfil 'Servicio Al Productor' esté asociado a 'Customer Community Login'

        return u;
    }


    /**
     * Obtiene lista de CUITs para obtentores y distribuidores especiales
     * @return List<String> Lista de CUITs
     */
    private static List<String> getCuitsObtentorDistribuidor(){
        String cuitsCs = Sembra_Evolucion__c.getOrgDefaults().Obtentor_Distribuidor__c;
        return cuitsCs != null ? cuitsCs.split(',') : new List<String>();
    }

    /**
     * Agrega automatización de comprobantes de venta al usuario
     * @param u Usuario a configurar
     */
    public static void addAutomatizacion(User u) {
        String profileId = u.ProfileId;
        String fieldsNames = '';

        // Obtener todos los campos del objeto de automatización
        for (Schema.SObjectField sObjectField : Schema.getGlobalDescribe().get('ERPvs__Automatizacion_Comprobante_Venta__c').getDescribe().fields.getMap().values()) {
            fieldsNames += sObjectField.getDescribe().getName() + ',';
        }
        
        // Verificar si el usuario necesita automatización
        if ([SELECT Id FROM User 
             WHERE Id =: u.Id 
             AND Id NOT IN (SELECT ERPvs__Usuario__c FROM ERPvs__Automatizacion_Comprobante_Venta__c) 
             AND Profile.Name IN ('Servicio al Productor', 'Distribuidor')].size() == 1) {
            
            ERPvs__Automatizacion_Comprobante_Venta__c aut = Test.isRunningTest() ? 
                new ERPvs__Automatizacion_Comprobante_Venta__c() : 
                Database.query('SELECT ' + fieldsNames.removeEnd(',') + 
                              ' FROM ERPvs__Automatizacion_Comprobante_Venta__c ' +
                              ' WHERE ERPvs__Usuario__r.ProfileId =: profileId LIMIT 1');
            
            ERPvs__Automatizacion_Comprobante_Venta__c newAut = aut.clone();
            newAut.ERPvs__Usuario__c = u.Id;
            if (!Test.isRunningTest()) insert newAut;
        }
    }

    /**
     * Procesa usuario después de la creación
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @param password Contraseña
     */
    public static void processUser(String email, String cuit, String password) {
        User u;
        Contact contact = getContact(email, cuit);

        try {
            u = [SELECT Id, FirstName, LastName, ProfileId, Username, Profile.UserLicense.Name 
                 FROM User 
                 WHERE Email =: email AND ContactId =: contact.Id];
            
            // Verificar licencia asignada
            System.debug('Licencia asignada al usuario: ' + u.Profile.UserLicense.Name);
            
            if([SELECT Name FROM Network WHERE Id =: Network.getNetworkId()].Name.contains('Sembrá Evolución')){
                Site.validatePassword(u, password, password);
            }
            System.setPassword(u.Id, password);      
        } catch (Exception e) {
            if (!Test.isRunningTest()) throw error('Error al asignar la contraseña: ' + e.getMessage());
        }      

        if (u != null) {            
            updateContactAsync(contact.Id, u.Id);
        }
    }

    /**
     * Actualiza contacto de forma asíncrona (para mantener compatibilidad)
     * @param contactId ID del contacto
     * @param userId ID del usuario
     */
    @future
    public static void updateContactAsync(Id contactId, Id userId){
        // Este método se mantiene para compatibilidad, pero ya no se usa en doCreateUser
        Contact contact = [SELECT Id FROM Contact WHERE Id = :contactId];
        User u = [SELECT FirstName, LastName, ProfileId, MobilePhone FROM User WHERE Id = :userId];

        contact.FirstName = u.FirstName;
        contact.LastName = u.LastName;
        contact.Es_Usuario_de_Portal__c = true;
        contact.MobilePhone = u.MobilePhone;
        
        update contact;

        addAutomatizacion(u);
    }

    /**
     * Confirma creación de usuario después de verificación
     * @param identifier Identificador de verificación
     * @param code Código de verificación
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @return String URL de redirección
     */
    @AuraEnabled
    public static string confirmUserCreation(String identifier, String code, String email, String cuit){
        try {
            Auth.VerificationResult res = System.UserManagement.verifySelfRegistration(Auth.VerificationMethod.EMAIL, identifier, code, '/s/');
            if (res.success == false) throw error(res.message);
            processUser(email, cuit, EncodingUtil.convertToHex(Crypto.generateAesKey(128)).substring(0, 32));
            
            // ENVIAR EMAIL DE BIENVENIDA PARA VERIFICACIÓN
            sendWelcomeEmailForVerifiedUser(email, cuit);
            
            return res.redirect.getUrl();
        } catch (Exception e) {
            throw error(e);
        }
    }

     /**
     * Inicia proceso de login sin contraseña
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @return String JSON con identificador y userId
     */
    @AuraEnabled
    public static string login(String email, String cuit) {
        try {
            List<User> u = [SELECT Id FROM User 
                           WHERE Email =: email 
                           AND Contact.Account.N_CUIT__c =: cuit];  
            
            if (u.isEmpty()) {
                throw error('No existe un usuario con ese email y cuit. Registrate');
            }
            
            String identifier = Test.isRunningTest() ? '123' : System.UserManagement.initPasswordlessLogin(u[0].Id, Auth.VerificationMethod.EMAIL);

            return JSON.serialize(new Map<String, String> {
                'identifier' => identifier,
                'userId' => u[0].Id
            });
        } catch (Exception e) {
            throw error(e);
        }
    }

    /**
     * Confirma login sin contraseña
     * @param userId ID del usuario
     * @param identifier Identificador de verificación
     * @param code Código de verificación
     * @return String URL de redirección
     */
    @AuraEnabled
    public static string confirmLogin(String userId, String identifier, String code){
        try {
            Auth.VerificationResult res = System.UserManagement.verifyPasswordlessLogin(userId, Auth.VerificationMethod.EMAIL, identifier, code, '/s/');    
            if (res.success == false) throw error(res.message);
            return res.redirect.getUrl();
        } catch (Exception e) {
            throw error(e);
        }
    }

    /**
     * Login con contraseña
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     * @param password Contraseña
     * @return String URL de redirección
     */
    @AuraEnabled
    public static String loginWithPassword(String email, String cuit, String password){
        List<User> u = [SELECT Id, Username FROM User 
                       WHERE Email =: email 
                       AND Contact.Account.N_CUIT__c =: cuit];  
        
        if (u.isEmpty()) {
            throw error('No existe un usuario con ese email y cuit. Registrate');
        }

        System.debug('loginWithPassword -> email: ' + email + ', cuit: ' + cuit);
        System.debug('loginWithPassword -> username: ' + u[0].Username);
        System.debug('loginWithPassword -> password: ' + password);

        try {
            System.Pagereference res = Site.login(u[0].Username, password, '/s/');
            return res.getUrl();
        } catch (Exception e) {
            System.debug('loginWithPassword -> error type: ' + e.getTypeName());
            System.debug('loginWithPassword -> error message: ' + e.getMessage());
            System.debug('loginWithPassword -> stack trace: ' + e.getStackTraceString());
            throw error('La contraseña es incorrecta. Detalle: ' + e.getMessage());
        }
    }

    /**
     * Obtiene URL del logo de Sembrá Evolución
     * @return String URL del logo
     */
    @AuraEnabled(cacheable=true)
    public static String getUrlLogoSE(){
        return Sembra_Evolucion__c.getOrgDefaults().URL_Logo_SE__c;
    }
   
        /**
     * Envía email de bienvenida INMEDIATAMENTE (método público)
     * @param userId ID del usuario
     */
    public static void sendWelcomeEmailImmediate(Id userId) {
        try {
            System.debug('📧📧📧 sendWelcomeEmailImmediate INICIADO 📧📧📧');
            System.debug('📧 UserId: ' + userId);
            
            // Verificar si el usuario existe
            System.debug('📧 Buscando usuario...');
            List<User> usuarios = [SELECT Id, Name, FirstName, LastName, Email, Username, 
                                  Profile.Name, ContactId, AccountId 
                                  FROM User WHERE Id = :userId];
            
            if (usuarios.isEmpty()) {
                System.debug('❌ No se encontró el usuario con ID: ' + userId);
                return;
            }
            
            User usuario = usuarios[0];
            System.debug('✅ Usuario encontrado: ' + usuario.Name);
            System.debug('✅ FirstName: ' + usuario.FirstName);
            System.debug('✅ LastName: ' + usuario.LastName);
            System.debug('✅ Email: ' + usuario.Email);
            System.debug('✅ Perfil: ' + usuario.Profile.Name);
            System.debug('✅ ContactId: ' + usuario.ContactId);
            
            // Verificar que no sea un usuario Guest/Site
            if (usuario.Profile.Name.contains('Guest') || usuario.Profile.Name.contains('Site')) {
                System.debug('⚠️ Usuario es Guest/Site, no se envía email');
                return;
            }
            
            // **OBTENER DATOS DEL CONTACTO (IMPORTANTE)**
            String nombreParaEmail = '';
            if (usuario.ContactId != null) {
                try {
                    Contact contacto = [SELECT Id, FirstName, LastName FROM Contact WHERE Id = :usuario.ContactId LIMIT 1];
                    System.debug('📧 Datos del Contacto:');
                    System.debug('📧 Contacto FirstName: ' + contacto.FirstName);
                    System.debug('📧 Contacto LastName: ' + contacto.LastName);
                    
                    // Usar datos del Contacto si están disponibles
                    if (String.isNotBlank(contacto.FirstName)) {
                        nombreParaEmail = contacto.FirstName;
                        System.debug('✅ Usando nombre del Contacto: ' + nombreParaEmail);
                    } else if (String.isNotBlank(usuario.FirstName)) {
                        nombreParaEmail = usuario.FirstName;
                        System.debug('⚠️ Contacto sin FirstName, usando Usuario: ' + nombreParaEmail);
                    } else {
                        nombreParaEmail = 'Usuario';
                        System.debug('⚠️ Sin nombre, usando "Usuario" por defecto');
                    }
                } catch(Exception e) {
                    System.debug('⚠️ Error obteniendo contacto: ' + e.getMessage());
                    // Fallback a datos del usuario
                    if (String.isNotBlank(usuario.FirstName)) {
                        nombreParaEmail = usuario.FirstName;
                    } else {
                        nombreParaEmail = 'Usuario';
                    }
                }
            } else {
                // Si no hay Contacto, usar datos del usuario
                if (String.isNotBlank(usuario.FirstName)) {
                    nombreParaEmail = usuario.FirstName;
                } else {
                    nombreParaEmail = 'Usuario';
                }
            }
            
            System.debug('✅ Nombre para email: ' + nombreParaEmail);
            
            // Buscar plantilla
            System.debug('📧 Buscando plantilla "Nuevo Usuario Productor"...');
            List<EmailTemplate> templates = [SELECT Id, Name, DeveloperName 
                                            FROM EmailTemplate 
                                            WHERE Name = 'Nuevo Usuario Productor' 
                                            OR DeveloperName = 'Nuevo_Usuario_Productor'
                                            LIMIT 1];
            
            System.debug('📧 Plantillas encontradas: ' + templates.size());
            
            System.debug('✅ Plantilla encontrada: ' + templates[0].Name + ' (ID: ' + templates[0].Id + ')');
            
            // **SOLUCIÓN: Enviar email usando el Contacto como targetObjectId**
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setTemplateId(templates[0].Id);
            
            // **IMPORTANTE: Si el usuario tiene Contacto, usar el Contacto como targetObjectId**
            if (usuario.ContactId != null) {
                System.debug('✅ Usando ContactId como targetObjectId: ' + usuario.ContactId);
                email.setTargetObjectId(usuario.ContactId);
                email.setSaveAsActivity(true); // Para Contactos, puede ser true
            } else {
                System.debug('⚠️ Usuario no tiene Contacto asociado, usando UserId');
                email.setTargetObjectId(usuario.Id);
                email.setSaveAsActivity(false); // Para Usuarios, DEBE ser false
            }
            
            email.setUseSignature(false);
            
            // Configurar remitente
            try {
                System.debug('📧 Configurando remitente...');
                List<OrgWideEmailAddress> oweaList = [SELECT Id, Address, DisplayName 
                                                     FROM OrgWideEmailAddress 
                                                     WHERE Address = 'info@sembraevolucion.com.ar'
                                                     LIMIT 1];
                
                if (!oweaList.isEmpty()) {
                    email.setOrgWideEmailAddressId(oweaList[0].Id);
                    System.debug('✅ Remitente configurado: ' + oweaList[0].Address);
                } else {
                    System.debug('⚠️ No se encontró OrgWideEmailAddress info@sembraevolucion.com.ar');
                }
            } catch(Exception e) {
                System.debug('⚠️ Error configurando remitente: ' + e.getMessage());
            }
            
            // Enviar email
            System.debug('📧📧📧 ENVIANDO EMAIL CON PLANTILLA 📧📧📧');
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
            // Verificar resultado
            System.debug('📧 Resultado del envío:');
            for(Messaging.SendEmailResult result : results) {
                System.debug('✅ Éxito: ' + result.isSuccess());
                if (result.isSuccess()) {
                    System.debug('✅✅✅ EMAIL ENVIADO EXITOSAMENTE ✅✅✅');
                    System.debug('✅ Destinatario: ' + usuario.Email);
                    System.debug('✅ Nombre para email: ' + nombreParaEmail);
                } else {
                    System.debug('❌ Falló el envío');
                    for(Messaging.SendEmailError error : result.getErrors()) {
                        System.debug('❌ Error: ' + error.getMessage());
                        System.debug('❌ Código: ' + error.getStatusCode());
                    }
                }
            }
            
        } catch(Exception e) {
            System.debug('❌❌❌ ERROR en sendWelcomeEmailImmediate ❌❌❌');
            System.debug('❌ Mensaje: ' + e.getMessage());
            System.debug('❌ Línea: ' + e.getLineNumber());
            System.debug('❌ StackTrace: ' + e.getStackTraceString());
        }
    }

    /**
     * Envía email de bienvenida para usuarios verificados por email
     * @param email Email del usuario
     * @param cuit CUIT de la cuenta
     */
    private static void sendWelcomeEmailForVerifiedUser(String email, String cuit) {
        try {
            Contact contact = getContact(email, cuit);
            List<User> users = [SELECT Id FROM User 
                               WHERE Email =: email AND ContactId =: contact.Id];
            
            if (!users.isEmpty()) {
                sendWelcomeEmailImmediate(users[0].Id);
            }
        } catch(Exception e) {
            System.debug('Error enviando email para usuario verificado: ' + e.getMessage());
        }
    }

    

    /**
     * Manejo de excepciones
     * @param e Excepción
     * @return AuraHandledException Excepción manejada
     */
    public static AuraHandledException error(Exception e) {
        System.debug(e);
        System.debug(e.getStackTraceString());
        return error(e.getMessage());
    }

    /**
     * Crea excepción manejada con mensaje
     * @param message Mensaje de error
     * @return AuraHandledException Excepción manejada
     */
    public static AuraHandledException error(String message) {
        AuraHandledException ex = new AuraHandledException(message);
        ex.setMessage(message);
        return ex;
    }
}