/**
* @author Maximo Martinez
* @date 8/30/2014
* @description Clase de Test de la Clase EncryptionUtils
*/
@isTest
public class Test_EncryptionUtils{
    /**
    * @description Método de Test
    */
    public static testmethod void test(){
        
        String dataEncrypted = EncryptionUtils.encrypt('hello world');
        
        String dataDecrypted = EncryptionUtils.decrypt(dataEncrypted);
    	
        System.assertEquals('hello world', dataDecrypted);
    }
}