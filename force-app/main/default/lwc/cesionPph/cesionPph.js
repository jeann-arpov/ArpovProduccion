import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getLoadData from '@salesforce/apex/CesionPPH.getLoadData';
import deleteDestinatario from '@salesforce/apex/CesionPPH.deleteDestinatario';
import sendCesion from '@salesforce/apex/CesionPPH.sendCesion';
import save from '@salesforce/apex/CesionPPH.save';
import backToEnCurso from '@salesforce/apex/CesionPPH.backToEnCurso';
import anular from '@salesforce/apex/CesionPPH.anular';
import deleteFile from '@salesforce/apex/CesionPPH.deleteFile';
import uploadContratoFile from '@salesforce/apex/CesionPPH.uploadContratoFile';
import getNewCesionData from '@salesforce/apex/CesionPPH.getNewCesionData';

import {errorEvent} from 'c/utils';
import icons from 'c/icons';
import { trackGa4Event } from 'c/portalGa4Events';
import { goToCommunityPage, PAGES } from 'c/seNav';

/** Cap destinatarios per cesión; raise when multi-destinatario is enabled. */
const MAX_DESTINATARIOS = 1;
const WIZARD_STEPS = 3;
const WIZARD_STEP_LABELS = ['Cultivo', 'Destinatario', 'Toneladas'];

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
    wizardStep = 1;
    wizardDestReady = false;
    wizardToneladasValid = false;
    wizardToneladasTotal = 0;
    initialized = false;
    counter = 1;
    cesion;
    accounts = {};
    hiding = {};
    licenses;
    files = [];
    contratoUploading = false;
    contratoUploadName = '';
    contratoUploadPct = 0;
    _contratoUploadTimer;
    doContinue = false;
    cultivos;
    cultivo;
    tnsBolsatech;

    seedIcon = icons.compraVenta.seed;
    currentModal;
    modalCallback;

    connectedCallback() {
        document.documentElement.classList.add('se-inner', 'se-inner-wizard');
        document.body.classList.add('se-inner', 'se-inner-wizard');
    }

    disconnectedCallback() {
        this._stopContratoProgress();
        document.documentElement.classList.remove('se-inner', 'se-inner-wizard');
        document.body.classList.remove('se-inner', 'se-inner-wizard');
    }

    async init() {
        this.initialized = true;

        try {
            const data = await getLoadData({
                cesionId: this.pageRecordId,
                tipoCesion: this.pageTipoCesion
            });
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
        this.syncBodyClasses();
    }

    syncBodyClasses() {
        const html = document.documentElement;
        const body = document.body;
        if (this.isResumen || this.isCultivo || this.isCesion || this.isEdit) {
            html.classList.add('se-inner', 'se-inner-wizard');
            body.classList.add('se-inner', 'se-inner-wizard');
        }
    }

    buildDestinatarioPayload(dest) {
        const account = dest.account || this.accounts?.[dest.record?.Destinatario__c];
        const variedades = {};

        for (const linea of dest.lineas || []) {
            const cantidad = Number(linea.record?.Cantidad__c) || 0;
            if (cantidad > 0 || linea.record?.Id) {
                const variedad = linea.variedad;
                const obtentorId = variedad?.Obtentor_Comercializa__r?.Id_Obtentor__c;
                variedades[linea.id] = {
                    id: linea.record?.Id,
                    cantidad,
                    variedad,
                    license: linea.record?.Licencia__c,
                    icono: icons.semilleros[obtentorId]
                };
            }
        }

        return {
            destinatarioId: account?.id || dest.record?.Destinatario__c,
            variedades,
            id: dest.record?.Id,
            record: dest.record,
            destinatarioRecord: account?.record
        };
    }

    loadData(data) {
        if(data.cultivos){
            this.cultivos = data.cultivos;
            this.step = 'cultivo';
            this.wizardStep = 1;
        }else{
            if (data.cesion) {
                this.variedades = data.variedades;
                this.cesion = data.cesion;
    
                this.variedades.forEach(v => v.totals = {stock: data.stock[v.Id]});
    
                if (data.accounts?.length) {
                    this.accounts = {
                        ...(this.accounts || {}),
                        ...Object.fromEntries(data.accounts.map((a) => [a.id, a]))
                    };
                }
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

            this.syncWizardStep();
            this.syncWizardDestReady();
        }
        console.log('variedades:', this.variedades);
    }

    syncWizardStep() {
        if (this.isCultivo) {
            this.wizardStep = 1;
            return;
        }
        if (!(this.isCesion || this.isEdit)) {
            return;
        }
        // Autosave tras elegir destinatario: no saltar de paso en medio del wizard mobile.
        if (this.wizardStep === 2 || this.wizardStep === 3) {
            return;
        }
        const first = this.destinatarios[0];
        const hasDest = !!(first?.account || first?.record?.Destinatario__c);
        if (!hasDest) {
            this.wizardStep = 2;
            return;
        }
        this.wizardStep = this.hasContrato ? 3 : 2;
    }

    addRow() {
        if (this.destinatarios.length >= MAX_DESTINATARIOS) return;
        if(this.destinatarios.length > 0){
            this.modalCallback = this.confirmAddRow.bind(this);
            this.currentModal = "confirm-add-destinatario";
        }else{
            this.confirmAddRow();
        }
    }

    get showAddDestinatario() {
        return this.destinatarios.length < MAX_DESTINATARIOS;
    }

    get allowRemoveDestinatario() {
        return MAX_DESTINATARIOS > 1 && this.destinatarios.length > 1;
    }

    get destinatarioPhase() {
        if (this.wizardStep === 2) return 'destinatario';
        if (this.wizardStep === 3) return 'toneladas';
        return 'all';
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
        if (this.cesion?.Id) {
            this.step = 'cesion';
            this.wizardStep = 2;
            return;
        }

        await this.doRequest(async _ => {
            const data = await getNewCesionData({cultivoId: this.cultivo, tipoCesion: this.pageTipoCesion});
            console.log(data);
            this.loadData(data);
            this.step = 'cesion';
            this.wizardStep = 2;
        });
    }

    handleCultivoGridSelect(event) {
        this.cultivo = event.detail.value;
    }

    get wizardStepLabels() {
        return WIZARD_STEP_LABELS;
    }

    get wizardStepsTotal() {
        return WIZARD_STEPS;
    }

    get selectedCultivoSaldo() {
        const found = (this.cultivos || []).find((c) => String(c.value) === String(this.cultivo));
        const saldo = found?.saldo;
        const n = Number(saldo);
        return Number.isFinite(n) ? n : 0;
    }

    syncWizardDestReady() {
        const first = this.destinatarios[0];
        this.wizardDestReady = !!(first?.account || first?.record?.Destinatario__c);
    }

    handleDestSelectionChange(event) {
        this.wizardDestReady = event.detail.hasSelection;
    }

    handleToneladasChange(event) {
        this.wizardToneladasValid = event.detail.valid;
        this.wizardToneladasTotal = event.detail.total || 0;
    }

    formatTonLabel(n) {
        return Number(n).toLocaleString('es-AR', { maximumFractionDigits: 0 });
    }

    /** Wizard vs desktop legacy: siempre el bloque del wizard activo. */
    getDestinatarioComponents() {
        if (this.isResumen) {
            return this.template.querySelectorAll('c-destinatario-pph');
        }
        return this.template.querySelectorAll('c-destinatario-pph.se-dest-block');
    }

    getPrimaryDestinatarioComponent() {
        return this.getDestinatarioComponents()[0] || null;
    }

    get hasContrato() {
        return (this.files || []).length > 0;
    }

    get primaryContrato() {
        return this.hasContrato ? this.files[0] : null;
    }

    get contratoTitle() {
        return this.primaryContrato?.ContentDocument?.Title || 'Seleccioná el contrato';
    }

    get contratoSubtitle() {
        if (!this.hasContrato) return 'Subí el PDF del convenio de cesión';
        const ext = this.primaryContrato?.ContentDocument?.extension;
        return ext ? `${ext} · Contrato adjunto` : 'Contrato adjunto';
    }

    get mobTitleBadge() {
        if (this.isWizardStep2 || this.isWizardStep3) return this.cultivoPillLabel;
        return '';
    }

    get cultivoPillLabel() {
        if (this.cesion?.Cultivo__r?.Name) return this.cesion.Cultivo__r.Name;
        const found = (this.cultivos || []).find((c) => c.value === this.cultivo);
        return found?.label || '';
    }

    get isWizardStep1() {
        return this.wizardStep === 1 && !this.isResumen;
    }

    get isWizardStep2() {
        return (this.isCesion || this.isEdit) && this.wizardStep === 2;
    }

    get isWizardStep3() {
        return (this.isCesion || this.isEdit) && this.wizardStep === 3;
    }

    get showMobWizardFooter() {
        if (typeof window === 'undefined') {
            return !this.isResumen && (this.isCultivo || this.isCesion || this.isEdit);
        }
        const isMobile = window.matchMedia('(max-width: 767px)').matches;
        return isMobile && !this.isResumen && (this.isCultivo || this.isCesion || this.isEdit);
    }

    get mobFooterStatus() {
        switch (this.wizardStep) {
            case 1:
                return this.cultivoPillLabel ? `${this.cultivoPillLabel} seleccionado` : 'Elegí un cultivo';
            case 2:
                return this.destinatarios[0]?.account?.title || this.destinatarios[0]?.account?.record?.Name || 'Ingresá el CUIT destinatario';
            case 3:
                return this.wizardToneladasValid
                    ? `${this.formatTonLabel(this.wizardToneladasTotal)} t a ceder`
                    : 'Ingresá las toneladas';
            default:
                return '';
        }
    }

    get contratoUploadBarStyle() {
        return `width: ${this.contratoUploadPct}%`;
    }

    get mobFooterContinuarDisabled() {
        if (this.loading || this.contratoUploading) return true;
        if (this.wizardStep === 1) return !this.cultivo || this.selectedCultivoSaldo <= 0;
        if (this.wizardStep === 2) return !this.wizardDestReady || !this.hasContrato;
        if (this.wizardStep === 3) return !this.wizardToneladasValid;
        return false;
    }

    get mobFooterVariant() {
        return 'dual';
    }

    get mobCancelLabel() {
        return this.wizardStep === 1 ? 'Cancelar' : 'Atrás';
    }

    get mobFooterContinuarLabel() {
        return this.wizardStep === 3 ? 'Ceder toneladas' : 'Continuar →';
    }

    async handleMobContinuar() {
        if (this.wizardStep === 1) {
            await this.startCesion();
            return;
        }
        if (this.wizardStep === 2) {
            if (!this.validateWizardStep(2)) return;
            const destComp = this.getPrimaryDestinatarioComponent();
            const account = destComp?.getAccount?.();
            const destData = destComp?.getData?.();
            await this.save();
            if (this.destinatarios[0]) {
                const current = this.destinatarios[0];
                this.destinatarios = [
                    {
                        ...current,
                        account: account || current.account,
                        record: destData?.destinatarioId
                            ? { ...current.record, Destinatario__c: destData.destinatarioId }
                            : current.record
                    },
                    ...this.destinatarios.slice(1)
                ];
            }
            this.wizardToneladasValid = false;
            this.wizardToneladasTotal = 0;
            this.wizardStep = 3;
            return;
        }
        if (this.wizardStep === 3) {
            if (!this.validateWizardStep(3)) return;
            await this.save();
            if (!this.isValid(true, true)) return;
            this.step = 'resumen';
            return;
        }
    }

    validateWizardStep(step) {
        try {
            const dest = this.getPrimaryDestinatarioComponent();
            if (!dest) return false;
            if (step === 2) {
                if (!this.hasContrato) {
                    this.onError('Debe subir al menos un contrato para continuar');
                    return false;
                }
                return dest.validate(false);
            }
            if (step === 3) return dest.validate(true);
            return true;
        } catch (e) {
            this.onError(e);
            return false;
        }
    }

    handleMobBack() {
        if (this.wizardStep > 1 && (this.isCesion || this.isEdit)) {
            this.wizardStep -= 1;
            return;
        }
        goToCommunityPage(PAGES.cesiones);
    }

    handleMobClose() {
        goToCommunityPage(PAGES.cesiones);
    }

    handleMobCancel() {
        if (this.wizardStep === 1) {
            this.handleMobClose();
            return;
        }
        this.handleMobBack();
    }

    get mobPageTitle() {
        if (this.isResumen) return 'Resumen de tu solicitud';
        return 'Cesión de Toneladas';
    }

    get deskPageTitle() {
        if (this.isResumen) return this.mobPageTitle;
        return `Cesión de toneladas — ${this.pageTipoCesion || this.tipoCesion || 'Productor'}`;
    }

    get deskPageSubtitle() {
        if (this.isResumen) return '';
        return 'Completá los pasos para iniciar la cesión.';
    }

    get deskResumenTipo() {
        return this.pageTipoCesion || this.tipoCesion || '—';
    }

    get deskResumenCultivo() {
        return this.cultivoPillLabel || '—';
    }

    get deskResumenDestinatario() {
        const dest = this.destinatarios[0];
        return dest?.account?.title || dest?.account?.record?.Name || '—';
    }

    get showDeskResumenDestinatario() {
        return this.wizardStep >= 2;
    }

    get showDeskResumenContrato() {
        return this.wizardStep >= 2 && this.hasContrato;
    }

    get showDeskResumenToneladas() {
        return this.wizardStep >= 3 && this.wizardToneladasValid;
    }

    get deskResumenToneladas() {
        return `${this.formatTonLabel(this.wizardToneladasTotal)} t`;
    }

    get isResumenMobileEmbedded() {
        if (typeof window === 'undefined') return false;
        return window.matchMedia('(max-width: 767px)').matches;
    }

    handleWizardStepClick(event) {
        const clicked = Number(event.detail?.step);
        if (!clicked || clicked >= this.wizardStep) return;
        this.wizardStep = clicked;
    }

    get mobPageSubtitle() {
        if (this.isWizardStep1) return 'Elegí el cultivo';
        return '';
    }

    get tipoCesion(){
        return this.cesion?.tipoCesion;
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
            for (const destinatario of this.getDestinatarioComponents()) {
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
        const data = {
            destinatarios: [],
            cesion: this.cesion,
            licenses: this.licenses,
            tnsBolsatech: this.tnsBolsatech
        };

        const components = this.isResumen ? [] : Array.from(this.getDestinatarioComponents());

        if (components.length > 0) {
            for (const destinatario of components) {
                const dest = destinatario.getData();
                data.destinatarios.push(dest);
                if (dest.destinatarioId) {
                    if (!this.accounts) this.accounts = {};
                    this.accounts[dest.destinatarioId] = destinatario.getAccount();
                }
            }
        } else {
            for (const dest of this.destinatarios || []) {
                if (this.hiding[dest.id]) continue;
                data.destinatarios.push(this.buildDestinatarioPayload(dest));
            }
        }

        data.stock = (this.variedades || []).map((v) => v.totals?.stock || 0).reduce((a, b) => a + b, 0);
        return data;
    }

    get resumenCanEnviar() {
        return (this.destinatarios || []).some((d) => d.record?.Estado__c === 'En Curso');
    }

    get resumenEnviarDisabled() {
        return !this.resumenCanEnviar;
    }

    get showResumenMobFooter() {
        if (typeof window === 'undefined') return true;
        return window.matchMedia('(max-width: 767px)').matches;
    }

    get resumenFooterStatus() {
        const total = (this.destinatarios || []).reduce((sum, dest) => {
            return (
                sum +
                (dest.lineas || []).reduce(
                    (lineSum, linea) => lineSum + (Number(linea.record?.Cantidad__c) || 0),
                    0
                )
            );
        }, 0);
        return total > 0 ? `${this.formatTonLabel(total)} t cedidas` : 'Revisá el resumen';
    }

    handleResumenGuardar() {
        goToCommunityPage(PAGES.cesiones);
    }

    handleResumenBack() {
        this.step = 'cesion';
        this.wizardStep = 3;
    }

    handleResumenEnviar() {
        this.template.querySelector('c-resumen-cesion-pph')?.requestEnviar();
    }

    continuar(e) {
        if (this.isValid(true, true)) {
            this.step = "resumen";
        }
    }

    get isEnCurso() {
        // Borrador se edita igual que En Curso; solo se oculta del listado hasta el primer save.
        return this.cesion.Estado__c == 'En Curso' || this.cesion.Estado__c == 'Borrador';
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
            trackGa4Event('cesion_confirmada', { modulo: 'Cesiones' });
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

    handleContratoPick() {
        this.template.querySelector('.se-file-input')?.click();
    }

    async handleContratoFileChange(event) {
        const file = event.target.files?.[0];
        event.target.value = '';

        if (!file || !this.cesion?.Id) {
            return;
        }

        const maxBytes = 10 * 1024 * 1024;
        if (file.size > maxBytes) {
            this.onError('El archivo no puede superar 10 MB.');
            return;
        }

        this.contratoUploading = true;
        this.contratoUploadName = file.name;
        this.contratoUploadPct = 12;
        this._startContratoProgress();

        try {
            if (this.hasContrato) {
                const previous = this.files[0];
                await deleteFile({ fileId: previous.ContentDocument.Id, cesionId: this.cesion.Id });
            }

            const base64Data = await this._readFileAsBase64(file);
            this.contratoUploadPct = 55;

            const uploaded = await uploadContratoFile({
                cesionId: this.cesion.Id,
                fileName: file.name,
                base64Data
            });

            this.contratoUploadPct = 100;
            this.files = [{
                ContentDocument: {
                    Id: uploaded.documentId,
                    Title: uploaded.title,
                    extension: uploaded.extension
                }
            }];
        } catch (e) {
            this.onError(e);
        } finally {
            this._stopContratoProgress();
            this.contratoUploading = false;
            this.contratoUploadName = '';
            this.contratoUploadPct = 0;
        }
    }

    _readFileAsBase64(file) {
        return new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => {
                const marker = 'base64,';
                const idx = reader.result.indexOf(marker);
                resolve(idx >= 0 ? reader.result.substring(idx + marker.length) : reader.result);
            };
            reader.onerror = () => reject(reader.error);
            reader.readAsDataURL(file);
        });
    }

    _startContratoProgress() {
        this._stopContratoProgress();
        this._contratoUploadTimer = setInterval(() => {
            if (this.contratoUploadPct < 88) {
                this.contratoUploadPct += 4;
            }
        }, 180);
    }

    _stopContratoProgress() {
        if (this._contratoUploadTimer) {
            clearInterval(this._contratoUploadTimer);
            this._contratoUploadTimer = null;
        }
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