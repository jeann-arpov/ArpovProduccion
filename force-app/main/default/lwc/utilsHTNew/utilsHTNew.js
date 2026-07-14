import fontAwesome from '@salesforce/resourceUrl/fontawesome';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {reduceErrors, validateInputs} from 'c/utils';
import {api, track} from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import icons from 'c/icons';
import HT_DISPONIBLES from '@salesforce/label/c.Compra_Venta_HT_Disponibles';
import HT_FUTURAS from '@salesforce/label/c.Compra_Venta_HT_Futuras';
import HT_FUTURAS_TRIGO from '@salesforce/label/c.Compra_Venta_HT_Futuras_Trigo';

const CSS = `
    lightning-record-edit-form:not(:first-of-type) lightning-helptext {
        display:none;
    }
            
    lightning-record-edit-form:not(:first-of-type) lightning-layout-item > * {
        padding: 0 var(--lwc-spacingXxSmall,0.25rem);
        margin-bottom: var(--lwc-spacingXSmall,0.5rem);
        display: block;
    }

    .slds-text-align_center .slds-input{
        text-align: center!important;
        padding-right: 0px;
    }

    .toastContainer {
        top:50% !important;
        transform: translateY(-50%);
        position:fixed;
        white-space: break-spaces !important;
    }

    lightning-card .slds-card {
        border-radius: var(--lwc-borderRadiusLarge);
        box-shadow: 1px 1px 2px 2px rgba(211, 211, 211, 0.25);
        border-color: rgba(211, 211, 211, 0.25);
    }

    .variedades lightning-layout {
        border-bottom: 1px solid grey;
        padding-top: 1rem;
        padding-bottom: 1rem;
    }
    
    .variedades > lightning-layout {
        padding-top: 0px;
    }
    
    .variedades-card lightning-layout {
        padding-left: 3%;
        padding-right: 3%;
    }

    .black-border {
        --slds-c-button-neutral-color-border: black;
    }

    span.facturable {
        background-color: #C5FE00;
        padding: 0.4rem;
        border-radius: 20px;
    }

    span.pendiente {
        background-color: red;
        color: white;
        padding: 0.4rem;
        border-radius: 20px;
    }
`;

const LineaCompraVentaMixin = (cls) => class extends NavigationMixin(cls) {
    @api priceBookEntries;
    @api index;
    @api factura;
    @track tipoFinanciamiento;
    @track isFuturaFlag = false; 

    request;
    _record = {};
    precio;
    initialized;
    preCampaign;
    //@api tiposDeCompra = [];// = [{value: 'Futura', label: 'Futura'}, {'value': 'Disponible', label: 'Disponible'}];
    variedad;
    lastSaveHash;

    icons = icons.lineaCompraVenta;
    iconsCompraVenta = icons.compraVenta;
    
    @api
    get record() {
        return this._record;
    }

    set record(data) {
        const newRecord = JSON.parse(JSON.stringify(data || {}));
        if (this._record && this._record.Tipo_de_Pago__c && !newRecord.Tipo_de_Pago__c) {
            newRecord.Tipo_de_Pago__c = this._record.Tipo_de_Pago__c;
        }
        this._record = newRecord;
    }

    //solo muestro los tipos de HT por las cuales hay una entry
    get tiposDeCompra(){
        const entries = this.priceBookEntries.filter(v => (v.record.Product2.Variedad2__c == this.variedad || this.hasId && v.label == this.variedad));
        const tiposCompra = entries.reduce((tiposCompra, entry) => [...tiposCompra, {label: entry.record.Product2.Tipo_de_Compra__c, value: entry.record.Product2.Tipo_de_Compra__c}], []);
        console.log(tiposCompra);
        return tiposCompra;
    }

    connectedCallback() {
        loadStyle(this, fontAwesome + '/fontawesome-free-6.1.1-web/css/all.min.css');
    }

    get isFacturable() {
        return this._record.Estado__c == 'Facturable';
    }

    get isPendiente() {
        return this._record.Estado__c == 'Pendiente';
    }

    get shouldShowImage() {
        console.log("asd", this.isFacturable, this.isPendiente, this._record.Estado__c)
        return this.isFacturable || this.isPendiente;
    }

    get estadoClass() {
        if (this.isFacturable) return "facturable";
        else if (this.isPendiente) return "pendiente";
        return "";
    }

    get disableTipoHt(){
        return !this.variedad;
    }

    variedadChange(event) {
        this.preCampaign = null;
        const selection = event.target.getSelection();
        this.variedad = selection.length ? selection[0].record.Id : null;
        this.productChange();
        this.checkAutoSave();
    }

    preCampaignChange(event) {
        this.preCampaign = event.target.value;
        const dt = new Date();
        this.record.Fecha_de_Activacion__c = this.preCampaign == 'Disponible' ? dt.getFullYear() + '-' + ('0' + (dt.getMonth() + 1)).slice(-2) + '-' + ('0' + dt.getDate()).slice(-2) : this.getFechaActivacion();
        console.log('Fecha activación', this.record.Fecha_de_Activacion__c );
        this.productChange();
        const priceBookEntry = this.priceBookEntries.find(v => (v.record.Product2.Variedad2__c == this.variedad || this.hasId && v.label == this.variedad) && v.record.Product2.Tipo_de_Compra__c == this.preCampaign);
        this.isFuturaFlag = this.preCampaign === 'Futura' && priceBookEntry && priceBookEntry.record.Unit_Price__c != null && priceBookEntry.record.Unit_Price__c !== 0;
        console.log('preCampaignChange this.preCampaign', this.preCampaign );
        
        this.checkAutoSave();
        this.dispatchEvent(new CustomEvent('tipohtchange', {
            detail: {
                //isFutura: (event.target.value === 'Futura'),
                isFutura: this.isFuturaFlag,
                recordId: this.record.id
            },
            bubbles: true
        }));
        console.log('preCampaignChange valor is futura utilsht',this.isFutura);
    }

    getFechaActivacion(){
        const dt = new Date();
        const cultivo = this.priceBookEntries[0].record.Product2.Variedad2__r.Cultivo__r.Name;
        const fechaConversion = new Date();
        fechaConversion.setDate(1);
        fechaConversion.setMonth((cultivo == 'SOJA' ? 2 : 10));

        let año = dt.getFullYear();

        if(dt > fechaConversion){
            año++;
        }

        const monthDay = cultivo == 'SOJA' ? '03-01' : '11-01';

        return `${año}-${monthDay}`;
    }

    init() {
        const priceBookEntry = this.priceBookEntries.find(v => v.value == this._record.Id_Producto_de_Lista_de_Precio__c);
        console.log(priceBookEntry, this._record.Id_Producto_de_Lista_de_Precio__c, this.priceBookEntries)
        if (priceBookEntry) {
            this.preCampaign = priceBookEntry.record.Product2.Tipo_de_Compra__c;
            this.variedad = priceBookEntry.label;
        }
        console.log(this.variedad, this.variedades);
        this.productChange();
        this.updatePrice();
    }

    shouldAutoSaveChanges() {
        const hash = this._record.Producto__c + '-' + this._record.Cantidad__c;
        console.log(hash, this.lastSaveHash );
        if (this._record.Producto__c && this._record.Cantidad__c && hash != this.lastSaveHash) {
            this.lastSaveHash = hash;
            console.log('llego aca cuantas')
            console.log('this.handleCheckEjecutado', this.handleCheckEjecutado)
            console.log('typeof this.handleCheckEjecutado ', typeof this.handleCheckEjecutado)
            if (typeof this.handleCheckEjecutado === 'function') {
                this.handleCheckEjecutado(); 
            }
            return true;
        }
        return false;
    }

    productChange() {
        const priceBookEntry = this.priceBookEntries.find(v => (v.record.Product2.Variedad2__c == this.variedad || this.hasId && v.label == this.variedad) && v.record.Product2.Tipo_de_Compra__c == this.preCampaign);

        if (priceBookEntry) {
            this._record.Precio_de_Lista__c = priceBookEntry.record.UnitPrice;
            this._record.Producto__c = priceBookEntry.record.Product2Id;
            this._record.Id_Producto_de_Lista_de_Precio__c = priceBookEntry.value;
            this.preCampaign = priceBookEntry.record.Product2.Tipo_de_Compra__c;
            console.log('productChange this.preCampaign', this.preCampaign)
            console.log('productChange priceBookEntry.record.Product2.Tipo_de_Compra__c; ', priceBookEntry.record.Product2.Tipo_de_Compra__c)       
            // ACTUALIZAR isFutura cuando cambie el producto
            this.isFuturaFlag = this.preCampaign === 'Futura' && priceBookEntry.record.Unit_Price__c != null && priceBookEntry.record.Unit_Price__c !== 0;
            console.log('productChange priceBookEntry.record.Unit_Price__c; ', priceBookEntry.record.Unit_Price__c)       

        } else {
            this._record.Id_Producto_de_Lista_de_Precio__c = this._record.Precio_de_Lista__c = null;
            this.isFuturaFlag = false;
        }

        if (this.variedad && this.preCampaign) {
            if(!priceBookEntry){
                const lookup = this.template.querySelector('c-lookup');
                lookup.clearSelection();
                this.onError(new Error('No existe la variedad para ese tipo de HT'));
                this.preCampaign = null;
                this.isFuturaFlag = false; 
            }
        }
        this.updatePriceBasedOnTipoCompra();
    }

    get variedades() { // agrupo por label, que solo aparezca 1. Con la checkbox defino si es pre campaña o entrega inmediata
        const variedades = {};

        for (const priceBookEntry of this.priceBookEntries) {
            variedades[priceBookEntry.label] = {label: priceBookEntry.label, value: priceBookEntry.label};
        }

        return Object.values(variedades);
    }

    syncCantidad(event) {
        this._record['Cantidad__c'] = event.target.value;
        console.log(this._record['Cantidad__c']);
        this.updatePriceBasedOnTipoCompra();
    }

    checkAutoSave() {
        console.log('check autosave');
        console.log('variedad seleccionada', this.variedad)
        console.log('Tipo de Financiamiento antes de guardar:', this.tipoFinanciamiento);

        if (this.shouldAutoSaveChanges()) {
            this.dispatchEvent(new CustomEvent('save'));
        }
    }

    updatePriceBasedOnTipoCompra() {
        const priceBookEntry = this.priceBookEntries.find(v => (v.record.Product2.Variedad2__c == this.variedad || this.hasId && v.label == this.variedad) && v.record.Product2.Tipo_de_Compra__c == this.preCampaign);
        this._record.Precio_de_Lista__c = priceBookEntry.record.Unit_Price__c;

        const mesActual = new Date().getMonth() + 1;
        
        console.log('Valor de Mes actual:', mesActual);
        console.log('Valor de Unit_Price__c:', this._record.Precio_de_Lista__c = priceBookEntry.record.Unit_Price__c);
        console.log('Valor de UnitPrice:', this._record.Precio_de_Lista__c = priceBookEntry.record.UnitPrice );
        console.log('Valor de tipo de pago:', this._record.Tipo_de_Pago__c);
        console.log('Id pricebookentry:', priceBookEntry.record.Id);
        
        
        if (this.preCampaign === 'Futura' && priceBookEntry.record.Unit_Price__c > 0 && this._record.Tipo_de_Pago__c === 'Contado'&& (mesActual === 9 || mesActual === 10 )) {
            const precioAAsignar = priceBookEntry.record.Unit_Price__c != null 
            ? priceBookEntry.record.Unit_Price__c
            : priceBookEntry.record.UnitPrice;
            this._record['Precio_de_Lista__c'] = precioAAsignar;
            this.precioLista = precioAAsignar;
        }
        

    
        this.updatePrice(); 
         
    }

    updatePrice() {
        
        const price = this._record.Precio_de_Lista__c;
        console.log('Valor de Precio_de_Lista__c:', price);
        const qty = this._record.Cantidad__c;
        this.precioLista = price;
        this.precio = price != null && qty != null ? price * qty : '';
    }

    saveRow(event) {
        this.dispatchEvent(new CustomEvent('save'));
       
    }

    removeRow(event) {
        this.dispatchEvent(new CustomEvent('delete'));
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }

    
    get canEdit() {
        return this._record.Estado__c == 'Creada' || !this._record.Estado__c;
    }

    get cantEdit() {
        return !this.canEdit;
    }

    get hasId() {
        return !!this._record.Id;
    }

    renderedCallback() {
        const style = document.createElement('style');
        style.innerText = CSS;
        const form = this.template.querySelector('lightning-record-edit-form');
        if (form && !form.querySelector('style')) form.appendChild(style);

        if (!this.initialized) {
            this.initialized = true;
            if (this._record.Id_Producto_de_Lista_de_Precio__c) this.init();
        }
    }
    
   @track isLoading = false;

    @api get loading() {
        return this.isLoading;
    }

    handleCheckEjecutado() {
        console.log('[CrearLineaVenta] handleCheckEjecutado()');
        this.loadingSppiner = true;
        this.loading = false;

        // Avisar al padre que el loading del hijo empezó
        this.dispatchEvent(new CustomEvent('loadingchange', {
            detail: { isLoading: true, source: 'crear-linea-venta', index: this.index }
        }));
    }

    @api
    async save(recordId, cultivo, productorId) {
        const form = this.template.querySelector('lightning-record-edit-form');
        let success = false;

        if (!validateInputs(form)) return success;

        try {
            console.log(JSON.stringify(this._record));

            // Avisar que empieza el loading
            this.dispatchEvent(new CustomEvent('loadingchange', {
                detail: { isLoading: true, source: 'crear-linea-venta', index: this.index }
            }));

            await this.saveItem(recordId, cultivo, productorId);
            success = true;
        } catch (e) {
            this.onError(e);
        }

        // Avisar que terminó el loading
        this.dispatchEvent(new CustomEvent('loadingchange', {
            detail: { isLoading: false, source: 'crear-linea-venta', index: this.index }
        }));

        return success;
    }
        
    @api
    async delete(recordId) {
        let success = false;

        try {
            if (this._record.Id) {
                this.request = true;
                let result = await this.deleteItem(recordId);
                this.dispatchEvent(new CustomEvent('record', {detail: result}));
            }
            success = true;
        } catch (e) {
            this.onError(e);
        } 

        this.request = false;
        return success;
    }

    openFactura(event) {
        this.dispatchEvent(new CustomEvent('openfactura', {detail: this.factura}));
    }

    get estado() {
        return this.record.Estado__c == 'Creada' ? 'En Curso' : this.record.Estado__c;
    }

    get showEstadoLicencia(){
        return this.record.Estado__c != null && this.record.Estado__c != 'Creada';
    }
} 

const CompraVentaMixin = (cls) => class extends NavigationMixin(cls) {
    @track
    items = [];
    counter = 0;
    _pendingSaveResponse;
    variedadesByObtentor = {};
    @api recordId = null;
    request = true;
    puedeEditar = true;
    puedeFacturar = false;
    data = {};
    title = '';
    licenciasListView;
    condicionesComerciales;
    currentModal;
    semilleros = [];
    semillero;
    tiposDeCompra = [];
    pendientesFacturacionListView;
    todasListView;
    lastDuplicateCheckId; // para saber si tengo que mostrar el popup de duplicado
    cultivos;
    cultivo;

    icons = icons.compraVenta;

    labels = {
        htDisponibles: HT_DISPONIBLES,
        htFuturas: HT_FUTURAS,
        htFuturasTrigo: HT_FUTURAS_TRIGO
    }

    async init() {
        this.initialized = true;
        this.recordId = this.recordId || this.pageRecordId;
        this.title = (this.puedeEditar ? (this.recordId ? 'Editar ' : "Nueva ") : 'Ver ') + this.community;

        try {
            await this.getData(true).then(d =>this.setData(d));
        } catch (e) {
            this.onError(e)
        }

        this.request = false;
    }

    setDataAndItems(data, items) {
        console.log('data', JSON.stringify(data));
        console.log('items', JSON.stringify(items));
        
        items = (data.record ? items : this.items) || [];
        if (items.length == 0) items = [{}];

        const previousItems = this.items || [];
        this.items = items.map((record, index) => {
            let id;
            if (record.Id) {
                const prev = previousItems.find(item => item.record?.Id === record.Id);
                id = prev?.id ?? record.Id;
            } else {
                id = previousItems[index]?.id;
                if (!id) {
                    this.counter++;
                    id = this.counter;
                }
            }
            return { id, record };
        });

        if (data.products) this.updateVariedades(data.products);
        if (data.misLicenciasId) this.licenciasListView = data.misLicenciasId;
        if (data.condicionesComerciales) this.condicionesComerciales = data.condicionesComerciales;
        if (data.pendientesFacturacionId) this.pendientesFacturacionListView = data.pendientesFacturacionId;
        if (data.todasListView) this.todasListView = data.todasListView;
        if (data.cultivos) this.cultivos = data.cultivos;

        if (data.semilleroData) {
            this.semilleroData = data.semilleroData;
            this.semillero = data.semilleroData.semillero.Id_Obtentor__c;
        }

        const facturas = {};

        for (const cv of (data.cvs || [])) {
            const factura = (cv.Attachments || []).find(a => a.Name == cv.ERPvs__Comprobante__c + '.pdf');
            if (factura) {
                for (const linea of cv.ERPvs__Renglones_de_Comprobante_de_Venta__r) {
                    facturas[linea.OpportunityLineItem__c] = factura;
                }
            }
        }

        if (data.oportunidad) {
            for (const linea of data.oportunidad.OpportunityLineItems) {
                const key = this.community.toLowerCase() == 'venta' ? linea.Linea_de_Compra_HT__r.Linea_de_Venta_HT__c : linea.Linea_de_Compra_HT__c;
                facturas[key] = facturas[linea.Id];
            }
        }

        for (const item of this.items) {
            item.factura = facturas[item.record.Id];
        }

        if (data.record) {
            this.data = data;
            this.puedeEditar = data.record.Estado__c == 'Creada';
            if (data.record.Estado__c == 'Caducado') this.currentModal = "vigencia";
            //this.puedeFacturar = this.puedeCrearCvs || this.puedeCrearFEs || this.puedeCrearPDFs;
            this.cultivo = data.record.Cultivo__c;
        }
        console.log('facturas', JSON.stringify(facturas));
        
        console.log(facturas);
    }

    info(message) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Información',
            message: message,
            variant: 'info',
            mode: 'sticky'
        }));
    }

    hasNoPCV(opLineItemId) {
        for (const cv of this.data.cvs) {
            for (const pcv of cv.ERPvs__Renglones_de_Comprobante_de_Venta__r) {
                if (pcv.OpportunityLineItem__c == opLineItemId) return false;
            }
        }
        return true;
    }

    puedeFacturarEnFecha(lineItem) {
        return (lineItem.Product2.Variedad2__r.Obtentor_Comercializa__r.Dias_de_Exclusion_de_Facturacion_SE__c || '').split(';').map(v => parseInt(v)).includes(new Date().getDate()) == false;
    }

    get puedeCrearCvs() {
        return this.data.oportunidad && this.data.oportunidad.StageName == 'Pendiente de Facturación' && this.data.oportunidad.OpportunityLineItems.some(l => l.Product2.Variedad2__r.Obtentor_Comercializa__r.Factura_por_Cuenta_y_Orden_SE__c && this.puedeFacturarEnFecha(l) && l.Estado__c == 'Facturable' && this.hasNoPCV(l.Id));
    }

    get puedeCrearFEs() {
        return this.data.cvs && this.data.cvs.some(cv => cv.ERPvs__Contabilizar__c != true);
    }

    get puedeCrearPDFs() {
        return this.data.cvs && this.data.cvs.some(cv => cv.Attachments && cv.Attachments.filter(a => a.Name == cv.ERPvs__Comprobante__c + '.pdf').length == 0);
    }

    updateVariedades(records) {
        const byObtentor = {};
        const tiposDeCompra = new Set();
        
        for (const record of records) {
            const key = record.Product2.Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c;
            console.log(byObtentor);
            console.log(record.Product2.Variedad2__r.Obtentor_Comercializa__r.Id_Obtentor__c);
            console.log(record.Product2.Id);
            console.log(record.Product2.Variedad2__c);
            byObtentor[key] = byObtentor[key] || [];
            byObtentor[key].push({label: record.Product2.Nombre_Comercial__c, value: record.Id, record});
            tiposDeCompra.add(record.Product2.Tipo_de_Compra__c);
        }

        this.semilleros = Object.keys(byObtentor)
        .map(key => ({value: key, label: byObtentor[key][0].record.Product2.Variedad2__r.Obtentor_Comercializa__r.Nombre_Obtentor__c}))
        .sort((a, b) => {
            if(a.label > b.label) return 1;
            if(a.label < b.label) return -1;
            return 0;
        });

        this.variedadesByObtentor = byObtentor;
        console.log(byObtentor);
        this.tiposDeCompra = Array.from(tiposDeCompra).map(value => ({value, label: value}));

        console.log('588',JSON.parse(JSON.stringify([records, byObtentor, this.semilleros])))
    }

    get variedades() {
        return this.variedadesByObtentor[this.semillero];
    }

    renderedCallback() {
        if (!this.initialized) this.init();
    }

    close() {
        if (window.opener != null || window.history.length == 1) window.close();
        else window.history.back();
    }

    get closeLabel() {
        return 'Volver al inicio';
    }

    getLineasRelationApi() {
        return this.community?.toLowerCase() === 'venta'
            ? 'Lineas_de_Venta_HT__r'
            : 'Lineas_de_Compra_HT__r';
    }

    applyRecordData(detail, unsavedItems = []) {
        if (!detail) {
            return;
        }

        this.recordId = detail.record.Id;
        const currentItems = this.items.map(item => ({
            ...item,
            record: { ...item.record }
        }));

        this.setData(detail);
        this.items = this.items.map((item, index) => {
            if (currentItems[index] && currentItems[index].record.Tipo_de_Pago__c) {
                item.record.Tipo_de_Pago__c = currentItems[index].record.Tipo_de_Pago__c;
            }
            return item;
        });

        if (unsavedItems.length > 0) {
            for (const unsaved of unsavedItems) {
                this.counter++;
                this.items.push({ id: this.counter, record: { ...unsaved.record } });
            }
            this.items = [...this.items];
        }
    }

    scheduleRecordPostUpdate() {
        setTimeout(() => {
            if (typeof this.updateShowFinanciamientoColumn === 'function') {
                this.updateShowFinanciamientoColumn();
            }
            if (this._promoEvalAfterLineRemove) {
                this._promoEvalAfterLineRemove = false;
                if (typeof this.evaluarCondicionPromocionalHtFutura === 'function') {
                    this.evaluarCondicionPromocionalHtFutura();
                }
            } else if (typeof this.syncPromoQualificationState === 'function') {
                this.syncPromoQualificationState();
            } else if (typeof this.evaluarCondicionPromocionalHtFutura === 'function') {
                this.evaluarCondicionPromocionalHtFutura();
            }
            if (typeof this.refreshAllLinePromoPrices === 'function') {
                this.refreshAllLinePromoPrices();
            }
            if (typeof this.notifyLineSaveStateChanged === 'function') {
                this.notifyLineSaveStateChanged();
            }
        }, 150);
    }

    assignSavedLineToChild(child) {
        const response = this._pendingSaveResponse;
        if (!response || !child) {
            return;
        }

        this.recordId = response.record.Id;
        const lineas = response.record?.[this.getLineasRelationApi()] || [];
        const pbe = child.record?.Id_Producto_de_Lista_de_Precio__c;
        const producto = child.record?.Producto__c;
        const match = lineas.find(line =>
            line.Id_Producto_de_Lista_de_Precio__c === pbe ||
            line.Producto__c === producto
        );

        if (!match) {
            return;
        }

        const item = this.items.find(row =>
            row.record?.Id_Producto_de_Lista_de_Precio__c === pbe &&
            (!row.record?.Id || row.record.Id === match.Id)
        );
        if (item) {
            item.record = { ...match };
        }
        child.updateRecordFromServer?.(match);
    }

    finalizePendingBatchSave() {
        if (!this._pendingSaveResponse) {
            return;
        }
        this.applyRecordData(this._pendingSaveResponse);
        this._pendingSaveResponse = null;
        this.scheduleRecordPostUpdate();
    }
    
    async addRowInternal(rows) {
        this.counter++;
        this.items.push({ id: this.counter, record: {} });
    }

    async removeRow(event) {
        const id = event.target.index;
        const hadSavedLine = !!event.target.record?.Id;
        this._promoEvalAfterLineRemove = true;

        const success = await event.target.delete(this.recordId);
        if (!success) {
            this._promoEvalAfterLineRemove = false;
            return;
        }

        this.items = this.items.filter(e => e.id != id);

        if (!hadSavedLine) {
            this.scheduleRecordPostUpdate();
        }
    }

    updateRecord(event) {
            console.log('[DEBUG] updateRecord - event detail:', JSON.stringify(event.detail));

        if (event.detail) {
            if (this._savingAllPending) {
                this.recordId = event.detail.record.Id;
                this._pendingSaveResponse = event.detail;
                return;
            }

            const currentItems = this.items.map(item => ({
            ...item,
            record: { ...item.record }
            }));

            const unsavedItems = currentItems.filter(item =>
                item.record && !item.record.Id && item.record.Producto__c
            );

            this.applyRecordData(event.detail, unsavedItems);
            this.scheduleRecordPostUpdate();
        
        } else {
            this.recordId = null;
            this.data = {};
            this.puedeFacturar = false;
            if (this.hasOwnProperty('showFinanciamientoColumn')) {
                this.showFinanciamientoColumn = false;
            }
        }
    }

    onError(e) {
        this.dispatchEvent(new ShowToastEvent({
            title: 'Error',
            message: reduceErrors(e).join('\n'),
            variant: 'error',
            mode: 'sticky'
        }));
    }

    get loading() {
        return this.request;
    }

    get isChildrenLoading() {
        for (const child of this.template.querySelectorAll('c-crear-linea-venta,c-crear-linea-compra')) {
            if (child.loading) return true;
        }

        return false;
    }

    get puedeFinalizar() {
        return this.puedeEditar && this.recordId;
    }

    get puedeAnular() {
        return this.data && this.data.record && this.data.record.Estado__c == 'Pendiente de Facturación';
    }

    get finalizada() {
        return this.recordId && !this.puedeEditar;
    }

    get variedadesTitle() {
        return this.finalizada ? '' : 'Variedades';
    }

    get puedeRealizarNueva() {
        return this.recordId && !this.puedeEditar && !this.puedeFacturar;
    }

    get cultivoName() {
        const seleccionado = (this.cultivos || []).find(c => c.value == this.cultivo);
        return seleccionado ? seleccionado.label : '';
    }

    get descripcionHtFuturas(){
        return this.cultivoName == 'TRIGO' ? this.labels.htFuturasTrigo : this.labels.htFuturas;
    }

    cultivoSelected(event){
        this.cultivo = event.detail.value;
        if(this.community != 'Venta'){
            this.getProductos();
        }
    }

    redirectMisFacturas() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'facturacion',
            }
        });
    }

    redirectToNew() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: this.community.toLowerCase() == 'venta' ? 'formularionuevaventaht' : 'FormularioNuevaVentaHT',
            }
        });
    }

    openCondicionesComerciales(event) {
        const document = this.condicionesComerciales.find(doc => doc.Title.includes('_' + this.semillero));
        
        if (document) {
            this.template.querySelector('c-pdf-reader').show({
                documentId: document.Id,
                title: document.Title
            });
        } else {
            this.info('No existe pdf de condiciones comerciales para el obtentor ' + this.semillero);
        }
    }

    openFactura(event) {
        console.log(event)
        this.template.querySelector('c-pdf-reader').show({
            documentId: event.detail.Id,
            title: event.detail.Name
        });
    }

    async facturar(event) {
        //this.currentModal = "facturando";

        try {
            if (this.puedeCrearCvs) {
                await this.crearCVS().then(res => this.setData(res));
            }
            if (this.puedeCrearFEs) {
                for (const cv of this.data.cvs.filter(cv => cv.Erpvs__Contabilizar__c != true)) {
                    await this.generarFE(cv.Id).then(res => this.setData(res));
                }
            }
            if (this.puedeCrearPDFs) {
                for (const cv of this.data.cvs.filter(cv => cv.Attachments && cv.Attachments.filter(a => a.name == cv.ERPvs__Comprobante__c + '.pdf').length == 0)) {
                    await this.generarPDF(cv.Id).then(res => this.setData(res));
                }
            }

            //this.currentModal = "facturado";
        } catch (e) {
            this.currentModal = null;
            this.onError(e);
        }
    }   

    semilleroSelected(event) {
        console.log('Semillero seleccionado: ' + event.detail );
        this.semillero = event.detail;
    }

    get obtentorEsPuntoDeVenta() {
        const entries = this.variedades;
        return entries?.length > 0
            && !entries[0]?.record?.Product2?.Variedad2__r?.Obtentor_Comercializa__r?.Factura_por_Cuenta_y_Orden_SE__c;
    }

    get missingConfirmData() {
        return !this.semillero || (this.community.toLowerCase() == "venta"  && !this.productor);
    }

    async confirm(event) {
        await this.requestWrap(async () => {
            this.semilleroData = await this.getSemilleroData();
        });
    }

    showAnularConfirm() {
        this.currentModal = "anular";
    }

    closeModal() {
        this.currentModal = null;
    }

    async requestWrap(method) {
        this.request = true;

        try {
            await method();
        } catch (e) {
            this.onError(e)
        }

        this.request = false
    }

    redirectToList(objectApiName, filterName) {
        filterName = filterName || "Default";

        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName,
                actionName: 'list'
            },
            state: {
                filterName
            }
        });
    }

    redirectPendientesFacturacion() {
        this.redirectToList(this.community.toLowerCase() == 'venta' ? 'Venta_HT__c' : 'Compra_HT__c', this.pendientesFacturacionListView);
    }

    redirectToPage(pageName) {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName,
            }
        });
    }

    redirectMisLicencias() {
        if (this.community.toLowerCase() == 'compra') {
            //this.redirectToList('Licencia__c', this.licenciasListView);
            const pageLicencias = 'licenciaslistcustomproductor';
            this.redirectToPage(pageLicencias);

        } else if(this.community.toLowerCase() == 'venta'){
            const pageName = this.isPortalObtentor ? 'consulta-de-licencias-del-licenciatario' : 'consulta-de-licencias-del-productor';
            this.redirectToPage(pageName);
        }
    }

    redirect(e) {
        if (e.detail == "licencias") {
            this.redirectMisLicencias();
        } else if (e.detail == "facturas") {
            this.redirectMisFacturas();
        } else if (e.detail == "compras") {
            //this.redirectToList('Compra_HT__c', this.todasListView);
            const pagecompras = 'comprahtlistproductor';
            this.redirectToPage(pagecompras);
        } else if (e.detail == "ventas") {
            this.redirectToList('Venta_HT__c', this.todasListView);
        }
    }
} 



export {CSS, LineaCompraVentaMixin, CompraVentaMixin}