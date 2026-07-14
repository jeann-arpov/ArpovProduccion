global with sharing class VentasObtentorController{
    
    public VentasObtentorController(ApexPages.StandardController controller){
        
    }
    
    @AuraEnabled
    @RemoteAction
    global static List<RowWrapper> getDatos(String accountId, Integer fila, Integer columna, List<String> whereList, Boolean sembraEvolucion){
        
        fila = Integer.valueOf(fila);
        columna = Integer.valueOf(columna);

        List<RowWrapper> filas = new List<RowWrapper>();
        
        try{
            Groupable algoritmo = null;
            
            if(columna == null){
            
                algoritmo = new AgruparPorCultivo();
            
            }else if(columna == 0){
            
                algoritmo = new AgruparPorCampana();

            }else{
                
                algoritmo = new AgruparPorVariedad();
                
            }
            
            if(algoritmo != null){
                filas = algoritmo.groupBy(accountId, fila, columna, whereList, sembraEvolucion);
            }

        }catch(Exception e){

            throw new AuraHandledException(e.getMessage()+' '+e.getStackTraceString());

        }
        
        return filas;
    }

    
    global class RowWrapper{

        @AuraEnabled
        public String cultivo {get; set;}
        @AuraEnabled
        public String campana {get; set;}
        @AuraEnabled
        public String variedad {get; set;}
        @AuraEnabled
        public String tipo {get; set;}
        @AuraEnabled
        public String categoria {get; set;}
        @AuraEnabled
        public String um {get; set;}
        @AuraEnabled
        public Double informadas {get; set;}
        @AuraEnabled
        public Double distribuidor {get; set;}
        @AuraEnabled
        public Double productor {get; set;}
        @AuraEnabled
        public Double porcentajeProductor {get; set;}
        @AuraEnabled
        public Double sinOrigen {get; set;}
        @AuraEnabled
        public String cssClass {get;set;}

    }
    
    
    /*Patron Strategy*/
    
    /*Interface que implementara cada algoritmo de agrupacion*/    
    public interface Groupable {
        
        List<RowWrapper> groupBy(String accountId,Integer fila, Integer columna,String[] whereList, Boolean sembraEvolucion);
        
    }
    
    
    /**
    * @description Metodo que toma los RowWrapper y hace los calculos finales
    * @param lista: RowWrappers a proce
    */
    public static List<RowWrapper> calculateRowWrapper(List<RowWrapper> lista){
        
        //Recorremos los Wrapper y hacemos las cuentas finales
        for(RowWrapper rwp : lista){
        
            //Calculamos el porcentage de productor
            rwp.porcentajeProductor = 0;
            
            if (rwp.informadas > 0){
                rwp.porcentajeProductor += (rwp.productor/rwp.informadas)*100;
            }
               
            //Calculamos el valor de la columna Distribuidor/Comercio
            rwp.distribuidor = rwp.informadas-rwp.distribuidor;
            
            //Calculamos cantidad sin origen
            Double cantidad = rwp.informadas - (rwp.productor+rwp.distribuidor);
            
            rwp.sinOrigen = Math.abs(cantidad);    
            
        }
        
        return lista;
        
    }
    
     
    
    //Clase que Implementara la Agrupacion por cultivo
    public class AgruparPorCultivo implements Groupable{
        
        public List<RowWrapper> groupBy(String accountId,Integer fila, Integer columna,String[] whereList, Boolean sembraEvolucion){
            
            //Lista que contendra las filas a devolver
            List<RowWrapper> filas = new List<RowWrapper>();
            
            List<AggregateResult> ags = new List<AggregateResult>();
            if(sembraEvolucion != null){
                ags = [SELECT Cultivo__r.Name Cultivo FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Producto__r.Variedad2__r.Sembra_Evolucion__c = :sembraEvolucion GROUP BY Cultivo__r.Name ORDER BY Cultivo__r.Name DESC];
            }else{
                ags = [SELECT Cultivo__r.Name Cultivo FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId GROUP BY Cultivo__r.Name ORDER BY Cultivo__r.Name DESC];
            }
            
            //Recorremos las ventas
            for(AggregateResult ag : ags){
                
                //Creamos una nueva fila
                RowWrapper rw = new RowWrapper();
                
                //Seteamos la campaña
                rw.cultivo = String.valueOf(ag.get('Cultivo'));
                
                //Insertamos en la lista de filas a devolver
                filas.add(rw);
            }
            
            return filas;
        }
    }
    
    
    //Clase que Implementara la Agrupacion por campaña
    public class AgruparPorCampana implements Groupable{
        
        public List<RowWrapper> groupBy(String accountId,Integer fila, Integer columna,String[] whereList, Boolean sembraEvolucion){
            
            //Lista que contendra las filas a devolver
            List<RowWrapper> filas = new List<RowWrapper>();
          
            //Variable que contendra la campaña
            String campana = '';
            
            //Variable que contendra cada fila
            RowWrapper rw = null;    

            String cultivoName = whereList[0];

            //Map que contiene las ventas informadas por Ano de CampanaAgricola
            Map<String, Double> informadasByCampana = new Map<String, Double>();

            List<AggregateResult> ags = new List<AggregateResult>();

            if(sembraEvolucion != null){
                ags = [SELECT Campana_Agricola__r.Ano__c CampanaAgricola, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Producto__r.Variedad2__r.Sembra_Evolucion__c = :sembraEvolucion AND Cultivo__r.Name = :cultivoName AND Originante__c = :accountId AND (Venta__c.Tipo_de_Venta__c = 'C' OR Venta__c.Tipo_de_Venta__c = 'CA' )  GROUP BY Campana_Agricola__r.Ano__c];
            }else{
                ags = [SELECT Campana_Agricola__r.Ano__c CampanaAgricola, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Cultivo__r.Name = :cultivoName AND Originante__c = :accountId AND (Venta__c.Tipo_de_Venta__c = 'C' OR Venta__c.Tipo_de_Venta__c = 'CA' )  GROUP BY Campana_Agricola__r.Ano__c];
            }

            for(AggregateResult ag : ags){

                String auxCampana = String.valueOf(ag.get('CampanaAgricola'));
                Double cantidad = Double.valueOf(ag.get('Cantidad'));

                informadasByCampana.put(auxCampana, cantidad);

            }

            Set<String> filtroVentas = new Set<String>{'Venta','TDS','TM','TC','NC'}; 

            if(sembraEvolucion != null){
                ags = [SELECT Campana_Agricola__r.Ano__c CampanaAgricola, Tipo_de_Venta__c TipoVenta, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Producto__r.Variedad2__r.Sembra_Evolucion__c = :sembraEvolucion AND Cultivo__r.Name = :cultivoName AND Tipo_de_Venta__c IN :filtroVentas GROUP BY Campana_Agricola__r.Ano__c, Tipo_de_Venta__c ORDER BY Campana_Agricola__r.Ano__c DESC];
            }else{
                ags = [SELECT Campana_Agricola__r.Ano__c CampanaAgricola, Tipo_de_Venta__c TipoVenta, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Cultivo__r.Name = :cultivoName AND Tipo_de_Venta__c IN :filtroVentas GROUP BY Campana_Agricola__r.Ano__c, Tipo_de_Venta__c ORDER BY Campana_Agricola__r.Ano__c DESC];
            }
            
            //Recorremos las ventas
            for(AggregateResult ag : ags){
                
                String auxCampana = String.valueOf(ag.get('CampanaAgricola'));

                Double cantidad = Double.valueOf(ag.get('Cantidad'));

                String tipoVenta = String.valueOf(ag.get('TipoVenta'));

                if( (campana == '') || (campana != auxCampana )  || (rw == null)){
                    
                    //Creamos una nueva fila
                    rw = new RowWrapper();
                    
                    //Seteamos la campaña
                    rw.campana = auxCampana;

                    rw.informadas = 0;
                    
                    if(informadasByCampana.containsKey(auxCampana)){

                        //Seteamos las cantidades en 0
                        rw.informadas = informadasByCampana.get(auxCampana);

                    }
                    
                    rw.productor = 0;
                    
                    rw.distribuidor = 0;
                    
                    rw.sinOrigen = 0;
                    
                    //Seteamos la campaña
                    campana = auxCampana;
                    
                    //Insertamos en la lista de filas a devolver
                    filas.add(rw);

                }
                    
                //Distribuidor/Comercio
          
                rw.distribuidor += cantidad;
                    
                
                if(tipoVenta == 'Venta'){
                    
                    rw.productor += cantidad;
                    
                }
                 
                
            }
            
            
        
            return calculateRowWrapper(filas);
            
        }
    
    }
    
    //Clase que Implementara la Agrupacion por variedad
    public class AgruparPorVariedad implements Groupable{
        
        public List<RowWrapper> groupBy(String accountId,Integer fila, Integer columna,String[] whereList, Boolean sembraEvolucion){
            //Lista que contendra las filas a devolver
            List<RowWrapper> filas = new List<RowWrapper>();

            String cultivoName = whereList[0];

            String campanaAno = whereList[1];
            
            //Variable que contendra la variedad
            String variedad = '';
            //Variable que contendra el tipo de producto
            String tipo = '';
            //Variable que contendra la categoria del producto
            String categoria = '';
            //Variable que contendra la unidad de medida del producto
            String um = '';


            //Map que contiene las ventas informadas por Ano de CampanaAgricola
            Map<String, Map<String, Map<String,Map< String, Double >>>> informadas = new Map<String, Map<String, Map<String,Map< String, Double >>>>();

            Set<String> filtros = new Set<String>{'CA','C','DPD','DPO','TDD','TDS'};

            List<AggregateResult> ags = new List<AggregateResult>();
            if(sembraEvolucion != null){
                ags = [SELECT Producto__r.Variedad__c Variedad, Producto__r.Family TipoProducto, Producto__r.Categoria__c Categoria, Producto__r.Unidad_de_Medida__c UnidadMedida, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Producto__r.Variedad2__r.Sembra_Evolucion__c = :sembraEvolucion AND Cultivo__r.Name = :cultivoName AND Campana_Agricola__r.Ano__c = :campanaAno AND Originante__c = :accountId AND Venta__c.Tipo_de_Venta__c = :filtros GROUP BY Producto__r.Variedad__c, Producto__r.Family, Producto__r.Categoria__c, Producto__r.Unidad_de_Medida__c];
            }else{
                ags = [SELECT Producto__r.Variedad__c Variedad, Producto__r.Family TipoProducto, Producto__r.Categoria__c Categoria, Producto__r.Unidad_de_Medida__c UnidadMedida, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Cultivo__r.Name = :cultivoName AND Campana_Agricola__r.Ano__c = :campanaAno AND Originante__c = :accountId AND Venta__c.Tipo_de_Venta__c = :filtros GROUP BY Producto__r.Variedad__c, Producto__r.Family, Producto__r.Categoria__c, Producto__r.Unidad_de_Medida__c];
            }

            for(AggregateResult ag : ags){

                String auxVariedad = String.valueOf(ag.get('Variedad'));

                String auxTipoProducto = String.valueOf(ag.get('TipoProducto'));

                String auxCategoria = String.valueOf(ag.get('Categoria'));

                String auxUnidadMedida = String.valueOf(ag.get('UnidadMedida'));

                Double cantidad = Double.valueOf(ag.get('Cantidad'));

                if(!informadas.containsKey(auxVariedad)){

                    informadas.put(auxVariedad, new Map<String, Map<String,Map< String, Double >>>());

                }

                if(!informadas.get(auxVariedad).containsKey(auxTipoProducto)){

                    informadas.get(auxVariedad).put(auxTipoProducto, new Map<String,Map< String, Double >>());

                }

                if(!informadas.get(auxVariedad).get(auxTipoProducto).containsKey(auxCategoria)){

                    informadas.get(auxVariedad).get(auxTipoProducto).put(auxCategoria, new Map<String, Double>());

                }

                if(!informadas.get(auxVariedad).get(auxTipoProducto).get(auxCategoria).containsKey(auxUnidadMedida)){

                    informadas.get(auxVariedad).get(auxTipoProducto).get(auxCategoria).put(auxUnidadMedida, cantidad);

                }

            }
            
            //Variable que contendra cada fila
            RowWrapper rw = null;

            Set<String> filtroVentas = new Set<String>{'Venta','TDS','TM','TC','DPD','DPO','TDD'}; 

            if(sembraEvolucion != null){
                ags = [SELECT Producto__r.Variedad__c Variedad, Producto__r.Family TipoProducto, Producto__r.Categoria__c Categoria, Producto__r.Unidad_de_Medida__c UnidadMedida, Tipo_de_Venta__c TipoVenta, Producto__r.Variedad2__r.Sembra_Evolucion__c SembraEvolucion, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Producto__r.Variedad2__r.Sembra_Evolucion__c = :sembraEvolucion AND Cultivo__r.Name = :cultivoName AND Campana_Agricola__r.Ano__c = :campanaAno AND Tipo_de_Venta__c IN :filtroVentas GROUP BY Producto__r.Variedad__c, Producto__r.Family, Producto__r.Categoria__c, Producto__r.Unidad_de_Medida__c,Tipo_de_Venta__c, Producto__r.Variedad2__r.Sembra_Evolucion__c];
            }else{
                ags = [SELECT Producto__r.Variedad__c Variedad, Producto__r.Family TipoProducto, Producto__r.Categoria__c Categoria, Producto__r.Unidad_de_Medida__c UnidadMedida, Tipo_de_Venta__c TipoVenta, Producto__r.Variedad2__r.Sembra_Evolucion__c SembraEvolucion, SUM(Cantidad_Bolsas_40__c) Cantidad FROM Venta__c WHERE Producto__r.Obtentor_Comercializa__c = :accountId AND Cultivo__r.Name = :cultivoName AND Campana_Agricola__r.Ano__c = :campanaAno AND Tipo_de_Venta__c IN :filtroVentas GROUP BY Producto__r.Variedad__c, Producto__r.Family, Producto__r.Categoria__c, Producto__r.Unidad_de_Medida__c,Tipo_de_Venta__c, Producto__r.Variedad2__r.Sembra_Evolucion__c];
            }
            
            //Recorremos las ventas
            for(AggregateResult ag : ags){
                
                String auxVariedad = String.valueOf(ag.get('Variedad'));

                String auxTipoProducto = String.valueOf(ag.get('TipoProducto'));

                String auxCategoria = String.valueOf(ag.get('Categoria'));

                String auxUnidadMedida = String.valueOf(ag.get('UnidadMedida'));

                String tipoVenta = String.valueOf(ag.get('TipoVenta'));

                Double cantidad = Double.valueOf(ag.get('Cantidad'));

                Boolean sembraEvolucionValue = Boolean.valueOf(ag.get('SembraEvolucion'));

                if( (variedad == '' && tipo == '' && categoria == '' && um == '') || (variedad != auxVariedad || tipo != auxTipoProducto || categoria != auxCategoria || um != auxUnidadMedida )  || (rw == null)){
                    
                    //Creamos una nueva fila
                    rw = new RowWrapper();
                    
                    //Seteamos la variedad deproducto
                    rw.variedad = auxVariedad;
                    
                    //Seteamos el tipo de producto
                    rw.tipo = auxTipoProducto;
                    
                    //Seteamoas la categoria del producto
                    rw.categoria = auxCategoria;
                    
                    //Seteamos la unidad de medida
                    rw.um = auxUnidadMedida;
                    
                    //Seteamos las cantidades en 0
                    rw.informadas = 0;
                    
                    if(informadas.containsKey(auxVariedad)){

                        if(informadas.get(auxVariedad).containsKey(auxTipoProducto)){

                            if(informadas.get(auxVariedad).get(auxTipoProducto).containsKey(auxCategoria)){

                                if(informadas.get(auxVariedad).get(auxTipoProducto).get(auxCategoria).containsKey(auxUnidadMedida)){

                                    rw.informadas = informadas.get(auxVariedad).get(auxTipoProducto).get(auxCategoria).get(auxUnidadMedida);

                                }
                                

                            }

                        }

                    }


                    rw.productor = 0;
                    
                    rw.distribuidor = 0;
                    
                    rw.sinOrigen = 0;
                    
                    //Seteamos la variedad deproducto
                    variedad = auxVariedad;
                    
                    //Seteamos el tipo de producto
                    tipo = auxTipoProducto;
                    
                    //Seteamoas la categoria del producto
                    categoria = auxCategoria;
                    
                    //Seteamos la unidad de medida
                    um = auxUnidadMedida;
                    
                    //Insertamos en la lista de filas a devolver
                    filas.add(rw);

                    rw.cssClass = sembraEvolucion == null && sembraEvolucionValue ? 'se' : '';

                }
                    
                //Distribuidor/Comercio
                rw.distribuidor += cantidad;

                if(tipoVenta == 'Venta'){
                    
                    rw.productor += cantidad;
                    
                }
                
            }
           
            
            return calculateRowWrapper(filas);
        }
    
    }

}