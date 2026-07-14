/**
* @author Maximo Martinez
* @date 12/05/2017
* @description Clase controladora de la vista drilldownComprobantesDePago
*/
global with sharing class DrilldownComprobantesDePagoController {
	
	public DrilldownComprobantesDePagoController(ApexPages.StandardController controller) {}

	@AuraEnabled
	public static List<SObject> getData(Id parentId){

		Schema.SObjectType parentSObjectType = Utils.getObjectTypeById(parentId);

		if(Account.SObjectType == parentSObjectType){
			return getComprobantesDePagoByCliente(parentId);
		}else if(Comprobante_de_Pago__c.SObjectType == parentSObjectType){
			return getValoresByComprobante(parentId);
		}else if(Valor__c.SObjectType == parentSObjectType){
			return getAplicacionesByValor(parentId);
		}

		return null;

	}

	@RemoteAction
	@ReadOnly
	global static List<Comprobante_de_Pago__c> getComprobantesDePagoByCliente(Id idCliente){
		return [SELECT Name,Anio_Cobranza__c,Cliente__c,Correccion__c,Cuenta_y_Orden__c,CUIT__c,Estado_ERP_IMG__c,Estado_ERP__c,Estado__c,Fecha_Contable_Mes_Anio__c,Fecha_de_Confirmacion_del_Pago__c,Fecha_de_Recepcion_de_Pago__c,Importe__c,Mes_Cobranza__c,Obtentor_Destinatario__r.Name,Saldo_del_Comprobante__c,Total_Aplicado__c, (SELECT Id FROM Valores__r) FROM Comprobante_de_Pago__c WHERE Cliente__c = :idCliente ORDER BY CreatedDate DESC];
	}

	@RemoteAction
	@ReadOnly
	global static List<Valor__c> getValoresByComprobante(Id idComprobante){
		return [SELECT Name, Forma_de_Pago__c, Fecha_de_Pago__c, Importe__c, Importe_Total__c, (SELECT Id FROM Aplicaciones__r) FROM Valor__c WHERE Comprobante_de_Pago__c = :idComprobante ORDER BY CreatedDate DESC];
	}

	@RemoteAction
	@ReadOnly
	global static List<Aplicacion__c> getAplicacionesByValor(Id idValor){
		return [SELECT Name, Comprobante__c, DUP_Auditoria__c, Fecha_Contable__c, Importe_Aplicar__c, Importe_Aplicado_ARS__c, Tipo_de_Cambio__c FROM Aplicacion__c WHERE Valor_Aplicado__c = :idValor ORDER BY CreatedDate DESC];
	}

	@AuraEnabled
	public static List<DataTableModel.Column> getColumns(){

		List<DataTableModel.Column> columns = new List<DataTableModel.Column>();

		columns.add(new DataTableModel.Column(Comprobante_de_Pago__c.Name.getDescribe()));

		DataTableModel.Column dObtentorColum = new DataTableModel.Column(Comprobante_de_Pago__c.Obtentor_Destinatario__c.getDescribe());
		dObtentorColum.type = 'url';
		dObtentorColum.typeAttributes = new DataTableModel.TypeAttributes();

		dObtentorColum.typeAttributes.label = new DataTableModel.Column();
		dObtentorColum.typeAttributes.label.fieldName = 'Obtentor_Destinatario__r.Name';
		dObtentorColum.typeAttributes.target = '_self';

		columns.add(dObtentorColum);

		//columns.add(new Column(Valor__c.Name.getDescribe()));
		columns.add(new DataTableModel.Column(Valor__c.Forma_de_Pago__c.getDescribe()));
		columns.add(new DataTableModel.Column(Valor__c.Fecha_de_Pago__c.getDescribe()));

		//columns.add(new Column(Aplicacion__c.Name.getDescribe()));
		columns.add(new DataTableModel.Column(Aplicacion__c.Fecha_Contable__c.getDescribe()));
		columns.add(new DataTableModel.Column(Aplicacion__c.Comprobante__c.getDescribe()));

		columns.add(new DataTableModel.Column(Comprobante_de_Pago__c.Importe__c.getDescribe()));

		columns.add(new DataTableModel.Column(Aplicacion__c.Importe_Aplicar__c.getDescribe()));
		columns.add(new DataTableModel.Column(Aplicacion__c.Tipo_de_Cambio__c.getDescribe()));

		return columns;

	}

}