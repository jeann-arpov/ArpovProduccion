import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLoadData from '@salesforce/apex/CesionPPH.getLoadData';
import deleteDestinatario from '@salesforce/apex/CesionPPH.deleteDestinatario';
import sendCesion from '@salesforce/apex/CesionPPH.sendCesion';
import save from '@salesforce/apex/CesionPPH.save';
import backToEnCurso from '@salesforce/apex/CesionPPH.backToEnCurso';
import anular from '@salesforce/apex/CesionPPH.anular';
import deleteFile from '@salesforce/apex/CesionPPH.deleteFile';
import getNewCesionData from '@salesforce/apex/CesionPPH.getNewCesionData';

import {errorEvent} from 'c/utils';
import icons from 'c/icons';

function validateCuit(cuit) {
    if (cuit.length !== 11) {
      return false;
    }
  
    const [checkDigit, ...rest] = cuit
      .split('')
      .map(Number)
      .reverse();
  
    const total = rest.reduce(
      (acc, cur, index) => acc + cur * (2 + (index % 6)),
      0,
    );
  
    const mod11 = 11 - (total % 11);
  
    if (mod11 === 11) {
        checkDigit = 0;
    }
  
    if (mod11 === 10) {
        checkDigit = 9;
    }
  
    return checkDigit === mod11;
}

export default class CesionPph extends NavigationMixin(LightningElement) {
    @track destinatarios = [];
    @track variedades = [];
    
    loading = true;
    step = "cesion";
    initialized = false;
    counter = 1;
    cesion;
    accounts;
    hiding = {};
    licenses;
    files = [];
    doContinue = false;
    cultivos;
    cultivo;
    tnsBolsatech;

    seedIcon = icons.compraVenta.seed;
    currentModal;
    modalCallback;

    async init() {
        this.initialized = true;

        try {
            const data = await getLoadData({cesionId: this.pageRecordId});
            this.loadData(data);
            console.log(data);
        } catch (e) {
            this.onError(e);
        }

        this.loading = false;
    }

    get pageRecordId() {
        if (window.location.href.includes('s/cesion-ht/')) return window.location.href.split('s/cesion-ht/')[1].split('/')[0];
        if (window.location.href.includes('recordId=')) return window.location.href.split('recordId=')[1].split('&')[0];
        return null;
    }

    get pageTipoCesion(){
        if(window.location.href.includes('type=')){
            const value = window.location.href.split('type=')[1];
            const tipoCesion = `${value.split('%20')[0]} ${value.split('%20')[1]}`;
            return tipoCesion;
        }
    }

    get isCesion() {
        return this.step == 'cesion';
    }

    get showFileUpload(){
        return this.isCesion || this.isEdit;
    }

    get isResumen() {
        return this.step == "resumen";
    }

    get isEdit() {
        return this.step == 'edit';
    }

    get isCultivo(){
        return this.step == 'cultivo';
    }

    renderedCallback() {
        if (this.initialized == false) {
            this.init();
        }
    }

    loadData(data) {
        if(data.cultivos){
            this.cultivos = data.cultivos;
            this.step = 'cultivo';
        }else{
            if (data.cesion) {
                this.variedades = data.variedades;
                this.cesion = data.cesion;
    
                this.variedades.forEach(v => v.totals = {stock: data.stock[v.Id]});
    
                this.accounts = Object.fromEntries(data.accounts.map(a => [a.id, a]));
                this.files = data.files;
            }

            if(data.tnsBolsatech) this.tnsBolsatech = data.tnsBolsatech;
    
            this.licenses = data.licenses;
            this.variedades.forEach(v => v.totals.current = 0);
    
            const variedades = Object.fromEntries(this.variedades.map(v => [v.Id, v]));
    
            const destinatarios = [];
    
            for (const destinatario of data.destinatarios) {
                const dest = {id: destinatario.Id, record: destinatario, lineas: [], account: this.accounts[destinatario.Destinatario__c]};
    
                for (const variedadId of Object.keys(variedades)) {
                    const record = (destinatario.Lineas_Cesion_HT__r || []).find(l => l.Variedad__c == variedadId) || {};
                    dest.lineas.push({id: variedadId, record, variedad: variedades[variedadId]});
                    variedades[variedadId].totals.current += record.Cantidad__c || 0;
                }

                //si la cesion ya no esta en curso, tengo que agregar las lineas independientemente del stock
                if(this.isEnCurso == false && this.hasDestinatarioEnCurso == false){
                    for(const linea of destinatario.Lineas_Cesion_HT__r || []){
                        if(!dest.lineas.find(l => l.id == linea.Variedad__c)){
                            dest.lineas.push({id: linea.Variedad__c, record: linea, variedad: {...linea.Variedad__r, totals: {stock: 0}}});
                        }
                    }
                }
    
                destinatarios.push(dest);
            }
    
            console.log(JSON.parse(JSON.stringify(destinatarios)))
    
            this.destinatarios = destinatarios;
    
            if (this.destinatarios.length == 0) this.addRow();
    
            if (this.isEnCurso == false && this.hasDestinatarioEnCurso == false) setTimeout(_ => this.step = "resumen", 0);

        }
        console.log('variedades:', this.variedades);
    }

    addRow() {
        if(this.destinatarios.length > 0){
            this.modalCallback = this.confirmAddRow.bind(this);
            this.currentModal = "confirm-add-destinatario";
        }else{
            this.confirmAddRow();
        }
    }

    confirmAddRow(){
        this.closeModal();
        const lineas = this.variedades.map(variedad => ({id: variedad.Id, record: {}, variedad}));
        this.destinatarios.push({id: ++this.counter, record: {Estado__c: 'En Curso'}, lineas});
    }

    remove(event) {
        if (this.destinatarios.length == 1) return this.onError("No puede borrar el único destinatario restante");
        this.modalCallback = this.confirmDelete.bind(this, event.target);
        this.currentModal = "confirm-delete-destinatario";
    }

    async confirmDelete(toDelete) {
        this.closeModal();
        const id = toDelete.info.record?.Id;

        if (id != null) {
            this.doRequest(() => deleteDestinatario({id}).then(_ => this.removeDestinatario(toDelete)));
        } else {
            this.removeDestinatario(toDelete);
        }
    }

    cultivoSelected(event){
        this.cultivo = event.detail.value;
    }

    async startCesion(){
        await this.doRequest(async _ => {
            const data = await getNewCesionData({cultivoId: this.cultivo, tipoCesion: this.pageTipoCesion});
            console.log(data);
            this.loadData(data);
            this.step = 'cesion';
        });
    }

    get tipoCesion(){
        return this.cesion?.tipoCesion;
    }

    get sinCultivosDisponibles(){
        return this.isCultivo && this.cultivos.length == 0;
    }

    removeDestinatario(destinatario) {
        const id = destinatario.info.id;
        const variedades = destinatario.getData().variedades;
        //tengo que descartar las cantidades de hectareas que pusieron
        for (const variedad of Object.keys(variedades)) {
            this.updateCantidad({detail:{variedad, cantidad: -variedades[variedad].cantidad}});
        }

        this.destinatarios = this.destinatarios.filter(e => e.id !== id);
    }

    redirectToCompraHT(){
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__namedPage',
            attributes: {
                pageName: 'FormularioNuevaVentaHT'
            }
        }).then(url => window.open(`${url}?cultivoId=${this.cesion.Cultivo__c}`, '_self'));
    }

    updateCantidad(event) {
        const variedad = this.variedades.find(v => v.Id == event.detail.variedad);
        variedad.totals.current += event.detail.cantidad;
    }

    async doRequest(callback) {
        this.loading = true;

        try {
            await callback();
        } catch (e) {
            this.onError(e);
        }

        this.loading = false;
    }

    closeModal() {
        this.currentModal = null;
        this.modalCallback = null;
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    autosave(e) {
        this.save();
    }

    isValid(showError = false, isContinue = false) {
        let valid = true;

        try {
            for (const destinatario of this.template.querySelectorAll('c-destinatario-pph')) {
                if (!destinatario.validate(isContinue)) valid = false;
            }
        } catch (e) {
            valid = false;
            if (showError) this.onError(e);
        }

        return valid;
    }

    async save() {
        console.log("saving")
        await this.doRequest(async _ => {
            if (this.isValid()) {
                const data = this.data;
                const toSend = {destinatarios: data.destinatarios.filter(d => d.record?.Estado__c == 'En Curso' || d.record?.Estado__c == null)};
                console.log(JSON.parse(JSON.stringify(toSend)));
                const newData = await save({js: JSON.stringify(toSend), cesionId: this.cesion.Id});
                this.loadData(newData);

                if (this.doContinue) {
                    this.doContinue = false;
                    this.continuar();
                }
            }
        })
    }

    get data() {
        const data = {destinatarios: [], cesion: this.cesion, licenses: this.licenses, tnsBolsatech: this.tnsBolsatech};

        for (const destinatario of this.template.querySelectorAll('c-destinatario-pph')) {
            const dest = destinatario.getData();
            data.destinatarios.push(dest);
            if (dest.destinatarioId) this.accounts[dest.destinatarioId] = destinatario.getAccount(); //se resetea el componente, me guardo en el map la info de la account para no tener que traer en cada load
        }

        data.stock = this.variedades.map(v => v.totals.stock).reduce((a, b) => a + b, 0);
        console.log(data);
        return data;
    }

    continuar(e) {
        if (this.isValid(true, true)) {
            this.step = "resumen";
        }
    }

    get isEnCurso() {
        return this.cesion.Estado__c == 'En Curso';
    }

    get hasDestinatarioEnCurso() {
        return this.destinatarios.find(d => d.record?.Estado__c == 'En Curso') != null;
    }

    editConfirm(e) {
        if (this.isEnCurso) {
            this.edit(e.detail.id);
        } else {
            this.modalCallback = this.edit.bind(this, e.detail.id);
            this.currentModal = "confirm-edit-cesion";
        }
    }

    async edit(id) {
        this.closeModal();

        await this.doRequest(async _ => {
            if (!this.isEnCurso) await backToEnCurso({cesionId: this.cesion.Id}).then(data => this.loadData(data));

            this.hiding = {};

            for (const destinatario of this.destinatarios) {
                if (destinatario.id !== id) {
                    this.hiding[destinatario.id] = true;
                }
            }
            
            this.step = "edit";
        })
    }

    anularConfirm(e) {
        this.modalCallback = this.anular.bind(this);
        this.currentModal = "confirm-anular-cesion";
    }

    async anular() {
        this.closeModal();

        await this.doRequest(async _ => {
            await anular({cesionId: this.cesion.Id}).then(data => this.loadData(data));
        });
    }

    backToResumen(e) {
        if (this.isValid(true, true)) {
            this.step = "resumen";
        }
    }
    
    get cesionClass() {
        return (this.isCesion || this.isEdit) ? '' : 'slds-hide';
    }

    enviarConfirm(e) {
        if(this.showWarningHT){
            this.dispatchEvent(errorEvent(new Error('No se puede enviar la cesión porque no tiene el stock suficiente')));
            return;
        }
        this.modalCallback = this.enviar.bind(this);
        this.currentModal = e.detail.hasLicenses ? "confirm-enviar-cesion" : "confirm-enviar-cesion-without-licenses";
    }

    async enviar(e) {
        await this.doRequest(async _ => {
            await sendCesion({cesionId: this.cesion.Id}).then(data => this.loadData(data));
            this.currentModal = "adherido-cesion";
        });
    }

    get title() {
        if (this.isResumen) {
            return this.cesion.Estado__c == 'Pendiente de Validación' ? '¡Tu solicitud de cesión ya fue enviada!' : 'Resumen de tu solicitud';
        }

        if(this.isCultivo){
            return 'Seleccioná el cultivo para la cesión';
        }

        return 'Subí tu contrato de convenio de cesión';
    }
    
    get showWarning(){
        return this.isResumen == false && (this.showWarningFechaCultivo || this.showWarningHT);
    }
    
    get showWarningHT(){
        return this.variedades.find(v => v.totals.stock - v.totals.current < 0);
    }

    get showWarningFechaCultivo(){
        const now = Date.now();
        return now < Date.parse(this.fechaInicioCesion) || now > Date.parse(this.fechaFinCesion);
    }

    get fechaInicioCesion(){
        return this.tipoCesion == 'Explotacion Conjunta' ? this.cesion?.Cultivo__r.Fecha_Inicio_de_Cesion__c : this.cesion?.Cultivo__r.Fecha_Inicio_de_Cesion_Semilla_Original__c;
    }

    get fechaFinCesion(){
        return this.tipoCesion == 'Explotacion Conjunta' ? this.cesion?.Cultivo__r.Fecha_Fin_de_Cesion__c : this.cesion?.Cultivo__r.Fecha_Fin_de_Cesion_Semilla_Original__c;
    }

    get htsWarningText(){
        return 'Atención: Es necesario que adquieras HT disponibles para cubrir las toneladas faltantes y poder confirmar la cesión. Podes igualmente iniciar el trámite y quedará pendiente.';
    }
    
    get fechasCesionWarningText(){
        return `Atención: No será posible confirmar operaciones de cesión de toneladas de ${this.cesion?.Cultivo__r.Name} hasta el próximo ${this.formattedFechaCesion}. Podés igualmente iniciar el trámite y quedará pendiente.`;
    }

    get formattedFechaCesion(){
        const formmatedDate = new Date(this.fechaInicioCesion);
        formmatedDate.setHours(formmatedDate.getHours() + 3);
        return formmatedDate.toLocaleDateString('es-AR', {day: 'numeric', month: 'long'});
    }

    handleUploadFinished(e) {
        this.files = this.files.concat(e.detail.files.map(f => ({ContentDocument: {Id: f.documentId, Title: f.name.substring(0, f.name.lastIndexOf('.')), extension: f.name.split('.').pop().toUpperCase()}})));
    }

    handleFilePreview(e) {
        const file = this.files.find(f => f.ContentDocument.Id == e.target.dataset.id);
        window.open(window.location.href.split('/s/')[0] + '/s/contentdocument/' + file.ContentDocument.Id);
    }

    async handleFileDelete(e) {
        const file = this.files.find(f => f.ContentDocument.Id == e.target.dataset.id);

        await this.doRequest(async _ => {
            await deleteFile({fileId: file.ContentDocument.Id, cesionId: this.cesion.Id});
            this.files = this.files.filter(f => f != file);
        });
    }

    registerCuit(e) {
        const cuit = e.detail;
        const target = e.target;
        
        if (validateCuit(cuit)) {
            this.currentModal = "register-cuit-" + cuit;
            this.modalCallback = this.onRegisterCuit.bind(this, target);
        } else {
            this.onError('Cuit inválido');
        }
    }

    onRegisterCuit(destinatario, res) {
        this.closeModal();
        destinatario.onRegisterCuit(res);
    }

    isPointerEventInsideElement(event, element) {
        var pos = {
            x: (event.targetTouches ? event.targetTouches[0].pageX : event.pageX) - window.scrollX,
            y: (event.targetTouches ? event.targetTouches[0].pageY : event.pageY) - window.scrollY
        };
        var rect = element.getBoundingClientRect();
        console.log(pos, rect, element)
        return  pos.x < rect.right && pos.x > rect.left && pos.y < rect.bottom && pos.y > rect.top;
    };

    loadingClick(e) {
        if (this.loading && this.step == "cesion" && this.isPointerEventInsideElement(e, this.template.querySelector('.continue'))) {
            this.doContinue = true; // si hacen click en continue, tengo que esperar a que termine el save y luego les ahorro rehacer el click
        } 
    }
}