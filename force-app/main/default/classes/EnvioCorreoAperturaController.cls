public with sharing class EnvioCorreoAperturaController {
    public void registrar() {
        if (ApexPages.currentPage() == null) {
            return;
        }
        EnvioCorreoAperturaService.solicitar(ApexPages.currentPage().getParameters().get('t'));
    }
}
