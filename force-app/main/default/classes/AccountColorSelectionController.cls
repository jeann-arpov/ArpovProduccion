public with sharing class AccountColorSelectionController {
	
	private ApexPages.StandardSetController setCon;
	public Map<String,Boolean> checkBoxex {get; set;}
    public String gestionType {get; set;}

	public AccountColorSelectionController(ApexPages.StandardSetController stdController) {

        this.setCon = stdController;
        this.gestionType = 'Cobranza';
        
        checkBoxex = new Map<String,Boolean>();
        checkBoxex.put('0150f000039RlDG',true);
        checkBoxex.put('0150f000039RlDV',false);
        checkBoxex.put('0150f000039RlDa',false);
        checkBoxex.put('0150f000039RlFC',false);

        SalesforceRestClient sf = new SalesforceRestClient(System.Url.getSalesforceBaseURL().toExternalForm(),AuraController.fetchUserSessionId());

        SalesforceRestClient.ListViewDescribe describe =  sf.getDescribeListViewById('Account',stdController.getFilterId());

        this.gestionType = null;

        for(SalesforceRestClient.Column cl : describe.columns){
            if(cl.fieldNameOrPath.toLowerCase().startsWith('estado_de_gestion_') && cl.fieldNameOrPath.toLowerCase().endsWith('_img__c') || cl.fieldNameOrPath.toLowerCase().startsWith('estado_gestion_') && cl.fieldNameOrPath.toLowerCase().endsWith('_img__c')){
                gestionType = cl.fieldNameOrPath.toLowerCase().replace('estado_gestion_', '').replace('estado_de_gestion_', '').replace('_img__c','');
                break;
            }
        }
        
        if(String.isEmpty(gestionType)){
            ApexPages.Message myMsg = new ApexPages.Message(ApexPages.Severity.ERROR,'No se ha encontrado un campo Estado Gestion en la vista de lista.');
            ApexPages.addMessage(myMsg);
            checkBoxex = new Map<String,Boolean>();
            return;
        }

    }

    public PageReference changeColor(){
    	
    	String selectedGestion = (checkBoxex.get('0150f000039RlDG') ) ? '01. Verde' : ( (checkBoxex.get('0150f000039RlDV')) ? '02. Naranja' : ((checkBoxex.get('0150f000039RlDa')) ? '03. Rojo' : null) );

    	for(Account acc : (List<Account>)setCon.getSelected()){
    		acc.put('Estado_de_Gestion_'+this.gestionType+'__c',selectedGestion);
    	}

    	return this.setCon.save();
    }

}