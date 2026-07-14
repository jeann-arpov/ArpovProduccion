public with sharing class VentasInformadasMassActionUtil {

    public static final String DEFAULT_LIST_URL = '/lightning/o/Ventas_Informadas__c/list';

    public static String getReturnUrl() {
        ApexPages.PageReference currentPage = ApexPages.currentPage();
        if (currentPage == null) {
            return DEFAULT_LIST_URL;
        }

        Map<String, String> params = currentPage.getParameters();
        String vfRetUrl = params.get('vfRetURLInSFX');
        if (String.isNotBlank(vfRetUrl)) {
            return vfRetUrl;
        }

        String retUrl = params.get('retURL');
        if (String.isNotBlank(retUrl)) {
            if (retUrl.startsWith('http') || retUrl.startsWith('/lightning')) {
                return retUrl;
            }
            return retUrl.startsWith('/') ? retUrl : '/' + retUrl;
        }

        return DEFAULT_LIST_URL;
    }

    public static PageReference redirectToReturnUrl() {
        PageReference pageRef = new PageReference(getReturnUrl());
        pageRef.setRedirect(true);
        return pageRef;
    }

    public static String encodeReturnUrlParam() {
        return EncodingUtil.urlEncode(getReturnUrl(), 'UTF-8');
    }
}