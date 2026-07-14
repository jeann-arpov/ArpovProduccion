trigger tg_OpportunityLineItem on OpportunityLineItem (Before insert) {

     if(Trigger.isInsert && Trigger.isBefore){
        // Debo asignar el valor de la cotización actual de la moneda DOLAR
        Date fechaActual = Date.today();
        
        Datetime today = Datetime.now();
        String dia = today.format('E');
        System.Debug(LoggingLevel.INFO,'>> >> Dia: '+dia);
        
        AggregateResult[] tiposCambio;
        
        // Obtengo las conversiones del DOLAR (USD)
        if(dia == 'Mon' || dia == 'Tue' || dia == 'Wed' || dia == 'Thu' || dia == 'Fri')
            tiposCambio = [Select moneda__r.Moneda_de_la_compania__c monedaDefault, moneda__r.Name moneda, Max(Fecha__c) fecha, Max(Cotizacion__c) cotizacion from Tipo_de_Cambio__c where Fecha__c = :fechaActual AND moneda__r.Codigo_Univoco__c = 'USD' group by moneda__r.Moneda_de_la_compania__c, moneda__r.Name];
        else
            tiposCambio = [Select moneda__r.Moneda_de_la_compania__c monedaDefault, moneda__r.Name moneda, Max(Fecha__c) fecha, Max(Cotizacion__c) cotizacion from Tipo_de_Cambio__c where Fecha__c <= :fechaActual AND moneda__r.Codigo_Univoco__c = 'USD' group by moneda__r.Moneda_de_la_compania__c, moneda__r.Name];
        
        for(OpportunityLineItem item: Trigger.new){
            for (AggregateResult tipoCambio: tiposCambio){
                item.Tipo_de_Cambio__c = null;
                
                //Siempre asigno el tipo de cambio dolar
                item.Tipo_de_Cambio__c = (Decimal)tipoCambio.get('cotizacion');
                break;
                
            }
            
            // Si no se asignó ningún tipo de cambio, lanzo un error
            if(item.Tipo_de_Cambio__c == null)
                item.addError('No se cargó el tipo de cambio para la fecha actual. Póngase en contacto con administración');
        }
    }

}