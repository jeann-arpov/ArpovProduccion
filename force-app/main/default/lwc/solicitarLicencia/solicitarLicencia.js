import { LightningElement } from 'lwc';
import {errorEvent, validateInputs, getPageParameter, doRequest, reduceErrors} from 'c/utils';
import getData from '@salesforce/apex/SolicitarLicencia.getData';
import solicitar from '@salesforce/apex/SolicitarLicencia.solicitar';
import deleteFile from '@salesforce/apex/SolicitarLicencia.deleteFile';
import enviar from '@salesforce/apex/SolicitarLicencia.enviar';
import renameFiles from '@salesforce/apex/SolicitarLicencia.renameFiles';
import { NavigationMixin } from 'lightning/navigation';

export default class SolicitarLicencia extends NavigationMixin(LightningElement) {

    marcas = [];
    loading = false;
    account;
    firmas = [{value: 'Electronica', label: 'Electrónica'}, {value: 'Holografica', label: 'Holográfica'}];
    licencia;
    files = [];
    filesData;
    tecnologia;
    marca = {Name: ''};
    step = "edit"; // 3
    mapMarkers = [];
    nombreMarcas;
    currentModal;
    modalCallback;
    needsPoder;
    licenceType;
    requireFirmanteFields = true;

    form = {
        email: null,
        firma: null,
        nombre: null,
        apellido: null,
        celular: null,
        cuil: null,
        cargo: null,
        tecnologia: null,
        marca: null,
        direccion: null,
        localidad: null,
        provincia: null,
        codigoPostal: null,
        id: null
    }

    get pageRecordId() {
        if (window.location.href.includes('s/licencia/')) return window.location.href.split('s/licencia/')[1].split('/')[0];
        return getPageParameter('recordId');
    }

    async init() {
        this.doRequest = doRequest.bind(this);
        this.initialized = true;

        this.doRequest(async _ => {
            if (!this.pageRecordId) {
                const type = getPageParameter('type');
                
                if (type == 'genetico') {
                    this.tecnologia = 'RR';//?
                } /*else if (type == 'hb4') {
                    this.tecnologia = 'RR';//?
                } */else {
                    return this.onError('Tipo de licencia inválido');
                }
            }

            const data = await getData({recordId: this.pageRecordId, firstLoad: true, tercero: getPageParameter('tercero')});
            console.log(data);

            this.account = data.account;
            this.licencia = data.licencia;
            this.files = data.files;
            this.filesData = data.filesData;
            console.log('filesData: ', this.filesData);
            this.needsPoder = data.needsPoder;
            
            this.tercero = data.tercero;

            if (!data.licencia) {
                this.fillAddressFromAccount(this.tercero || this.account);
                this.test();
                this.licenceType = getPageParameter('licenceType');
                this.marca = data.marcas.find(m => getPageParameter('marca') == m.Id);
            } else {
                this.updateFormFromRecord();
                this.updateStep();
                this.licenceType = data.licencia.Tipo_de_Licencia__c;
                this.marca = data.marcas.find(m => data.licencia.Cuenta_Obtentor__c == m.Id);
                this.requireFirmanteFields = data.licencia.Metodo_firma__c == 'Electronica';
            }

            if (!this.marca) return this.onError('Obtentor inválido');
            if (!this.licenceType) return this.onError('licenceType inválida');

            this.nombreMarcas = Array.from(new Set(data.marcas.filter(m => (this.marca.ParentId && [m.ParentId, m.Id].includes(this.marca.ParentId)) || m == this.marca || m.ParentId == this.marca.Id).map(m => m.Nombre_Obtentor__c))).join(', ');

            this.setMarker();
        });
    }

    fillAddressFromAccount(account) {
        this.form.direccion = account.ERPvs__Direccion__c;
        this.form.provincia = account.Provincia_Facturacion__c;
        this.form.localidad = account.ERPvs__Localidad__c;
        this.form.codigoPostal = account.ERPvs__Codigo_Postal__c;
    }

    setMarker() {
        if (!this.isEdit) return;
        if (this.template.querySelector(".email")) this.updateForm();

        if (this.form.direccion) {
            this.mapMarkers = [{location: {Country: 'Argentina', Street: this.form.direccion/*, PostalCode: direccion.codigoPostal*/, City: this.form.localidad, State: this.form.provincia}, title: 'Dirección Fiscal'}];
        } else {
            this.mapMarkers = [];
        }
    }

    updateStep() {
        const licencia = this.licencia;

        if (licencia.Estado__c == 'Creada' && licencia.Metodo_firma__c == 'Electronica') {
            if(this.needsUploadPoder){
                this.step = "upload-poder";
            }else if(this.needsUploadSucesion){
                this.step = "upload";
            }else{
                this.step = "firma-electronica-espera";
            }
        } else if (licencia.Estado__c == 'Creada' && licencia.Metodo_firma__c == 'Holografica') {
            this.step = "upload"; // 4 y 5
        } else {
            this.step = "resumen"; // 9, 10 y 11
        }

        console.log(this.step);
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    onError(e) {
        this.dispatchEvent(errorEvent(reduceErrors(e, true).join('\n').replace('Firmante Licencia: dirección de correo electrónico no válida', 'Dirección de correo electrónico no válida')));
    }

    redirectInicio() {
        this[NavigationMixin.Navigate]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'home'
            },
        });
    }

    validate() {
        return validateInputs(this.template);
    }

    updateForm() {
        const form = {
            email: this.template.querySelector('.email').value,
            firma: this.template.querySelector('.firma')?.value || 'Holografica',
            nombre: this.template.querySelector('.nombre').value,
            apellido: this.template.querySelector('.apellido').value,
            celular: this.template.querySelector('.celular').value,
            cuil: this.template.querySelector('.cuil').value,
            cargo: this.template.querySelector('.cargo').value,
            tecnologia: this.tecnologia,
            marca: this.marca.Id,
            direccion: this.template.querySelector('.direccion-fiscal').value,
            localidad: this.template.querySelector('.localidad').value,
            codigoPostal: this.template.querySelector('.codigo-postal').value,
            provincia: this.template.querySelector('.provincia').value,
            id: this.licencia?.Id
        }

        Object.assign(this.form, form);
    }

    async solicitarConfirm() {
        if (this.validate()) {
            this.currentModal = 'recordatorio-firmante';
            this.modalCallback = this.solicitar.bind(this);
        }
    }

    solicitar() {
        this.closeModal();
        this.updateForm();
        const data = this.form;
        data.tercero = this.tercero?.Id;
        data.licenceType = this.licenceType;
        console.log(data); 

        this.doRequest(async _ => {
            const newData = await solicitar({js: JSON.stringify(data)});
            console.log(newData);
            this.licencia = newData.licencia;
            this.files = newData.files;
            this.needsPoder = newData.needsPoder;
            this.updateStep();
        });
    }

    redirectToRecord() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.licencia.Id,
                actionName: 'view'
            }
        });
    }

    test() {
        if (getPageParameter('test') != 'true') return;
        this.form.nombre = 'test';
        this.form.apellido = 'test';
        this.form.cuil = '20216950209';
        this.form.celular = '+5411111111';
        this.form.cargo = 'ceo';
        this.form.firma = this.firmas[0].value;
    }

    downloadContratoLicencia(e) {
        const id = this.files.find(f => f.ContentDocument.Title == this.licencia.Name + '-Licencia').ContentDocument.Id;
        const version = this.filesData[id];
        this.doDownloadFile(version.fileName, version.data);
    }

    //hacemos la descarga manual porque el link esta sujeto a sharing y si un usuario quiere descargar una licencia que creo otro usuario de la misma cuenta no funciona (solo en cuentas distribuidor)
    doDownloadFile(fileName, fileBody){
        const binaryString = atob(fileBody);
        const blob = new Blob([new Uint8Array(Array.from(binaryString, char => char.charCodeAt(0)))], { type: 'application/pdf' });

        const downLink = document.createElement('a');
        downLink.href = URL.createObjectURL(blob);
        downLink.target = '_blank';
        downLink.download = fileName;
        downLink.click();
    }

    downloadFile(e) {
        const id = e.target.dataset.id;
        const version = this.filesData[id];
        this.doDownloadFile(version.fileName, version.data);
    }

    handleMetodoFirma(event){
        this.requireFirmanteFields = event.detail.value == 'Electronica';
    }

    async handleFileDelete(e) {
        const file = this.files.find(f => f.ContentDocument.Id == e.target.dataset.id);

        if (file.ContentDocument.Title == this.licencia.Name + '-Licencia') return this.onError('No se puede elimiar la carta oferta');

        await this.doRequest(async _ => {
            await deleteFile({fileId: file.ContentDocument.Id, licenciaId: this.licencia.Id});
            this.files = this.files.filter(f => f != file);
        });
    }

    contratoFirmadoUploadFinished(e) {
        this.rename(e.detail.files, this.licencia.Name + '-Licencia-Firmada');        
    }

    handleUploadFinished(e) {
        this.files = this.files.concat(e.detail.files.map(f => ({ContentDocument: {Id: f.documentId, Title: f.name.replace('.pdf', '')}})));
    }

    handleDniUploadFinished(e) {
        this.rename(e.detail.files, this.licencia.Name + e.target.dataset.filename);
    }

    handleConstanciaAfipUploadFinished(e) {
        this.rename(e.detail.files, this.licencia.Name + '-Constancia AFIP');
    }

    handleSucesionUploadFinished(e){
        this.rename(e.detail.files, this.licencia.Name + '-Poder / Resolucion Judicial de Sucesion');
    }

    poderUploadFinished(e) {
        this.rename(e.detail.files, this.licencia.Name + '-Poder');
    }

    async rename(files, name) {
        this.doRequest(async _ => {
            await renameFiles({licenciaId: this.licencia.Id, fileIds: files.map(f => f.documentId), name});

            for (const file of files) {
                this.files.push({ContentDocument: {Id: file.documentId, Title: name}});
            }
        });
    }

    handleFilePreview(e) {
        const file = this.files.find(f => f.ContentDocument.Id == e.target.dataset.id);

        this.template.querySelector('c-pdf-reader').show({
            documentId: file.ContentDocument.Id,
            title: file.ContentDocument.Title
        });
    }

    async enviar(e) {
        await this.doRequest(async _ => {
            this.licencia = await enviar({licenciaId: this.licencia.Id});
            this.step = "sent";
        });
    }

    get needsUploadPoder() {
        return this.licencia && this.needsPoder && this.licencia.Metodo_firma__c == 'Electronica';
    }

    get shouldUploadContract() {
        return this.isUploadPoder || this.files.find(f => f.ContentDocument.Title == this.licencia.Name + '-Licencia-Firmada') != null;
    }

    get needsUploadCertificadoFirma(){
        //return !this.isUploadPoder && this.licencia.Metodo_firma__c == 'Holografica' && !this.needsUploadDniAndAfip;
        return false;
    }

    get needsUploadDniAndAfip(){
        return !this.isUploadPoder && this.isPersonaFisica && this.licencia.Cuenta_Productor__r.N_CUIT__c == this.licencia.Firmante_Cuit__c && this.licencia.Metodo_firma__c == 'Holografica';
    }

    get needsUploadSucesion(){
        return this.isPersonaFisica && this.licencia.Cuenta_Productor__r.N_CUIT__c != this.licencia.Firmante_Cuit__c && this.licencia.Metodo_firma__c == 'Electronica';
    }

    get isEdit() {
        return this.account && this.step == 'edit';
    }

    get isUpload() {
        return this.step == 'upload' || this.isUploadPoder;
    }

    get isUploadPoder() {
        return this.step == 'upload-poder';
    }

    get isSendSuccess() {
        return this.step == 'sent';
    }

    get isResumen() {
        return this.step == 'resumen';
    }

    get isFirmaElectronicaEspera() {
        return this.step == 'firma-electronica-espera';
    }

    get showMetodoFirma(){
        return this.marca.Proveedor__c != null || this.marca.Parent?.Proveedor__c != null;
    }

    get isPersonaFisica(){
        return this.licencia.Cuenta_Productor__r.N_CUIT__c.startsWith('2');
    }

    goToResumen(e) {
        this.step = 'resumen';
    }

    get resumenTitle() {
        if (this.licencia.Estado__c == 'Aprobado') return '¡Felicitaciones! El contrato de licencia fue aprobado';
        else if (this.licencia.Estado__c == 'Rechazado') return 'Lamentamos informarte que el contrato de licencia no fue aprobado';
        return 'Seguí el estado de tu licencia';
    }

    get filesWithoutCartaOferta() {
        return this.files.filter(file => file.ContentDocument.Title != this.licencia.Name + '-Carta de Aceptacion' &&  file.ContentDocument.Title != this.licencia.Name + '-Licencia');
    }

    get filesFirmados() {
        return this.files.filter(file => file.ContentDocument.Title == this.licencia.Name + '-Licencia-Firmada' || file.ContentDocument.Title == this.licencia.Name + 'Carta de Aceptacion-Firmada');
    }

    get licenciatarioName() {
        return this.tercero ? this.tercero.Name : this.account.Name;
    }

    get licenciatarioCuit() {
        return this.tercero ? this.tercero.N_CUIT__c : this.account.N_CUIT__c;
    }

    get hideCertificaEscribano(){
        return this.licencia.Metodo_firma__c == 'Holografica' &&  this.isPersonaFisica && this.licencia.Cuenta_Obtentor__r.N_CUIT__c == '30616275905';
    }

    backToEdit() {
        this.step = "edit";
        this.updateFormFromRecord();
        this.setMarker();
    }

    updateFormFromRecord() {
        this.form.nombre = this.licencia.Firmante_First_Name__c;
        this.form.apellido = this.licencia.Firmante_Last_Name__c;
        this.form.cuil = this.licencia.Firmante_Cuit__c;
        this.form.celular = this.licencia.Firmante_Celular__c;
        this.form.cargo = this.licencia.Firmante_Cargo__c;
        this.form.firma = this.licencia.Metodo_firma__c;
        this.form.email = this.licencia.Firmante_Licencia__c;
        this.form.direccion = this.licencia.Direccion_Fiscal_Firmante__c;
        this.form.localidad = this.licencia.Localidad__c;
        this.form.codigoPostal = this.licencia.Codigo_Postal_Firmante__c;
        this.form.provincia = this.licencia.Provincia_Firmante__c;
    }

    /*get sentSuccessLabel() {
        return 'Tu solicitud de licencia ha sido enviada correctamente' + (this.licencia.Metodo_firma__c == 'Electronica' ? '. Deberá llegar al mail del firmante la solicitud de firma electrónica' : '')
    }*/

    closeModal() {
        this.currentModal = null;
        this.modalCallback = null;
    }
}