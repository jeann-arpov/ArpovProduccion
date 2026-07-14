@isTest
public class ImportEstablecimientosExcelTest {

    @TestSetup
    static void setup(){
        Test_TestUtils.crearProductor();
    }
    
    @isTest static void testSuccess(){
        
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Name' => 'test',
                'Coordenadas__longitude__s' => -60.234,
                'Coordenadas__latitude__s' => -35.554,
                'Vigente__c' => 'false'
            }
        };

        ImportEstablecimientosExcel.doImport(rows);

        System.assertEquals(1, [SELECT Id FROM Establecimiento__c].size());
    }

    @isTest static void testError(){

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'Name' => 'test',
                'Coordenadas__longitude__s' => -60.234
            }
        };

        List<Map<String, Object>> results = ImportEstablecimientosExcel.doImport(rows);

        System.assert(((String) results[0].get('Error')) == 'Falta el valor de Coordenadas__latitude__s');
    }
}