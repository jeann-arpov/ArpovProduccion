/**
 * @description Controller encargado del envío de correos de declaración de siembra.
 * @author      Nerio Alvarado
 * @date        Julio 2026
 */
public without sharing class ArpovDeclarationController {

    public class FileWrapper {
        @AuraEnabled public String fileName { get; set; }
        @AuraEnabled public String fileBase64 { get; set; }
        @AuraEnabled public String fileType { get; set; }
    }

    public class DeclarationWrapper {
        @AuraEnabled public String cuit { get; set; }
        @AuraEnabled public String campana { get; set; }
        @AuraEnabled public String comentarios { get; set; }
        @AuraEnabled public List<FileWrapper> files { get; set; }
    }

    @AuraEnabled
    public static void sendDeclarationEmail(DeclarationWrapper wrapper) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            
            // 1. OBTENER EL ID DE FORMA DINÁMICA DESDE EL CUSTOM METADATA
            ArPOV_Portal_Config__mdt emailConfig = ArPOV_Portal_Config__mdt.getInstance('Org_Wide_Email_Id');
            
            if (emailConfig != null && String.isNotBlank(emailConfig.Value__c)) {
                mail.setOrgWideEmailAddressId((Id)emailConfig.Value__c);
            } else {
                throw new AuraHandledException('Falta la configuración del ID del remitente en el Custom Metadata.');
            }

            // 2. CONFIGURACIÓN DEL DESTINATARIO
            String[] toAddresses = new String[] {'regaliaextendida@arpov.org.ar'};
            mail.setToAddresses(toAddresses);
            
            // 3. ASUNTO DEL CORREO
            mail.setSubject('NUEVA DECLARACIÓN: Semilla Fiscalizada - CUIT: ' + wrapper.cuit);
            
            // 4. CUERPO DEL CORREO EN HTML CON DISEÑO DE TARJETA (ESTILO ARPOV)
            String body = '<div style="background-color: #f2f7f5; padding: 30px 10px; font-family: Arial, Helvetica, sans-serif;">';
            body += '  <div style="max-width: 580px; margin: 0 auto; background-color: #ffffff; border-radius: 20px; padding: 40px 30px; text-align: center; box-shadow: 0 4px 10px rgba(0,0,0,0.05);">';
            
            // Encabezados
            body += '    <h1 style="color: #00382B; font-size: 22px; font-weight: bold; margin: 0 0 4px 0;">Portal del Productor</h1>';
            body += '    <p style="color: #00382B; font-size: 13px; font-weight: bold; margin: 0 0 25px 0;">ArPOV</p>';
            
            body += '    <h2 style="color: #00382B; font-size: 18px; font-weight: bold; margin: 0 0 20px 0;">¡Se ha recibido una nueva Declaración de Siembra!</h2>';
            
            // Tabla de datos declarados
            body += '    <table style="width: 100%; border-collapse: collapse; text-align: left; margin-bottom: 25px; font-size: 14px;">';
            body += '      <tr style="border-bottom: 1px solid #e0e0e0;">';
            body += '        <td style="padding: 10px 8px; color: #00382B; font-weight: bold; width: 40%;">CUIT del Productor:</td>';
            body += '        <td style="padding: 10px 8px; color: #333333;">' + wrapper.cuit + '</td>';
            body += '      </tr>';
            body += '      <tr style="border-bottom: 1px solid #e0e0e0;">';
            body += '        <td style="padding: 10px 8px; color: #00382B; font-weight: bold;">Campaña:</td>';
            body += '        <td style="padding: 10px 8px; color: #333333;">' + wrapper.campana + '</td>';
            body += '      </tr>';
            body += '      <tr style="border-bottom: 1px solid #e0e0e0;">';
            body += '        <td style="padding: 10px 8px; color: #00382B; font-weight: bold;">Comentarios:</td>';
            body += '        <td style="padding: 10px 8px; color: #333333;">' + (String.isNotBlank(wrapper.comentarios) ? wrapper.comentarios : 'Sin observaciones') + '</td>';
            body += '      </tr>';
            body += '    </table>';

            body += '    <p style="color: #555555; font-size: 13px; margin-bottom: 25px;">Se adjunta la documentación respaldatoria para su correspondiente validación.</p>';
            
            // Botón verde de acceso
            body += '    <div style="margin: 30px 0;">';
            body += '      <a href="https://arpov.org" target="_blank" style="background-color: #00c853; color: #ffffff; text-decoration: none; padding: 12px 32px; border-radius: 25px; font-weight: bold; font-size: 14px; display: inline-block;">Acceder al Portal</a>';
            body += '    </div>';
            
            // Pie de página
            body += '    <p style="color: #555555; font-size: 12px; margin-top: 35px; margin-bottom: 4px;">Si tenés alguna consulta, contactanos a</p>';
            body += '    <p style="margin: 0 0 25px 0;"><a href="mailto:regaliaextendida@arpov.org.ar" style="color: #00382B; font-weight: bold; text-decoration: none; font-size: 13px;">regaliaextendida@arpov.org.ar</a></p>';
            
            body += '    <p style="color: #00382B; font-weight: bold; font-size: 13px; margin: 0;">Saludos,<br/>ArPOV.</p>';
            
            body += '  </div>';
            body += '</div>';
            
            mail.setHtmlBody(body);

            // 5. PROCESAMIENTO Y ADJUNTO DE MÚLTIPLES ARCHIVOS
            List<Messaging.EmailFileAttachment> attachments = new List<Messaging.EmailFileAttachment>();

            if (wrapper.files != null && !wrapper.files.isEmpty()) {
                for (FileWrapper file : wrapper.files) {
                    if (String.isNotBlank(file.fileBase64) && String.isNotBlank(file.fileName)) {
                        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                        attachment.setFileName(file.fileName);
                        attachment.setBody(EncodingUtil.base64Decode(file.fileBase64));
                        if (String.isNotBlank(file.fileType)) {
                            attachment.setContentType(file.fileType);
                        }
                        attachments.add(attachment);
                    }
                }
            }

            if (!attachments.isEmpty()) {
                mail.setFileAttachments(attachments);
            }

            // 6. ENVÍO DEL CORREO Y VERIFICACIÓN
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
            if (!results[0].isSuccess()) {
                throw new AuraHandledException('Salesforce rechazó el envío del email: ' + results[0].getErrors()[0].getMessage());
            }
            
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}