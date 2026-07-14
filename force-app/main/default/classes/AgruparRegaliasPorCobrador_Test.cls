@IsTest
public class AgruparRegaliasPorCobrador_Test {

    @IsTest
    static void testAgruparRegalias() {

        // Crear cuentas para el lookup
        Account cobradorA = new Account(Name = 'Cobrador A');
        Account cobradorB = new Account(Name = 'Cobrador B');
        insert new List<Account>{ cobradorA, cobradorB };

        // Crear registros TN_Regalia_Enlist__c
        TN_Regalia_Enlist__c r1 = new TN_Regalia_Enlist__c(
            Cobrador__c = cobradorA.Id,
            CTGs_Involucrados__c = '1015834753',
            Cantidad__c = 10
        );

        TN_Regalia_Enlist__c r2 = new TN_Regalia_Enlist__c(
            Cobrador__c = cobradorB.Id,
            CTGs_Involucrados__c = '1015834755',
            Cantidad__c = 5
        );

        TN_Regalia_Enlist__c r3 = new TN_Regalia_Enlist__c(
            Cobrador__c = cobradorA.Id,
            CTGs_Involucrados__c ='1015834754',
            Cantidad__c = 7
        );

        List<TN_Regalia_Enlist__c> listaRegalias = new List<TN_Regalia_Enlist__c>{ r1, r2, r3 };

        // Preparar wrapper de entrada
        AgruparRegaliasPorCobrador.EntradaWrapper entrada = 
            new AgruparRegaliasPorCobrador.EntradaWrapper();
        entrada.registros = listaRegalias;

        List<AgruparRegaliasPorCobrador.EntradaWrapper> entradaLista =
            new List<AgruparRegaliasPorCobrador.EntradaWrapper>{ entrada };

        Test.startTest();
        List<AgruparRegaliasPorCobrador.SalidaWrapper> resultado =
            AgruparRegaliasPorCobrador.procesar(entradaLista);
        Test.stopTest();

        // Validaciones
        System.assertEquals(1, resultado.size(), 'Debe haber un wrapper de salida');

        List<TN_Regalia_Enlist__c> registrosAgrupados = resultado[0].registrosAgrupados;

        System.assertEquals(2, registrosAgrupados.size(), 'Debe devolver 2 registros agrupados');

        // Validar sumas por cobrador
        Map<Id, Decimal> mapaResultados = new Map<Id, Decimal>();
        for (TN_Regalia_Enlist__c reg : registrosAgrupados) {
            mapaResultados.put(reg.Cobrador__c, reg.Cantidad__c);
        }

        System.assertEquals(17, mapaResultados.get(cobradorA.Id),
            'El cobrador A debe tener suma 17');

        System.assertEquals(5, mapaResultados.get(cobradorB.Id),
            'El cobrador B debe tener suma 5');
    }
}