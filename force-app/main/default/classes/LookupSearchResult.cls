/**
 * Class used to serialize a single Lookup search result item
 * The Lookup controller returns a List<LookupSearchResult> when sending search result back to Lightning
 */
public virtual class LookupSearchResult implements Comparable {
    @AuraEnabled public Id id;
    @AuraEnabled public String sObjectType;
    @AuraEnabled public String icon;
    @AuraEnabled public String title;
    @AuraEnabled public String subtitle;
    @AuraEnabled public Sobject record;

    protected LookupSearchResult() {
    }

    public LookupSearchResult(Id id, String sObjectType, String icon, String title, String subtitle) {
        this.id = id;
        this.sObjectType = sObjectType;
        this.icon = icon;
        this.title = title;
        this.subtitle = subtitle;
    }
    /**
     * Allow to sort search results based on title
     */
    public Integer compareTo(Object compareTo) {
        LookupSearchResult other = (LookupSearchResult) compareTo;
        if (this.title == null) {
            return (other.title == null) ? 0 : 1;
        }
        if (other.title == null) {
            return -1;
        }
        return this.title.compareTo(other.title);
    }
}