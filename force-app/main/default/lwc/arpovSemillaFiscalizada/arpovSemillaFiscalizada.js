import { LightningElement, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import USER_ID from '@salesforce/user/Id';
import sendDeclarationEmail from '@salesforce/apex/ArpovDeclarationController.sendDeclarationEmail';

// Importación de controladores Apex
import getTodasLasCampanas from '@salesforce/apex/ArpovTransaccionesController.getTodasLasCampanas';

// Campo CUIT
import CUIT_FIELD from '@salesforce/schema/User.Contact.Account.N_CUIT__c'; 

export default class ArpovSemillaFiscalizada extends LightningElement {
    cuitProductor = '';
    
    @track isLoading = false;
    @track isSubmitted = false;

    // Array de archivos procesados: [{ fileName, fileBase64, fileType }]
    @track files = []; 

    @track formData = {
        campana: '',
        comentarios: ''
    };

    @track campanaOptions = [];

    get hasFiles() {
        return this.files && this.files.length > 0;
    }

    get isFileInputRequired() {
        return !this.hasFiles;
    }

    // Obtener CUIT automáticamente del usuario logueado
    @wire(getRecord, { recordId: USER_ID, fields: [CUIT_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.cuitProductor = getFieldValue(data, CUIT_FIELD) || 'SIN CUIT REGISTRADO';
        } else if (error) {
            console.error('Error al recuperar CUIT:', error);
            this.cuitProductor = 'Error al recuperar CUIT';
        }
    }

    // Cargar TODAS las campañas
    @wire(getTodasLasCampanas)
    wiredCampanas({ error, data }) {
        if (data) {
            this.campanaOptions = data.map(opt => ({ label: opt.label, value: opt.value }));
        } else if (error) {
            console.error('Error al recuperar campañas:', error);
            this.showToast('Error', 'No se pudieron recuperar las campañas.', 'error');
        }
    }

    handleInputChange(event) {
        const field = event.target.name;
        const value = event.target.value;
        this.formData[field] = value;
    }

    // Procesar la carga masiva de archivos a Base64
    async handleFileChange(event) {
        const selectedFiles = Array.from(event.target.files);
        if (!selectedFiles.length) return;

        this.isLoading = true;

        try {
            const filePromises = selectedFiles.map(file => this.readFileAsBase64(file));
            const newFiles = await Promise.all(filePromises);
            
            // Acumular archivos si ya existían previamente
            this.files = [...this.files, ...newFiles];

            // Limpiar error de validación visual del input de archivos
            const fileInput = this.template.querySelector('lightning-input[type="file"]');
            if (fileInput) {
                fileInput.setCustomValidity('');
                fileInput.reportValidity();
            }
        } catch (error) {
            console.error('Error al procesar archivos:', error);
            this.showToast('Error', 'Ocurrió un error al leer uno de los archivos.', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Helper para leer archivos en Base64 con Promise
    readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const base64Result = reader.result.split(',')[1];
                resolve({
                    fileName: file.name,
                    fileBase64: base64Result,
                    fileType: file.type
                });
            };
            reader.onerror = error => reject(error);
            reader.readAsDataURL(file);
        });
    }

    // Eliminar un archivo seleccionado
    handleRemoveFile(event) {
        const index = parseInt(event.target.dataset.index, 10);
        this.files = this.files.filter((_, i) => i !== index);
    }

    // Helper para obtener label de campaña por ID
    getLabelFromOptions(options, selectedValue) {
        const foundOption = options.find(opt => opt.value === selectedValue);
        return foundOption ? foundOption.label : selectedValue;
    }

    handleSubmit() {
        // 1. Validaciones estándar
        const allInputsValid = [
            ...this.template.querySelectorAll('lightning-combobox'),
            ...this.template.querySelectorAll('lightning-input'),
            ...this.template.querySelectorAll('lightning-textarea')
        ].reduce((validSoFar, inputCmp) => {
            inputCmp.reportValidity();
            return validSoFar && inputCmp.checkValidity();
        }, true);

        // 2. Validar que haya al menos un archivo
        if (!this.hasFiles) {
            const fileInput = this.template.querySelector('lightning-input[type="file"]');
            if (fileInput) {
                fileInput.setCustomValidity('Debe adjuntar al menos un comprobante para continuar.');
                fileInput.reportValidity();
            }
            this.showToast('Error', 'Por favor complete todos los campos obligatorios y adjunte al menos un comprobante.', 'error');
            return;
        }

        if (!allInputsValid) {
            this.showToast('Error', 'Por favor complete todos los campos obligatorios.', 'error');
            return;
        }

        this.isLoading = true;

        const campanaLabel = this.getLabelFromOptions(this.campanaOptions, this.formData.campana);

        // Estructura enviada a Apex (incluye la lista `files`)
        const emailParams = {
            cuit: this.cuitProductor,
            campana: campanaLabel,
            comentarios: this.formData.comentarios,
            files: this.files // Array de objetos { fileName, fileBase64, fileType }
        };

        sendDeclarationEmail({ wrapper: emailParams })
            .then(() => {
                this.isSubmitted = true;
                this.showToast('Éxito', 'Declaración enviada de forma correcta al equipo de Ventas.', 'success');
            })
            .catch(error => {
                console.error('Error enviando correo:', error);
                this.showToast('Error', 'Hubo un inconveniente al procesar tu solicitud. Intenta nuevamente.', 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}