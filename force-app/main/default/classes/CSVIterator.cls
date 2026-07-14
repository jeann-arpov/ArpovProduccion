global with sharing class CSVIterator implements Iterator<string>, Iterable<string>{
    
    private final static String CR = '\r';
    private final static String LF = '\n';
    private final static String CRLF = '\r\n';    

    private String header;
    private String csvString;
    private Integer position;
    private Integer cvsLength;

    public CSVIterator(String csvString){
        this.csvString = convertLineEndings(csvString.trim());
        this.position = 0;
        this.cvsLength = this.csvString.length();
        if(hasNext()){
            header = next();
        }   
    }
    
    
    private static String convertLineEndings(String str) {
        return str.replace(CRLF, LF).replace(CR, LF);
    }
   
    global Boolean hasNext(){
        return position < cvsLength;
    }

    global String next(){
   
        Integer endLine = csvString.indexOf(LF,position);

        Integer startLine = position;
        
        if(position < cvsLength){
            if(endLine!=-1){
                position = endLine + LF.length();
                return csvString.subString(startLine, endLine);
            }else{
                position = cvsLength;
                return csvString.subString(startLine, cvsLength);
            }
        }else{ // LAST ROW
            // Limpiamos el CSV String
            csvString = null;
            return '';
        }
      
    }

    global Iterator<string> Iterator(){
        return this;   
    }

    public String getHeader(){
        return header;
    }

}