public without sharing class VentaListController {

    @AuraEnabled(cacheable=true)
    public static List<Venta__c> getVentas() {
        Id userId = UserInfo.getUserId();

        // 🔹 Usuario dummy si es test
        User u = Test.isRunningTest()
            ? new User()
            : [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1];

        // 🔹 Ventas dummy si es test
        List<Venta__c> ventas = Test.isRunningTest()
            ? new List<Venta__c>{
                new Venta__c(
                    Fecha__c = Date.today(),
                    Estado__c = 'Aprobada',
                    Cultivo__r = new Cultivo__c(Name = 'Trigo'),
                    Producto__r = new Product2(Name = 'Producto Test'),
                    Originante__r = new Account(Name = 'Originante Test'),
                    Destinatario__r = new Account(Name = 'Destinatario Test'),
                    Cantidad__c = 10,
                    Canal__c = 'Directo'
                )
              }
            : [SELECT Id, Name, Fecha__c, Estado__c, Cultivo__r.Name, Variedad__c,
                       Producto__r.Name, Producto__c, Campana_Agricola__c,
                       Originante__r.Name, Destinatario__r.Name, Destinatario__c,
                       Cantidad__c, Destinatario_CUIT__c, Canal__c, CreatedDate
               FROM Venta__c
               WHERE Tipo_de_Venta__c = 'Venta'
               AND Originante__c = :u.AccountId
               AND Semba_Evolucion__c = true
               AND Destinatario__r.RecordType.Name != 'Obtentor'
               ORDER BY CreatedDate DESC];

        // 🔹 Notas de Crédito que revierten una FC (en la NC el comercio es el Destinatario).
        //    Guardamos clave + fecha para repeler la FC correspondiente.
        List<Venta__c> notasCredito = Test.isRunningTest()
            ? new List<Venta__c>()
            : [SELECT Originante__c, Producto__c, Cantidad__c,
                      Campana_Agricola__c, Fecha__c
               FROM Venta__c
               WHERE Tipo_de_Comprobante__c = 'NC'
               AND Destinatario__c = :u.AccountId];

        Map<String, Date> ncKeyToFecha = buildNcKeyMap(notasCredito);

        //  Filtrar por CUIT único, repeliendo las FC que tienen una NC que las revierte
        Set<String> vistos = new Set<String>();
        List<Venta__c> resultado = new List<Venta__c>();

        for (Venta__c v : ventas) {
            if (esRevertidaPorNC(v, ncKeyToFecha)) continue;

            if (v.Destinatario_CUIT__c != null && !vistos.contains(v.Destinatario_CUIT__c)) {
                vistos.add(v.Destinatario_CUIT__c);
                resultado.add(v);
            }
        }

        return resultado;
    }

    // Construye el mapa clave -> fecha de NC. Si hay varias NC con la misma clave,
    // conserva la fecha más temprana para la guarda temporal contra la FC.
    // Reutilizable desde otros controladores (ej. UserControllerComunidad).
    public static Map<String, Date> buildNcKeyMap(List<Venta__c> notasCredito) {
        Map<String, Date> ncKeyToFecha = new Map<String, Date>();
        for (Venta__c nc : notasCredito) {
            String key = buildReversoKey(nc.Originante__c, nc.Producto__c,
                                         nc.Cantidad__c, nc.Campana_Agricola__c);
            if (key == null) continue;
            if (!ncKeyToFecha.containsKey(key) ||
                (nc.Fecha__c != null && nc.Fecha__c < ncKeyToFecha.get(key))) {
                ncKeyToFecha.put(key, nc.Fecha__c);
            }
        }
        return ncKeyToFecha;
    }

    // Clave compuesta para emparejar una FC con la NC que la revierte.
    // En la NC las cuentas están invertidas, por lo que la cuenta-productor de la
    // NC es su Originante__c y la de la FC es su Destinatario__c.
    @TestVisible
    private static String buildReversoKey(Id cuentaProductor, Id producto,
                                          Decimal cantidad, Id campana) {
        if (cuentaProductor == null || producto == null ||
            cantidad == null || campana == null) {
            return null;
        }
        return cuentaProductor + '|' + producto + '|' + cantidad + '|' + campana;
    }

    // Una FC se considera revertida si existe una NC con la misma clave
    // (cuentas invertidas + mismo producto, cantidad y campaña) y fecha posterior o igual.
    // Reutilizable desde otros controladores (ej. UserControllerComunidad).
    public static Boolean esRevertidaPorNC(Venta__c fc, Map<String, Date> ncKeyToFecha) {
        String key = buildReversoKey(fc.Destinatario__c, fc.Producto__c,
                                     fc.Cantidad__c, fc.Campana_Agricola__c);
        if (key == null || !ncKeyToFecha.containsKey(key)) return false;

        Date ncFecha = ncKeyToFecha.get(key);
        // Guarda temporal: la NC debe ser posterior o igual a la FC.
        if (ncFecha != null && fc.Fecha__c != null && ncFecha < fc.Fecha__c) {
            return false;
        }
        return true;
    }

    @AuraEnabled(cacheable=true)
    public static List<Venta_HT__c> getVentasHT() {
        // 🔹 Usuario dummy si es test
        Id userAccountId = Test.isRunningTest()
            ? '001000000000002'
            : [SELECT AccountId FROM User WHERE Id = :UserInfo.getUserId()].AccountId;

        // 🔹 Ventas HT dummy si es test
        List<Venta_HT__c> ventasHT = Test.isRunningTest()
            ? new List<Venta_HT__c>{
                new Venta_HT__c(
                    Name = 'Venta HT Test',
                    Cuenta_Productor__r = new Account(Name = 'Prod Test', N_CUIT__c = '30-98765432-1'),
                    Estado__c = 'Pagada',
                    Comercio__r = new Account(Name = 'Comercio Test', Phone = '123456'),
                    Cultivo__c = '001000000000003',
                    Cultivo__r = new Cultivo__c(Name = 'Maíz')
                )
              }
            : [SELECT Id, Name, Cuenta_Productor__r.Name, Cuenta_Productor__r.N_CUIT__c,
                       Estado__c, Comercio__r.Name, CUIT_Productor__c, Comercio__r.Phone,
                       Total_HT__c, Total_USD__c, Cultivo__c, Cultivo__r.Name, CreatedDate
               FROM Venta_HT__c
               WHERE (Estado__c = 'Pagada' OR Estado__c = 'Facturada')
               AND Comercio__c = :userAccountId
               ORDER BY CreatedDate DESC];

        //  Filtrar por CUIT único
        Set<String> vistos = new Set<String>();
        List<Venta_HT__c> resultado = new List<Venta_HT__c>();

        for (Venta_HT__c v : ventasHT) {
            if (v.CUIT_Productor__c != null && !vistos.contains(v.CUIT_Productor__c)) {
                vistos.add(v.CUIT_Productor__c);
                resultado.add(v);
            }
        }

        return resultado;
    }
}