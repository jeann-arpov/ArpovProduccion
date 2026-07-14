/*
    Controlador usado en el Componente Liquidacion Auditoría
*/
public class LiquidacionAuditoriaController {
    
    /*
        Atributos privados usados para convertir el total a palabras
    */
    
    private static List<String> grupos =  new List<String>{ '', 'millon','billon','trillon'};
  
    private static List<String> unidades = new List<String>{ '','un','dos','tres','cuatro','cinco','seis','siete','ocho','nueve'};
  
    private static List<String> decenasEspeciales = new List<String>{ '','once','doce','trece','catorce','quince','dieciseis','diecisiete','dieciocho','diecinueve' };
  
    private static List<String> decenas = new List<String>{ '','diez','veinte','treinta','cuarenta','cincuenta','sesenta','setenta','ochenta','noventa'};
  
    private static List<String> centenas = new List<String>{ '','cien','doscientos','trescientos','cuatrocientos',  'quinientos','seiscientos','setecientos','ochocientos','novecientos'};
        
    //Atributo que contendra el valor total expresado en palabras
    public String totalEnPalabras {get; set;}
    
    //Atributo que contendra la oportunidad actual
    public Opportunity oportunity;
    
    //Atributo que contendra la lineas de oportunidad
    public List<OpportunityLineItemWrapper> itemsOportunidad {get; set;}
    
    //Atributo que contendra el tipo de cambio
    public Double tipoDeCambio {get; set;}
    
    public Decimal total {get; set;}
    
    //Getter y Setter del atributo oportunidad
    public void setOportunity(Opportunity oportunity){
        this.oportunity = oportunity;
        init();
    }
    
    public Opportunity getOportunity(){
        return oportunity;
    }
    
    public void init(){
        
        total = 0;
        
        //Coleccionamos los item de las oportunidad
        itemsOportunidad = new List<OpportunityLineItemWrapper>();
        
        for(OpportunityLineItem item : [SELECT Opportunity.Transaccion__r.Cultivo__r.Name,Precio_de_Venta_USD__c, Total_USD__c,UnitPrice, PricebookEntry.Product2.Name, Quantity, TotalPrice, Tipo_de_Cambio__c, Item_Auditoria__r.Motivo__c, Item_Auditoria__r.Campana__r.Name FROM OpportunityLineItem WHERE OpportunityId =:oportunity.Id]){
            
            //Creamos un Wrapper
            OpportunityLineItemWrapper ow = new OpportunityLineItemWrapper(item);

            //Agregamos el item a la lista
            itemsOportunidad.add(ow);    
            
            //Sumarizamos el total
            total += ow.total;
        }
        
        if(itemsOportunidad.size() > 0)
            tipoDeCambio = itemsOportunidad.get(0).tipoDeCambio; 
        
        total = total.setScale(2, RoundingMode.DOWN);


        //Convertimos el total a palabras
        convertirTotalAPalabras(Math.abs((Double)total));
    }
    
    private void convertirTotalAPalabras(Double total){
        
        //Convertimos el total a string
       String valorTotal = String.valueOf(total);
       
       //Separamos la parte decimal de la entera
       String[] valorTotalSeparado = valorTotal.split('\\.'); 
       
       //Varificamos si la parte decimal es distinta de 0
       if(Long.valueOf(valorTotalSeparado.get(1)) == 0)
           totalEnPalabras = numeroAPalabra(Long.valueOf(valorTotalSeparado.get(0)));
       else
           totalEnPalabras = numeroAPalabra(Long.valueOf(valorTotalSeparado.get(0))) +' con '+ numeroAPalabra(Long.valueOf(valorTotalSeparado.get(1))) +' centavos';
       
    }
    
    public static String numeroAPalabra( long n  ){

        
        String resultado = '';
        
        Integer grupo = 0;
        
        if(n == 0)
            return 'cero';
        
        while ( n != 0 && grupo < grupos.size() ) {
        
            Long fragmento = Math.mod(n,1000000);
            Integer millarAlto = (Integer) (fragmento / 1000);
            Integer millarBajo = (Integer) Math.mod(fragmento,1000);
            n = n / 1000000;
            
            String nombreGrupo = grupos[grupo];
            
            if (fragmento > 1 && grupo > 0)
                nombreGrupo += 'es';


            if ((millarAlto != 0) || (millarBajo != 0)) {
            
                if (millarAlto > 1)
                    resultado = millarATexto(millarAlto) + ' mil ' + millarATexto(millarBajo) + ' ' +nombreGrupo + ' ' +resultado;

                if (millarAlto == 0) 
                    resultado = millarATexto(millarBajo) + ' ' + nombreGrupo + ' '+resultado;

                if (millarAlto == 1)
                    resultado = 'mil ' + millarATexto(millarBajo) + ' ' + nombreGrupo + ' ' + resultado;
            }
            grupo++;
        }
        
        return resultado;
    }


    public static String millarATexto( Integer n ) {

        if (n == 0)
            return '';

        Integer cent = n / 100;
        n = Math.mod(n,100);
        Integer dec = n / 10;
        Integer unid = Math.mod(n,10);

        String sufijo = '';

        if ( dec == 0 && unid != 0 ) 
            sufijo = unidades[unid];

        if ( dec == 1 && unid != 0 )
            sufijo = decenasEspeciales[unid];

        if ( dec == 2 && unid != 0 )
            sufijo   = 'veinti'+unidades[unid];

        if ( unid == 0) 
            sufijo = decenas[dec];

        if ( dec > 2 && unid != 0)
            sufijo = decenas[dec] + ' y ' + unidades[unid];

        if (cent != 1)
            return centenas[cent] + ' ' + sufijo;

        if ( unid == 0 && dec == 0)
            return 'cien';

        return 'ciento '+sufijo; 
    }


    public class OpportunityLineItemWrapper {

        //Atributos
        public String cultivo {get; set;}
        public String producto {get; set;}
        public String motivo {get; set;}
        public String campana {get; set;}
        public Double cantidad {get; set;}
        public Decimal regalias  {get; set;}
        public Decimal total {get; set;}
        public Decimal tipoDeCambio {get; set;}

        //Contructor
        public OpportunityLineItemWrapper(OpportunityLineItem o){

            this.cultivo = o.Opportunity.Transaccion__r.Cultivo__r.Name;
            this.producto = o.PricebookEntry.Product2.Name;
            this.motivo = o.Item_Auditoria__r.Motivo__c;
            this.campana = o.Item_Auditoria__r.Campana__r.Name;
            this.cantidad = o.Quantity;
            this.regalias = ((Decimal)o.UnitPrice*1.21).setScale(4, RoundingMode.DOWN);
            this.total = ((Decimal)this.regalias*o.Quantity).setScale(2, RoundingMode.DOWN);
            this.tipoDeCambio = ((Decimal)o.Tipo_de_Cambio__c).setScale(3, RoundingMode.DOWN);

        }

    } 

}