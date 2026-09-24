public without sharing class CustomJWTSigner {
  @AuraEnabled(cacheable=true)
  public static String CustomJWTSigner(
    String userId,
    String url,
    String contactId
  ) {
    User usr = [
      SELECT Id, Email, ContactId, CUIT__c, Razon_Social__c
      FROM User
      WHERE Id = :userId
    ];
    System.debug('contactId::' + contactId);
    Contact ctc = [
      SELECT Id, AccountId, FirstName, LastName
      FROM Contact
      WHERE Id = :contactId
    ];
    Account acc = [SELECT Type FROM Account WHERE Id = :ctc.AccountId];

    Map<String, Object> header = new Map<String, Object>();
    header.put('typ', 'JWT');
    header.put('alg', 'HS256');

    Map<String, Object> payload = new Map<String, Object>();
    payload.put('sub', 'user@example.com');
    payload.put('email', usr.Email);

    payload.put('cuit', usr.CUIT__c);
    payload.put('razonSocial', usr.Razon_Social__c);
    payload.put('accType', acc.Type);
    payload.put('firstName', ctc.FirstName);
    payload.put('lastName', ctc.LastName);

    payload.put('admin', true);
    payload.put('roles', new List<String>{ 'Admin', 'Editor' });
    payload.put('permissions', new List<String>{ 'read', 'write', 'delete' });

    payload.put('iat', DateTime.now().getTime() / 1000);
    payload.put('exp', DateTime.now().addHours(1).getTime() / 1000);

    String encodedHeader = base64URLencode(
      Blob.valueOf(JSON.serialize(header))
    );
    String encodedPayload = base64URLencode(
      Blob.valueOf(JSON.serialize(payload))
    );

    String unsignedJWT = encodedHeader + '.' + encodedPayload;

    String signature = createHMACSignature(
      unsignedJWT,
      '518C1F10-6106-4E09-9B4A-7FBF245308F9'
    );

    String signedJWT = unsignedJWT + '.' + signature;

    Map<String, String> updatedSglUrls = new Map<String, String>();
    return tokenForSgl(signedJWT);
  }

  private static String createHMACSignature(String data, String secretKey) {
    Blob key = Blob.valueOf(secretKey);
    Blob dataBlob = Blob.valueOf(data);

    Blob signedBlob = Crypto.generateMac('HMACSHA256', dataBlob, key);

    return base64URLencode(signedBlob);
  }

  public static String base64URLencode(Blob input) {
    String output = encodingUtil.base64Encode(input);
    output = output.replace('+', '-');
    output = output.replace('/', '_');
    while (output.endsWith('=')) {
      output = output.subString(0, output.length() - 1);
    }
    return output;
  }

  private static final String SGL_AES_ALGORITHM = 'AES256-GCM';
  private static final String SGL_AES_KEY_B64 = 'vC96Z7XgY7oglv9Mb0CKIZgvUFv3FQ5jbzD/ZvdNPUg=';

  private static Boolean isSandboxOrg {
    get {
      if (isSandboxOrg == null) {
        // Community users cannot query Organization; detect sandbox from My Domain.
        System.Domain domain = System.DomainParser.parse(
          System.Url.getOrgDomainUrl().getHost()
        );
        isSandboxOrg = String.isNotBlank(domain.getSandboxName());
      }
      return isSandboxOrg;
    }
    set;
  }

  /**
   * JWT cifrado (AES-256-GCM) para envío a SGL en todos los entornos.
   */
  @TestVisible
  static String tokenForSgl(String jwt) {
    return encryptJwtForSgl(jwt);
  }

  /**
   * Cifra el JWT con AES-256-GCM para enviarlo a SGL.
   * Formato wire: nonce(12) || ciphertext || tag(16)
   * Encoding en URL: Base64URL (sin +, / ni =) para que no se rompa en query string.
   * Key: EncodingUtil.base64Decode(SGL_AES_KEY_B64) → exactamente 32 bytes.
   * AAD: ninguno (null / no se pasa additionalAuthenticatedData).
   * Apex antepone 1 byte con la longitud del IV (0x0C); se quita del wire hacia SGL.
   */
  @TestVisible
  static String encryptJwtForSgl(String jwt) {
    if (String.isBlank(jwt)) {
      return jwt;
    }
    Blob encrypted = Crypto.encryptWithManagedIV(
      SGL_AES_ALGORITHM,
      EncodingUtil.base64Decode(SGL_AES_KEY_B64),
      Blob.valueOf(jwt)
    );
    String hex = EncodingUtil.convertToHex(encrypted);
    String wireHex = stripGcmLengthPrefix(hex);
    return base64URLencode(EncodingUtil.convertFromHex(wireHex));
  }

  @TestVisible
  static String decryptJwtFromSgl(String encoded) {
    if (String.isBlank(encoded)) {
      return encoded;
    }
    Blob wire = base64URLdecode(encoded);
    Blob sfFormat = EncodingUtil.convertFromHex(
      '0c' + EncodingUtil.convertToHex(wire)
    );
    return Crypto.decryptWithManagedIV(
        SGL_AES_ALGORITHM,
        EncodingUtil.base64Decode(SGL_AES_KEY_B64),
        sfFormat
      )
      .toString();
  }

  @TestVisible
  static Blob base64URLdecode(String input) {
    String output = input.replace('-', '+').replace('_', '/');
    while (Math.mod(output.length(), 4) != 0) {
      output += '=';
    }
    return EncodingUtil.base64Decode(output);
  }

  private static String stripGcmLengthPrefix(String hex) {
    if (String.isBlank(hex) || hex.length() < 26) {
      throw new SglCryptoException('Blob AES-GCM vacío o demasiado corto');
    }
    String prefix = hex.substring(0, 2).toLowerCase();
    if (prefix == '0c') {
      return hex.substring(2);
    }
    String prefix4 = hex.substring(0, 8).toLowerCase();
    if (prefix4 == '0c000000' || prefix4 == '0000000c') {
      return hex.substring(8);
    }
    throw new SglCryptoException(
      'Formato AES-GCM inesperado. Prefijo=' + hex.substring(0, 8)
    );
  }

  private class SglCryptoException extends Exception {
  }

  @AuraEnabled
  public static String CustomJWTSignerLicencias(
    String userId,
    String url,
    String contactId
  ) {
    try {
      return runCustomJWTSignerLicencias(userId, url, contactId);
    } catch (Exception ex) {
      throw new AuraHandledException(
        'userId: ' +
          System.UserInfo.getUserId() +
          ' ex_message +' +
          ex.getMessage() +
          ' stack_trace: ' +
          ex.getStackTraceString()
      );
    }
  }

  @AuraEnabled
  public static String singleLicenseJWTSigner(
    String userId,
    String contactId,
    String licenseId
  ) {
    User usr = [
      SELECT Id, Email, ContactId, CUIT__c, Razon_Social__c
      FROM User
      WHERE Id = :userId
    ];
    System.debug('contactId::' + contactId);
    Contact ctc = [
      SELECT Id, AccountId, FirstName, LastName
      FROM Contact
      WHERE Id = :contactId
    ];
    Account acc = [SELECT Type FROM Account WHERE Id = :ctc.AccountId];
    System.debug('acc:::' + acc);
    Licencia__c license = [
      SELECT Id, Name
      FROM Licencia__c
      WHERE Id = :licenseId
    ];
    Map<String, Object> header = new Map<String, Object>();
    header.put('typ', 'JWT');
    header.put('alg', 'HS256');

    Map<String, Object> payload = new Map<String, Object>();
    payload.put('sub', 'user@example.com');
    payload.put('email', usr.Email);

    payload.put('cuit', usr.CUIT__c);
    payload.put('razonSocial', usr.Razon_Social__c);
    payload.put('accType', acc.Type);
    payload.put('firstName', ctc.FirstName);
    payload.put('lastName', ctc.LastName);
    payload.put('LicenseCode', license.Name);

    payload.put('admin', true);
    payload.put('roles', new List<String>{ 'Admin', 'Editor' });
    payload.put('permissions', new List<String>{ 'read', 'write', 'delete' });

    payload.put('iat', DateTime.now().getTime() / 1000);
    payload.put('exp', DateTime.now().addHours(1).getTime() / 1000);

    String encodedHeader = base64URLencode(
      Blob.valueOf(JSON.serialize(header))
    );
    String encodedPayload = base64URLencode(
      Blob.valueOf(JSON.serialize(payload))
    );
    //String encodedPayload = base64URLencode(Blob.valueOf('{"exp":1753158069,"iat":1753154469,"permissions":["read","write","delete"],"roles":["Admin","Editor"],"admin":true,"LicenseCode":"GDM5424G0010317","lastName":"Empresa","firstName":"Adeco Agropecuaria SA","accType":"Productor","razonSocial":"ADECO AGROPECUARIA S.A.","cuit":"30618705672","email":"sfdc.clauacu@gmail.com","sub":"user@example.com"}'));

    String unsignedJWT = encodedHeader + '.' + encodedPayload;

    String signature = createHMACSignature(
      unsignedJWT,
      '518C1F10-6106-4E09-9B4A-7FBF245308F9'
    );

    String signedJWT = unsignedJWT + '.' + signature;

    return tokenForSgl(signedJWT);
  }

  @AuraEnabled
  public static String singleNewLicenseRequestJWTSigner(
    String userId,
    String contactId
  ) {
    User usr = [
      SELECT Id, Email, ContactId, CUIT__c, Razon_Social__c
      FROM User
      WHERE Id = :userId
    ];
    System.debug('contactId::' + contactId);
    Contact ctc = [
      SELECT Id, AccountId, FirstName, LastName
      FROM Contact
      WHERE Id = :contactId
    ];
    Account acc = [SELECT Type FROM Account WHERE Id = :ctc.AccountId];
    System.debug('acc:::' + acc);
    Map<String, Object> header = new Map<String, Object>();
    header.put('typ', 'JWT');
    header.put('alg', 'HS256');

    Map<String, Object> payload = new Map<String, Object>();
    payload.put('sub', 'user@example.com');
    payload.put('email', usr.Email);

    payload.put('cuit', usr.CUIT__c);
    payload.put('razonSocial', usr.Razon_Social__c);
    payload.put('accType', acc.Type);
    payload.put('firstName', ctc.FirstName);
    payload.put('lastName', ctc.LastName);

    payload.put('admin', true);
    payload.put('roles', new List<String>{ 'Admin', 'Editor' });
    payload.put('permissions', new List<String>{ 'read', 'write', 'delete' });

    payload.put('iat', DateTime.now().getTime() / 1000);
    payload.put('exp', DateTime.now().addHours(1).getTime() / 1000);

    String encodedHeader = base64URLencode(
      Blob.valueOf(JSON.serialize(header))
    );
    String encodedPayload = base64URLencode(
      Blob.valueOf(JSON.serialize(payload))
    );
    //String encodedPayload = base64URLencode(Blob.valueOf('{"exp":1753158069,"iat":1753154469,"permissions":["read","write","delete"],"roles":["Admin","Editor"],"admin":true,"LicenseCode":"GDM5424G0010317","lastName":"Empresa","firstName":"Adeco Agropecuaria SA","accType":"Productor","razonSocial":"ADECO AGROPECUARIA S.A.","cuit":"30618705672","email":"sfdc.clauacu@gmail.com","sub":"user@example.com"}'));

    String unsignedJWT = encodedHeader + '.' + encodedPayload;

    String signature = createHMACSignature(
      unsignedJWT,
      '518C1F10-6106-4E09-9B4A-7FBF245308F9'
    );

    String signedJWT = unsignedJWT + '.' + signature;

    return tokenForSgl(signedJWT);
  }

  public static String runCustomJWTSignerLicencias(
    String userId,
    String url,
    String contactId
  ) {
    User usr = [
      SELECT Id, Email, ContactId, CUIT__c, Razon_Social__c
      FROM User
      WHERE Id = :userId
    ];
    System.debug('contactId::' + contactId);
    Contact ctc = [
      SELECT Id, AccountId, FirstName, LastName
      FROM Contact
      WHERE Id = :contactId
    ];
    Account acc = [SELECT Type FROM Account WHERE Id = :ctc.AccountId];
    System.debug('acc:::' + acc);
    Map<Id, Licencia__c> licencesMap = new Map<Id, Licencia__c>(
      [
        SELECT Id, Tipo_de_Licencia__c, Origen_de_Licencia__c
        FROM Licencia__c
        WHERE
          Cuenta_Distribuidor__c = :acc.Id
          OR Cuenta_Obtentor__c = :acc.Id
          OR Cuenta_Productor__c = :acc.Id
      ]
    );
    Map<String, Object> header = new Map<String, Object>();
    header.put('typ', 'JWT');
    header.put('alg', 'HS256');

    Map<String, Object> payload = new Map<String, Object>();
    payload.put('sub', 'user@example.com');
    payload.put('email', usr.Email);

    payload.put('cuit', usr.CUIT__c);
    payload.put('razonSocial', usr.Razon_Social__c);
    payload.put('accType', acc.Type);
    payload.put('firstName', ctc.FirstName);
    payload.put('lastName', ctc.LastName);

    payload.put('admin', true);
    payload.put('roles', new List<String>{ 'Admin', 'Editor' });
    payload.put('permissions', new List<String>{ 'read', 'write', 'delete' });

    payload.put('iat', DateTime.now().getTime() / 1000);
    payload.put('exp', DateTime.now().addHours(1).getTime() / 1000);

    String encodedHeader = base64URLencode(
      Blob.valueOf(JSON.serialize(header))
    );
    String encodedPayload = base64URLencode(
      Blob.valueOf(JSON.serialize(payload))
    );

    String unsignedJWT = encodedHeader + '.' + encodedPayload;

    String signature = createHMACSignature(
      unsignedJWT,
      '518C1F10-6106-4E09-9B4A-7FBF245308F9'
    );

    String signedJWT = unsignedJWT + '.' + signature;

    Map<String, String> updatedSglUrls = new Map<String, String>();

    for (Licencia__c currentLic : licencesMap.values()) {
      String entorno = isSandboxOrg ? 'Sandbox' : 'Prod';

      Parametro_Portal_Licencias__mdt licParam = Parametro_Portal_Licencias__mdt.getInstance(
        entorno
      );

      String sglUrl = null;
      String currentTipoLicencia = acc.Type;
      if (
        (currentLic.Tipo_de_Licencia__c == 'Productor' ||
        currentTipoLicencia == 'Productor') &&
        currentLic.Origen_de_Licencia__c == 'Aporte Genético'
      ) {
        sglUrl = licParam.url__c + '/GeneticLicenseSearch?token=';
      } else if (
        (currentLic.Tipo_de_Licencia__c == 'Productor' ||
        currentTipoLicencia == 'Productor') &&
        currentLic.Origen_de_Licencia__c == 'Enlist/Conkesta'
      ) {
        sglUrl = licParam.url__c + '/LicenseSearch?token=';
      } else if (
        (currentLic.Tipo_de_Licencia__c == 'Comercio' ||
        currentTipoLicencia == 'Comercio') &&
        currentLic.Origen_de_Licencia__c == 'Aporte Genético'
      ) {
        sglUrl = licParam.url__c + '/CommerceGeneticLicenseSearch?token=';
      } else if (
        (currentLic.Tipo_de_Licencia__c == 'Comercio' ||
        currentTipoLicencia == 'Comercio') &&
        currentLic.Origen_de_Licencia__c == 'Enlist/Conkesta'
      ) {
        sglUrl = licParam.url__c + '/CommerceEnlistLicenseSearch?token=';
      }
      System.debug('currentLic:::' + currentLic);
      if (sglUrl != null) {
        updatedSglUrls.put(currentLic.Id, sglUrl);
      }
    }

    if (!updatedSglUrls.isEmpty()) {
      List<Licencia__c> licToUpdList = new List<Licencia__c>();

      for (String licId : updatedSglUrls.keySet()) {
        if (!licencesMap.containsKey(licId)) {
          continue;
        }

        Licencia__c licToUpd = licencesMap.get(licId);
        licToUpd.sglUrl__c = updatedSglUrls.get(licId);
        licToUpd.tokenHeaderFromApex__c = encodedHeader + '.';
        licToUpd.tokenPayloadFromApex__c = encodedPayload.left(255); // get first 255 chars
        licToUpd.tokenPayloadFromApex2__c =
          encodedPayload.mid(255, encodedPayload.length()) + '.'; // get rest of the chars starting from position 255
        licToUpd.tokenSignatureFromApex__c = signature;
        licToUpd.urlFromApex__c = '&url=' + url;

        licToUpdList.add(licToUpd);
      }

      try {
        update licToUpdList;
      } catch (Exception e) {
        System.debug(' Error al actualizar licencias: ' + e.getMessage());
        // Opcional: registrar en un campo de log, o lanzar una CustomException si querés reportar algo específico
      }
    }

    return tokenForSgl(signedJWT);
  }
}
