@RestResource(urlMapping='/RESTExecuteBatchDeleteDups/*')
global with sharing class RESTExecuteBatchDeleteDups{

    @HttpPost
    global static String execute(String Id) {
        System.debug(LoggingLevel.INFO, 'RESTExecuteBatchDeleteDups');
        System.debug(LoggingLevel.INFO, 'Id' + Id);
        
        SchdEliminarDups schd = new SchdEliminarDups();
        System.debug(LoggingLevel.INFO, 'RESTExecuteBatchDeleteDups'); 
        schd.eliminarDups(Id);
        
        return 'Done';
    }

}