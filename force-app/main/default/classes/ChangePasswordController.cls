/**
 * An apex page controller that exposes the change password functionality
 */
public with sharing class ChangePasswordController {
    public String oldPassword {get; set;}
    public String newPassword {get; set;}
    public String verifyNewPassword {get; set;}        
    
    public String changePassword() {
        if (newPassword != verifyNewPassword) {
            return 'Error: The new passwords you entered do not match.';
        }
         try {
            System.Site.changePassword(newPassword, verifyNewPassword, oldPassword);
            return 'Success: Your password has been changed successfully.';

        } catch (Exception e) {
            System.debug('Password change failed for user ' + UserInfo.getUserId() + '. Error: ' + e.getMessage());
            return 'Error: ' + e.getMessage();
        }
    }     
    
}