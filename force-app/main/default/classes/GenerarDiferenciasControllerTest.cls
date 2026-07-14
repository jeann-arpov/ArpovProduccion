@isTest
public class GenerarDiferenciasControllerTest {
    public static testmethod void main() {
        User u = [select id from user limit 1];

        GenerarDiferenciasController.generarDiferencias(new List<Id>());
        GenerarDiferenciasController.facturar(null);
        GenerarDiferenciasController.agregarDocumentosAfectados(new List<Id>());

        GenerarDiferenciasController cont = new GenerarDiferenciasController(new ApexPages.StandardSetController(new List<User>{u}));
    }
}