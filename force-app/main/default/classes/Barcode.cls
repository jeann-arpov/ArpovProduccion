public with sharing abstract class Barcode{
    
    public abstract String encode(String data, Integer checkDigit);
    public abstract String getHumanText(String data, Integer checkDigit);
    
    public virtual String drawBarcode(String data,Integer checkDigit,Boolean showLabel,String units,Decimal minBarWidth,Decimal width,Decimal height,Decimal barWidthRatio,String textLocation,String textAlignment,String textStyle,String foreColor,String backColor,String mode){
        
        //Validaciones
        if (foreColor == null)
            foreColor = 'black';
        
        if (backColor == null)
            backColor = 'white';
        
        if (textLocation == null)
            textLocation = 'bottom';
        
        else if (textLocation != 'bottom' && textLocation != 'top')
            textLocation = 'bottom';
            
        if (textAlignment == null)
            textAlignment = 'center';
        else if (textAlignment!='center' && textAlignment!='left' && textAlignment!='right')
            textAlignment='center';
          
        if (textStyle == null)
            textStyle='';
        
        if (barWidthRatio == null)
            barWidthRatio=3;              
        
        if (height == null)
            height=1;
        else if (height<=0 || height >15)
            height=1;
        
        if (width == null)
            width=3;
        else if (width<=0 || width >15)
            width=3;
        
        if (minBarWidth == null)
              minBarWidth=0;
        else if (minBarWidth<0 || minBarWidth >2)
              minBarWidth=0;
        
        if (units == null)
            units='in';
        else if (units!='in' && units !='cm')
            units='in';
        
        if (showLabel == null)
            showLabel = true;
        
        Integer encodedLength = 0;
        Integer thinLength = 0;
        Decimal thickLength = 0.0;
        Decimal totalLength = 0.0;
        Decimal incrementWidth = 0.0;
        Integer swing = 1;
        String result='';
        Decimal barWidth = 0;
        Decimal thickWidth=0.0;
        Integer svg;
        
        String encodedData = encode(data,checkDigit);
        
        String humanReadableText = getHumanText(data,checkDigit);
        
        System.Debug(LoggingLevel.INFO,encodedData);
        
        System.Debug(LoggingLevel.INFO,humanReadableText);
        
        if (barWidthRatio >= 2 && barWidthRatio <= 3){
        
        }else{
            barWidthRatio = 3;
        }    
        
        Integer i=0;
        do{
            if(i<encodedData.length()){
        
      
        
                if (encodedData.substring(i,i+1) == 't'){
                            thinLength++;
                            encodedLength++;
                }else if (encodedData.substring(i,i+1) == 'w'){
                            thickLength = thickLength + barWidthRatio;
                            encodedLength = encodedLength + 3;
                }
        
            }
            i=i+1;
        }while(i < encodedData.length());
        
        totalLength = totalLength + thinLength + thickLength;

        if (minBarWidth > 0){
            //barWidth = minBarWidth.toFixed(2);
            barWidth = minBarWidth;
            width=barWidth * totalLength;
        }else{
            //barWidth = (width / totalLength).toFixed(2);
            barWidth = (width / totalLength);
        }
        thickWidth = barWidth * 3;
        
        if (barWidthRatio >= 2 && barWidthRatio <= 3.0){
            thickWidth = barWidth * barWidthRatio;
        }

        if (mode=='html'){
        
          if (textAlignment=='center')
              result='<div style='+'\''+'text-align:center'+'\''+'>';
          else if (textAlignment=='left')
              result='<div style='+'\''+'text-align:left'+'\''+'>';
          else if (textAlignment=='right')
              result='<div style='+'\''+'text-align:right'+'\''+'>';

          String humanSpan = '';
          
          if (showLabel == true && textLocation=='top'){
            if (textStyle == '')
                humanSpan = '<span style='+'\''+'font-family : arial; font-size:12pt'+'\''+'>'+humanReadableText+'</span><br />';
            else
                humanSpan = '<span style='+textStyle+'>'+humanReadableText+'</span><br />';
          }
              result=result+humanSpan;
        }
          
        i=0;
        do{
            if(i<encodedData.length()){
            
                String brush;
                
                if (swing == 0)
                    brush = backColor;
                else
                    brush = foreColor;

                if (encodedData.substring(i,i+1) == 't' || encodedData.substring(i,i+1) == 'b'){
                  
                  if (mode=='html')
                    result=result 
                         +'<span style='+'\''+'border-left:'
                         +barWidth
                         +units
                         +' solid ' 
                         +brush
                         +';height:'
                         +height
                         +units+';display:inline-block;'+'\''+'></span>';
                    incrementWidth = incrementWidth + barWidth;
                }else if (encodedData.substring(i,i+1) == 'w'){
                  
                  if (mode == 'html')
                    result=result
                         +'<span style='+'\''+'border-left :'+
                         +thickWidth
                         +units+' solid ' 
                         +brush
                         +';height:'
                         +height
                         +units+';display:inline-block;'+'\''+'></span>';
                        incrementWidth = incrementWidth + thickWidth;
                }

                if (swing == 0)
                    swing = 1;
                else
                    swing = 0;
         }    
         i=i+1;
     }while(i < encodedData.length());

     if (mode == 'html'){
     
         String humanSpan= '';
         if (showLabel == true && textLocation=='bottom'){
                if (textStyle=='')
                    humanSpan='<br /><span style='+'\''+'font-family : arial; font-size:12pt'+'\''+'>'+humanReadableText+'</span>';
                else
                    humanSpan='<br /><span style='+textStyle+'>'+humanReadableText+'</span>';
         }
              result=result+humanSpan+'</div>';
     }
     
     System.Debug(LoggingLevel.INFO,result);
     
     return result;
    }
       

}