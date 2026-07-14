@isTest
public class BatchApexRevertirTNMarcadas_Test {
    @TestSetup
    static void makeData(){
        Account prod = new Account(
            Name = 'Prod Test'
        );
        insert prod;
        List<Tonelada__c> toneladas = new List<Tonelada__c>();
        for (Integer i = 0; i < 200; i++){
            Tonelada__c ton = new Tonelada__c(
                Tonelada_Anterior__c = false,
                Cantidad__c = i,
                Productor__c = prod.Id
            );
            toneladas.add(ton);
        }

        insert toneladas;

        
        for(Tonelada__c ton : toneladas){
            ton.Tonelada_Anterior__c = true;
        }

        update toneladas;

    }

    @isTest
    static void testReversionToneladas(){
        List<Tonelada__History> tonsH = new List<Tonelada__History>();
        for (Tonelada__c ton :[SELECT Id,Tonelada_Anterior__c FROM Tonelada__c]){
            Assert.areEqual(true, ton.Tonelada_Anterior__c, 'La tonelada anterior debe ser true');
            Tonelada__History tonh = new Tonelada__History(
                ParentId = ton.Id
            );
            tonsH.add(tonh);
        }
    
        test.startTest();
        database.executebatch(new BatchApexRevertirTNMarcadas(tonsH), 200);
        test.stopTest();

        for(Tonelada__c ton : [SELECT Id, Tonelada_Anterior__c FROM Tonelada__c]){
            Assert.areEqual(false, ton.Tonelada_Anterior__c, 'La tonelada no se ha revertido');
        }
    }
}