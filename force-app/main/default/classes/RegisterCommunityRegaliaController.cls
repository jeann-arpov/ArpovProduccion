/**
 * @description Controlador exclusivo y optimizado para el registro e inicio de sesión
 * en el portal de Regalía Extendida.
 * @author Nerio Alvarado
 * @date 2026-07-20
 */
public without sharing class RegisterCommunityRegaliaController {

    private static final String WELCOME_EMAIL_TEMPLATE = 'Nuevo_Usuario_Regalia_Productor';
    private static final String TARGET_PROFILE_NAME = 'Productor Regalia Extendida';
    private static final String FALLBACK_REDIRECT = '/s/';

    private static Exception error(String msg) {
        AuraHandledException auraEx = new AuraHandledException(msg);
        auraEx.setMessage(msg); 
        return auraEx;
    }

    @AuraEnabled
    public static String doCreateUser(String email, String cuit, String firstName, String lastName, String dni, String password, String telefono) {
        try {
            if (String.isBlank(firstName) || String.isBlank(lastName)) {
                throw error('El nombre y apellido son obligatorios');
            }
            
            // 1. Validamos y obtenemos el contacto base (existente)
            Contact contact = getContact(email, cuit);
            
            // Si el contacto ya existía pero no está habilitado, bloqueamos
            if (contact.Id != null && contact.Contacto_SRE__c == false) {
                throw error('El contacto no se encuentra habilitado para registrarse en el portal de Regalía Extendida. Contáctanos para más información.');
            }

            // 2. Modificamos los valores del contacto en memoria
            contact.FirstName = firstName;
            contact.LastName = lastName;
            contact.Es_Usuario_Portal_Regalia__c = true;
            if (String.isNotBlank(telefono)) {
                contact.MobilePhone = telefono;
            }
            
            // Insertamos o actualizamos el Contacto en MODO DE SISTEMA para evitar restricciones del Guest User
            Database.SaveResult srContact;
            if (contact.Id == null) {
                srContact = Database.insert(contact, true, AccessLevel.SYSTEM_MODE);
            } else {
                srContact = Database.update(contact, true, AccessLevel.SYSTEM_MODE);
            }
            
            if (!srContact.isSuccess()) {
                throw error('No se pudo guardar la información de contacto previa al registro.');
            }
            
            // 3. Preparamos la entidad del Usuario asociándola al contacto ya guardado (contact.Id ya está disponible)
            User u = prepareUserEntity(email, cuit, firstName, lastName, dni, telefono, contact.Id);
            
            // Inserción del Usuario en Modo de Sistema para el Guest User
            Database.SaveResult sr = Database.insert(u, true, AccessLevel.SYSTEM_MODE);
            
            if (sr.isSuccess()) {
                System.setPassword(u.Id, password);
                
                // 4. Ejecutamos las lógicas posteriores síncronamente (Aisladas contra fallos)
                ejecutarProcesosPostRegistroSync(u.Id, u.ProfileId);
                
                return 'USER_CREATED_SUCCESSFULLY';
            } else {
                throw error('Error al registrar el usuario de comunidad.');
            }
        } catch (Exception e) {
            throw error(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String loginWithPassword(String email, String cuit, String password) {
        try {
            if (String.isBlank(email) || String.isBlank(cuit) || String.isBlank(password)) {
                throw error('El email, el CUIT y la contraseña son obligatorios.');
            }

            String targetUsername = generateUsername(email.trim(), cuit.trim());
            System.PageReference pageRef = Site.login(targetUsername, password, FALLBACK_REDIRECT);
            
            if (pageRef != null) {
                return pageRef.getUrl();
            } else {
                throw error('Intento de inicio de sesión fallido. Verifique sus credenciales.');
            }
        } catch (Exception e) {
            throw error(e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void handleForgotPassword(String email) {
        try {
            if (String.isBlank(email)) {
                throw error('El Email es requerido para restablecer la contraseña.');
            }
            
            DataAccessSelector selector = new DataAccessSelector();
            List<User> users = selector.getUserByEmailForForgotPassword(email.trim());
                                
            if (users.isEmpty()) {
                throw error('No se encontró ningún usuario habilitado con el correo electrónico especificado.');
            }

            Boolean success = Site.forgotPassword(users[0].Username);
            if (!success) {
                throw error('No se pudo procesar la solicitud de restablecimiento en este momento. Intente más tarde.');
            }
            
        } catch (Exception e) {
            throw error(e.getMessage());
        }
    }

    // =========================================================================
    // MÉTODOS AUXILIARES E INTERNOS
    // =========================================================================
    
    /**
     * @description Ejecuta de manera síncrona y tolerante a fallos los procesos posteriores al registro.
     */
    private static void ejecutarProcesosPostRegistroSync(Id userId, Id profileId) {
        // Enviar email de bienvenida inmediato (Aislado de manera independiente)
        try {
            sendWelcomeEmailImmediate(userId);
        } catch(Exception e) { 
            System.debug('❌ ERROR CRÍTICO AL ENVIAR EMAIL DE BIENVENIDA: ' + e.getMessage()); 
        }
    }

    public static Contact getContact(String email, String cuit) {
        DataAccessSelector selector = new DataAccessSelector();
        List<Account> accs = selector.getAccountByCuit(cuit);
        if (accs.isEmpty()) throw error('No existe una cuenta con ese CUIT. ' + errorContactMessage());

        List<Contact> contacts = selector.getContactByEmailAndAccount(email, accs[0].Id);
        
        return contacts[0];
    } 

    private static String errorContactMessage() {
         return 'Contáctanos a regaliaextendida@arpov.org.ar para ayudarte.';
    }

    public static String generateUsername(String email, String cuit) {
        return cuit + email.split('@')[0] + '@portalagro.com.ar';
    }

    private static User prepareUserEntity(String email, String cuit, String firstName, String lastName, String dni, String telefono, Id contactId) {
        DataAccessSelector selector = new DataAccessSelector();

        for (User u : selector.getUserByUsername(generateUsername(email, cuit))) {
            throw error('Ya existe un usuario con ese email y cuit en el sistema. ' + errorContactMessage());
        }

        Id Idprofile;
        ArPOV_Portal_Config__mdt profileConfig = ArPOV_Portal_Config__mdt.getInstance('Profile_Productor_Id');
        if (profileConfig != null && String.isNotBlank(profileConfig.Value__c)) {
            Idprofile = (Id)profileConfig.Value__c;
        } else {
            throw error('Falta la configuración del ID de Perfil en Custom Metadata.');
        }

        User u = new User();
        u.Username = generateUsername(email, cuit);
        u.Email = email;
        u.FirstName = firstName;
        u.LastName = lastName;
        u.ProfileId = Idprofile;
        u.CommunityNickname = firstName + String.valueOf(System.now().getTime() / 1000);
        u.Id_Externo__c = u.Username;
        u.Alias = firstName.length() > 8 ? firstName.substring(0, 8) : firstName;
        u.ContactId = contactId;
        u.LanguageLocaleKey = 'es';
        u.LocaleSidKey = 'es_AR';
        u.EmailEncodingKey = 'UTF-8';
        u.TimeZoneSidKey = 'America/Argentina/Buenos_Aires';
        u.Numero_de_Documento__c = dni;
        if (String.isNotBlank(telefono)) u.MobilePhone = telefono;

        return u;
    }

    public static void sendWelcomeEmailImmediate(Id userId) {
        DataAccessSelector selector = new DataAccessSelector();
        List<User> users = selector.getUserWithContactById(userId);
        if (users.isEmpty()) return;
        User usuario = users[0];

        // Consultamos la plantilla mediante el selector dinámico en SYSTEM_MODE
        List<EmailTemplate> etList = selector.getEmailTemplateByName(WELCOME_EMAIL_TEMPLATE);
        
        if(etList.isEmpty()) {
            System.debug('❌ ERROR: No se encontró la plantilla de email con DeveloperName: ' + WELCOME_EMAIL_TEMPLATE);
            return;
        }
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setTemplateId(etList[0].Id);
        
        if (usuario.ContactId != null) {
            email.setTargetObjectId(usuario.ContactId);
            email.setSaveAsActivity(false); // Evita problemas DML mixtos o de actividades del Guest User
        } else {
            email.setTargetObjectId(usuario.Id);
            email.setSaveAsActivity(false);
        }
        
        ArPOV_Portal_Config__mdt emailConfig = ArPOV_Portal_Config__mdt.getInstance('Org_Wide_Email_Id');
        
        // Manejo defensivo en ambientes de pruebas si el ID de Remitente Organizacional no es idóneo/válido
        if (emailConfig != null && String.isNotBlank(emailConfig.Value__c) && !Test.isRunningTest()) {
            email.setOrgWideEmailAddressId((Id)emailConfig.Value__c);
        } else {
            System.debug('ℹ️ [Contexto Remitente] Utilizando remitente por defecto (Contexto de Test o metadata vacío).');
        }
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        System.debug('✅ Email de bienvenida enviado con éxito para el usuario: ' + userId);
    }

    // =========================================================================
    // CAPA DE DATOS (WITHOUT SHARING - CONTEXTO DE SISTEMA SEGURO EXPLÍCITO)
    // =========================================================================
    private without sharing class DataAccessSelector {
        
        public List<Account> getAccountByCuit(String cuit) {
            String query = 'SELECT Id FROM Account WHERE N_CUIT__c = :cuit AND Type IN (\'Obtentor\', \'Productor\', \'Distribuidor\', \'Comercio\') AND ParentId = null LIMIT 1';
            return Database.query(query, AccessLevel.SYSTEM_MODE);
        }

        public List<Contact> getContactByEmailAndAccount(String email, Id accountId) {
            Id recordTypeId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Regal_a_Extendida').getRecordTypeId();
            String query = 'SELECT Id, Email, AccountId, Account.Type, Account.IsCustomerPortal, Contacto_SRE__c FROM Contact WHERE Email = :email AND AccountId = :accountId and RecordType.Id = : recordTypeId ' ;
            return Database.query(query, AccessLevel.SYSTEM_MODE);
        }

        public List<User> getUserByUsername(String username) {
            String query = 'SELECT Id FROM User WHERE Username = :username LIMIT 1';
            return Database.query(query, AccessLevel.SYSTEM_MODE);
        }

        public List<User> getUserWithContactById(Id userId) {
            String query = 'SELECT Id, ContactId, Email FROM User WHERE Id = :userId LIMIT 1';
            return Database.query(query, AccessLevel.SYSTEM_MODE);
        }

        public List<User> getUserByEmailForForgotPassword(String email) {
            String query = 'SELECT Username FROM User WHERE Email = :email AND IsActive = true AND Contact.Contacto_SRE__c = true LIMIT 1';
            return Database.query(query, AccessLevel.SYSTEM_MODE);
        }

        public List<EmailTemplate> getEmailTemplateByName(String developerName) {
            String query = 'SELECT Id FROM EmailTemplate WHERE DeveloperName = :developerName LIMIT 1';
            return Database.query(query, AccessLevel.SYSTEM_MODE);
        }
    }
}