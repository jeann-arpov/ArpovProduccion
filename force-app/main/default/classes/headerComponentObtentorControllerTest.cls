@isTest
public class headerComponentObtentorControllerTest {

    private static User fakeUser(Boolean esAbogado, String roleDevName) {
        User u = new User();
        u.Id = UserInfo.getUserId();

        UserRole r = new UserRole();
        r.DeveloperName = roleDevName;
        u.UserRole = r;

        Contact c = new Contact();
        c.Es_abogado_CTV__c = esAbogado;
        u.Contact = c;

        return u;
    }

    @isTest
    static void testMenuCTVNoAbogado() {

        User u = fakeUser(false, 'CORTEVAAGRISCIENCEARGENTINASRLClienteUsuario');

        List<headerComponentObtentorController.MenuItem> menu =
            headerComponentObtentorController.getDynamicMenu(u);

        System.assert(menu.size() > 0);
    }

    @isTest
    static void testMenuCTVAbogado() {

        User u = fakeUser(true, 'CORTEVAAGRISCIENCEARGENTINASRLClienteUsuario');

        List<headerComponentObtentorController.MenuItem> menu =
            headerComponentObtentorController.getDynamicMenu(u);

        System.assertEquals(2, menu.size());
    }

    @isTest
    static void testMenuSembraEvolucion() {

        User u = fakeUser(false, 'OtroRolCualquiera');

        List<headerComponentObtentorController.MenuItem> menu =
            headerComponentObtentorController.getDynamicMenu(u);

        System.assert(menu.size() > 0);
    }
}