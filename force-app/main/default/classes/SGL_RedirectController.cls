public class SGL_RedirectController {
  public String jwtToken { get; set; }
  public String targetUrl { get; set; }

  public String userId { get; set; }
  public String contactId { get; set; }
  public String licenseId { get; set; }
  public String returnUrl { get; set; }

  public SGL_RedirectController() {
    // obtener los parámetros desde la URL
    userId = ApexPages.currentPage().getParameters().get('userId');
    contactId = ApexPages.currentPage().getParameters().get('contactId');
    licenseId = ApexPages.currentPage().getParameters().get('licenseId');
    returnUrl = ApexPages.currentPage().getParameters().get('returnUrl');
    targetUrl = getUrl();
  }

  @AuraEnabled(cacheable=true)
  public static String getUrl() {
    // Community users cannot query Organization; detect sandbox from My Domain.
    System.Domain domain = System.DomainParser.parse(
      System.Url.getOrgDomainUrl().getHost()
    );
    String entorno = String.isNotBlank(domain.getSandboxName())
      ? 'Sandbox'
      : 'Prod';

    Parametro_Portal_Licencias__mdt licParam = Parametro_Portal_Licencias__mdt.getInstance(
      entorno
    );

    return licParam.url__c;
  }

  public void init() {
    String uid = userId;
    String cid = contactId;
    if (String.isBlank(uid) || String.isBlank(cid)) {
      User runningUser = [
        SELECT Id, ContactId
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];
      if (String.isBlank(uid)) {
        uid = runningUser.Id;
      }
      if (String.isBlank(cid)) {
        cid = runningUser.ContactId;
      }
    }
    jwtToken = singleLicenseJWTSigner(uid, cid, licenseId);
  }

  @AuraEnabled
  public static String singleLicenseJWTSigner(
    String userId,
    String contactId,
    String licenseId
  ) {
    return CustomJWTSigner.singleLicenseJWTSigner(userId, contactId, licenseId);
  }
}
