public with sharing class DesaplicarController {

	private ApexPages.StandardSetController setCon;
    private String parentId {get; set;}

    public DesaplicarController(ApexPages.StandardSetController stdController) {
        this.setCon = stdController;
        this.parentId = ApexPages.currentPage().getParameters().get('id');
    }

    public PageReference desaplicar() {

        Map<Id,Aplicacion__c> aplicacionesById = new Map<Id,Aplicacion__c>((Aplicacion__c[])setCon.getSelected());

        System.debug(LoggingLevel.WARN,aplicacionesById);

        String result = ws_Desaplicar.desaplicarFromAplicaciones(new List<Id>(aplicacionesById.keySet()));

        return new PageReference('/lightning/cmp/c__desaplicar?c__result='+result+'&c__id='+parentId+'&c__nocache='+Math.random());
    }
}