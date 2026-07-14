trigger tg_Opportunity on Opportunity (after update, after insert) {
    
    //Consultamos si el trigger si activa por un Update
    if(Trigger.isAfter){

        Set<Id> idsGestionaLegales = new Set<Id>();
        
        if(Trigger.isInsert){
            
            Set<Id> idsOportunidades = new Set<Id>();

            Set<Id> idsOportunidadesFC = new Set<Id>();

            Set<Id> idsOportunidadesNC = new Set<Id>();
            
            for(Opportunity oportunidad : Trigger.new){
                
                /*if( (oportunidad.N_de_Comprobante__c != null) && (oportunidad.Tipo_de_Comprobante__c != 'NC') && (oportunidad.Saldo_a_Cobrar_Comprobante__c != 0)){
                    //Colecciono el Id
                    idsOportunidades.add(oportunidad.Id); 
                }*/

                if(oportunidad.StageName == 'Gestiona Legales')
                    idsGestionaLegales.add(oportunidad.Id);
                
            }

            UtilsTransaccion.sincronizarTransaccionDesdeOppFacturada(Trigger.new, null);
            
            /*if(idsOportunidades.size() > 0){
                 UtilsCasos.crearCasosFromFacturas(idsOportunidades);
            }*/   

            
        }
        
        //Consultamos si se realizo una actualizacion
        if(Trigger.isUpdate){
            
            System.Debug(LoggingLevel.INFO,'Trigger tg_Opportunity');
            
            //Recorremos las Oportunidades que dispararon el Trigger y coleccionamos los Id de las Transacciones
            //que debemos pasar a Estado Facturada
            Set<Id> idsTransacciones = new Set<Id>();
            
            Set<Id> idsOportunidades = new Set<Id>();
            
            Set<Id> idsOportunidadesCrearCasos = new Set<Id>();
            
            Set<Id> idsOportunidadesReAbrirCasos = new Set<Id>();
            
            Set<Id> idsOportunidadesCerrarCasos = new Set<Id>();
            
            Set<Id> idsLiquidacionesEnviadas = new Set<Id>();
            
            for(Opportunity oportunidad : Trigger.new){
                
                //Si se completa el Campo N_de_Comprobante__c de la Opportunidad coleccionamos la Transaccion 
                //y la oportunidad es de Tipo de Comprobante Igual a FC
                /*if((oportunidad.Tipo_de_Comprobante__c == 'FC') && (oportunidad.N_de_Comprobante__c != null && Trigger.oldMap.get(oportunidad.Id).N_de_Comprobante__c == null)){
                    
                    idsTransacciones.add(oportunidad.Transaccion__c);
                
                }*/
                
                //Si en la oportunidad el campo Liquidacion_Enviada__c = TRUE, o el campo N_de_Comprobante__c <> NULL
                //coleccionamos el id de la oportunidad
                /*if( (oportunidad.N_de_Comprobante__c != Trigger.oldMap.get(oportunidad.Id).N_de_Comprobante__c ) || (oportunidad.Saldo_a_Cobrar_Comprobante__c != Trigger.oldMap.get(oportunidad.Id).Saldo_a_Cobrar_Comprobante__c)){               
                    
                    if( (oportunidad.Tipo_de_Comprobante__c != 'NC') && ( oportunidad.N_de_Comprobante__c != null) && (oportunidad.Saldo_a_Cobrar_Comprobante__c != 0)){
                    
                        idsOportunidades.add(oportunidad.Id);
                    
                    }
                
                }*/
                
                //Si el saldo de la oportunidad paso a 0
                if(oportunidad.Saldo_a_Gestionar__c == 0 && Trigger.oldMap.get(oportunidad.Id).Saldo_a_Gestionar__c != 0){
                    idsOportunidadesCerrarCasos.add(oportunidad.Id);
                }
                
                //Si el saldo de la oportunidad pasa a ser distinto de 0 se reabre el caso
                /*if(oportunidad.Saldo_a_Gestionar__c != Trigger.oldMap.get(oportunidad.Id).Saldo_a_Gestionar__c){
                    
                    if(oportunidad.Saldo_a_Gestionar__c != 0){

                        idsOportunidadesReAbrirCasos.add(oportunidad.Id);
                    
                    }

                }*/
                
                //Si en la oportunidad el campo Liquidacion_Enviada__c = TRUE, debemos cerrar sus Tasks con asunto "Enviar Liquidacion"
                if(oportunidad.Liquidacion_Enviada__c == true &&  Trigger.oldMap.get(oportunidad.Id).Liquidacion_Enviada__c != true){
                    
                    idsLiquidacionesEnviadas.add(oportunidad.Id);
                    
                }

                if(oportunidad.StageName != Trigger.oldMap.get(oportunidad.Id).StageName)
                    if(oportunidad.StageName == 'Gestiona Legales')
                        idsGestionaLegales.add(oportunidad.Id);
                
            }

            UtilsTransaccion.sincronizarTransaccionDesdeOppFacturada(Trigger.new, Trigger.oldMap);
            
            //Llamamos a una Clase Auxiliar
            if(idsTransacciones.size() > 0){
            
                //Pasamos las transacciones a Estado Factura
                UtilsTransaccion.cambiarEstado(idsTransacciones,'Facturada');
                
            
            }

            //Llamamos a la clase auxiliar
            /*if(idsOportunidadesReAbrirCasos.size() > 0){
                
                UtilsCasos.reabrirCasosCobranzas(idsOportunidadesReAbrirCasos);
            
            }*/
            
            //Llamamos a una clase auxiliar
            /*if(idsOportunidades.size() > 0){
                
                UtilsCasos.crearCasosFromFacturas(idsOportunidades);
                
            }*/
            
            //Llamamos a la clase auxiliar
            if(idsOportunidadesCerrarCasos.size() > 0){
                
                UtilsCasos.cerrarCasosFromFactura(idsOportunidadesCerrarCasos);
                
            }
            
            //Llamamos a una clase auxiliar
            if(idsLiquidacionesEnviadas.size() > 0){
                
                CerrarTasksDesdeFacturas.cerrarTasks(idsLiquidacionesEnviadas);
                
            }
            
        }

        if(idsGestionaLegales.size() > 0)
            UtilsCasos.setOwnerToLegalesQueue(idsGestionaLegales);     
        
    }
    
}