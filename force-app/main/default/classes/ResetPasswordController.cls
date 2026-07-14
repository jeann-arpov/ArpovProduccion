public with sharing class ResetPasswordController {
    public String newPassword {get; set;}
    public String verifyNewPassword {get; set;}        
    
    public PageReference resetPassword() {
        return Site.changePassword(newPassword, verifyNewPassword);
    }     
    
   	public ResetPasswordController() {}
}