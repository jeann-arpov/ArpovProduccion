@isTest
public class lwcVentasImportFromCsvControllerTest {
    public static String csv = ',3,,a,b,1-1-2021,3,3,,,,\n'.repeat(3);
    public static testmethod void saveFile() {
        Test.startTest();
        lwcVentasImportFromCsvController.process(csv);
        Test.stopTest(); 
    }
}