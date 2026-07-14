public with sharing class DisableTrigger{
    public static Boolean turnedOffBeforeInsert {
        get{
            return turnedOffBeforeInsert;
        }
        set{
            turnedOffBeforeInsert = value;
        }
    }
    
    public static Boolean turnedOffAfterInsert {
        get{
            return turnedOffAfterInsert;
        }
        set{
            turnedOffAfterInsert = value;
        }
    }
    
    static{
        turnedOffBeforeInsert = false;
        turnedOffAfterInsert = false;
    }
}