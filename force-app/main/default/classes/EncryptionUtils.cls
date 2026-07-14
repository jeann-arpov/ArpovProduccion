global with sharing class EncryptionUtils {
    public static String encrypt(String dataToEncrypt){
        generateBaseKey(); 
        if(dataToEncrypt != null){
          // Get the private key
          Blob cryptoKey = EncodingUtil.base64Decode(Crypto_Key__c.getOrgDefaults().Key__c);
       
          // Generate the data to be encrypted.
          Blob data = Blob.valueOf(dataToEncrypt);
      
          // Encrypt the data and have Salesforce.com generate the initialization vector
          Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, data);
      
          return EncodingUtil.base64Encode(encryptedData);
        }else{
          return null;
        }  
    }
  
    public static String decrypt(String dataToDecrypt){
        generateBaseKey();
        
        if(dataToDecrypt != null){
          // Get the private key
          Blob cryptoKey = EncodingUtil.base64Decode(Crypto_Key__c.getOrgDefaults().Key__c);
          
          // Generate the data to be decrypted.
          Blob encryptedData = EncodingUtil.base64Decode(dataToDecrypt);
          
          // Decrypt the data
          Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, encryptedData);
      
          return decryptedData.toString();
        }else{
          return null;
        }
    }
  
    global static String generateBaseKey(){
        if(Crypto_Key__c.getOrgDefaults().Key__c == null){
            Crypto_Key__c cryptoKey = new Crypto_Key__c();
            cryptoKey.Key__c = EncodingUtil.base64Encode(Crypto.generateAesKey(256));       
            insert cryptoKey;
        }
        return Crypto_Key__c.getOrgDefaults().Key__c;
    }
}