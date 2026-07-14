import { LightningElement, track} from 'lwc';
import getLoadData from '@salesforce/apex/AdhesionPPH.getLoadData';
import save from '@salesforce/apex/AdhesionPPH.save';
import deleteEstablecimiento from '@salesforce/apex/AdhesionPPH.deleteEstablecimiento';
import acceptTerms from '@salesforce/apex/AdhesionPPH.acceptTerms';
import sendAdhesion from '@salesforce/apex/AdhesionPPH.sendAdhesion';
import rectificarAdhesion from '@salesforce/apex/AdhesionPPH.rectificarAdhesion';
import {errorEvent, warningEvent} from 'c/utils';

const CSS = `
.toastMessage{

    white-space: break-spaces !important;
    }
`;

export default class AdhesionPph extends LightningElement {
    @track establecimientos = [];
    @track variedades = [];

    counter = 1;
    loading = true;
    step = "adhesion";
    account;
    currentModal;
    plan;
    doContinue = false;
    modalCallback;
    hiding = {};
    htsGlobales = {}; // Las HTs globales de PPH están porque se certificaron previo a las HTs por variedad. Son hts sin variedad
    saldoPph;

    get parametro() {
        const parametro = new URL(window.location.href).searchParams.get("recordId");
        return parametro;
    }

    async init() {
        this.initialized = true;

        try {
            const data = await getLoadData({parametroId: this.parametro});
            this.loadData(data);
            console.log(data);
        } catch (e) {
            this.onError(e);
        }

        this.loading = false;
    }
    
    loadData(data) {
        this.variedades = data.variedades ? data.variedades : this.variedades;

        if (data.stockPorVariedad) {
            this.variedades.forEach(v => v.totals = data.stockPorVariedad[v.Id]);
            this.htsGlobales = data.stockGlobal;
        }

        if (data.account) this.account = data.account;
        if (data.plan) this.plan = data.plan;

        if (this.plan) {
            const campaña = this.plan.Parametro_PPH__r?.Name?.match(/\d{4}\/\d{4}/)?.[0];
            console.log('campaña', this.plan.Parametro_PPH__r?.Name?.match(/\d{4}\/\d{4}/));
            console.log('Campañas', {
                campaña,
                parametroName: this.plan.Parametro_PPH__r?.Name,
                planName: this.plan.Name,
                cultivo: this.plan.Parametro_PPH__r?.Cultivo__r?.Name
            });
        }
        
        this.saldoPph = data.saldoPph;
        
        this.variedades.forEach(v => v.totals.current = 0);

        const variedades = Object.fromEntries(this.variedades.map(v => [v.Id, v]));

        const establecimientos = [];

        for (const establecimiento of data.establecimientos) {
            const est = {id: establecimiento.Id, record: establecimiento, lineas: []};

            for (const variedadId of Object.keys(variedades)) {
                const record = (establecimiento.Lineas_PPH__r || []).find(l => l.Variedad__c == variedadId) || {};
                est.lineas.push({id: variedadId, record, variedad: variedades[variedadId]});
                variedades[variedadId].totals.current += record.Cantidad_Declarada__c || 0;
            }

            if(this.plan.Estado__c != 'En Preparación' && this.plan.Estado__c != 'Rectificado'){
                if(establecimiento.Lineas_PPH__r){
                    for(const linea of establecimiento.Lineas_PPH__r){
                        if(est.lineas.find(l => l.id == linea.Variedad__c) == null){
                            est.lineas.push({id: linea.Variedad__c, record: linea, variedad: {...linea.Variedad__r, totals: {}}});
                        }
                    }
                }
            }

            establecimientos.push(est);
        }

        console.log(JSON.parse(JSON.stringify(establecimientos)))

        this.establecimientos = establecimientos;

        if (this.establecimientos.length == 0) this.addRow();

        if (this.plan.Estado__c != 'En Preparación' && this.plan.Estado__c != 'Rectificado') setTimeout(_ => this.step = "resumen", 0);

        if (this.plan.Estado__c == 'En Preparación' && data.isInPeriodoAdhesion == false) this.onError('Ya ha terminado el período de adhesión');
        
        if (data.validation) {
            const style = document.createElement('style');
            style.innerText = CSS;
            this.template.querySelector('div').appendChild(style);
            
            this.onWarning(data.validation);
        }

        if (this.grandesCuentas) this.template.querySelector('button').className = 'slds-hide';
    }

    get isAdhesion() {
        return this.step == "adhesion";
    }

    get isEdit() {
        return this.step == "edit";
    }

    get isTerminosYCondiciones() {
        return this.step == "terminos";
    }

    get isResumen() {
        return this.step == "resumen";
    }

    get year() {
        if (!this.plan) return '';
        const param = this.plan.Parametro_PPH__r;
        return param.Fecha_Inicio_Adhesion_PPH__c.split('-')[0] + '/' + param.Fecha_Fin_Adhesion_PPH__c.split('-')[0];
    }

    get cultivo(){
        if (!this.plan) return '';
        const param = this.plan.Parametro_PPH__r;
        return param.Cultivo__r.Name;
    }

    get paramName(){
        if(!this.plan) return '';
        const param = this.plan.Parametro_PPH__r;
        return param.Name;
    }

    get grandesCuentas(){
        return this.account.Grandes_Cuentas__c;
    }

    get gcEstablecimientoName(){
        return this.account.N_CUIT__c + ' - ' + this.plan.Parametro_PPH__r.Name;
    }

    addRow() {
        const lineas = this.variedades.map(variedad => ({id: variedad.Id, record: {}, variedad}));
        this.establecimientos.push({id: ++this.counter, record: {}, lineas});
    }

    connectedCallback() {
        if (!this.initialized) {
            this.init();
        }
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    onWarning(e) {
        this.dispatchEvent(warningEvent(e));
    }

    updateCantidad(event) {
        const variedad = this.variedades.find(v => v.Id == event.detail.variedad);
        variedad.totals.current += event.detail.cantidad;
    }

    showMap(event) {
        this.template.querySelector('c-map').show(event.detail.callback);
    }

    closeModal() {
        this.currentModal = null;
        this.modalCallback = null;
    }
    
    remove(event) {
        if (this.establecimientos.length == 1) return this.onError("No puede borrar el único establecimiento restante");
        this.modalCallback = this.confirmDelete.bind(this, event.target);
        this.currentModal = "confirm-delete";
    }

    async changeEstablecimiento(event){
        const id = event.target.info.record.Establecimiento__r.Id;
        const idPph = event.target.info.id;
        await this.doRequest(async () => await deleteEstablecimiento({id}));
        let idx = this.establecimientos.findIndex(e => e.id === idPph);
        this.establecimientos[idx].lineas = this.establecimientos[idx].lineas.map(l => ({...l, record: {Cantidad_Declarada__c: l.record.Cantidad_Declarada__c}}));
        this.establecimientos[idx].record = {};
        delete this.establecimientos[idx].id;
    }

    confirmDelete(toDelete) {
        this.closeModal();
        const id = toDelete.info.record.Establecimiento__r?.Id;

        if (id != null) {
            this.doRequest(() => deleteEstablecimiento({id}).then(_ => this.removeEstablecimiento(toDelete)));
        } else {
            this.removeEstablecimiento(toDelete);
        }
    }

    removeEstablecimiento(establecimiento) {
        const id = establecimiento.info.id;
        const variedades = establecimiento.getData().variedades;
        //tengo que descartar las cantidades de hectareas que pusieron
        for (const variedad of Object.keys(variedades)) {
            this.updateCantidad({detail:{variedad, cantidad: -variedades[variedad].cantidad}});
        }

        this.establecimientos = this.establecimientos.filter(e => e.id !== id);
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

    get data() {
        const data = {establecimientos: [], account: this.account, plan: this.plan};

        for (const establecimiento of this.template.querySelectorAll('c-establecimiento-pph')) {
            const est = establecimiento.getData();

            if (this.grandesCuentas == true) est.name = this.gcEstablecimientoName;

            est.origen = this.grandesCuentas == true ? 'Grandes Cuentas' : 'Propio';

            if (establecimiento.info.record.Establecimiento__r) {
                est.id = establecimiento.info.record.Establecimiento__r.Id;
                est.pphId = establecimiento.info.id;
            }

            data.establecimientos.push(est);
        }

        data.total = this.variedades.map(v => v.totals.total).reduce((a, b) => a + b, 0) + (this.htsGlobales.total || 0);
        data.grandesCuentas = this.grandesCuentas;
        data.saldoPph = this.saldoPph;
        return data;
    }

    get cultivo(){
        return this.plan.Parametro_PPH__r.Cultivo__r.Name;
    }

    get campaña(){
        return this.plan?.Parametro_PPH__r?.Name?.match(/\d{4}\/\d{4}/)?.[0];
    }

    isValid(showError = false) {
        let valid = true;

        try {
            let cantidadSE = 0;
            for (const establecimiento of this.template.querySelectorAll('c-establecimiento-pph')) {
                if (!establecimiento.validate()) valid = false;
                for(const variedadData of Object.values(establecimiento.getData().variedades)){
                    cantidadSE += variedadData.cantidad;
                }
            }
            if(cantidadSE == 0) throw new Error('No se puede realizar la adhesión sin tener hectareas SE en al menos un establecimiento');
        } catch(e) {
            valid = false;
            if (showError) this.onError(e);
        }

        return valid;
    }

    async save() {
        await this.doRequest(async _ => {
            if (this.isValid()) {
                const data = this.data;
                console.log(JSON.parse(JSON.stringify(data)));
                const newData = await save({js: JSON.stringify(data), planId: this.plan.Id});
                this.loadData(newData);

                if (this.doContinue) {
                    this.doContinue = false;
                    this.continuar();
                }
            }
        })
    }

    get adhesionClass() {
        return this.isAdhesion || this.isEdit ? '' : 'slds-hide';
    }

    continuar(e) {
        if (this.isValid(true)) {
            this.currentModal = "confirm-continue";
            this.modalCallback = this.goToNextStep.bind(this);
        }
    }

    goToNextStep() {
        this.closeModal();

        if (this.plan.Terminos_y_Condiciones__c != true) {
            this.step = "terminos";
        } else {
            this.step = "resumen";
        }
    }

    cancelTerms(e) {
        this.step = "adhesion";
    }

    async acceptTerms(e) {
        await this.doRequest(async _ => {
            await acceptTerms({planId: this.plan.Id});
            this.plan.Terminos_y_Condiciones__c = true;
            this.enviarConfirm();
            //this.step = "resumen";
        })
    }

    backToResumen() {
        if (this.isValid(true)) {
            this.step = "resumen";
        }
    }

    edit(e) {
        this.hiding = {};

        for (const establecimiento of this.establecimientos) {
            if (establecimiento.record.Establecimiento__r.Id !== e.detail.id) {
                this.hiding[establecimiento.id] = true;
            }
        }
        console.log(this.establecimientos, this.hiding, e.detail.id)
        this.step = "edit";
    }

    autosave(e) {
        this.save();
    }

    enviarConfirm(e) {
        this.loading = true;
        this.enviar();
        //this.modalCallback = this.enviar.bind(this);
        //this.currentModal = "confirm-continue-resumen";
    }

    rectificarConfirm(e) {
        this.modalCallback = this.rectificar.bind(this);
        this.currentModal = "confirm-continue-rectificar";
    }

    async enviar() {
        await this.doRequest(async _ => {
            await sendAdhesion({planId: this.plan.Id});
            this.plan.Estado__c = 'Adherido';
            this.currentModal = "adherido";
        });
        if(this.plan.Tiene_Hts_Pendientes__c == true){
            this.dispatchEvent(warningEvent(new Error('La adhesión de las HTs que se encuentran pendientes de pago está atada al pago en tiempo y forma de las mismas')));
        }
    }

    async rectificar() {
        await this.doRequest(async _ => {
            await rectificarAdhesion({planId: this.plan.Id});
            window.location.reload();
        });
    }

    isPointerEventInsideElement(event, element) {
        var pos = {
            x: (event.targetTouches ? event.targetTouches[0].pageX : event.pageX) - window.scrollX,
            y: (event.targetTouches ? event.targetTouches[0].pageY : event.pageY) - window.scrollY
        };
        var rect = element.getBoundingClientRect();
        return  pos.x < rect.right && pos.x > rect.left && pos.y < rect.bottom && pos.y > rect.top;
    };

    loadingClick(e) {
        if (this.loading && this.step == "adhesion" && this.isPointerEventInsideElement(e, this.template.querySelector('.continue'))) {
            this.doContinue = true; // si hacen click en continue, tengo que esperar a que termine el save y luego les ahorro rehacer el click
        } 
    }

    handleOnInformarPagoClick(event){
        this.template.querySelector('c-informar-pago').show({
            title:'No veo mis HTs',
            subject: `CUIT: ${this.account.N_CUIT__c} - ${this.plan.Name} - PPH`,
            accountId: this.account.Id
        });
    }
}