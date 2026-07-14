public with sharing class Barcode_I25 extends Barcode{
        
        public override String encode(String data,Integer checkDigit){
            
            String output = '';
            String pattern = '';
            
            String fontOutput = connectCodeEncodeI2OF5(data,checkDigit);
            
            Integer i=0;
            
            do{
                if(i<fontOutput.length()){
                    
                    pattern = '';
                    
                    Integer i2of5Value = getI2of5Value(fontOutput.substring(i,i+1));
                    
                    if(i2of5Value == 0){
                        pattern = 'ttttwwwwtt';
                    }else if(i2of5Value == 1){
                        pattern = 'twttwtwttw';
                    }else if(i2of5Value == 2){
                        pattern = 'tttwwtwttw';
                    }else if(i2of5Value == 3){
                        pattern = 'twtwwtwttt';
                    }else if(i2of5Value == 4){
                        pattern = 'ttttwwwttw';
                    }else if(i2of5Value == 5){
                        pattern = 'twttwwwttt';
                    }else if(i2of5Value == 6){
                        pattern = 'tttwwwwttt';
                    }else if(i2of5Value == 7){
                        pattern = 'ttttwtwwtw';
                    }else if(i2of5Value == 8){
                        pattern = 'twttwtwwtt';
                    }else if(i2of5Value == 9){
                        pattern = 'tttwwtwwtt';
                    }else if(i2of5Value == 10){
                        pattern = 'wttttwtwwt';
                    }else if(i2of5Value == 11){
                        pattern = 'wwttttttww';
                    }else if(i2of5Value == 12){
                        pattern = 'wttwttttww';
                    }else if(i2of5Value == 13){
                        pattern = 'wwtwttttwt';
                    }else if(i2of5Value == 14){
                        pattern = 'wttttwttww';
                    }else if(i2of5Value == 15){
                        pattern = 'wwtttwttwt';
                    }else if(i2of5Value == 16){
                        pattern = 'wttwtwttwt';
                    }else if(i2of5Value == 17){
                        pattern = 'wttttttwww';
                    }else if(i2of5Value == 18){
                        pattern = 'wwtttttwwt';
                    }else if(i2of5Value == 19){
                        pattern = 'wttwtttwwt';
                    }else if(i2of5Value == 20){
                        pattern = 'ttwttwtwwt';
                    }else if(i2of5Value == 21){
                        pattern = 'twwtttttww';
                    }else if(i2of5Value == 22){
                        pattern = 'ttwwttttww';
                    }else if(i2of5Value == 23){
                        pattern = 'twwwttttwt';
                    }else if(i2of5Value == 24){
                        pattern = 'ttwttwttww';
                    }else if(i2of5Value == 25){
                        pattern = 'twwttwttwt';
                    }else if(i2of5Value == 26){
                        pattern = 'ttwwtwttwt';
                    }else if(i2of5Value == 27){
                        pattern = 'ttwttttwww';
                    }else if(i2of5Value == 28){
                        pattern = 'twwttttwwt';
                    }else if(i2of5Value == 29){
                        pattern = 'ttwwtttwwt';
                    }else if(i2of5Value == 30){
                        pattern = 'wtwttwtwtt';
                    }else if(i2of5Value == 31){
                        pattern = 'wwwttttttw';
                    }else if(i2of5Value == 32){
                        pattern = 'wtwwtttttw';
                    }else if(i2of5Value == 33){
                        pattern = 'wwwwtttttt';
                    }else if(i2of5Value == 34){
                        pattern = 'wtwttwtttw';
                    }else if(i2of5Value == 35){
                        pattern = 'wwwttwtttt';
                    }else if(i2of5Value == 36){
                        pattern = 'wtwwtwtttt';
                    }else if(i2of5Value == 37){
                        pattern = 'wtwttttwtw';
                    }else if(i2of5Value == 38){
                        pattern = 'wwwttttwtt';
                    }else if(i2of5Value == 39){
                        pattern = 'wtwwtttwtt';
                    }else if(i2of5Value == 40){
                        pattern = 'ttttwwtwwt';
                    }else if(i2of5Value == 41){
                        pattern = 'twttwtttww';
                    }else if(i2of5Value == 42){
                        pattern = 'tttwwtttww';
                    }else if(i2of5Value == 43){
                        pattern = 'twtwwtttwt';
                    }else if(i2of5Value == 44){
                         pattern = 'ttttwwttww';
                    }else if(i2of5Value == 45){
                         pattern = 'twttwwttwt';
                    }else if(i2of5Value == 46){
                         pattern = 'tttwwwttwt';
                    }else if(i2of5Value == 47){
                         pattern = 'ttttwttwww';
                    }else if(i2of5Value == 48){
                         pattern = 'twttwttwwt';
                    }else if(i2of5Value == 49){
                         pattern = 'tttwwttwwt';
                    }else if(i2of5Value == 50){
                         pattern = 'wtttwwtwtt';
                    }else if(i2of5Value == 51){
                         pattern = 'wwttwttttw';
                    }else if(i2of5Value == 52){
                         pattern = 'wttwwttttw';
                    }else if(i2of5Value == 53){
                         pattern = 'wwtwwttttt';
                    }else if(i2of5Value == 54){
                         pattern = 'wtttwwtttw';
                    }else if(i2of5Value == 55){
                         pattern = 'wwttwwtttt';
                    }else if(i2of5Value == 56){
                         pattern = 'wttwwwtttt';
                    }else if(i2of5Value == 57){
                         pattern = 'wtttwttwtw';
                    }else if(i2of5Value == 58){
                         pattern = 'wwttwttwtt';
                    }else if(i2of5Value == 59){
                         pattern = 'wttwwttwtt';
                    }else if(i2of5Value == 60){
                         pattern = 'ttwtwwtwtt';
                    }else if(i2of5Value == 61){
                         pattern = 'twwtwttttw';
                    }else if(i2of5Value == 62){
                         pattern = 'ttwwwttttw';
                    }else if(i2of5Value == 63){
                         pattern = 'twwwwttttt';
                    }else if(i2of5Value == 64){
                         pattern = 'ttwtwwtttw';
                    }else if(i2of5Value == 65){
                         pattern = 'twwtwwtttt';
                    }else if(i2of5Value == 66){
                         pattern = 'ttwwwwtttt';
                    }else if(i2of5Value == 67){
                         pattern = 'ttwtwttwtw';
                    }else if(i2of5Value == 68){
                         pattern = 'twwtwttwtt';
                    }else if(i2of5Value == 69){
                         pattern = 'ttwwwttwtt';
                    }else if(i2of5Value == 70){
                         pattern = 'tttttwwwwt';
                    }else if(i2of5Value == 71){
                         pattern = 'twttttwtww';
                    }else if(i2of5Value == 72){
                         pattern = 'tttwttwtww';
                    }else if(i2of5Value == 73){
                         pattern = 'twtwttwtwt';
                    }else if(i2of5Value == 74){
                         pattern = 'tttttwwtww';
                    }else if(i2of5Value == 75){
                         pattern = 'twtttwwtwt';
                    }else if(i2of5Value == 76){
                         pattern = 'tttwtwwtwt';
                    }else if(i2of5Value == 77){
                         pattern = 'ttttttwwww';
                    }else if(i2of5Value == 78){
                         pattern = 'twttttwwwt';
                    }else if(i2of5Value == 79){
                         pattern = 'tttwttwwwt';
                    }else if(i2of5Value == 80){
                         pattern = 'wttttwwwtt';
                    }else if(i2of5Value == 81){
                         pattern = 'wwttttwttw';
                    }else if(i2of5Value == 82){
                         pattern = 'wttwttwttw';
                    }else if(i2of5Value == 83){
                         pattern = 'wwtwttwttt';
                    }else if(i2of5Value == 84){
                         pattern = 'wttttwwttw';
                    }else if(i2of5Value == 85){
                         pattern = 'wwtttwwttt';
                    }else if(i2of5Value == 86){
                         pattern = 'wttwtwwttt';
                    }else if(i2of5Value == 87){
                         pattern = 'wtttttwwtw';
                    }else if(i2of5Value == 88){
                         pattern = 'wwttttwwtt';
                    }else if(i2of5Value == 89){
                         pattern = 'wttwttwwtt';
                    }else if(i2of5Value == 90){
                         pattern = 'ttwttwwwtt';
                    }else if(i2of5Value == 91){
                         pattern = 'twwtttwttw';
                    }else if(i2of5Value == 92){
                         pattern = 'ttwwttwttw';
                    }else if(i2of5Value == 93){
                         pattern = 'twwwttwttt';
                    }else if(i2of5Value == 94){
                         pattern = 'ttwttwwttw';
                    }else if(i2of5Value == 95){
                         pattern = 'twwttwwttt';
                    }else if(i2of5Value == 96){
                         pattern = 'ttwwtwwttt';
                    }else if(i2of5Value == 97){
                         pattern = 'ttwtttwwtw';
                    }else if(i2of5Value == 98){
                         pattern = 'twwtttwwtt';
                    }else if(i2of5Value == 99){
                         pattern = 'ttwwttwwtt';
                    }
                   
                    output=output+pattern;
                }
            
                i=i+1;
            
            }while(i < fontOutput.length());
            
            return 'tttt'+output+'wtt';
            
            
        
        }
        
        public String connectCodeEncodeI2OF5(String data,Integer checkDigit){
            
            String result = '';
            String cd = '';
            String filtereddata = '';
            filtereddata = filterInput(data);
            
            Integer filteredlength = filtereddata.length();
            
            System.Debug(LoggingLevel.INFO,filteredlength);
            
            
            
            if (checkDigit ==1 ){
                if (filteredlength > 253){
                    filtereddata = filtereddata.substring(0,253);
                }
                
                if ( math.mod(filtereddata.length(),2) ==0){
                    filtereddata = '0' + filtereddata;
                }

                cd = generateCheckDigit(filtereddata);
            
            }else{
                if (filteredlength > 254){
                    filtereddata = filtereddata.substring(0,254);
                }
                if ( math.mod(filtereddata.length(),2)==1){
                    filtereddata = '0' + filtereddata;
                }

            }
           
            filtereddata = filtereddata+cd;

            Integer num = 0;
           
            Integer i=0;
            do{
                if(i<filtereddata.length()){
                    num = Integer.valueOf(filtereddata.substring(i,i+2));
                    result = result + getI2of5Character(num);
                }
                i=i+2;
            }while(i < filtereddata.length());
            
            
            result = '{' + result + '}';
             
            return result;
   
        }
        
        public  String filterInput(String data){
            
            String result='';
            
            Integer i=0;
            do{
                if(i<data.length()){
                    if ((charCodeAt(data,i)>=48) && (charCodeAt(data,i)<=57)){
                        result = result + data.substring(i,i+1);
                    }
                }
                i=i+1;
            }while(i < data.length());
            
            
            return result;
            
        }
        
        public Integer charCodeAt(String data, Integer index){
            
            String ch = data.substring(index,index+1);
            return UtilsCharacter.toAscii(ch);
            
        }
        
        public String fromCharCode(Integer code){
            return UtilsCharacter.toChar(code);
        }
        
        public String generateCheckDigit(String data){
            Integer datalength = 0;
            Integer lastcharpos = 0;
            Integer Result = 0;
            String strResult = '';
            String barcodechar = '';
            Integer barcodevalue = 0;
            Integer toggle = 1;
            Integer sum = 0;
               
            datalength = data.length();
            lastcharpos = datalength - 1;
               
            for (Integer i = lastcharpos ; i > = 0 ; i--){
                     barcodevalue = charCodeAt(data,i)-48;
                     
                     if (toggle == 1){
                           sum = sum + (barcodevalue * 3);
                           toggle = 0;
                     }else{
                           sum = sum + barcodevalue;
                           toggle = 1;
                     }
            }
            
            if (math.mod(sum,10) == 0){
                result = 48;
            }else{
                result = (10 - math.mod(sum,10)) + 48;
            }
               
            strResult = fromCharCode(result);
            return strResult;
       }
       
       
       public String getI2of5Character(Integer inputvalue){
       
            if ((inputvalue <= 90) && (inputvalue >= 0)){
                inputvalue = inputvalue + 32;
            }else if ((inputvalue <= 99) && (inputvalue >= 91)){
                inputvalue = inputvalue + 100;
            }else{
                inputvalue = -1;
            }
            
            return fromCharCode(inputvalue);
       
       }
       
       public Integer getI2of5Value(String data){
            Integer inputvalue = charCodeAt(data,0);
            if (inputvalue <= 90+32 && inputvalue >= 0+32)
                inputvalue = inputvalue - 32;
            else if (inputvalue <= 99+100 && inputvalue >= 91+100)
                inputvalue = inputvalue - 100;
            else
                inputvalue = -1;

            return inputvalue;
          }
       
       public override String getHumanText(String data,Integer checkDigit){
            String result = '';
            String cd = '';
            String filtereddata = '';
            filtereddata = filterInput(data);
            Integer filteredlength = filtereddata.length();
            if (checkDigit==1){
                if (filteredlength > 253){
                    filtereddata = filtereddata.substring(0,253);
                }
                
                if (Math.mod(filtereddata.length(),2) ==0){
                        filtereddata = '0' + filtereddata;
                }

                cd = generateCheckDigit(filtereddata);
            }else{
                
                if (filteredlength > 254){
                    filtereddata = filtereddata.substring(0,254);
                }
                if (Math.mod(filtereddata.length(),2) ==1){
                    filtereddata = '0' + filtereddata;
                }

            }
            filtereddata = filtereddata+cd;

            result = filtereddata;
              
            return result;
        }


}