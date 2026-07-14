trigger LicenciaEmailTrigger2 on Licencia__c (before insert, before update) {
    List<EmailSplitHelper.EmailInput> inputs = new List<EmailSplitHelper.EmailInput>();
    Map<String, Licencia__c> licMap = new Map<String, Licencia__c>();

    for (Licencia__c lic : Trigger.new) {
        if (String.isNotBlank(lic.Emails_Adicionales__c)) {
            EmailSplitHelper.EmailInput input = new EmailSplitHelper.EmailInput();
            input.emails = lic.Emails_Adicionales__c;
            inputs.add(input);
            licMap.put(input.emails, lic);
        }
    }

    if (!inputs.isEmpty()) {
        List<EmailSplitHelper.EmailSplitResult> resultados = EmailSplitHelper.dividir(inputs);

        for (Integer i = 0; i < resultados.size(); i++) {
            EmailSplitHelper.EmailSplitResult resultado = resultados[i];
            Licencia__c lic = licMap.get(inputs[i].emails);

            lic.email_adicional_1__c = resultado.email_adicional_1;
            lic.email_adicional_2__c = resultado.email_adicional_2;
            lic.email_adicional_3__c = resultado.email_adicional_3;
            lic.email_adicional_4__c = resultado.email_adicional_4;
            lic.email_adicional_5__c = resultado.email_adicional_5;
        }
    }
}