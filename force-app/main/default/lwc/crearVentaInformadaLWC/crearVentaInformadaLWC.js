import { LightningElement, api } from 'lwc';
import getCuenta from '@salesforce/apex/CrearVentaInformadaLWCController.getCuenta';
import getVariedad from '@salesforce/apex/CrearVentaInformadaLWCController.getVariedad';
import saveVentaInformada from '@salesforce/apex/CrearVentaInformadaLWCController.saveVentaInformada';
import getCuentaOriginante from '@salesforce/apex/CrearVentaInformadaLWCController.getCuentaOriginante';
import getRazonSocialPorCuit from '@salesforce/apex/CrearVentaInformadaLWCController.getRazonSocialPorCuit';
import getCuentaDestinatarioPorCuit from '@salesforce/apex/CrearVentaInformadaLWCController.getCuentaDestinatarioPorCuit';
import getCampanasAgricolasParaLookup from '@salesforce/apex/CrearVentaInformadaLWCController.getCampanasAgricolasParaLookup';
import { wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';

// Mapeo Tipo de Comprobante: lo que ve el usuario -> lo que se guarda/reprocesa (FC/NC).
// Nota: el API value de "Remito" en la picklist es "REMITO" (caso heredado en SF).
const TIPO_COMPROBANTE_MAP = {
    'FC': 'FC',
    'NC': 'NC',
    'REMITO': 'FC',
    'Remito de Devolución': 'NC'
};

/** Prefijos obligatorios e inmutables en N° de Comprobante según tipo (ticket 1874). */
const PREFIJO_N_COMPROBANTE = {
    REMITO: 'R-',
    'Remito de Devolución': 'RD-'
};

export default class CrearVentaInformadaLWC extends NavigationMixin(LightningElement) {
    _isModal = false;
    _originanteAccountId;

    @api
    get originanteAccountId() {
        return this._originanteAccountId;
    }

    set originanteAccountId(value) {
        this._originanteAccountId = value;
        if (this._isModal && value) {
            this.loadOriginanteFromAccountId(value);
        }
    }

    @api 
    get isModal() {
        return this._isModal;
    }

    set isModal(value) {
        this.isLoading = true;
        this._isModal = value;
        if (value) {
            if (this._originanteAccountId) {
                this.loadOriginanteFromAccountId(this._originanteAccountId);
            } else {
                getCuentaOriginante()
                    .then(response => {
                        this.applyOriginanteAccount(response);
                        this.isLoading = false;
                    })
                    .catch(error => {
                        console.error('Error loading originante:', error);
                        this.dispatchEvent(new ShowToastEvent({
                            message: 'Error cargando datos del usuario',
                            variant: 'error',
                            title: 'Error'
                        }));
                        this.isLoading = false;
                    });
            }
        }
    }

    loadOriginanteFromAccountId(accountId) {
        this.isLoading = true;
        getCuenta({ recordId: accountId })
            .then(response => {
                this.applyOriginanteAccount(response);
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading originante por cuenta:', error);
                this.dispatchEvent(new ShowToastEvent({
                    message: error?.body?.message || 'Error cargando cuenta originante',
                    variant: 'error',
                    title: 'Error'
                }));
                this.isLoading = false;
            });
    }

    applyOriginanteAccount(response) {
        if (!response) {
            return;
        }
        this.originante = response.Id;
        this.originanteName = response.Name;
        this.valueRolOriginante = response.Type;
        this.cuitOriginario = response.N_CUIT__c;
        if (this.ventaInternaChecked) {
            this.applyAutoventaDestinatario();
        } else if (this.DestinatarioSelected) {
            this.syncVentaInternaPorCuit(this.DestinatarioSelected);
        }
    }

    isLoading = false;
    matchingInfo = {
        primaryField: { fieldPath: 'Name' },
        additionalFields: [{ fieldPath: 'N_CUIT__c' }],
    };

    get options() {
        return [
            { label: 'Obtentor', value: 'Obtentor' },
            { label: 'Distribuidor', value: 'Distribuidor' },
            { label: 'Productor', value: 'Productor' },
        ];
    }

    get optionsCategoria() {
        return [
            { label: 'Pre Básica', value: 'Pre Básica' },
            { label: 'Original o Fundadora', value: 'Original o Fundadora' },
            { label: 'Primera Multiplicación', value: 'Primera Multiplicación' },
            { label: 'Segunda Multiplicación', value: 'Segunda Multiplicación' },
            { label: 'Tercera Multiplicación', value: 'Tercera Multiplicación' }
        ];
    }

    // Ticket 1874: se quita ND y se agregan Remito y Remito de Devolución.
    get optionsTipoComprobante() {
        return [
            { label: 'FC', value: 'FC' },
            { label: 'NC', value: 'NC' },
            { label: 'Remito', value: 'REMITO' },
            { label: 'Remito de Devolución', value: 'Remito de Devolución' }
        ]
    }

    get comboboxClass(){
        return this.isModal ? 'slds-var-p-horizontal_xx-small' : 'slds-var-p-horizontal_x-small';
    }

    get categoriaClass(){
        return this.isModal ? 'slds-var-p-horizontal_xx-small' : 'slds-var-p-left_x-small';
    }

    get saveButtonClass(){
        return this.isModal ? 'slds-hide' : 'form-btn-save';
    }

    get destinatarioClass(){
        return this.isModal ? 'slds-col slds-size_1-of-2' : 'slds-col slds-size_1-of-2 slds-var-p-horizontal_x-small'
    }

    get modalClass() {
        return this.isModal ? 'slds-col slds-size_1-of-2 slds-var-p-horizontal_xx-small' : 'slds-col slds-size_1-of-2 slds-var-p-horizontal_x-small'
    }

    get requierePrefijoNComprobante() {
        return Boolean(PREFIJO_N_COMPROBANTE[this.tipoComprobanteValue]);
    }

    get prefijoNComprobanteVisible() {
        return this.getPrefijoNComprobante(this.tipoComprobanteValue);
    }

    get placeholderNComprobanteCuerpo() {
        return 'Ej. 00012345';
    }

    /** Fuerza remount al cambiar entre control con prefijo y campo libre (FC/NC). */
    get nComprobanteModoKey() {
        return this.requierePrefijoNComprobante ? 'con-prefijo' : 'libre';
    }

    obtenerNComprobanteValorCompleto() {
        const prefijo = this.getPrefijoNComprobante(this.tipoComprobanteValue);
        if (prefijo) {
            return prefijo + (this.nComprobanteCuerpo || '');
        }
        return this.prefillNComprobante || '';
    }

    get formStyle() {
        return this.isModal ? 'width: 100%;' : 'width: 70%;';
    }

    get formCardClass() {
        return this.isModal ? 'form-card form-card--modal' : 'form-card';
    }

    get formShellClass() {
        return this.isModal
            ? 'form-shell form-shell--modal'
            : 'form-shell slds-align_absolute-center';
    }

    // Visibilidad por modo (ocultos en el Pop Up).
    get showOriginanteFields() {
        return !this.isModal;
    }

    get showRolDestinatario() {
        return !this.isModal;
    }

    valueRolOriginante;
    valueRolDestinatario;
    cuitOriginario;
    cuitDestinatario;
    originante;
    originanteName;
    destinatario;
    categoria;
    variedad;
    campanaAgricolaId;
    filteredVariedadOptions = [];
    variedadDisplayValue = '';
    variedadDropdownOpen = false;
    variedadSearchLoading = false;
    _variedadSearchTimeout;
    _variedadSearchSeq = 0;
    DestinatarioSelected;
    razonSocialDestinatario;
    tipoComprobanteValue;
    ventaInternaChecked = false;

    // Prefill values for duplication
    prefillNComprobante;
    /** Parte editable del N° de comprobante cuando el tipo es Remito (R-) o Remito de Devolución (RD-). */
    nComprobanteCuerpo = '';
    allCampanaOptions = [];
    filteredCampanaOptions = [];
    campanaSearchTerm = '';
    campanaDisplayValue = '';
    campanaDropdownOpen = false;
    prefillCuitDestinatario;
    prefillCantidadBolsas;
    prefillTipoComprobante;
    prefillFechaFacturacion;
    prefillLineaFacturacion;
    prefillVentaInterna;
    fechaComprobante;

    _prefillData;
    @api
    get prefillData() {
        return this._prefillData;
    }

    normalizeSalesforceId(rawValue) {
        if (!rawValue) {
            return null;
        }

        if (typeof rawValue === 'string') {
            return /^[a-zA-Z0-9]{15,18}$/.test(rawValue) ? rawValue : null;
        }

        if (Array.isArray(rawValue) && rawValue.length > 0) {
            return this.normalizeSalesforceId(rawValue[0]);
        }

        if (typeof rawValue === 'object') {
            return this.normalizeSalesforceId(
                rawValue.id || rawValue.Id || rawValue.value || rawValue.recordId
            );
        }

        return null;
    }

    set prefillData(value) {
        this._prefillData = value;
        if (value) {
            this.tipoComprobanteValue = this.mapTipoComprobanteToUi(value);
            this.actualizarPartesNComprobante(value.N_de_Comprobante__c, this.tipoComprobanteValue);
            this.prefillCuitDestinatario = value.CUIT_Destinatario__c;
            this.prefillCantidadBolsas = value.Cantidad_de_Bolsas__c;
            this.prefillTipoComprobante = this.tipoComprobanteValue;
            this.prefillFechaFacturacion = value.Fecha_de_Facturacion__c;
            this.fechaComprobante = this.toInputDateString(value.Fecha_de_Facturacion__c);
            this.prefillLineaFacturacion = value.Linea_Facturacion__c;
            this.prefillVentaInterna = value.Venta_Interna__c;
            this.ventaInternaChecked = !!value.Venta_Interna__c;
            this.campanaAgricolaId = this.normalizeSalesforceId(value.Campana_Agricola__c);
            this.categoria = value.Categoria__c;
            this.DestinatarioSelected = value.CUIT_Destinatario__c;
            this.razonSocialDestinatario = value.Razon_Social_Destinatario__c || null;
            this.destinatario = value.Destinatario__c || null;
            this.valueRolDestinatario = value.Rol_Destinatario__c || null;

            this.variedad = this.normalizeSalesforceId(
                value.VariedadId || value.Variedad_INASE__c || null
            );
            this.variedadDisplayValue = value.VariedadName || '';

            // Si hay CUIT precargado, intentar resolver Razón Social.
            if (this.DestinatarioSelected) {
                this.resolveRazonSocial(this.DestinatarioSelected);
            }
        }
    }


    handleChange(event){
        let name = event.target.name;
        if(name == 'rolOriginante') {
            this.valueRolOriginante = event.detail.value;
        } else if (name == 'rolDestinatario') {
            this.valueRolDestinatario = event.detail.value;
        } else if (name == 'tipoComprobante') {
            const nuevoTipo = event.detail.value;
            const valorActual = this.obtenerNComprobanteValorCompleto();
            this.tipoComprobanteValue = nuevoTipo;
            this.actualizarPartesNComprobante(valorActual, nuevoTipo);
            this.programarSyncNComprobanteTrasCambioTipo();
        } else if (name == 'categoria') {
            this.categoria = event.detail.value;
        }
    }

    actualizarPartesNComprobante(valor, tipoUi) {
        const prefijo = this.getPrefijoNComprobante(tipoUi);
        if (prefijo) {
            this.nComprobanteCuerpo = this.stripPrefijosRemito(valor, prefijo);
            this.prefillNComprobante = prefijo + this.nComprobanteCuerpo;
        } else {
            this.nComprobanteCuerpo = '';
            this.prefillNComprobante = this.stripPrefijosRemito(valor, null);
        }
    }

    programarSyncNComprobanteTrasCambioTipo() {
        // Tras el swap de template (prefijo ↔ campo libre), sincronizar el control visible.
        Promise.resolve().then(() => {
            if (!this.requierePrefijoNComprobante) {
                this.syncNComprobanteFieldLibre();
            }
        });
    }

    syncNComprobanteFieldLibre() {
        const field = this.template.querySelector(
            'lightning-input-field[field-name="N_de_Comprobante__c"]'
        );
        if (field) {
            field.value = this.prefillNComprobante || '';
        }
    }

    /** Valores guardados en SF → valor del combobox UI. Prioriza Tipo_Comprobante_Externo__c. */
    mapTipoComprobanteToUi(recordOrTipo) {
        if (!recordOrTipo) return null;
        const externo =
            typeof recordOrTipo === 'object'
                ? recordOrTipo.Tipo_Comprobante_Externo__c
                : null;
        const interno =
            typeof recordOrTipo === 'object'
                ? recordOrTipo.Tipo_de_Comprobante__c
                : recordOrTipo;

        if (externo === 'Remito' || externo === 'REMITO') return 'REMITO';
        if (externo) return externo;

        if (interno === 'REMITO' || interno === 'Remito') return 'REMITO';
        if (interno === 'Remito de Devolución') return 'Remito de Devolución';
        return interno;
    }

    /** Valor UI del combobox → Tipo_Comprobante_Externo__c (picklist visible). */
    mapTipoComprobanteToExterno(tipoUi) {
        if (!tipoUi) return null;
        if (tipoUi === 'REMITO') return 'Remito';
        return tipoUi;
    }

    getPrefijoNComprobante(tipoUi) {
        return PREFIJO_N_COMPROBANTE[tipoUi] || '';
    }

    /**
     * Extrae solo la parte editable del número (sin R- / RD-).
     * Si el usuario borra con backspace, a veces queda "R" o "RD" sin guión: eso no es cuerpo válido.
     */
    stripPrefijosRemito(valor, prefijoEsperado) {
        let s = valor == null ? '' : String(valor);

        if (prefijoEsperado === 'RD-') {
            if (s.startsWith('RD-')) return s.substring(3);
            if (s === 'RD-' || s === 'RD' || s === 'R-' || s === 'R') return '';
            return s;
        }
        if (prefijoEsperado === 'R-') {
            if (s.startsWith('RD-')) return s.substring(3);
            if (s.startsWith('R-')) return s.substring(2);
            if (s === 'R-' || s === 'R') return '';
            return s;
        }

        /* FC / NC: quitar cualquier resto de Remito */
        if (s.startsWith('RD-')) return s.substring(3);
        if (s.startsWith('R-')) return s.substring(2);
        if (s === 'RD-' || s === 'RD' || s === 'R-' || s === 'R') return '';
        return s;
    }

    /**
     * Aplica o restaura el prefijo según tipo. Remito → R-, Remito de Devolución → RD- (inmutable).
     */
    applyPrefijoNComprobante(valor, tipoUi) {
        const prefijo = this.getPrefijoNComprobante(tipoUi);
        const cuerpo = this.stripPrefijosRemito(valor, prefijo);
        if (!prefijo) {
            return cuerpo;
        }
        return prefijo + cuerpo;
    }

    handleNComprobanteChange(event) {
        this.prefillNComprobante = event.detail?.value ?? event.target?.value ?? '';
    }

    handleNComprobanteCuerpoInput(event) {
        this.nComprobanteCuerpo = event.target?.value ?? '';
        this.prefillNComprobante = this.prefijoNComprobanteVisible + this.nComprobanteCuerpo;
    }

    /** Solo dígitos, para comparar CUITs con o sin guiones. */
    normalizeCuit(cuit) {
        if (cuit == null || cuit === '') return '';
        return String(cuit).replace(/\D/g, '');
    }

    /**
     * Si CUIT destinatario = CUIT originante (11 dígitos), tilda Venta Interna automáticamente.
     * @returns {Boolean} true si quedó como venta interna
     */
    syncVentaInternaPorCuit(cuitDestinatario) {
        const orig = this.normalizeCuit(this.cuitOriginario);
        const dest = this.normalizeCuit(cuitDestinatario);
        const isInterna = orig.length === 11 && dest.length === 11 && orig === dest;

        this.ventaInternaChecked = isInterna;
        this.prefillVentaInterna = isInterna;

        if (isInterna) {
            this.prefillCuitDestinatario = dest;
            this.razonSocialDestinatario = this.originanteName || this.razonSocialDestinatario;
            this.cuitDestinatario = dest;
            this.destinatario = this.originante;
            this.valueRolDestinatario = 'Productor';
        }
        return isInterna;
    }

    DestinatarioSelect(event){
        const newCuit = this.normalizeCuit(event.target.value) || event.target.value;
        this.DestinatarioSelected = newCuit;

        const cuitField = this.template.querySelector(
            'lightning-input-field[field-name="CUIT_Destinatario__c"]'
        );
        if (cuitField && cuitField.value !== newCuit) {
            cuitField.value = newCuit;
        }

        if (this.syncVentaInternaPorCuit(newCuit)) {
            return;
        }

        if (/^[0-9]{11}$/.test(this.normalizeCuit(newCuit))) {
            this.resolveRazonSocial(newCuit);
        } else {
            this.razonSocialDestinatario = null;
        }
    }

    // Resolución del nombre del destinatario: primero busca en SF, luego (pendiente) consulta ARCA.
    resolveRazonSocial(cuit) {
        if (!cuit) return;
        getCuentaDestinatarioPorCuit({ cuit: cuit, variedadId: this.variedad || null })
            .then(data => {
                if (data?.name) {
                    this.razonSocialDestinatario = data.name;
                }
                if (data?.id) {
                    this.destinatario = data.id;
                }
                if (data?.rol && !this.ventaInternaChecked) {
                    this.valueRolDestinatario = data.rol;
                }
                if (!data?.name) {
                    return getRazonSocialPorCuit({ cuit: cuit, variedadId: this.variedad || null }).then(name => {
                        this.razonSocialDestinatario = name || null;
                    });
                }
                return null;
            })
            .catch(err => {
                console.warn('No se pudo resolver Razón Social para CUIT', cuit, err);
                this.razonSocialDestinatario = null;
            });
    }

    applyAutoventaDestinatario() {
        const cuitOrig = this.normalizeCuit(this.cuitOriginario) || this.cuitOriginario;
        if (!cuitOrig) {
            return;
        }
        this.DestinatarioSelected = cuitOrig;
        this.prefillCuitDestinatario = cuitOrig;
        this.cuitDestinatario = cuitOrig;
        this.destinatario = this.originante;
        this.valueRolDestinatario = 'Productor';
        this.razonSocialDestinatario = this.originanteName || null;

        const cuitField = this.template.querySelector(
            'lightning-input-field[field-name="CUIT_Destinatario__c"]'
        );
        if (cuitField) {
            cuitField.value = cuitOrig;
        }
    }

    handleVentaInternaChange(event) {
        const checked = event.target.checked;
        this.ventaInternaChecked = checked;
        this.prefillVentaInterna = checked;

        if (checked) {
            this.applyAutoventaDestinatario();
        } else {
            this.DestinatarioSelected = null;
            this.prefillCuitDestinatario = null;
            this.cuitDestinatario = null;
            this.destinatario = null;
            this.valueRolDestinatario = null;
            this.razonSocialDestinatario = null;
        }
    }

    handleSelect(event) {
        this.isLoading = true;
        var name = event.target.name;
        var recordId = event.detail.recordId;
        if(recordId != null){
            getCuenta({ recordId: recordId})
            .then(response => {
                if(name === 'originante') {
                    this.originante = recordId;
                    this.originanteName = response.Name;
                    this.valueRolOriginante = response.Type;
                    this.cuitOriginario = response.N_CUIT__c;
                } else {
                    this.destinatario = recordId;
                    this.valueRolDestinatario = response.Type;
                    this.cuitDestinatario = response.N_CUIT__c;
                    this.razonSocialDestinatario = response.Name;
                }
                this.isLoading = false;
            })
            .catch(error => {
                console.log(error);
                this.isLoading = false;
            })
        } else {
            if(name === 'originante') {
                this.originante = null;
                this.cuitOriginario = null;
                this.originanteName = null;
            } else {
                this.destinatario = null;
                this.cuitDestinatario = null;
                this.razonSocialDestinatario = null;
            }
            this.isLoading = false;
        }
    }

    clearVariedadSelection() {
        this.variedad = null;
        this.variedadDisplayValue = '';
        this.variedadDropdownOpen = false;
        this.filteredVariedadOptions = [];
        this.variedadSearchLoading = false;
        if (this._variedadSearchTimeout) {
            clearTimeout(this._variedadSearchTimeout);
            this._variedadSearchTimeout = null;
        }
    }

    clearCampanaSelection() {
        this.campanaAgricolaId = null;
        this.campanaDisplayValue = '';
        this.campanaDropdownOpen = false;
        this.clearVariedadSelection();
        this.updateFilteredOptions('');
    }

    handleVariedadSelect(event) {
        event.preventDefault();
        const selectedValue = event.currentTarget.dataset.value;
        const selectedOption = this.filteredVariedadOptions.find(opt => opt.value === selectedValue);

        if (selectedOption) {
            this.variedadDisplayValue = selectedOption.label;
            this.variedad = this.normalizeSalesforceId(selectedValue);
            this.variedadDropdownOpen = false;
            this.filteredVariedadOptions = [];
            const cuitDest = this.normalizeCuit(this.cuitDestinatario || this.DestinatarioSelected);
            if (cuitDest && /^[0-9]{11}$/.test(cuitDest)) {
                this.resolveRazonSocial(cuitDest);
            }
        }
    }

    get variedadComboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.variedadDropdownOpen ? 'slds-is-open' : ''
        }`;
    }

    get hasFilteredVariedadOptions() {
        return this.filteredVariedadOptions && this.filteredVariedadOptions.length > 0;
    }

    get variedadDropdownEmptyMessage() {
        if (this.variedadSearchLoading) {
            return 'Cargando variedades...';
        }
        return 'No se encontraron variedades';
    }

    mapVariedadSearchResults(data) {
        return (data || []).map(item => ({
            label: item.title,
            value: item.id,
            itemClass: item.id === this.variedad
                ? 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small slds-is-selected'
                : 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
        }));
    }

    scheduleVariedadSearch(searchTerm) {
        if (this._variedadSearchTimeout) {
            clearTimeout(this._variedadSearchTimeout);
        }
        if (!this.campanaAgricolaId) {
            this.filteredVariedadOptions = [];
            this.variedadSearchLoading = false;
            return;
        }

        const term = (searchTerm || '').trim();
        const delay = term ? 300 : 0;

        this.variedadSearchLoading = true;
        this._variedadSearchTimeout = setTimeout(() => {
            this._variedadSearchTimeout = null;
            this.searchVariedades(term);
        }, delay);
    }

    async searchVariedades(searchTerm) {
        if (!this.campanaAgricolaId) {
            this.filteredVariedadOptions = [];
            this.variedadSearchLoading = false;
            return;
        }

        const term = (searchTerm || '').trim();
        const requestId = ++this._variedadSearchSeq;
        this.variedadSearchLoading = true;

        try {
            const selectedIds = this.variedad ? [this.variedad] : [];
            const data = await getVariedad({
                searchTerm: term,
                selectedIds,
                campanaAgricolaId: this.campanaAgricolaId
            });
            if (requestId !== this._variedadSearchSeq) {
                return;
            }
            this.filteredVariedadOptions = this.mapVariedadSearchResults(data);
        } catch (error) {
            if (requestId !== this._variedadSearchSeq) {
                return;
            }
            console.error('Error buscando variedades:', error);
            this.filteredVariedadOptions = [];
        } finally {
            if (requestId === this._variedadSearchSeq) {
                this.variedadSearchLoading = false;
                if (this.variedadDropdownOpen) {
                }
            }
        }
    }

    handleVariedadInput(event) {
        const searchTerm = event.target.value;
        this.variedadDisplayValue = searchTerm;
        this.variedad = null;
        this.variedadDropdownOpen = true;
        this.scheduleVariedadSearch(searchTerm);
    }

    handleVariedadFocus() {
        if (!this.campanaAgricolaId) {
            return;
        }
        this.variedadDropdownOpen = true;
        this.scheduleVariedadSearch(this.variedadDisplayValue);
    }

    handleVariedadBlur() {
        setTimeout(() => {
            const active = this.template.activeElement;
            const container = this.template.querySelector('[data-id="variedad-combobox"]')
                ?.closest('.slds-combobox_container');
            if (container && active && container.contains(active)) {
                return;
            }
            this.variedadDropdownOpen = false;
        }, 200);
    }

    handleVariedadDropdownMouseDown(event) {
        event.preventDefault();
    }

    get campanaComboboxClass() {
        return `slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click ${
            this.campanaDropdownOpen ? 'slds-is-open' : ''
        }`;
    }

    get hasFilteredOptions() {
        return this.filteredCampanaOptions && this.filteredCampanaOptions.length > 0;
    }

    @wire(getCampanasAgricolasParaLookup, { searchTerm: '' })
    wiredCampanas({ data, error }) {
        if (data) {
            this.allCampanaOptions = data.map(item => ({
                label: item.title,
                value: item.id,
                itemClass: 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
            }));
            this.updateFilteredOptions('');
        } else if (error) {
            console.error('Error cargando campañas:', error);
            this.allCampanaOptions = [];
            this.filteredCampanaOptions = [];
        }
    }

    updateFilteredOptions(searchTerm) {
        const term = searchTerm.toLowerCase();
        if (!term) {
            this.filteredCampanaOptions = this.allCampanaOptions.map(opt => ({
                ...opt,
                itemClass: opt.value === this.campanaAgricolaId 
                    ? 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small slds-is-selected'
                    : 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
            }));
        } else {
            this.filteredCampanaOptions = this.allCampanaOptions
                .filter(opt => opt.label.toLowerCase().includes(term))
                .map(opt => ({
                    ...opt,
                    itemClass: opt.value === this.campanaAgricolaId 
                        ? 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small slds-is-selected'
                        : 'slds-media slds-listbox__option slds-listbox__option_plain slds-media_small'
                }));
        }
    }

    handleCampanaInput(event) {
        const searchTerm = event.target.value;
        this.campanaDisplayValue = searchTerm;
        this.campanaDropdownOpen = true;

        const selectedOption = this.campanaAgricolaId
            ? this.allCampanaOptions.find((opt) => opt.value === this.campanaAgricolaId)
            : null;

        if (!searchTerm.trim()) {
            this.clearCampanaSelection();
            return;
        }

        if (selectedOption && searchTerm !== selectedOption.label) {
            this.campanaAgricolaId = null;
            this.clearVariedadSelection();
        }

        this.updateFilteredOptions(searchTerm);
    }

    handleCampanaFocus() {
        this.campanaDropdownOpen = true;
        this.updateFilteredOptions(this.campanaDisplayValue);
    }

    handleCampanaBlur() {
        setTimeout(() => {
            const active = this.template.activeElement;
            const container = this.template.querySelector('[data-id="campana-combobox"]')
                ?.closest('.slds-combobox_container');
            if (container && active && container.contains(active)) {
                return;
            }

            this.campanaDropdownOpen = false;
            if (!this.campanaDisplayValue.trim()) {
                this.clearCampanaSelection();
                return;
            }

            if (!this.campanaAgricolaId) {
                const exactMatch = this.allCampanaOptions.find(
                    (opt) => opt.label === this.campanaDisplayValue
                );
                if (exactMatch) {
                    this.handleCampanaSelect({
                        preventDefault: () => {},
                        currentTarget: { dataset: { value: exactMatch.value } }
                    });
                }
            }
        }, 200);
    }

    handleCampanaDropdownMouseDown(event) {
        event.preventDefault();
    }

    handleCampanaSelect(event) {
        event.preventDefault();
        const selectedValue = event.currentTarget.dataset.value;
        const selectedOption = this.allCampanaOptions.find(opt => opt.value === selectedValue);
        
        if (selectedOption) {
            this.campanaDisplayValue = selectedOption.label;
            const newCampanaId = this.normalizeSalesforceId(selectedValue);

            if (newCampanaId !== this.campanaAgricolaId) {
                this.clearVariedadSelection();
            }
            this.campanaAgricolaId = newCampanaId;
            this.campanaDropdownOpen = false;
            this.updateFilteredOptions('');
            this.scheduleVariedadSearch('');
        }
    }

    handleFechaChange(event) {
        this.fechaComprobante = event.detail?.value ?? event.target?.value ?? '';
    }

    /** Convierte fecha de SF/prefill a YYYY-MM-DD para lightning-input type="date". */
    toInputDateString(raw) {
        if (raw == null || raw === '') return '';
        if (typeof raw === 'string') {
            if (/^\d{4}-\d{2}-\d{2}/.test(raw)) return raw.substring(0, 10);
            const parts = raw.split(/[/-]/);
            if (parts.length === 3) {
                const y = parts[2].length === 4 ? parts[2] : parts[0];
                const m = parts[1].padStart(2, '0');
                const d = (parts[2].length === 4 ? parts[0] : parts[2]).padStart(2, '0');
                return `${y}-${m}-${d}`;
            }
        }
        try {
            const d = new Date(raw);
            if (!isNaN(d.getTime())) return d.toISOString().substring(0, 10);
        } catch (e) { /* ignore */ }
        return '';
    }

    @api
    parentSave(){
        const button = this.template.querySelector('[data-id="save-button"]');
        button.click();
    }

    handleClick(event) {
        let comboboxes = this.template.querySelectorAll("lightning-combobox");
        comboboxes.forEach(combobox => {
            combobox.reportValidity();
        });
        let lookups = this.template.querySelectorAll("lightning-record-picker");
        lookups.forEach(lookup => {
            lookup.reportValidity();
        });
    }

    handleSubmit(event) {
        const cuitField = this.template.querySelector('lightning-input-field[field-name="CUIT_Destinatario__c"]');
        const cuitValue = cuitField ? cuitField.value : '';

        if (this.isModal && !/^[0-9]{11}$/.test(this.DestinatarioSelected || cuitValue || '')) {
            event.preventDefault();
            const toastEvent = new ShowToastEvent({
                message: 'El CUIT debe estar compuesto por solo números y debe contener 11 dígitos.',
                variant: 'error',
                title: 'Error'
            });
            this.dispatchEvent(toastEvent);
            return;
        }

        if (this.requierePrefijoNComprobante) {
            const cuerpo = (this.nComprobanteCuerpo || '').trim();
            if (!cuerpo) {
                event.preventDefault();
                this.dispatchEvent(new ShowToastEvent({
                    message: `Completá el número de comprobante después de ${this.prefijoNComprobanteVisible}`,
                    variant: 'error',
                    title: 'Error'
                }));
                return;
            }
        }

        // Validar Tipo de Comprobante
        if (!this.tipoComprobanteValue) {
            event.preventDefault();
            this.dispatchEvent(new ShowToastEvent({
                message: 'Debe seleccionar Tipo de Comprobante.',
                variant: 'error',
                title: 'Error'
            }));
            return;
        }

        // Validar Fecha Comprobante (lightning-input, fuera del record-edit-form field bag).
        if (!this.fechaComprobante) {
            event.preventDefault();
            this.dispatchEvent(new ShowToastEvent({
                message: 'Debe completar Fecha Comprobante.',
                variant: 'error',
                title: 'Error'
            }));
            return;
        }

        const fields = event.detail.fields || {};
        const kilos = parseFloat(fields.Cantidad_de_Bolsas__c);
        if (isNaN(kilos) ) {
            event.preventDefault();
            this.dispatchEvent(new ShowToastEvent({
                message: 'Ingresá Kilos Totales.',
                variant: 'error',
                title: 'Error'
            }));
            return;
        }
        
        this.isLoading = true;
        event.preventDefault();
        let comboboxes = this.template.querySelectorAll("lightning-combobox");
        let continuar = true;
        comboboxes.forEach(combobox => {
            if(continuar){
                continuar = combobox.checkValidity();
            }
        });
        let lookups = this.template.querySelectorAll("lightning-record-picker");
        lookups.forEach(lookup => {
            if(continuar){
                continuar = lookup.checkValidity();
            }
        });

        if(continuar) {
            let venta = fields;
            venta.Rol_Originante__c = this.valueRolOriginante;
            venta.Rol_Destinatario__c = this.ventaInternaChecked ? 'Productor' : this.valueRolDestinatario;
            venta.Categoria__c = this.categoria;
            venta.Originante__c = this.originante;
            venta.Destinatario__c = this.destinatario;
            venta.CUIT_Originante__c = this.cuitOriginario;

            venta.Fecha_de_Facturacion__c = this.fechaComprobante;

            // Externo = lo que eligió el usuario; interno = FC/NC para reproceso.
            const tcInput = this.tipoComprobanteValue;
            venta.Tipo_Comprobante_Externo__c = this.mapTipoComprobanteToExterno(tcInput);
            venta.Tipo_de_Comprobante__c = TIPO_COMPROBANTE_MAP[tcInput] || tcInput;

            // Razón Social Destinatario (si la conocemos en el front, la pasamos como hint).
            if (this.razonSocialDestinatario) {
                venta.Razon_Social_Destinatario__c = this.razonSocialDestinatario;
            }

            if(!this.isModal) {
                venta.CUIT_Destinatario__c = this.cuitDestinatario;
            } else {
                venta.CUIT_Destinatario__c = this.DestinatarioSelected || venta.CUIT_Destinatario__c;
            }

            if (this.requierePrefijoNComprobante) {
                venta.N_de_Comprobante__c = this.prefijoNComprobanteVisible + (this.nComprobanteCuerpo || '');
            } else {
                venta.N_de_Comprobante__c = venta.N_de_Comprobante__c || this.prefillNComprobante;
            }

            venta.Venta_Interna__c = this.ventaInternaChecked;
            venta.Campana_Agricola__c = this.campanaAgricolaId;

            if (!this.campanaAgricolaId) {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    message: 'Debe seleccionar Campaña Agrícola antes de Variedad.',
                    variant: 'error',
                    title: 'Error'
                }));
                return;
            }

            const variedadId = this.variedad;

            if (!variedadId) {
                this.isLoading = false;
                this.dispatchEvent(new ShowToastEvent({
                    message: 'Debe seleccionar Variedad (después de elegir Campaña Agrícola).',
                    variant: 'error',
                    title: 'Error'
                }));
                return;
            }
            
            saveVentaInformada({
                venta: venta,
                variedadId: variedadId,
                originanteAccountId: this._originanteAccountId || null
            })
            .then(result => {
                const ev = new ShowToastEvent({
                    message: 'Redirigiendo...',
                    variant: 'success',
                    title: 'Venta Informada creada exitosamente'
                });
                this.dispatchEvent(ev);

                this.resetFields();

                if(this.isModal){
                    const saveEvent = new CustomEvent("save", {});
                    this.dispatchEvent(saveEvent);

                    this[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result,
                            objectApiName: 'Ventas_Informadas__c',
                            actionName: 'view',
                        },
                    })
                } else {
                    // En core: volver a la list view de Ventas Informadas (Recientes).
                    this[NavigationMixin.Navigate]({
                        type: 'standard__objectPage',
                        attributes: {
                            objectApiName: 'Ventas_Informadas__c',
                            actionName: 'list',
                        },
                        state: {
                            filterName: 'Recent'
                        }
                    })
                }
            })
            .catch(error => {
                console.log(error);
                const ev = new ShowToastEvent({
                    message: error?.body?.message || 'Error al guardar la Venta Informada',
                    variant: 'error',
                    title: 'Ha ocurrido un error'
                });
                this.dispatchEvent(ev);
            })
            .finally(() => {
                this.isLoading = false;
            })
        } else {
            this.isLoading = false;
        }
    }

    renderedCallback() {
        this.applyFechaInputStyles();
    }

    /**
     * Oculta el hint "Utilizar formato..." y corrige el ícono calendario.
     * El tema del portal usa .slds-input-has-icon .slds-input__icon con top: 50% /
     * margin-top: -.4375rem que desalinea; se anulan (mismo criterio que en crearVentaInformadaLWC.css).
     */
    applyFechaInputStyles() {
        const dateInput = this.template.querySelector('lightning-input.fecha-input');
        if (!dateInput?.shadowRoot) return;

        const existing = dateInput.shadowRoot.querySelector('style[data-fecha-fix]');
        if (existing?.getAttribute('data-fecha-fix') === '3') return;
        if (existing) existing.remove();

        const style = document.createElement('style');
        style.setAttribute('data-fecha-fix', '3');
        style.textContent = `
            .slds-form-element__help,
            .slds-form-element__helper,
            .slds-form-element__static {
                display: none !important;
            }
            .slds-form-element__control {
                position: relative;
            }
            .slds-input_faux,
            input.slds-input {
                min-height: 2.25rem;
                height: 2.25rem;
                line-height: 2.25rem;
                box-sizing: border-box;
            }
            .slds-input-has-icon .slds-input__icon,
            .slds-input-has-icon .slds-input__icon_right,
            .slds-input-has-icon .slds-button_icon.slds-input__icon {
                top: unset !important;
                margin-top: 0 !important;
                bottom: auto !important;
                transform: none !important;
            }
        `;
        dateInput.shadowRoot.appendChild(style);
    }

    resetFields(){
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        inputFields.forEach( field => {
            field.reset();
        });
        const lookupFields = this.template.querySelectorAll('lightning-record-picker');
        lookupFields.forEach( lookup => {
            lookup.clearSelection();
        });

        this.categoria = null;
        this.valueRolDestinatario = null;
        this.valueRolOriginante = null;
        this.cuitDestinatario = null;
        this.cuitOriginario = null;
        this.clearVariedadSelection();
        this.clearCampanaSelection();
        this.originante = null;
        this.destinatario = null;
        this.razonSocialDestinatario = null;
        this.tipoComprobanteValue = null;
        this.prefillNComprobante = null;
        this.nComprobanteCuerpo = '';
        this.DestinatarioSelected = null;
        this.ventaInternaChecked = false;
        this.fechaComprobante = null;
        this.originanteName = null;

        this.isLoading = false;
    }
}