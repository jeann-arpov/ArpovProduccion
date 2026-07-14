@isTest
public class EmailSplitHelperTest {

    @isTest
    static void testDividirEmails() {
        // Simulamos input
        EmailSplitHelper.EmailInput input = new EmailSplitHelper.EmailInput();
        input.emails = 'uno@mail.com, dos@mail.com, tres@mail.com, cuatro@mail.com, cinco@mail.com';
        List<EmailSplitHelper.EmailInput> inputs = new List<EmailSplitHelper.EmailInput>{input};

        // Llamamos a la clase a testear
        List<EmailSplitHelper.EmailSplitResult> resultados = EmailSplitHelper.dividir(inputs);

        // Validaciones
        System.assertEquals(1, resultados.size());

        EmailSplitHelper.EmailSplitResult res = resultados[0];
        System.assertEquals('uno@mail.com', res.email_adicional_1);
        System.assertEquals('dos@mail.com', res.email_adicional_2);
        System.assertEquals('tres@mail.com', res.email_adicional_3);
        System.assertEquals('cuatro@mail.com', res.email_adicional_4);
        System.assertEquals('cinco@mail.com', res.email_adicional_5);
    }

    @isTest
    static void testEmailsIncompletos() {
        EmailSplitHelper.EmailInput input = new EmailSplitHelper.EmailInput();
        input.emails = 'uno@mail.com, dos@mail.com';
        List<EmailSplitHelper.EmailInput> inputs = new List<EmailSplitHelper.EmailInput>{input};

        List<EmailSplitHelper.EmailSplitResult> resultados = EmailSplitHelper.dividir(inputs);
        EmailSplitHelper.EmailSplitResult res = resultados[0];

        System.assertEquals('uno@mail.com', res.email_adicional_1);
        System.assertEquals('dos@mail.com', res.email_adicional_2);
        System.assertEquals(null, res.email_adicional_3);
        System.assertEquals(null, res.email_adicional_4);
        System.assertEquals(null, res.email_adicional_5);
    }
}