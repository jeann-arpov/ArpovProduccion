public class headerComponentObtentorController {
    @AuraEnabled
    public static Id getListViewIdByName(String listViewName) {
        if (String.isBlank(listViewName)) {
            return null;
        }

        List<ListView> views = [
            SELECT Id, Name 
            FROM ListView 
            WHERE DeveloperName = :listViewName 
            LIMIT 1
        ];

        return views.isEmpty() ? null : views[0].Id;
    }
    
       
    @AuraEnabled(cacheable=true)
    public static List<MenuItem> getDynamicMenu(User testUser) {
    
        User u;
    
        if (Test.isRunningTest() && testUser != null) {
            u = testUser;
        } else {
            u = [
                SELECT Id,
                       UserRole.DeveloperName,
                       Contact.Es_abogado_CTV__c
                FROM User
                WHERE Id = :UserInfo.getUserId()
            ];
        }

        List<MenuItem> menuSembraEvolucion = new List<MenuItem>();
        List<MenuItem> menuCTV = new List<MenuItem>();
        List<MenuItem> menuCTVAbogados = new List<MenuItem>();

        MenuItem Licencias =
            new MenuItem(
                'Licencias',
                false,
                'licenciasobtentor', 
                null
            );

        MenuItem VentasHT =
            new MenuItem(
                'Ventas HT',
                true,
                null,
                new List<MenuItem>{
                    new MenuItem('Vender HT', false, 'vender', null),                        
                    new MenuItem('Todas las ventas HT', false, 'venta-ht/Venta_HT__c/Name:Todas_las_Ventas', null)
                });

        MenuItem ExpedienteNegativo = 
            new MenuItem(
                'Expediente de Negativos',
                false,
                'expediente-de-negativos/Expediente_de_Negativos__c/Name:All',
                null
            );

        MenuItem Reporte = 
            new MenuItem(
                'Reporte',
                false,
                '/report/00OQk000001srBdMAI/view',
                null
            );

        MenuItem PuntodeVenta = 
            new MenuItem(
                'Punto de venta',
                false,
                'puntos-de-venta',
                null 
            );

        MenuItem ListaPrecios = 
            new MenuItem(
                'lista de precios',
                false,
                'productoslist',
                //'producto-obtentor/Producto_Obtentor__c/Name:Lista_de_Productos',
                null
            );

        MenuItem Variedades =
            new MenuItem(
                'variedades sre a se',
                false,
                'variedades-sre-a-se',
                null
            );

        MenuItem Ventas =
            new MenuItem(
                'Ventas informadas',
                true,
                null,
                new List<MenuItem>{
                    new MenuItem('ventas informadas procesadas', false, 'ventasinformadasprocesadas', null),                        
                    new MenuItem('ventas informadas sin procesar', false, 'ventasinformadassinprocesar', null)
                });

        menuSembraEvolucion.add(Licencias);
        menuSembraEvolucion.add(VentasHT);
        menuSembraEvolucion.add(ListaPrecios);
        menuSembraEvolucion.add(Variedades);
        menuSembraEvolucion.add(Ventas);

        menuCTV.add(Licencias);
        menuCTV.add(ExpedienteNegativo);
        menuCTV.add(PuntodeVenta);
        menuCTV.add(VentasHT);
        menuCTV.add(ListaPrecios);
        menuCTV.add(Variedades);
        menuCTV.add(Ventas);

        menuCTVAbogados.add(ExpedienteNegativo);
        menuCTVAbogados.add(Reporte);

        if(u.UserRole.DeveloperName == 'CORTEVAAGRISCIENCEARGENTINASRLClienteUsuario' && u.Contact.Es_abogado_CTV__c == false){
            return menuCTV;
        }
        else if(u.UserRole.DeveloperName == 'CORTEVAAGRISCIENCEARGENTINASRLClienteUsuario' && u.Contact.Es_abogado_CTV__c == true){
            return menuCTVAbogados;
        }
        else {
            return menuSembraEvolucion;
        }

    }

    // ============================================================
    // WRAPPER DEL MENÚ
    // ============================================================
    public class MenuItem {
        @AuraEnabled public String label;
        @AuraEnabled public Boolean hasSubmenu;
        @AuraEnabled public String url;
        @AuraEnabled public List<MenuItem> submenu;

        public MenuItem(String label, Boolean hasSubmenu, String url, List<MenuItem> submenu) {
            this.label = label;
            this.hasSubmenu = hasSubmenu;
            this.url = url;
            this.submenu = submenu;
        }
    }
}