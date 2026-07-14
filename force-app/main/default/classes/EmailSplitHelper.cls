public class EmailSplitHelper {

    @InvocableMethod(label='Dividir Emails' description='Divide emails separados por coma y retorna lista')
    public static List<EmailSplitResult> dividir(List<EmailInput> inputs) {
        List<EmailSplitResult> resultados = new List<EmailSplitResult>();

        for (EmailInput input : inputs) {
            List<String> emails = input.emails != null ? input.emails.split(',') : new List<String>();

            EmailSplitResult res = new EmailSplitResult();
            res.email_adicional_1 = emails.size() > 0 ? emails[0].trim() : null;
            res.email_adicional_2 = emails.size() > 1 ? emails[1].trim() : null;
            res.email_adicional_3 = emails.size() > 2 ? emails[2].trim() : null;
            res.email_adicional_4 = emails.size() > 3 ? emails[3].trim() : null;
            res.email_adicional_5 = emails.size() > 4 ? emails[4].trim() : null;

            resultados.add(res);
        }

        return resultados;
    }

    public class EmailInput {
        @InvocableVariable(required=true)
        public String emails;
    }

    public class EmailSplitResult {
        @InvocableVariable public String email_adicional_1;
        @InvocableVariable public String email_adicional_2;
        @InvocableVariable public String email_adicional_3;
        @InvocableVariable public String email_adicional_4;
        @InvocableVariable public String email_adicional_5;
    }
}