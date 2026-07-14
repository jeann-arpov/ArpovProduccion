@IsTest
public class VentaListControllerTest {

    private static Integer fakeIdCounter = 1;

    // Genera un Id falso con el prefijo correcto del objeto referenciado por el campo lookup.
    private static Id fakeId(Schema.SObjectField field) {
        String prefix = field.getDescribe().getReferenceTo()[0].getDescribe().getKeyPrefix();
        String suffix = String.valueOf(fakeIdCounter++);
        suffix = '000000000000'.substring(suffix.length()) + suffix;
        return Id.valueOf(prefix + suffix);
    }

    public static testmethod void main () {
        VentaListController.getVentas();
        VentaListController.getVentasHT();
    }

    @IsTest
    static void testFcRevertidaPorNcSeRepele() {
        Id productor = fakeId(Venta__c.Destinatario__c);
        Id producto  = fakeId(Venta__c.Producto__c);
        Id campana   = fakeId(Venta__c.Campana_Agricola__c);

        // NC: cuentas invertidas -> la cuenta-productor es su Originante__c.
        String ncKey = VentaListController.buildReversoKey(productor, producto, 40, campana);
        System.assertNotEquals(null, ncKey, 'La clave de la NC no debe ser nula');

        Map<String, Date> ncKeyToFecha = new Map<String, Date>{
            ncKey => Date.newInstance(2026, 1, 24)
        };

        // FC con misma cuenta-productor (Destinatario), producto, cantidad y campaña,
        // y fecha anterior a la NC: debe considerarse revertida.
        Venta__c fc = new Venta__c(
            Destinatario__c = productor,
            Producto__c = producto,
            Cantidad__c = 40,
            Campana_Agricola__c = campana,
            Fecha__c = Date.newInstance(2026, 1, 15)
        );

        System.assertEquals(true,
            VentaListController.esRevertidaPorNC(fc, ncKeyToFecha),
            'La FC con una NC coincidente y posterior debe repelerse');
    }

    @IsTest
    static void testFcSinNcSeMantiene() {
        Id productor = fakeId(Venta__c.Destinatario__c);
        Id producto  = fakeId(Venta__c.Producto__c);
        Id campana   = fakeId(Venta__c.Campana_Agricola__c);

        // Sin NC: el mapa está vacío.
        Venta__c fc = new Venta__c(
            Destinatario__c = productor,
            Producto__c = producto,
            Cantidad__c = 40,
            Campana_Agricola__c = campana,
            Fecha__c = Date.newInstance(2026, 1, 15)
        );

        System.assertEquals(false,
            VentaListController.esRevertidaPorNC(fc, new Map<String, Date>()),
            'Una FC sin NC coincidente debe mantenerse');

        // Cantidad distinta: aunque exista una NC, no debe repeler (reversión parcial).
        String ncKeyOtraCantidad =
            VentaListController.buildReversoKey(productor, producto, 10, campana);
        Map<String, Date> ncKeyToFecha = new Map<String, Date>{
            ncKeyOtraCantidad => Date.newInstance(2026, 1, 24)
        };
        System.assertEquals(false,
            VentaListController.esRevertidaPorNC(fc, ncKeyToFecha),
            'Una NC de distinta cantidad no debe repeler la FC');
    }

    @IsTest
    static void testNcAnteriorNoRepele() {
        Id productor = fakeId(Venta__c.Destinatario__c);
        Id producto  = fakeId(Venta__c.Producto__c);
        Id campana   = fakeId(Venta__c.Campana_Agricola__c);

        String ncKey = VentaListController.buildReversoKey(productor, producto, 40, campana);
        // NC con fecha anterior a la FC: no debe repeler (guarda temporal).
        Map<String, Date> ncKeyToFecha = new Map<String, Date>{
            ncKey => Date.newInstance(2026, 1, 1)
        };

        Venta__c fc = new Venta__c(
            Destinatario__c = productor,
            Producto__c = producto,
            Cantidad__c = 40,
            Campana_Agricola__c = campana,
            Fecha__c = Date.newInstance(2026, 1, 15)
        );

        System.assertEquals(false,
            VentaListController.esRevertidaPorNC(fc, ncKeyToFecha),
            'Una NC anterior a la FC no debe repelerla');
    }

    @IsTest
    static void testBuildReversoKeyNulo() {
        System.assertEquals(null,
            VentaListController.buildReversoKey(null, null, null, null),
            'Con campos nulos la clave debe ser nula');
    }

    @IsTest
    static void testBuildNcKeyMap() {
        Id productor = fakeId(Venta__c.Originante__c);
        Id producto  = fakeId(Venta__c.Producto__c);
        Id campana   = fakeId(Venta__c.Campana_Agricola__c);

        // Dos NC con la misma clave: debe conservarse la fecha más temprana.
        // Una NC con campos nulos: debe ignorarse.
        List<Venta__c> ncs = new List<Venta__c>{
            new Venta__c(
                Originante__c = productor, Producto__c = producto,
                Cantidad__c = 40, Campana_Agricola__c = campana,
                Fecha__c = Date.newInstance(2026, 1, 24)
            ),
            new Venta__c(
                Originante__c = productor, Producto__c = producto,
                Cantidad__c = 40, Campana_Agricola__c = campana,
                Fecha__c = Date.newInstance(2026, 1, 10)
            ),
            new Venta__c(
                Originante__c = null, Producto__c = null,
                Cantidad__c = null, Campana_Agricola__c = null
            )
        };

        Map<String, Date> result = VentaListController.buildNcKeyMap(ncs);

        String key = VentaListController.buildReversoKey(productor, producto, 40, campana);
        System.assertEquals(1, result.size(), 'Solo debe haber una clave (NC nula ignorada)');
        System.assertEquals(Date.newInstance(2026, 1, 10), result.get(key),
            'Debe conservarse la fecha más temprana');
    }
}