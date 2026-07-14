public without sharing class GraficoSemillaController {

    @AuraEnabled(cacheable=true)
    public static List<Data> getData(String campaignName){
        List<Data> result = new List<Data>();

        for(AggregateResult ag : [
                            SELECT Producto__r.Grupo_de_Madurez_Ciclo_Ag__c madurez, SUM(Cantidad_Bolsas_40__c) semillas FROM Venta__c 
                            WHERE Tipo_de_producto__c = 'Semilla Fiscalizada' AND 
                                  Campana_Agricola__r.Name =: campaignName AND
                                  Tipo_de_Venta__c = 'Venta' AND
                                  Producto__r.Categoria__c IN ('Primera Multiplicación', 'Segunda Multiplicación', 'Tercera Multiplicación', 'Original o Fundadora') 
                            GROUP BY Producto__r.Grupo_de_Madurez_Ciclo_Ag__c]){

            Data dt = new Data();
            dt.label = String.valueOf(ag.get('madurez'));
            dt.semillas = Double.valueOf(ag.get('semillas'));

            result.add(dt);

        }

        return result;

    }

    public class Data{
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Double semillas;
    }

}