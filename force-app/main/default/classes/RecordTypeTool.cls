public without sharing class RecordTypeTool{

    // Build a local cache so that we don't request this multiple times
    private static Map<Schema.SObjectType,Map<String,Id>> rtypesCache;
    
    static {
        rtypesCache = new Map<Schema.SObjectType,Map<String,Id>>();
    }
    
    // Returns a map of active, user-available RecordType IDs for a given SObjectType,
    // keyed by each RecordType's unique, unchanging DeveloperName 
    public static Map<String, Id> GetRecordTypeIdsByDeveloperName(Schema.SObjectType token) {
        // Do we already have a result? 
        Map<String, Id> mapRecordTypes = rtypesCache.get(token);
        // If not, build a map of RecordTypeIds keyed by DeveloperName
        if (mapRecordTypes == null) {
            mapRecordTypes = new Map<String, Id>();
            rtypesCache.put(token,mapRecordTypes);
        } else {
            return mapRecordTypes;
        }
    
        // Get the Describe Result
        Schema.DescribeSObjectResult obj = token.getDescribe();
    
        // Obtain ALL Active Record Types for the given SObjectType token
        // (We will filter out the Record Types that are unavailable
        // to the Running User using Schema information)
        String soql = 
            'SELECT Id, Name, DeveloperName '
            + 'FROM RecordType '
            + 'WHERE SObjectType = \'' + String.escapeSingleQuotes(obj.getName()) + '\' '
            + 'AND IsActive = TRUE';
        List<SObject> results;
        
        try {
            results = Database.query(soql);
        } catch (Exception ex) {
            results = new List<SObject>();
        }
        
        // Obtain the RecordTypeInfos for this SObjectType token
        Map<Id,Schema.RecordTypeInfo> recordTypeInfos = obj.getRecordTypeInfosByID();
    
        // Loop through all of the Record Types we found,
        //      and weed out those that are unavailable to the Running User
        for (SObject rt : results) {  
            //if (recordTypeInfos.get(rt.Id).isAvailable()) {
                // This RecordType IS available to the running user,
                //      so add it to our map of RecordTypeIds by DeveloperName
                mapRecordTypes.put(String.valueOf(rt.get('DeveloperName')),rt.Id);
            //}
        }
        return mapRecordTypes;
    }
    
}