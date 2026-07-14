/**
* @author Maximo Martinez
* @date 9/6/2014
* @description Clase de Test de la Clase BarcodeI25
*/
@isTest
public class Test_Barcode{
    
    /*
    * @description Método de Test Algoritmo I25
    */
    public static testmethod void testBarcodeI25(){
        
        //Instanciamos el controlador
        BarcodeController bc = new BarcodeController();
        
        //Seteamos los valores necesarios
        
        //La codificacion sera i25
        bc.code = 'i25';
        
        //El valor a codificar sera
        bc.value = '626643186054';
        
        //Indicamos que usaremos un digito de checkeo
        bc.checkDigit = 1;
        
        //Obtenemos el codigo de barras generado
        System.Debug(LoggingLevel.INFO,bc.getBarcode());
        
        //Indicamos que no usaremos digito de checkeo
        bc.checkDigit = 0;
        
        //El valor a codificar sera
        bc.value = '626643186054AHHA123KAOT1928';
        
        //Obtenemos el codigo de barras generado
        System.Debug(LoggingLevel.INFO,bc.getBarcode());
        
        //Indicamos que no usaremos digito de checkeo
        bc.checkDigit = 0;
        
        //El valor a codificar sera
        bc.value = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890';
        
         //Obtenemos el codigo de barras generado
        System.Debug(LoggingLevel.INFO,bc.getBarcode());
        
        //Indicamos que no usaremos digito de checkeo
        bc.checkDigit = 0;
        
        //El valor a codificar sera
        bc.value = '123456789!"#$%&/()=?¡*[]}{-:_;.,-^`ABCDEFGHIJKLMNOPQRSTUVW';
        
         //Obtenemos el codigo de barras generado
        System.Debug(LoggingLevel.INFO,bc.getBarcode());
        
        //Indicamos que no usaremos digito de checkeo
        bc.checkDigit = 0;
        
        //El valor a codificar sera
        bc.value = '123456789!"#$123456789!"#$%&/()=?¡*[]}{-:_;.,-^`ABCDEFGHIJKLMNOPQRSTUVW%&/()=?¡*[]}{123456789!"#$%&/()=?¡*[]}{-:_;.,-^`ABCDEFGHIJKLMNOPQRSTUVW-:_;.,-^`ABCDEFGH123456789!"#$%&/()=?¡*[]}{-:_;.,-^`ABCDEFGHIJKLMNOPQRSTUVWIJKLMNOPQRSTUVW';
        
         //Obtenemos el codigo de barras generado
        System.Debug(LoggingLevel.INFO,bc.getBarcode());
        
        //Indicamos que no usaremos digito de checkeo
        bc.checkDigit = 0;
        
        //El valor a codificar sera
        bc.value = '"YUAiai1oáéíóúÁÉÍÓÚOQPEO#rq%&(19*++)182-_}[]Q@:;,:))!!9922129FFGTQ*ñÑ<¡&/%)+-/*->:6==1293¡¡¡13ncjs145-;,,,,,[[][[{}{}´++****¨?¿¡°|¬h/10s0a1?="381kskqa(/%GT1523bv%Ee';
        
         //Obtenemos el codigo de barras generado
        System.Debug(LoggingLevel.INFO,bc.getBarcode());
            
    }
    
  
}