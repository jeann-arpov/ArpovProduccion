@RestResource(urlMapping='/RESTExecuteBatchGenerarDups/*')
global with sharing class RESTExecuteBatchGenerarDups{

    @HttpPost
    global static String execute(String Id) {
        System.debug(LoggingLevel.INFO, 'RESTExecuteBatchGenerarDups');
        System.debug(LoggingLevel.INFO, 'Id' + Id);
        SchdGenerarDups schd = new SchdGenerarDups();
        System.debug(LoggingLevel.INFO, 'RESTExecuteBatchGenerarDups'); 
        schd.generarDups(Id);
        
        return 'Done';
    }

}