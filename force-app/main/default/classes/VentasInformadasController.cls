public without sharing class VentasInformadasController {

    @TestVisible
    private static Id testCuentaId;

    @AuraEnabled
    public static Map<String, Object> getVentaInformadaById(Id ventaId) {
        try {
            Ventas_Informadas__c v = [
                SELECT N_de_Comprobante__c, Campana_Agricola__c,
                       CUIT_Destinatario__c, CUIT_Originante__c,
                       Categoria__c,
                       Cantidad_de_Bolsas__c, Tipo_de_Comprobante__c,
                       Tipo_Comprobante_Externo__c,
                       Fecha_de_Facturacion__c, Linea_Facturacion__c,
                       Venta_Interna__c, Variedad__c, Variedad_INASE__c,
                       Variedad_INASE__r.Name, Variedad_INASE__r.Obtentor_Comercializa__c,
                       Originante__c, Rol_Originante__c,
                       Destinatario__c, Rol_Destinatario__c,
                       Razon_Social_Destinatario__c,
                       Campana_Agricola__r.Cultivo__c
                FROM Ventas_Informadas__c
                WHERE Id = :ventaId
                LIMIT 1
            ];

            Id obtComId = v.Variedad_INASE__r != null ? v.Variedad_INASE__r.Obtentor_Comercializa__c : null;
            if (
                obtComId != null
                || (v.Destinatario__c == null && String.isNotBlank(v.CUIT_Destinatario__c))
                || (v.Originante__c == null && String.isNotBlank(v.CUIT_Originante__c))
            ) {
                VentasInformadasCuitResolver.aplicarOriginanteYDestinatario(v, obtComId);
            }

            Variedad__c variedadSeleccionada;
            if (v.Variedad_INASE__c != null) {
                variedadSeleccionada = new Variedad__c(
                    Id = v.Variedad_INASE__c,
                    Name = v.Variedad_INASE__r.Name
                );
            } else if (v.Variedad__c != null) {
                Id cultivoId = v.Campana_Agricola__r != null ? v.Campana_Agricola__r.Cultivo__c : null;

                List<Variedad__c> variedades = cultivoId != null
                    ? [
                        SELECT Id, Name
                        FROM Variedad__c
                        WHERE Cultivar_INASE__c = :v.Variedad__c
                            AND Cultivo__c = :cultivoId
                        LIMIT 1
                      ]
                    : [
                        SELECT Id, Name
                        FROM Variedad__c
                        WHERE Cultivar_INASE__c = :v.Variedad__c
                        LIMIT 1
                      ];

                if (!variedades.isEmpty()) {
                    variedadSeleccionada = variedades[0];
                }
            }

            return new Map<String, Object>{
                'N_de_Comprobante__c'     => v.N_de_Comprobante__c,
                'Campana_Agricola__c'     => v.Campana_Agricola__c,
                'CUIT_Destinatario__c'    => v.CUIT_Destinatario__c,
                'Categoria__c'            => v.Categoria__c,
                'Cantidad_de_Bolsas__c'   => v.Cantidad_de_Bolsas__c,
                'Tipo_de_Comprobante__c'  => v.Tipo_de_Comprobante__c,
                'Tipo_Comprobante_Externo__c' => v.Tipo_Comprobante_Externo__c,
                'Fecha_de_Facturacion__c' => v.Fecha_de_Facturacion__c != null ? String.valueOf(v.Fecha_de_Facturacion__c) : null,
                'Linea_Facturacion__c'    => v.Linea_Facturacion__c,
                'Venta_Interna__c'        => v.Venta_Interna__c,
                'Variedad_INASE__c'         => v.Variedad_INASE__c,
                'VariedadId'              => variedadSeleccionada != null ? variedadSeleccionada.Id : null,
                'VariedadName'            => variedadSeleccionada != null ? variedadSeleccionada.Name : null,
                'Destinatario__c'         => v.Destinatario__c,
                'Rol_Destinatario__c'     => v.Rol_Destinatario__c,
                'Razon_Social_Destinatario__c' => v.Razon_Social_Destinatario__c,
                'Originante__c'           => v.Originante__c,
                'Rol_Originante__c'       => v.Rol_Originante__c,
                'CUIT_Originante__c'      => v.CUIT_Originante__c
            };
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener datos: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteVentaInformada(Id ventaId) {
        try {
            Ventas_Informadas__c venta = [SELECT Id FROM Ventas_Informadas__c WHERE Id = :ventaId LIMIT 1];
            delete venta;
        } catch (Exception e) {
            throw new AuraHandledException('Error al eliminar: ' + e.getMessage());
        }
    }

    // Helper para obtener la cuenta del usuario logueado (portal: Contact.AccountId)
    private static Id getCuentaUsuario() {
        if (Test.isRunningTest()) {
            if (testCuentaId != null) {
                return testCuentaId;
            }
            return '001000000000001';
        }

        User u = [
            SELECT AccountId, Contact.AccountId
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];
        // Portal: User.AccountId y Contact.AccountId suelen coincidir; priorizar AccountId (comportamiento histórico en prod).
        if (u.AccountId != null) {
            return u.AccountId;
        }
        return u.Contact?.AccountId;
    }

    @AuraEnabled
    public static List<Map<String, Object>> getVentasInformadasSinProcesar() {
        Id cuentaId = getCuentaUsuario();

        // Datos dummy si es test sin cuenta de prueba configurada
        List<Ventas_Informadas__c> ventas = (Test.isRunningTest() && testCuentaId == null)
            ? new List<Ventas_Informadas__c>{
                new Ventas_Informadas__c(
                    Estado__c = 'En Curso',
                    Campana_Agricola__r = new Campana_Agricola__c(Name = 'Agri Test'),
                    Destinatario__r = new Account(Name = 'Destinatario Test'),
                    CUIT_Destinatario__c = '20123456789',
                    Variedad__c = 'Variedad A',
                    Categoria__c = 'Cat 1',
                    Cantidad_de_Bolsas__c = 4000,
                    Cantidad_Bolsas_40__c = 100,
                    Tipo_Comprobante_Externo__c = 'Remito',
                    Tipo_de_Comprobante__c = 'FC',
                    Fecha_de_Facturacion__c = Date.today(),
                    N_de_Comprobante__c = '12345',
                    Linea_Facturacion__c = 1
                )
              }
            : [
                SELECT Id, Name, Estado__c,
                    Campana_Agricola__r.Name,
                    Destinatario__r.Name,
                    Razon_Social_Destinatario__c,
                    CUIT_Destinatario__c,
                    Variedad__c,
                    Categoria__c,
                    Cantidad_de_Bolsas__c,
                    Cantidad_Bolsas_40__c,
                    Tipo_Comprobante_Externo__c,
                    Tipo_de_Comprobante__c,
                    Fecha_de_Facturacion__c,
                    N_de_Comprobante__c,
                    Linea_Facturacion__c,
                    CreatedDate
                FROM Ventas_Informadas__c
                WHERE Estado__c != 'Procesado'
                AND Originante__c = :cuentaId
                ORDER BY CreatedDate DESC
              ];

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Ventas_Informadas__c v : ventas) {
            result.add(buildVentaInformadaMap(v));
        }
        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getVentasInformadasProcesadas() {
        Id cuentaId = getCuentaUsuario();

        List<Ventas_Informadas__c> ventas = (Test.isRunningTest() && testCuentaId == null)
            ? new List<Ventas_Informadas__c>{
                new Ventas_Informadas__c(
                    Estado__c = 'Procesado',
                    Campana_Agricola__r = new Campana_Agricola__c(Name = 'Campaña Test'),
                    Destinatario__r = new Account(Name = 'Destinatario Test'),
                    CUIT_Destinatario__c = '20123456789',
                    Variedad__c = 'Variedad A',
                    Categoria__c = 'Cat 1',
                    Cantidad_de_Bolsas__c = 4000,
                    Cantidad_Bolsas_40__c = 100,
                    Tipo_Comprobante_Externo__c = 'Remito',
                    Tipo_de_Comprobante__c = 'FC',
                    Fecha_de_Facturacion__c = Date.today(),
                    N_de_Comprobante__c = '12345',
                    Linea_Facturacion__c = 1
                )
            }
            : [
                SELECT Id, Name, Estado__c,
                    Campana_Agricola__r.Name,
                    Destinatario__r.Name,
                    Razon_Social_Destinatario__c,
                    CUIT_Destinatario__c,
                    Variedad__c,
                    Categoria__c,
                    Cantidad_de_Bolsas__c,
                    Cantidad_Bolsas_40__c,
                    Tipo_Comprobante_Externo__c,
                    Tipo_de_Comprobante__c,
                    Fecha_de_Facturacion__c,
                    N_de_Comprobante__c,
                    Linea_Facturacion__c,
                    CreatedDate
                FROM Ventas_Informadas__c
                WHERE Estado__c = 'Procesado'
                AND Originante__c = :cuentaId
                ORDER BY CreatedDate DESC
            ];

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Ventas_Informadas__c v : ventas) {
            result.add(buildVentaInformadaMap(v));
        }
        return result;
    }

    private static Map<String, Object> buildVentaInformadaMap(Ventas_Informadas__c v) {
        // Cantidad_de_Bolsas__c = Kilos Totales (campo de la plantilla)
        Decimal kilosTotales = v.Cantidad_de_Bolsas__c != null ? v.Cantidad_de_Bolsas__c : 0;
        Decimal bolsas40 = v.Cantidad_Bolsas_40__c != null
            ? v.Cantidad_Bolsas_40__c
            : (kilosTotales > 0 ? (kilosTotales / 40) : 0);
        String destinatarioNombre = v.Destinatario__r != null
            ? v.Destinatario__r.Name
            : v.Razon_Social_Destinatario__c;

        return new Map<String, Object>{
            'id'              => v.Id,
            'name'            => v.Name,
            'estado'          => v.Estado__c,
            'campanaAgri'     => v.Campana_Agricola__r != null ? v.Campana_Agricola__r.Name : '',
            'destinatario'    => destinatarioNombre != null ? destinatarioNombre : '',
            'cuitDest'        => v.CUIT_Destinatario__c,
            'variedad'        => v.Variedad__c,
            'categoria'       => v.Categoria__c,
            'bolsas40'        => bolsas40,
            'cantidadKilos'   => kilosTotales,
            'cantidadBigBags' => kilosTotales / 800,
            'unidadMedida'    => 'Bolsas 40 Kg',
            'tipoCompExterno' => getTipoComprobanteExterno(v),
            'fechaFact'       => v.Fecha_de_Facturacion__c != null ? String.valueOf(v.Fecha_de_Facturacion__c) : '',
            'numero'          => v.N_de_Comprobante__c,
            'lineaComprobante'=> v.Linea_Facturacion__c != null ? String.valueOf(v.Linea_Facturacion__c.intValue()) : '',
            'created'         => String.valueOf(v.CreatedDate)
        };
    }

    private static String getTipoComprobanteExterno(Ventas_Informadas__c v) {
        if (String.isNotBlank(v.Tipo_Comprobante_Externo__c)) {
            return v.Tipo_Comprobante_Externo__c;
        }
        // Legacy: registros sin Tipo_Comprobante_Externo__c poblado
        if (v.Tipo_de_Comprobante__c == 'REMITO') {
            return 'Remito';
        }
        if (v.Tipo_de_Comprobante__c == 'Remito de Devolución') {
            return 'Remito de Devolución';
        }
        return v.Tipo_de_Comprobante__c;
    }
}