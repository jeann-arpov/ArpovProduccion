/**
* @author Maximo Martinez
* @date 8/30/2014
* @description Clase Utils Relacionada Con el Manejo de Token, para acceder al portal Declaraciones Online
*/
public class Utils{

    public static Schema.SObjectType getObjectTypeById(String input){

        Id someId = (String.isNotEmpty(input)) ? Id.valueOf(input) : null;

        return (String.isNotEmpty(input)) ? someId.getSobjectType() : null ;

    }


    public static Schema.SObjectType getObjectTypeByObjectName(String input){
        
        Map<String, Schema.SObjectType> globalDescribeMap = Schema.getGlobalDescribe(); 
       
        return GlobalDescribeMap.get(input);
    
    }

    public static String createToken(Id idProductor){
        String generatedToken = EncryptionUtils.encrypt(idProductor);
        String url = EncodingUtil.urlEncode(generatedToken, 'UTF-8');
        return url;
    }
    
    public static String decryptToken(String url){
        if(Test.isRunningTest()){
            url = EncodingUtil.urlDecode(url, 'UTF-8');
        }
        
        String generatedToken = EncryptionUtils.decrypt(url);
        
        return generatedToken;
    }
    
    public static void setearTokenProductores(List<Account> lista){
        
         
        //Set que contendra los ids de las cuentas
        Set<Id> idsCuentas = new Set<Id>();
        
        //Lista que contendra los productores a generar token
        List<Account> toUpdate = new List<Account>();
        
        for(Account cuenta : lista){
            idsCuentas.add(cuenta.Id);
        }

        //Recorremos las cuentas
        for(Account cuenta : [SELECT Id, RecordTypeId, Token_de_Seguridad__c FROM Account WHERE  Id IN :idsCuentas]){
            
            if(cuenta.Token_de_Seguridad__c == null){
                //Generamos el token del productor
                cuenta.Token_de_Seguridad__c = createToken(cuenta.Id);
                
                //Agregamos a la lista de updates
                toUpdate.add(cuenta);
            }
        }
        
        if(toUpdate.size() > 0){
          //Llamamos al metodo de actualizacion por lotes
          updateList(toUpdate);    
        }
    
    }
    
    public static void updateList(List<Account> lista){
    
        List<Account> toUpdate = new List<Account>();
        for(Account a : lista){
            toUpdate.add(a);
        
            if(toUpdate.size() == 200){
                update toUpdate;
                toUpdate.clear();
            }
        }
        
        if(toUpdate.size() > 0){
            update toUpdate;
            toUpdate.clear();
        }

    }


    /**
    * @author Maximo Martinez
    * @date 16/09/2014
    * @description Metodo que transforma un string en formato dd/mm/yyyy a un date
    */ 
    public static Date stringToDate(String s){

        try{
            String[] stringDate = s.split('/');
            Integer d =  Integer.valueOf(stringDate[0]);
            Integer m = Integer.valueOf(stringDate[1]);
            Integer y = Integer.valueOf(stringDate[2]);     
            return date.newInstance(y,m,d);
        }catch(Exception e){
            return null;
        }    
    }

    /**
    * @author Maximo Martinez
    * @date 16/09/2014
    * @description Metodo que toma un string y lo pasa a double
    */ 
    public static Double stringToDouble(String s){

        //Creamos una expresion regular para validar que sea un double valido
        Pattern pat = Pattern.compile('[0-9]*\\.?[0-9]+');

        Matcher mat = pat.matcher(s);

        //Verificamos si es valido
        if(mat.matches()){
            return Double.valueOf(s);
        }

        return null;
        
    }


    /**
    * @author Maximo Martinez
    * @date 14/10/2014
    * @description Metodo que retorna un numero aleatorio
    */
    public static Long getRandomLong(Integer length){
        return Math.roundToLong(Math.random()*Math.pow(10, length));
    }


    /**
    * @author Maximo Martinez
    * @date 16/10/2014
    * @description Metodo que actua como un SELECT * FROM X
    */
    public static String selectByName(String objectName,  String additionalFilters){
        
        //get object fields
        List<String> fieldList = new List<String>(Schema.getGlobalDescribe()
                               .get(objectName).getDescribe().fields.getMap().keySet());
        String fields = String.join(fieldList,',');
        
        return 'SELECT '+fields+' FROM '+objectName+ ' '+additionalFilters;
    
    } 

    /**
    * @author Maximo Martinez
    * @date 27/10/2014
    * @description Metodo que retorna el id del pricebook activo dependiendo del conexto en el que este
    */
    public static Id getPricebook2Id(){

        //Variable que contendra el id de la lista de precios
        Id idPriceBook = null;

        if(!Test.isRunningTest()){
        
            //Obtenemos la lista de precios standard del sitio
            Pricebook2 listaPrecios = [SELECT Id FROM Pricebook2 WHERE IsStandard = true AND IsActive = true LIMIT 1];
            
            idPriceBook = listaPrecios.Id;
        }else{

            idPriceBook = Test.getStandardPricebookId();

        }

        return idPriceBook;
    }


    /**
    * @author Maximo Martinez
    * @date 27/10/2014
    * @description Metodo que retorna el id de un Group por su tipo y developer name
    */
    public static Id getGroupId(String developerName, String type){
        List<Group> groups = [SELECT Id FROM Group WHERE DeveloperName = :developerName AND Type =:type LIMIT 1];

        if(groups.size() > 0)
            return groups.get(0).Id;
        else
            return null;    
    }

    /**
    * @author Maximo Martinez
    * @date 07/11/2014
    * @description Metodo que verifica que una cadena se encuentra en una cadena a splitear
    */
    public static Boolean checkStringInToSplit(String toSplit, String toFind){
        if(!String.isEmpty(toSplit)){
            Set<String> splited = new Set<String>(toSplit.split('/'));
            return splited.contains(toFind);
        }
        return false;
    }


    /**
    * @author Maximo Martinez
    * @date 06/11/2014
    * @description Metodo de Actualizacion por lotes
    */
    public static void updateList(List<SObject> lista){
        
        updateList(lista, true);
        
    }

    /**
    * @author Maximo Martinez
    * @date 06/11/2014
    * @description Metodo de Insert por lotes
    */
    public static void insertList(List<SObject> lista){
        
        insertList(lista, true);
        
    }

    /**
    * @author Maximo Martinez
    * @date 19/06/2015
    * @description Metodo que hace inserciones parciales por lotes, retorna una lista de SaveResult
    * @param lista : lista de Sobject a Insertar en la Base de Datos
    * @param allOrNothing, indica que si hay un error se detenga la insercion (true) o que si hay un error se prosiga con el siguiente (false)
    */
    public static List<Database.SaveResult> insertList(List<SObject> lista, Boolean allOrNothing){

        List<SObject> toInsert = new List<SObject>();
        
        List<Database.SaveResult> results = new List<Database.SaveResult>();
        
        for(SObject o : lista){
            toInsert.add(o);
                
            if(toInsert.size() == Limits.getLimitDMLRows()){
                results.addAll(Database.insert(toInsert,allOrNothing));
                toInsert.clear();
            }
        }

        if(toInsert.size() > 0){
            results.addAll(Database.insert(toInsert,allOrNothing));
            toInsert.clear();
        }

        return results;

    }

    /**
    * @author Maximo Martinez
    * @date 19/06/2015
    * @description Metodo que hace eliminaciones parciales por lotes, retorna una lista de DleeteResult
    * @param lista : lista de Sobject a Eliminar de la Base de Datos
    * @param allOrNothing, indica que si hay un error se detenga la eliminacion (true) o que si hay un error se prosiga con el siguiente (false)
    */
    public static List<Database.DeleteResult> deleteList(List<SObject> lista, Boolean allOrNothing){

        List<SObject> toDelete = new List<SObject>();
        
        List<Database.DeleteResult> results = new List<Database.DeleteResult>();
        
        for(SObject o : lista){
            toDelete.add(o);
                
            if(toDelete.size() == Limits.getLimitDMLRows()){
                results.addAll(Database.delete(toDelete,allOrNothing));
                toDelete.clear();
            }
        }

        if(toDelete.size() > 0){
            results.addAll(Database.delete(toDelete,allOrNothing));
            toDelete.clear();
        }

        return results;

    }

    /**
    * @author Maximo Martinez
    * @date 21/10/2015
    * @description Metodo que hace actualizaciones parciales por lotes, retorna una lista de SaveResult
    * @param lista : lista de Sobject a actualizar de la Base de Datos
    * @param allOrNothing, indica que si hay un error se detenga la actualizacion (true) o que si hay un error se prosiga con el siguiente (false)
    */
    public static List<Database.SaveResult> updateList(List<SObject> lista, Boolean allOrNothing){

        List<SObject> toUpdate = new List<SObject>();
        
        List<Database.SaveResult> results = new List<Database.SaveResult>();
        
        for(SObject o : lista){
            toUpdate.add(o);
                
            if(toUpdate.size() == Limits.getLimitDMLRows()){
                results.addAll(Database.update(toUpdate,allOrNothing));
                toUpdate.clear();
            }
        }

        if(toUpdate.size() > 0){
            results.addAll(Database.update(toUpdate,allOrNothing));
            toUpdate.clear();
        }

        return results;

    }


    /**
    * @author Maximo Martinez
    * @date 04/12/2018
    * @description Realisa un upsert de una lista de objetos CustIdByUser
    * @para lista : Lista de objetos CustIdByUser para realizar upsert
    */
    public static List<Database.UpsertResult> upsertList(List<Documento_Gestionado__c> lista, Boolean allOrNothing){

        List<Database.UpsertResult> uprs = new List<Database.UpsertResult>();

        List<Documento_Gestionado__c> toUpsert = new List<Documento_Gestionado__c>();
        
        for(Documento_Gestionado__c o : lista){
            toUpsert.add(o);
        
            if(toUpsert.size() == 200){

                uprs.addAll(Database.upsert(toUpsert, allOrNothing));
            
                toUpsert.clear();
            
            }
        }
        
        if(toUpsert.size() > 0){
        
            uprs.addAll(Database.upsert(toUpsert, allOrNothing));

            toUpsert.clear();
        
        }

        return uprs;

    }


    /**
    * @author Maximo Martinez
    * @date 04/12/2018
    * @description Realisa un upsert de una lista de objetos CustIdByUser
    * @para lista : Lista de objetos CustIdByUser para realizar upsert
    */
    public static List<Database.UpsertResult> upsertList(List<Interaccion__c> lista, Boolean allOrNothing){

        List<Database.UpsertResult> uprs = new List<Database.UpsertResult>();

        List<Interaccion__c> toUpsert = new List<Interaccion__c>();
        
        for(Interaccion__c o : lista){
            toUpsert.add(o);
        
            if(toUpsert.size() == 200){

                uprs.addAll(Database.upsert(toUpsert, allOrNothing));
            
                toUpsert.clear();
            
            }
        }
        
        if(toUpsert.size() > 0){
        
            uprs.addAll(Database.upsert(toUpsert, allOrNothing));

            toUpsert.clear();
        
        }

        return uprs;

    }

    /**
    * @author Maximo Martinez
    * @date 12/04/2018
    * @description Realisa un upsert de una lista de objetos CustIdByUser
    * @para lista : Lista de objetos CustIdByUser para realizar upsert
    */
    public static List<Database.UpsertResult> upsertList(List<Interaccion_Nueva__c> lista, Boolean allOrNothing){

        List<Database.UpsertResult> uprs = new List<Database.UpsertResult>();

        List<Interaccion_Nueva__c> toUpsert = new List<Interaccion_Nueva__c>();
        
        for(Interaccion_Nueva__c o : lista){
            toUpsert.add(o);
        
            if(toUpsert.size() == 200){

                uprs.addAll(Database.upsert(toUpsert, allOrNothing));
            
                toUpsert.clear();
            
            }
        }
        
        if(toUpsert.size() > 0){
        
            uprs.addAll(Database.upsert(toUpsert, allOrNothing));

            toUpsert.clear();
        
        }

        return uprs;

    }
    
    public static String numberFormat(String numberString){
    
        System.Debug('numberFormat(String numberString)');
        System.Debug('numberString: ' + numberString);
        
        Decimal value = 1000.10;
        String formattedValue = value.format();
        String thousandSep = formattedValue.substring(1,2);
        String decimalSep = formattedValue.substring(5,6);
        
        Integer comaPosition = numberString.lastIndexOf(decimalSep);
        if(comaPosition == -1){
            return numberString + decimalSep + '00';
        }
        String subDecimal = numberString.substring(comaPosition);
        if(subDecimal.length() < 3){
            return numberString + '0';
        }
        return numberString;
        
    }


    /**
    * @author Maximo Martinez
    * @date 11/02/2016
    * @description Metodo que hace formatea un decimal, para que se imprima con el formato del número que es con punto agrupador y coma decimal
    */
    public static String formatNumber(Decimal dec){
    
        System.Debug('formatNumber(Decimal dec)');
        System.Debug('dec: ' + dec);
    
        String n = (dec.format().contains(','))?dec.format():(dec.format()+',00');
        
        return (n.split(',')[1].length() == 1)?n+'0':n;    

    }


    /**
    * @author Maximo Martinez
    * @date 21/01/2016
    * @description Metodo que transforma un Id de 15 a 18
    */
    public static String fifteenToEighteen(String id){
        
        String suffix = '';
        Integer flags;
    
        for (integer i = 0; i < 3; i++) {
              flags = 0;
              for (integer j = 0; j < 5; j++) {
                   string c = id.substring(i * 5 + j,i * 5 + j + 1);
                   //Only add to flags if c is an uppercase letter:
                   if (c.toUpperCase().equals(c) && c >= 'A' && c <= 'Z') {
                        flags = flags + (1 << j);
                   }
              }
              if (flags <= 25) {
                   suffix = suffix + 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.substring(flags,flags+1);
              }else{
                   suffix = suffix + '012345'.substring(flags-25,flags-24);
              }
         }
         
         System.Debug(LoggingLevel.INFO,id+suffix);
         
         return id+suffix;
    
    }

    /**
    * @author Maximo Martinez
    * @date 04/02/2016
    * @description Metodo que transforma un valor a palabras
    */
    public static String convertirTotalAPalabras(Decimal total){
        
        System.Debug('convertirTotalAPalabras(Decimal total)');
        System.Debug('total: ' + total);
        
        String valorTotal = '';
        String menos = '';

        if(total == null){
            return valorTotal;
        }
        
        if(total < 0){
            total = total * -1;
            menos = 'Menos ';
        }

        //Convertimos el total a string
        valorTotal = String.valueOf(total);
       
        //Separamos la parte decimal de la entera
        String[] valorTotalSeparado = valorTotal.split('\\.'); 
       
        //Varificamos si la parte decimal es distinta de 0
        if(Long.valueOf(valorTotalSeparado.get(1)) == 0){
           return menos + numeroAPalabra(Long.valueOf(valorTotalSeparado.get(0)));
        }else{
           return menos + numeroAPalabra(Long.valueOf(valorTotalSeparado.get(0))) +' con '+ numeroAPalabra(Long.valueOf(valorTotalSeparado.get(1))) +' centavos';
        }
       
    }
    
    /**
    * @author Maximo Martinez
    * @date 04/02/2016
    * @description Metodo que transforma un numero a una palabra
    */
    private static String numeroAPalabra( long n  ){
    
        System.Debug('numeroAPalabra(long n)');
        System.Debug('n: ' + n);

        List<String> grupos =  new List<String>{ '', 'millon','billon','trillon'};
        
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

    /**
    * @author Maximo Martinez
    * @date 04/02/2016
    * @description Metodo que transforma un millar a una palabra
    */
    private static String millarATexto( Integer n ) {

        System.Debug('millarATexto(Integer n)');
        System.Debug('n: ' + n);
        
        List<String> unidades = new List<String>{ '','un','dos','tres','cuatro','cinco','seis','siete','ocho','nueve'};
        List<String> decenasEspeciales = new List<String>{ '','once','doce','trece','catorce','quince','dieciseis','diecisiete','dieciocho','diecinueve' };
        List<String> decenas = new List<String>{ '','diez','veinte','treinta','cuarenta','cincuenta','sesenta','setenta','ochenta','noventa'};
        List<String> centenas = new List<String>{ '','cien','doscientos','trescientos','cuatrocientos',  'quinientos','seiscientos','setecientos','ochocientos','novecientos'};

        if (n == 0){
            return '';
        }

        Integer cent = n / 100;
        n = Math.mod(n,100);
        Integer dec = n / 10;
        Integer unid = Math.mod(n,10);

        String sufijo = '';

        if ( dec == 0 && unid != 0 ){
            sufijo = unidades[unid];
        }

        if ( dec == 1 && unid != 0 ){
            sufijo = decenasEspeciales[unid];
        }

        if ( dec == 2 && unid != 0 ){
            sufijo   = 'veinti'+unidades[unid];
        }

        if ( unid == 0){
            sufijo = decenas[dec];
        }

        if ( dec > 2 && unid != 0){
            sufijo = decenas[dec] + ' y ' + unidades[unid];
        }

        if (cent != 1){
            return centenas[cent] + ' ' + sufijo;
        }

        if ( unid == 0 && dec == 0){
            return 'cien';
        }

        return 'ciento '+sufijo; 
    }

    /**
    * @author Maximo Martinez
    * @date 04/07/2016
    * @description Devuelve el lenght de un campo
    */
    public static Integer getFieldLength(String objectName, String fieldName){

        Map<String, Schema.SObjectField> fMap = Schema.getGlobalDescribe().get(objectName.toLowerCase()).getDescribe().Fields.getMap();
        List<string> selectFields = new list<string>(); 
        
        Schema.DescribeFieldResult fd = null;

        if (fMap != null){
            for (Schema.SObjectField ft : fMap.values()){
                fd = ft.getDescribe(); 
                if(fd.getName().toLowerCase()==fieldName.toLowerCase()){
                    break;
                }
            }
        }

        if(fd == null){
            return 0;
        }

        if(fd.getType() == Schema.DisplayType.String){
            return fd.getLength();
        }else if(fd.getType() == Schema.DisplayType.Integer){
            return fd.getDigits();
        }else{
            return 0;
        }

    }    


    /**
    * @author Maximo Martinez
    * @date 24/01/2018
    * @description Metodo que formatea un numero en decimal
    * @return Numero formateado
    */
    public static String doFormatting(Decimal val, integer dec, String tSep, String dSep) {
        String s, tmp;
        Integer i = 4 + dec;
     
        // If the number of decimals is zero (0)... prevents the first 1000s seperator from being set at the 4th.
        if(dec==0){
            i--;
        }
     
        s = val.setScale(dec).toPlainString().replace(tSep, dSep);
        while(s.length() > i) {
            tmp = s.substring(0, s.length() - i) + tSep + s.substring(s.length() - i);
            s = tmp;
            i += 4;
        }
     
        // If the number is negative and has a number non-decimal digits divisible by 3, it prevents putting a comma before the 1st digit (ex -300,000.00  comes out -,300,000.00)
        if (s.substring(0,1) == '-') {
            if (s.substring(1,2) == tSep) {
                s = '-' + s.substring(2);
            }
        }
     
        return s;
    }
    
}