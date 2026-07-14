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
import {
    getPriceBookListPrice,
    getPromoUnitPrice,
    isHtFuturaPromoContext,
    isHtFuturaPromoScreen,
    resolveBaseListPrice
} from 'c/htCondicionPromocionalGdm';

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

    lightning-input.input-numerico {
        --sds-c-input-text-align: center;
        --slds-c-input-text-align: center;
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
    }

    span.pendiente {
        background-color: red;
        color: white;
        padding: 0.4rem;
    }
`;

const LineaCompraVentaMixin = (cls) => class extends NavigationMixin(cls) {
    @api priceBookEntries;
    @api index;
    @api factura;
    @api semilleroId;
    @track tipoFinanciamiento;
    @track isFuturaFlag = false; 
    @api cultivoSeleccionado;

    @api batchSaving = false;

    @api tipoCompraSeleccionado;

    _promoCantidadTotal;

    request;
    _record = {};
    precio;
    initialized;
    preCampaign;
    //@api tiposDeCompra = [];// = [{value: 'Futura', label: 'Futura'}, {'value': 'Disponible', label: 'Disponible'}];
    variedad;
    _persistedProducto;
    _persistedCantidad;
    _persistedPrecio;

    icons = icons.lineaCompraVenta;
    iconsCompraVenta = icons.compraVenta;
    
    @api
    get record() {
       //  console.log('this._record =' , JSON.parse(JSON.stringify(this._record || {})));
        return this._record;
    }

    set record(data) {
        //this._record = JSON.parse(JSON.stringify(data || {}));
         //console.log('this._record =' , JSON.parse(JSON.stringify(data || {})));
        const newRecord = JSON.parse(JSON.stringify(data || {}));
        console.log('newRecord',newRecord);
        if (this._record && this._record.Tipo_de_Pago__c && !newRecord.Tipo_de_Pago__c) {
            newRecord.Tipo_de_Pago__c = this._record.Tipo_de_Pago__c;
        }
        this._record = newRecord;
        if (newRecord.Id) {
            this.capturePersistedState();
        } else {
            this._persistedProducto = null;
            this._persistedCantidad = null;
            this._persistedPrecio = null;
        }
    }

    capturePersistedState() {
        if (!this._record?.Id) {
            return;
        }
        this._persistedProducto = this._record.Producto__c;
        this._persistedCantidad = this._record.Cantidad__c;
        this._persistedPrecio = this._record.Precio_de_Lista__c;
    }

    @api
    refreshPromoPrice(cantidadTotal) {
        this._promoCantidadTotal = cantidadTotal == null ? null : Number(cantidadTotal);
        if (this._record?.Producto__c) {
            this.updatePriceBasedOnTipoCompra();
        }
    }

    //solo muestro los tipos de HT por las cuales hay una entry
    get tiposDeCompra(){
        const entries = (this.priceBookEntries || []).filter(v => (v.record.Product2.Variedad2__c == this.variedad || this.hasId && v.label == this.variedad));
        const tiposCompra = entries.reduce((tiposCompra, entry) => [...tiposCompra, {label: entry.record.Product2.Tipo_de_Compra__c, value: entry.record.Product2.Tipo_de_Compra__c}], []);
        console.log(tiposCompra);
        return tiposCompra;
    }

    connectedCallback() {
        loadStyle(this, fontAwesome + '/fontawesome-free-6.1.1-web/css/all.min.css');
         console.log('newRecord2',this._record);
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
        this.isFuturaFlag = this.preCampaign === 'Futura' && priceBookEntry && priceBookEntry.record.Unit_Price__c != null && priceBookEntry.record.Unit_Price__c !== 0 && this.cultivoSeleccionado === 'SOJA';
        console.log('preCampaignChange this.preCampaign', this.preCampaign );
        
        this.productChange();
        this.checkAutoSave();
        this.dispatchPromoLineChange(true, false);
        this.dispatchEvent(new CustomEvent('tipohtchange', {
            detail: {
                //isFutura: (event.target.value === 'Futura'),
                isFutura: this.isFuturaFlag,
                recordId: this.record.id
            },
            bubbles: true
        }));
        console.log('preCampaignChange valor is futura',this.isFutura);

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
            console.log(' init priceBookEntry.record.Product2.Tipo_de_Compra__c ', priceBookEntry.record.Product2.Tipo_de_Compra__c)

            if (this.hasId) {
                // Record guardado → combobox usa label como value
                this.variedad = priceBookEntry.label;
            } else {
                // Record re-inyectado sin Id → productChange necesita el ID de variedad
                this.variedad = priceBookEntry.record.Product2.Variedad2__c;
                // Restaurar selección visual del lookup
                const lookup = this.template.querySelector('c-lookup');
                if (lookup) {
                    lookup.selection = [{
                        id: priceBookEntry.record.Product2.Variedad2__c,
                        title: priceBookEntry.label,
                        record: { Id: priceBookEntry.record.Product2.Variedad2__c }
                    }];
                }
            }
        }
        console.log(this.variedad, this.variedades);
        console.log('log desde init, valor de tipo de pago:',this._record.Tipo_de_Pago__c);

        this.productChange();
        this.updatePrice();
    }

    shouldAutoSaveChanges() {
        return this.hasUnsavedChanges();
    }

    // MODIFICAR productChange para NO sobrescribir precio guardado
productChange() {
    console.log('🔍 DEBUG - productChange - Iniciando');
    console.log('🔍 DEBUG - productChange - variedad:', this.variedad);
    console.log('🔍 DEBUG - productChange - preCampaign:', this.preCampaign);
    console.log('🔍 DEBUG - productChange - hasId:', this.hasId);
    console.log('🔍 DEBUG - productChange - Precio_de_Lista__c actual:', this._record.Precio_de_Lista__c);
    console.log('🔍 DEBUG - productChange - Es_NC__c:', this._record.Es_NC__c);
    console.log('🔍 DEBUG - productChange - priceBookEntries count:', this.priceBookEntries?.length);
    
    const priceBookEntry = this.priceBookEntries.find(v => 
        (v.record.Product2.Variedad2__c == this.variedad || 
         this.hasId && v.label == this.variedad) && 
        v.record.Product2.Tipo_de_Compra__c == this.preCampaign
    );

    console.log('🔍 DEBUG - productChange - priceBookEntry encontrado:', !!priceBookEntry);

    if (priceBookEntry) {
        // ✅ IMPORTANTE: Solo actualizar Precio_de_Lista__c si NO existe o es nueva línea
        if (!this._record.Precio_de_Lista__c || !this.hasId) {
            this._record.Precio_de_Lista__c = priceBookEntry.record.UnitPrice;
            console.log('🔍 DEBUG - productChange - Asignando precio de pricebook (nueva línea):', this._record.Precio_de_Lista__c);
        } else {
            console.log('🔍 DEBUG - productChange - Manteniendo precio guardado:', this._record.Precio_de_Lista__c);
        }
        
        this._record.Producto__c = priceBookEntry.record.Product2Id;
        this._record.Id_Producto_de_Lista_de_Precio__c = priceBookEntry.value;
        this.preCampaign = priceBookEntry.record.Product2.Tipo_de_Compra__c;
        
        // Actualizar isFutura
        this.isFuturaFlag = this.preCampaign === 'Futura' && 
                           priceBookEntry.record.Unit_Price__c != null && 
                           priceBookEntry.record.Unit_Price__c !== 0;

    } else {
        this._record.Id_Producto_de_Lista_de_Precio__c = null;
        // ❌ NO resetear Precio_de_Lista__c si ya existe
        if (!this._record.Precio_de_Lista__c) {
            this._record.Precio_de_Lista__c = null;
        }
        this.isFuturaFlag = false;
    }

    if (this.variedad && this.preCampaign && !priceBookEntry) {
        const lookup = this.template.querySelector('c-lookup');
        lookup.clearSelection();
        this.onError(new Error('No existe la variedad para ese tipo de HT'));
        this.preCampaign = null;
        this.isFuturaFlag = false; 
    }

    if (this.isOnHtFuturaPromoScreen()) {
        this.dispatchPromoLineChange(false, false);
        return;
    }

    this.updatePriceBasedOnTipoCompra();
}

    isOnHtFuturaPromoScreen() {
        return isHtFuturaPromoScreen({
            semilleroId: this.semilleroId,
            cultivoName: this.cultivoSeleccionado
        });
    }

    shouldDeferLocalPromoPricing() {
        return this.isOnHtFuturaPromoScreen() && this._promoCantidadTotal == null;
    }

    get variedades() { // agrupo por label, que solo aparezca 1. Con la checkbox defino si es pre campaña o entrega inmediata
        const variedades = {};

        for (const priceBookEntry of (this.priceBookEntries || [])) {
            variedades[priceBookEntry.label] = {label: priceBookEntry.label, value: priceBookEntry.label};
        }

        return Object.values(variedades);
    }

    syncCantidad(event) {
        this._record['Cantidad__c'] = event.target.value;
        console.log(this._record['Cantidad__c']);
        if (this.isOnHtFuturaPromoScreen()) {
            this.dispatchPromoLineChange(false, false);
            return;
        }
        this.updatePriceBasedOnTipoCompra();
        this.dispatchPromoLineChange(false, false);
    }

    handleCantidadBlur() {
        this.dispatchPromoLineChange(true, true);
    }

    @api
    hasUnsavedChanges() {
        if (!this._record?.Producto__c || !this._record?.Cantidad__c) {
            return false;
        }
        if (!this._record.Id) {
            return true;
        }
        if (this._persistedProducto == null) {
            return true;
        }
        if (this._record.Producto__c !== this._persistedProducto) {
            return true;
        }
        if (String(this._record.Cantidad__c) !== String(this._persistedCantidad)) {
            return true;
        }
        if (String(this._record.Precio_de_Lista__c) !== String(this._persistedPrecio)) {
            return true;
        }
        return false;
    }

    @api
    syncSaveHash() {
        this.capturePersistedState();
    }

    @api
    updateRecordFromServer(serverLine) {
        if (!serverLine) {
            return;
        }
        this._record = JSON.parse(JSON.stringify(serverLine));
        this.capturePersistedState();
    }

    dispatchPromoLineChange(immediate = false, evalModal = false) {
        this.dispatchEvent(new CustomEvent('promolinechange', {
            bubbles: true,
            composed: true,
            detail: { immediate, evalModal }
        }));
    }

    getActivePriceBookEntry() {
        if (!this.priceBookEntries || !Array.isArray(this.priceBookEntries)) {
            return null;
        }
        return this.priceBookEntries.find(v =>
            (v.record.Product2.Variedad2__c == this.variedad ||
                this.hasId && v.label == this.variedad) &&
            v.record.Product2.Tipo_de_Compra__c == this.preCampaign
        );
    }

    @api
    getPromoLineData() {
        const priceBookEntry = this.getActivePriceBookEntry();
        const listPrice = getPriceBookListPrice(priceBookEntry) ?? resolveBaseListPrice(this._record.Precio_de_Lista__c);
        const tipoCompra = this.preCampaign || this.tipoCompraSeleccionado;
        if (!tipoCompra || listPrice == null) {
            return null;
        }
        return {
            tipoCompra,
            cantidad: this._record.Cantidad__c,
            listPrice
        };
    }

    checkAutoSave() {
        console.log('check autosave');
        console.log('variedad seleccionada', this.variedad)
        console.log('Tipo de Financiamiento antes de guardar:', this.tipoFinanciamiento);
        
        if (this.shouldAutoSaveChanges()) {
            console.log('entro al if');
            this.dispatchEvent(new CustomEvent('save'));
        }
    }
    
    // MODIFICAR COMPLETAMENTE updatePriceBasedOnTipoCompra para priorizar precio guardado
updatePriceBasedOnTipoCompra() {
    console.log('🔍 DEBUG - updatePriceBasedOnTipoCompra - Iniciando');
    console.log('🔍 DEBUG - Precio_de_Lista__c del registro:', this._record.Precio_de_Lista__c);
    console.log('🔍 DEBUG - Es_NC__c:', this._record.Es_NC__c);
    console.log('🔍 DEBUG - hasId:', this.hasId);

    const priceBookEntry = this.getActivePriceBookEntry();
    const baseListPrice = getPriceBookListPrice(priceBookEntry) ?? resolveBaseListPrice(this._record.Precio_de_Lista__c);

    if (this.canEdit && isHtFuturaPromoContext({
        semilleroId: this.semilleroId,
        tipoCompra: this.preCampaign || this.tipoCompraSeleccionado,
        listPrice: baseListPrice,
        cultivoName: this.cultivoSeleccionado
    })) {
        if (this.shouldDeferLocalPromoPricing()) {
            this.updatePrice();
            return;
        }
        const promoPrice = getPromoUnitPrice({
            semilleroId: this.semilleroId,
            tipoCompra: this.preCampaign || this.tipoCompraSeleccionado,
            listPrice: baseListPrice,
            cantidad: this._record.Cantidad__c,
            cultivoName: this.cultivoSeleccionado,
            cantidadTotal: this._promoCantidadTotal
        });
        this._record.Precio_de_Lista__c = promoPrice;
        this.precioLista = promoPrice;
        this.updatePrice();
        return;
    }
    
    // ✅ CRÍTICO: SIEMPRE usar el Precio_de_Lista__c del registro si existe
    if (this._record.Precio_de_Lista__c) {
        this.precioLista = this._record.Precio_de_Lista__c;
        console.log('🔍 DEBUG - Usando precio guardado del registro:', this.precioLista);
        this.updatePrice();
        return; // ❌ SALIR INMEDIATAMENTE si hay precio guardado
    }
    
    // ✅ Solo continuar con pricebook si NO hay precio guardado
    if (!this.priceBookEntries || !Array.isArray(this.priceBookEntries)) {
        console.warn('🔍 DEBUG - priceBookEntries no disponible');
        this.precioLista = this._record.Precio_de_Lista__c || 0;
        this.updatePrice();
        return;
    }
    
    if (priceBookEntry) {
        this.precioLista = priceBookEntry.record.Unit_Price__c || priceBookEntry.record.UnitPrice;
        console.log('🔍 DEBUG - Usando precio de pricebook:', this.precioLista);
    } else {
        this.precioLista = 0;
    }

    // Lógica de precio especial solo para nuevas líneas sin precio guardado
    const mesActual = new Date().getMonth() + 1;
    if (!this._record.Precio_de_Lista__c && this.preCampaign === 'Futura' && 
        priceBookEntry?.record.Unit_Price__c > 0 && 
        this._record.Tipo_de_Pago__c === 'Contado' && 
        (mesActual === 9 || mesActual === 10)) {
        
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
    
    @api 
    get loading() {
        return this.request;
    }

    @api
    async save(recordId, cultivo, productorId) {
        const form = this.template.querySelector('lightning-record-edit-form');
        let success = false;
        console.log('Saving record:', this._record);

        console.log('Validating inputs in form:', form);

        if (!validateInputs(form)) return success;

        console.log('Inputs valid, proceeding to save.');
        try {
            
            console.log('414',JSON.stringify(this._record));

            if (!this.batchSaving) {
                this.request = true;
            }
            await this.saveItem(recordId, cultivo, productorId);
            success = true;
            this.syncSaveHash();
        } catch (e) {
            this.onError(e)
        }

        if (!this.batchSaving) {
            this.request = false;
        }
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
            console.log('Setting data record:', JSON.stringify(data.record));
            this.data = data;
            this.puedeEditar = data.record.Estado__c == 'Creada';
            if (data.record.Estado__c == 'Caducado') this.currentModal = "vigencia";
            //this.puedeFacturar = this.puedeCrearCvs || this.puedeCrearFEs || this.puedeCrearPDFs;
            this.cultivo = data.record.Cultivo__c;
        }

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
        this.tiposDeCompra = Array.from(tiposDeCompra).map(value => ({value, label: value}));

        console.log(JSON.parse(JSON.stringify([records, byObtentor, this.semilleros])))
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
                pageName: 'mis-facturas',
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
            this.redirectToList('Licencia__c', this.licenciasListView);
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
            this.redirectToList('Compra_HT__c', this.todasListView);
        } else if (e.detail == "ventas") {
            this.redirectToList('Venta_HT__c', this.todasListView);
        }
    }
} 



export {CSS, LineaCompraVentaMixin, CompraVentaMixin}