public with sharing class BarcodeController{
    
    public String value {get; set;}
    public String code {get; set;}
    public Integer checkDigit {get; set;}
    public Boolean showLabel {get; set;}
    public String unit {get; set;}
    public Decimal minBarWidth {get; set;}
    public Decimal width {get; set;}
    public Decimal height {get; set;}
    public Decimal barWidthRatio {get; set;}
    public String textLocation {get; set;}
    public String textAlignment {get; set;}
    public String textStyle {get; set;}
    public String foreColor {get; set;}
    public String backColor {get; set;}
    
    public BarcodeController(){
            
    }
    
    public String getBarcode(){
        
        String barcode = '';
        
        if(value != null){
            Barcode bc = null;
            
            if(code == 'code39'){
                //bc = new Barcode_Code39();
            }else if(code == 'i25'){
                bc = new Barcode_I25();
            }else if(code == 'code128'){
                //bc = new Barcode_Code128();
            }
            
            System.Debug(LoggingLevel.INFO,this.value);
            
            barcode = bc.drawBarcode(this.value,this.checkDigit,this.showLabel,this.unit,this.minBarWidth,this.width,this.height,this.barWidthRatio,this.textLocation,this.textAlignment,this.textStyle,this.foreColor,this.backColor,'html');
        }
        
        return barcode;
    }
    
}