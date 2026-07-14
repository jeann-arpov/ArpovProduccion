public inherited sharing class ventasDistribuidorConS {
   
      
    private static final List<String> SELECT_COLUMNS = new List<String>{'Cultivo__r.Name','Campana_Agricola__r.Ano__c','Id_Obtentor__c','Producto__r.Variedad__c','Tipo_de_Producto__c','Categoria__c','UM__c','Originante__r.N_CUIT__c','Tipo_de_Venta__c','Destinatario__r.N_CUIT__c','Originante__c','Destinatario__c','Cantidad_Bolsas_40__c','Id','Producto__r.Obtentor_Comercializa__c'};
    
    private static final Set<String> CATEGORIAS = new Set<String>{'Primera Multiplicación', 'Segunda Multiplicación', 'Tercera Multiplicación', 'No Definida', 'Identificada'};
    
    public ventasDistribuidorConS(ApexPages.StandardController controller){
    }
    

    private static Decimal cantidad(Venta__c venta, String accountId, Integer columna) {
        Set<String> notaDeCreaditos = new Set<String>{'DPD','DPO','TDD','TDS'};

        if(!CATEGORIAS.contains(venta.Categoria__c) && columna != 3) return 0; // columna = 3 = detalle de ventas, lo muestro

        Decimal qty = 0;

        if(notaDeCreaditos.contains(venta.Tipo_de_Venta__c) && venta.Destinatario__c == accountId){
            qty = venta.Cantidad_Bolsas_40__c;
        }else if(notaDeCreaditos.contains(venta.Tipo_de_Venta__c) &&  venta.Originante__c == accountId){
            qty = venta.Cantidad_Bolsas_40__c * -1;
        }

        // Si es un Movimiento TRC o el Originante no es la cuenta que se consulta entonces se suma
        else if( (venta.Originante__c == venta.Destinatario__c && ( venta.Tipo_de_Venta__c == 'TRC' || venta.Tipo_de_Venta__c == 'RCA' ) && venta.Tipo_de_Producto__c == 'Semilla Fiscalizada') || venta.Originante__c != accountId ){
            qty = venta.Cantidad_Bolsas_40__c;
        }else if(venta.Originante__c == accountId){// Si el Originante es la cuenta que se consulta entonces se Resta
            qty = venta.Cantidad_Bolsas_40__c * -1;
        }

        return qty; // si agrupo por obtentor no tengo que sumar los negativos
    }

    @ReadOnly
    @RemoteAction
    public static List<VentasDistribuidorController.RowWrapper> get(String accountId, Integer fila, Integer columna, String[] whereList){
        return get(accountId, fila, columna, whereList, null);
    }
    
    @ReadOnly
    @remoteAction
    public static List<VentasDistribuidorController.RowWrapper> get(String accountId, Integer fila, Integer columna, String[] whereList, Boolean sembraEvolucion) {
        if(accountId == '') return null;

        Map<String, VentasDistribuidorController.RowWrapper> rows = new Map<String, VentasDistribuidorController.RowWrapper>();

        if (columna == null) { // AgruparPorCultivo
            //La cuenta corriente mostrará los cultivos para los cuáles existen ventas para ese CUIT. Para cada cultivo, siempre se mostrará la cantidad en 0.
            for (AggregateResult res: [select Cultivo__c cultivoId, Cultivo__r.Name cultivo FROM Venta__c WHERE (Originante__c =:accountId OR Destinatario__c = :accountId) AND Producto__r.Obtentor_Comercializa__c != :accountId group by Cultivo__c, Cultivo__r.Name order by Cultivo__r.Name]) {
                VentasDistribuidorController.RowWrapper row = new VentasDistribuidorController.RowWrapper();
                row.cultivo = (String) res.get('cultivo'); 
                rows.put((String) res.get('cultivoId'), row);
            }
        } else {
            String qry =  'SELECT Name, Producto__r.Variedad__c, Producto__r.Variedad2__r.Sembra_Evolucion__c, Cultivo__r.Name, Campana_Agricola__r.Ano__c, Campana_Agricola__r.Name, Originante__r.Name , Destinatario__r.Name, Cantidad_Bolsas_40__c, Categoria__c, Tipo_de_Venta__c, Tipo_de_Producto__c, UM__c, Fecha__c, Id_Obtentor__c, Originante__r.N_CUIT__c, Destinatario__r.N_CUIT__c FROM Venta__c WHERE (Originante__c =:accountId OR Destinatario__c = :accountId) AND Producto__r.Obtentor_Comercializa__c != :accountId ';

            if (columna >= 0) qry += ' AND Cultivo__r.Name = \'' + whereList[0] + '\'';
            if (columna >= 1) qry += ' AND Campana_Agricola__r.Ano__c = \'' + whereList[1] + '\'';
            if (columna >= 2) qry += ' AND Id_Obtentor__c = \'' + whereList[2] + '\'';
            if (columna == 3) qry += ' AND Producto__r.Variedad__c = \'' + whereList[3] + '\'' + ' AND Tipo_de_Producto__c = \'' + whereList[4] + '\'' + ' AND Categoria__c = \'' + whereList[5] + '\'' + ' AND UM__c = \'' + whereList[6] + '\'';

            if(sembraEvolucion != null) qry += ' AND Producto__r.Variedad2__r.Sembra_Evolucion__c = ' + sembraEvolucion;

            qry += ' ORDER BY ' + String.join(SELECT_COLUMNS, ',');

            for(Venta__c venta: Database.query(qry)) {
                String key = venta.Cultivo__c + ',' + venta.Campana_Agricola__r.Ano__c;

                if(venta.Id_Obtentor__c != null) {
                    if (columna >= 0) key += ',' + venta.Id_Obtentor__c;
                    //aunque quiera agrupar por obtentor, tengo que agrupar por producto ya que si la suma da negativo, sólo tengo que sumarle 0 al grupo
                    // lo mismo para campaña, tiene que sumar lo que dieron los obtentores
                    if (columna >= 0) key += ',' + venta.Producto__r.Variedad__c + ',' + venta.Tipo_de_Producto__c + ',' + venta.Categoria__c + ',' + venta.UM__c;
                    if (columna == 3) key = venta.id;
        
                    if (rows.containsKey(key) == false) {
                        VentasDistribuidorController.RowWrapper row = new VentasDistribuidorController.RowWrapper();
                        row.cantidad = 0;

                        if (columna == 0) row.campana = venta.Campana_Agricola__r.Ano__c == null ? '' : venta.Campana_Agricola__r.Ano__c; // AgruparPorCampana
                        else if (columna == 1) row.obtentor = venta.Id_Obtentor__c == null ? '' : venta.Id_Obtentor__c; // AgruparPorObtentor
                        else if (columna == 2) { // AgruparPorVariedadTipoCategoriaUnidadMedida
                            row.variedad = venta.Producto__r.Variedad__c == null ? ' ' : venta.Producto__r.Variedad__c;
                            row.tipo = venta.Tipo_de_Producto__c;
                            row.categoria = venta.Categoria__c;
                            row.um = venta.UM__c;
                            row.drilldown = true; //Indicamos que se puede ampliar el dato
                            row.isClosed = true; //Indicamos que esta cerrado
                            row.cssClass = sembraEvolucion == null && venta.Producto__r.Variedad2__r.Sembra_Evolucion__c ? 'se' : '';
                        } else if (columna == 3) { // AgruparPorUMCuitOriginanteTipoVentaCuitDestinatario
                            row.cuitOriginante = venta.Originante__r.N_CUIT__c;
                            row.tipoVenta = venta.Tipo_de_Venta__c;
                            row.cuitDestinatario = venta.Destinatario__r.N_CUIT__c;
                            row.id = venta.Id;
                            row.originanteId = venta.Originante__c;
                            row.destinatarioId = venta.Destinatario__c;
                            row.drilldown = false;
                            row.cssClass = sembraEvolucion == null && venta.Producto__r.Variedad2__r.Sembra_Evolucion__c ? 'se' : '';

                            row.popOverData = new VentasDistribuidorController.PopOver();
                            row.popOverData.destinatarioId = venta.Destinatario__c;
                            row.popOverData.tipoDeVenta = venta.Tipo_de_Venta__c;
                            row.popOverData.destinatarioName = venta.Destinatario__r.Name;
                            row.popOverData.originanteId = venta.Originante__c;
                            row.popOverData.originanteName = venta.Originante__r.Name;
                            row.popOverData.campanaId = venta.Campana_Agricola__c;
                            row.popOverData.campanaName = venta.Campana_Agricola__r.Name;
                            row.popOverData.cultivoName = venta.Cultivo__r.Name;
                            row.popOverData.cultivoId = venta.Cultivo__c;
                            row.popOverData.fecha = venta.Fecha__c;
                            row.popOverData.ventaName = venta.Name;
                            row.popOverData.ventaId = venta.Id;
                        }

                        rows.put(key, row);
                    }

                    rows.get(key).cantidad += cantidad(venta, accountId, columna);
                }
            }
        }

        //tengo que agrupar los subgrupos en los grupos. Sólo sumo si no dio negativo
        if (columna == 0 || columna == 1) {
            for (String key: rows.keySet()) {
                VentasDistribuidorController.RowWrapper row = rows.get(key);
                Decimal qtyToAdd = Math.max(row.cantidad, 0);

                rows.remove(key);
                String groupKey = row.campana + ',' + row.obtentor; // la columna definira cuales estan en null. columna = 0 solo campana esta lleno, asi que agrupa por campana

                if (rows.containsKey(groupKey) == false) {
                    row.cantidad = 0;
                    rows.put(groupKey, row);
                }

                rows.get(groupKey).cantidad += qtyToAdd;
            }
        }

        if (columna == 1) {
            //Obtenemos el nombre del obtentor basado en el id que quedo almacenado en la venta
            Map<String,String> obtentorsById = new Map<String,String>();

            for (VentasDistribuidorController.RowWrapper row : rows.values()) {
                if (row.obtentor != null) obtentorsById.put(row.obtentor, '');
            }
            
            for(Account acc : [SELECT Id_Obtentor__c, Name FROM Account WHERE Id_Obtentor__c IN :obtentorsById.keySet()]){
                obtentorsById.put(acc.Id_Obtentor__c, acc.Name);
            }

            for (VentasDistribuidorController.RowWrapper row : rows.values()) {
                row.obtentorName = obtentorsById.get(row.obtentor);
            }
        }

        return rows.values();
    }
}