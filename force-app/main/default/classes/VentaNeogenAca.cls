/**
 * SE-332. A.C.A (CUIT 30500120882) informa semilla fiscalizada NEOGEN de soja
 * (Obtentor Comercializa = GDM, Id Obtentor 85) con el mismo rol y la misma
 * regla de variedad propia que una venta informada por GDM.
 * Obtentor Comercializa de la variedad no se modifica: la licencia y la HT
 * siguen saliendo de esa cuenta GDM.
 * Si el cultivo está informado y no es SOJA, la excepción no aplica.
 * Si el cultivo no está en la variedad, alcanza con Id Obtentor 85.
 */
public class VentaNeogenAca {
    public static final String CUIT_ACA = '30500120882';
    public static final String ID_OBTENTOR_NEOGEN = '85';
    public static final String CULTIVO_SOJA = 'SOJA';

    private static Map<Id, String> idObtentorPorCuenta = new Map<Id, String>();
    private static Map<String, String> cultivoPorVariedad = new Map<String, String>();
    private static Set<Id> cuentasCargadas = new Set<Id>();
    private static Set<String> variedadesCargadas = new Set<String>();

    public static Boolean esAca(String cuit) {
        return CrearVentaInformadaLWCController.limpiarCuit(cuit) == CUIT_ACA;
    }

    public static Boolean acreditaComoObtentor(String cuitOriginante, String idObtentor, String cultivo) {
        if (!esAca(cuitOriginante) || idObtentor != ID_OBTENTOR_NEOGEN) {
            return false;
        }
        return String.isBlank(cultivo) || cultivo.equalsIgnoreCase(CULTIVO_SOJA);
    }

    public static void precargar(List<Ventas_Informadas__c> ventas, Set<Id> obtentorIds) {
        Set<Id> cuentas = new Set<Id>();
        if (obtentorIds != null) {
            cuentas.addAll(obtentorIds);
        }
        Set<String> cultivares = new Set<String>();
        Set<Id> variedadIds = new Set<Id>();
        if (ventas != null) {
            for (Ventas_Informadas__c venta : ventas) {
                if (venta == null) {
                    continue;
                }
                if (venta.Originante__c != null) {
                    cuentas.add(venta.Originante__c);
                }
                if (String.isNotBlank(venta.Variedad__c)) {
                    cultivares.add(venta.Variedad__c);
                }
                if (venta.Variedad_INASE__c != null) {
                    variedadIds.add(venta.Variedad_INASE__c);
                }
            }
        }
        cuentas.removeAll(cuentasCargadas);
        if (!cuentas.isEmpty()) {
            for (Account cuenta : [SELECT Id, Id_Obtentor__c FROM Account WHERE Id IN :cuentas]) {
                idObtentorPorCuenta.put(cuenta.Id, cuenta.Id_Obtentor__c);
            }
            cuentasCargadas.addAll(cuentas);
        }

        cultivares.removeAll(variedadesCargadas);
        if (!cultivares.isEmpty() || !variedadIds.isEmpty()) {
            for (Variedad__c variedad : [
                SELECT Cultivar_INASE__c, Cultivo__r.Name
                FROM Variedad__c
                WHERE Cultivar_INASE__c IN :cultivares OR Id IN :variedadIds
            ]) {
                String cultivo = variedad.Cultivo__r == null ? null : variedad.Cultivo__r.Name;
                if (String.isNotBlank(variedad.Cultivar_INASE__c)) {
                    cultivoPorVariedad.put(variedad.Cultivar_INASE__c, cultivo);
                }
            }
            variedadesCargadas.addAll(cultivares);
        }
    }

    public static Boolean acreditaVentaInformada(
        Ventas_Informadas__c venta,
        Account originante,
        Id obtentorComercializaId
    ) {
        if (venta == null || obtentorComercializaId == null) {
            return false;
        }
        if (!cuentasCargadas.contains(obtentorComercializaId)) {
            precargar(new List<Ventas_Informadas__c>{ venta }, new Set<Id>{ obtentorComercializaId });
        }
        String cuit = venta.CUIT_Originante__c;
        if (
            originante != null &&
            originante.getPopulatedFieldsAsMap().containsKey('N_CUIT__c') &&
            String.isNotBlank(originante.N_CUIT__c)
        ) {
            cuit = originante.N_CUIT__c;
        }
        String cultivo = String.isNotBlank(venta.Variedad__c)
            ? cultivoPorVariedad.get(venta.Variedad__c)
            : null;
        return acreditaComoObtentor(cuit, idObtentorPorCuenta.get(obtentorComercializaId), cultivo);
    }
}
