@isTest
public class ResetPasswordControllerTest {
    @IsTest(SeeAllData=true) public static void main() {
        ResetPasswordController controller = new ResetPasswordController();
        controller.newPassword = 'qwerty1'; 
        controller.verifyNewPassword = 'qwerty1';                
        
        System.assertEquals(controller.resetPassword(),null);                           
    }    
}