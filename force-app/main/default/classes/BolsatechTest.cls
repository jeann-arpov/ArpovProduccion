@isTest
public class BolsatechTest {
    public static testmethod void main() {
        
        Account productor = Test_TestUtils.crearProductor();
        productor.Usuario_Enlist__c = true;
        update productor;

        Movimiento_BolsaTech__c movimiento = new Movimiento_BolsaTech__c();

        movimiento.Estado__c = 'Creado';
        movimiento.Fecha_de_Analisis__c = '15/10/2023';
        movimiento.Cultivo__c = 'SOJA';
        movimiento.Tecnologia__c = 'Enlist';
        movimiento.CTG__c = '123';
        movimiento.Codigo_de_Muestra__c = '123';
        movimiento.Peso_Neto__c = 100;
        movimiento.CUIT_Titular__c = productor.N_CUIT__c;
        movimiento.Cuit_Destinatario__c = productor.N_CUIT__c;

        insert movimiento;

        Bolsatech.validate(movimiento.id);
        
        System.assertEquals('OK', [select Resultado__c from Movimiento_BolsaTech__c where id =: movimiento.id].Resultado__c);
    }
}