import { LightningElement, track } from 'lwc';
import getDataApex from '@salesforce/apex/CrearCompraController.getData';
import finalizarCompra from '@salesforce/apex/CrearCompraController.finalizarCompra';
import anular from '@salesforce/apex/CrearCompraController.anular';
import getSemilleroData from '@salesforce/apex/CrearCompraController.getSemilleroData';
import getProductsData from '@salesforce/apex/CrearCompraController.getProductsData';
import canFinish from '@salesforce/apex/CrearVentaController.canFinish';
import getUserAccountData from '@salesforce/apex/CrearCompraController.getUserAccountData';
import updateTipoPago from '@salesforce/apex/CrearCompraController.updateTipoPago';
import saveItem from '@salesforce/apex/CrearCompraController.saveItem';
import verificarExpedienteEnHTDisponible from '@salesforce/apex/ExpedientesController.verificarExpedienteEnHTDisponible';
import { CompraVentaMixin } from 'c/utilsHTNew';
import { NavigationMixin } from 'lightning/navigation';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';
import basePath from '@salesforce/community/basePath';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import {
    isHtFuturaPromoScreen,
    qualifiesForHtFuturaPromoAggregate,
    resolveBaseListPrice,
    resolveHtFuturaPromoUiState,
    scheduleHtFuturaPromoEval,
    cancelHtFuturaPromoEval,
    sumHtFuturaPromoEligibleQuantity,
    MSG_PROMO_ACTIVA
} from 'c/htCondicionPromocionalGdm';
import {
    trackGa4Event,
    resolveSemilleroLabel,
    buildHtCompraConfirmadaParams
} from 'c/portalGa4Events';

/** Temporal: true = no se muestra el modal de expediente negativo en HT disponible ni se detiene finalizar. */
const OMITIR_MODAL_ALERTA_EXPEDIENTE_NEGATIVO = true;

/** Mapeo variedad → tecnología de licencia (CesionPPH.getMapBiotecnologias). */
const MAP_TECNOLOGIAS_LICENCIA = {
    'RR1': 'RR',
    'RR2 - BT': 'RR',
    'BGRR': 'RR',
    'Convencional': 'RR',
    'Enlist E3': 'Enlist',
    'Conkesta E3': 'Enlist'
};

export default class CrearCompra2 extends CompraVentaMixin(LightningElement) {
    showFacturaRegaliaEnlistMsg;
    iconCebadaUrl = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;
    iconSojaHTUrl = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
    iconTrigoHTUrl = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;
    iconCondicionesHTUrl = `${resourcePortal}/resourcePortal/images/icon-condiciones.svg`;
    productor;
    showResumen = false;
    legacyResumenMode = false;
    aceptaTerminos = false;
    semilleroIcono = false;
    showFileUploadModal = false;
    isLoading = false;   // ✅ Nuevo estado para spinner
    showFinanciamientoColumn = false;
    isModalOpen = false;
    @track DataCompra;
    /** success | pending-payment | pending-licencia | pending-origen | duplicate | expediente | promo | anular | vigencia */
    resultModal = null;
    haveLicence;
    haveOrigenLegal;
    Blanqueo;
    esFutura = false;
    Futura;
    tipoCompraSeleccionado = null;
    cultivoSeleccionadoId = null;
    marcaSearch = '';
    @track variedadCantidades = {};
    @track _lineasListasFlag = false;
    @track guardandoLineas = false;
    @track finalizandoOperacion = false;

    tipoPago = null;          // 'Contado' | 'Financiado'
    showTipoPagoSheet = false;
    selectedTipoPago = 'Contado';
    _payModalScrollLocked = false;
    _payModalScrollY = 0;
    pendingFinalizar = false; // para reintentar
    pendingFinalizarPorExpediente = false;
    shouldMarkRevisarCompra = false;

    htFuturaPromoMessage = null;
    htFuturaPromoVariant = 'success';
    htFuturaPromoPreviouslyQualified = false;
    htFuturaPromoCelebrationShown = false;

    get bloqueCompraClass() {
        return this.legacyResumenMode ? 'oculto' : 'visible';
    }

    get bloqueResumenClass() {
        return this.legacyResumenMode ? 'visible' : 'oculto';
    }

    /** Footer legado solo al editar una compra existente. */
    get showLegacyFooter() {
        return this.legacyResumenMode;
    }

    get headerClass() {
        return this.showFinanciamientoColumn
            ? 'tabla-header con-financiamiento'
            : 'tabla-header sin-financiamiento';
    }
    get cultivoNombre() {
        const seleccionado = (this.cultivos || []).find(c => c.value === this.cultivo);
        return seleccionado ? seleccionado.label : '';
    }

    async connectedCallback() {
        document.documentElement.classList.add('se-inner', 'se-inner-wizard');
        document.body.classList.add('se-inner', 'se-inner-wizard');
        try {
            const data = await getUserAccountData();
            this.productor = {
                Name: data?.productorNombre,
                N_CUIT__c: data?.cuit
            };

            if (this.pageRecordId) {
                this.legacyResumenMode = true;
                this.step = 3;
                this.showResumen = true;
                this.isLoading = true;

                try {
                    const compraData = await getDataApex({
                        compraId: this.pageRecordId,
                        isFirstLoad: true
                    });
                    this.DataCompra = compraData;
                    this.setData(compraData);
                    await this.finish();
                    await this.validarExpedienteDisponible(false);
                    setTimeout(() => {
                        this.syncPromoQualificationState();
                        this.refreshAllLinePromoPrices();
                        this.notifyLineSaveStateChanged();
                    }, 250);
                    if (typeof window !== 'undefined') {
                        const popupKey = 'htPopup_' + this.pageRecordId;
                        const popup = window.sessionStorage.getItem(popupKey);
                        if (popup === 'licencia') {
                            this.resultModal = 'pending-licencia';
                        } else if (popup === 'origen') {
                            this.resultModal = 'pending-origen';
                        }
                        if (popup) {
                            window.sessionStorage.removeItem(popupKey);
                        }
                    }
                } catch (e) {
                    // eslint-disable-next-line no-console
                    console.error('Error cargando compra desde Apex', e);
                } finally {
                    this.isLoading = false;
                }
            }
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('Error obteniendo la cuenta del usuario:', error);
        }
    }

    handleOpenModal(event) {
        console.log('Evento recibido del hijo:', event.detail);
        this.isModalOpen = true;
    }

    openModal(event) {
        console.log('Evento openmodal recibido del hijo:', event.detail);
        this.isModalOpen = true; // 🔹 este abre el modal del padre
    }

    async closeModal() {
        const debeContinuarFinalizar =
            this.resultModal === 'expediente' && this.pendingFinalizarPorExpediente;

        this.isModalOpen = false;
        this.resultModal = null;
        this.currentModal = null;

        if (debeContinuarFinalizar) {
            this.shouldMarkRevisarCompra = true;
            this.pendingFinalizarPorExpediente = false;
            await this.finalizar({ mostrarModalExpediente: false });
        }
    }

    showAnularConfirm() {
        this.resultModal = 'anular';
    }

    // ====== DATA ======
    getData(isFirstLoad) {
        return getDataApex({ compraId: this.recordId, isFirstLoad });
    }

    handleSemilleroIconReady(event) {
        console.log('que valor llegó a semilleroIcono', event.detail);
        this.semilleroIcono = event.detail;
        if (event.detail == null) {
            this.step = 3;
        }
    }

    setData(data) {
        const lineas = data?.record?.Lineas_de_Compra_HT__r || [];
        this.setDataAndItems(data, lineas);

        if (!this.tipoCompraSeleccionado && lineas.length > 0 && data.products) {
            const ultimaLinea = lineas[lineas.length - 1];
            const pbe = data.products.find(p => p.Id === ultimaLinea.Id_Producto_de_Lista_de_Precio__c);
            if (pbe?.Product2?.Tipo_de_Compra__c) {
                this.tipoCompraSeleccionado = pbe.Product2.Tipo_de_Compra__c;
                this.Futura = this.tipoCompraSeleccionado === 'Futura';
            }
        }
        if (data?.record?.Estado__c === 'Caducado') {
            this.resultModal = 'vigencia';
            this.currentModal = null;
        }
    }

    get pageRecordId() {
        if (typeof window === 'undefined') return null;
        try {
            const href = window.location.href;
            const url = new URL(href);
            let recordIdValue = url.searchParams.get('recordId');

            if (!recordIdValue && href.includes('compra-ht/') && !href.includes('compra-ht/Compra_HT__c/')) {
                recordIdValue = href.split('compra-ht/')[1]?.split('/')[0] || null;
            }

            this.recordId = recordIdValue || null;
            return this.recordId;
        } catch (e) {
            this.recordId = null;
            return null;
        }
    }

    get parametroCultivo() {
        return new URL(window.location.href).searchParams.get("cultivoId");
    }

    get community() {
        return 'Compra';
    }

    // ====== LÍNEAS ======
    addRow(event) {
        this.addRowInternal(Array.from(this.template.querySelectorAll('c-crear-linea-compra')));
    }

    saveRow(event) {
        event.target.save(this.recordId, this.cultivo);
    }

    get mostrarContinuar() {
        if (!this.puedeEditar || this.guardandoLineas) {
            return false;
        }
        // eslint-disable-next-line no-unused-expressions
        this._lineasListasFlag;
        return this.tieneLineasPendientesDeGuardar;
    }

    get mostrarFinalizarCompra() {
        return this.puedeFinalizar && !this.guardandoLineas && !this.tieneLineasPendientesDeGuardar;
    }

    get tieneLineasPendientesDeGuardar() {
        if (this.guardandoLineas) {
            return true;
        }
        const children = this.template.querySelectorAll('c-crear-linea-compra-new');
        for (const child of children) {
            const rec = child.record;
            if (!rec?.Producto__c || !rec?.Cantidad__c) continue;
            if (!rec.Id) return true;
            if (child.hasUnsavedChanges?.()) return true;
        }
        return false;
    }

    async continuar() {
        this.guardandoLineas = true;
        try {
            this.refreshAllLinePromoPrices();
            await this.saveAllPendingLines();
            await new Promise(resolve => setTimeout(resolve, 200));
            this.refreshAllLinePromoPrices();
            this.notifyLineSaveStateChanged();
        } catch (e) {
            this.onError('Error al guardar las líneas: ' + (e.message || e));
        } finally {
            this.guardandoLineas = false;
        }
    }

    notifyLineSaveStateChanged() {
        this._lineasListasFlag = !this._lineasListasFlag;
    }

    handleCantidadChange() {
        this._lineasListasFlag = !this._lineasListasFlag;
        Promise.resolve().then(() => {
            this.refreshAllLinePromoPrices();
            this.notifyLineSaveStateChanged();
        });
    }

    computeHtFuturaPromoCantidadTotal() {
        if (!isHtFuturaPromoScreen({ semilleroId: this.semillero, cultivoName: this.cultivoNombre })) {
            return 0;
        }
        return sumHtFuturaPromoEligibleQuantity(this.collectPromoLineData(), {
            semilleroId: this.semillero,
            cultivoName: this.cultivoNombre
        });
    }

    refreshAllLinePromoPrices() {
        if (!this.legacyResumenMode && this.step < 5) {
            return;
        }
        const total = this.computeHtFuturaPromoCantidadTotal();
        this.template.querySelectorAll('c-crear-linea-compra-new').forEach(line => {
            line.refreshPromoPrice?.(total);
        });
    }

    get hayLineasListas() {
        const children = this.template.querySelectorAll('c-crear-linea-compra-new');
        for (const child of children) {
            const rec = child.record;
            if (rec && rec.Producto__c && rec.Cantidad__c > 0) return true;
        }
        return false;
    }

    get finalizarDeshabilitado() {
        return this.isLoading || this.finalizandoOperacion;
    }

    async saveAllPendingLines() {
        this._savingAllPending = true;
        try {
            const children = Array.from(this.template.querySelectorAll('c-crear-linea-compra-new'));
            for (const child of children) {
                const rec = child.record;
                if (!rec?.Producto__c || !rec?.Cantidad__c) {
                    continue;
                }
                if (!rec.Id || child.hasUnsavedChanges?.()) {
                    await child.save(this.recordId, this.cultivo);
                    this.assignSavedLineToChild(child);
                }
            }
            this.finalizePendingBatchSave();
        } finally {
            this._savingAllPending = false;
        }
    }

    async finalizar(options = {}) {
        const { mostrarModalExpediente = true } = options;
        const marcarRevisarCompra = this.shouldMarkRevisarCompra === true;
        this.shouldMarkRevisarCompra = false;
        this.finalizandoOperacion = true;

        try {
            try {
                this.isLoading = true;
                if (this.legacyResumenMode) {
                    await this.saveAllPendingLines();
                } else {
                    await this.persistSelectedVariedades();
                }
            } catch (e) {
                this.isLoading = false;
                return this.onError('Error al guardar las líneas: ' + (e.message || e));
            }
            this.isLoading = false;

            // ===== Gate Tipo de Pago =====
        console.log('[CrearCompra] finalizar() -> tipo de pago: ', this.tipoPago);
        console.log('[CrearCompra] finalizar() -> tipo de pago:',this.requiresTipoPago());
        if (this.requiresTipoPago() && !this.tipoPago) {
            this.pendingFinalizar = true;
            this.selectedTipoPago = 'Contado';
            this.showTipoPagoSheet = true;
            return;
        }

        if (this.isChildrenLoading) {
            return this.onError('Espere a que se termine de guardar la línea');
        }

        // Traemos los datos actualizados de la compra antes de validar
        const compraData = await getDataApex({
            compraId: this.recordId,
            isFirstLoad: true
        });
        this.DataCompra = compraData;

        const bloquearPorExpediente = await this.validarExpedienteDisponible(mostrarModalExpediente);
        if (bloquearPorExpediente) {
            this.pendingFinalizarPorExpediente = true;
            return;
        }
        this.pendingFinalizarPorExpediente = false;

        // Ejecuta canFinish y setea flags de licencia / origen legal
                const guardar = await this.finish();
                console.log(guardar);

                if (guardar === false) {
        
                        // =========================
                        // CASO 1: FALTA LICENCIA
                        // =========================
                        // Cuando NO hay licencia aprobada → mostrar pop de licencia
                        //   “Tu compra/venta de HT queda pendiente porque el CUIT no cuenta con la licencia…”
                        if (this.haveLicence === false) {
                            await this.requestWrap(async () => {
                                const data = await finalizarCompra({
                                    compraId: this.recordId,
                                    checkDuplicates: this.recordId != this.lastDuplicateCheckId,
                                    origen: this.haveOrigenLegal,
                                    blanqueo: this.Blanqueo === true,
                                    marcarRevisarCompra
                                });
                
                                if (data.duplicate) {
                                    return this.notifyDuplicate();
                                }
                
                                // Refresca la venta y las líneas en pantalla
                                this.setData(data);
                                this.DataCompra = data;
                                this.trackHtCompraConfirmada(data);
                                this.resultModal = 'pending-licencia';
                                window.sessionStorage.setItem('htPopup_' + this.recordId, 'licencia');
                            });
                
                            return;
                        }
                
                        // ==========================================
                        // CASO 2: TIENE LICENCIA PERO FALTA ORIGEN
                        // ==========================================
                        // Cuando hay licencia pero NO hay origen legal → pop de “no encontramos compras o tenencia…”
                        if (this.haveOrigenLegal === false && this.haveLicence === true) {
                            await this.requestWrap(async () => {
                                const data = await finalizarCompra({
                                    compraId: this.recordId,
                                    checkDuplicates: this.recordId != this.lastDuplicateCheckId,
                                    origen: this.haveOrigenLegal,
                                    blanqueo: this.Blanqueo === true,
                                    marcarRevisarCompra
                                });
                
                                if (data.duplicate) {
                                    return this.notifyDuplicate();
                                }
                
                                // Refresca la venta y las líneas en pantalla
                                this.setData(data);
                                this.DataCompra = data;
                                this.trackHtCompraConfirmada(data);
                                this.resultModal = 'pending-origen';
                                window.sessionStorage.setItem('htPopup_' + this.recordId, 'origen');
                            });
                
                            return;
                        }
                         // =========================
                        // CASO 4: FALTA LICENCIA Y ORIGEN LEGAL 
                        // =========================
                        if ( this.haveLicence == false && this.haveOrigenLegal == false) {
                             await this.requestWrap(async () => {
                                const data = await finalizarCompra({
                                    compraId: this.recordId,
                                    checkDuplicates: this.recordId != this.lastDuplicateCheckId,
                                    origen: this.haveOrigenLegal,
                                    blanqueo: this.Blanqueo === true,
                                    marcarRevisarCompra
                                });
                
                                if (data.duplicate) {
                                    return this.notifyDuplicate();
                                }
                
                                // Refresca la venta y las líneas en pantalla
                                this.setData(data);
                                this.DataCompra = data;
                                this.trackHtCompraConfirmada(data);
                                this.resultModal = 'pending-licencia';
                                window.sessionStorage.setItem('htPopup_' + this.recordId, 'licencia');
                            });
                
                            return;
                        }
                }
        
                // =========================
                // CASO 3: TODO OK
                // =========================
                // Tiene licencia y tiene origen legal → venta normal
                else if (guardar === true) {
                    await this.requestWrap(async () => {
                        const data = await finalizarCompra({
                            compraId: this.recordId,
                            checkDuplicates: this.recordId != this.lastDuplicateCheckId,
                            origen: this.haveOrigenLegal,
                            blanqueo: this.Blanqueo === true,
                            marcarRevisarCompra
                        });
        
                        if (data.duplicate) {
                            return this.notifyDuplicate();
                        }
        
                        this.setData(data);
                        this.DataCompra = data;
                        this.trackHtCompraConfirmada(data);
        
                        if (this.puedeFacturar) {
                            await this.facturar();
                        }

                        this.resultModal = data.pendiente ? 'pending-payment' : 'success';
                    });
                }
        } finally {
            this.finalizandoOperacion = false;
        }
    }

    notifyDuplicate() {
        this.lastDuplicateCheckId = this.recordId;
        this.resultModal = 'duplicate';
    }

    async anular(event) {
        await this.requestWrap(async () => {
            const data = await anular({ compraId: this.recordId });
            this.setData(data);
            this.resultModal = null;
            this.currentModal = null;
            this.redirectPendientesFacturacion();
        });
    }

    // ====== DATOS COMPLEMENTARIOS ======
    getSemilleroData() {
        console.log('Semillero data:', JSON.stringify(this.semillero));
        console.log('Semillero data:', JSON.stringify(getSemilleroData({obtentorId: this.semillero})));
        return getSemilleroData({ obtentorId: this.semillero });
    }

    async getProductos() {
        await this.requestWrap(async () => {
            const products = await getProductsData({ cultivoId: this.cultivo });
            this.updateVariedades(products);
        });
        if (!this.tipoCompraSeleccionado) {
            const disponibles = this.tiposCompraDisponibles;
            if (disponibles.includes('Futura')) {
                this.tipoCompraSeleccionado = 'Futura';
                this.Futura = true;
            } else if (disponibles.length === 1) {
                this.tipoCompraSeleccionado = disponibles[0];
                this.Futura = disponibles[0] === 'Futura';
            }
        }
        this.step = 2;
    }

    // ====== STEPS ======
    step = 1;
    campaignLabel = 'Campaña 25/26';

    get uiStep() {
        if (this.legacyResumenMode) return 5;
        return this.step || 1;
    }

    get progressLabel() {
        return `Comprar HT · Paso ${this.uiStep} de 5`;
    }

    get wizardProgressLabel() {
        return `Paso ${this.uiStep} de 5`;
    }

    get progressPctLabel() {
        return `${this.uiStep * 20}%`;
    }

    get progressBarStyle() {
        return `width: ${this.uiStep * 20}%`;
    }

    get buyClass() {
        let cls = 'se-buy';
        if (this.showMobWizardFooter) cls += ' se-buy--mob-wizard';
        if (this.hasOverlayModal) cls += ' is-pay-modal-open';
        return cls;
    }

    get bodyShellClass() {
        return 'body' + (this.hasOverlayModal ? ' se-pay-backdrop-open' : '');
    }

    get hasOverlayModal() {
        return this.showTipoPagoSheet || !!this.resultModal;
    }

    get buyMainClass() {
        return 'se-buy-main' + (this.showMobWizardFooter ? ' se-buy-main--mob-footer' : '');
    }

    get showMobWizardFooter() {
        return !this.legacyResumenMode && this.step >= 1 && this.step <= 5;
    }

    get mobFooterClass() {
        return (
            'se-mob-footer' + (this.step === 5 ? ' se-mob-footer--confirm' : '')
        );
    }

    get mobFooterStepLabel() {
        return this.step === 5 ? 'Total a pagar' : this.wizardProgressLabel;
    }

    get mobFooterStatus() {
        switch (this.step) {
            case 1:
                return this.paso1MobStatus;
            case 2:
                if (!this.tipoCompraSeleccionado) return 'Elegí el tipo de HT';
                return `${this.resumenTipo} seleccionado`;
            case 3: {
                const marca = this.resumenMarca;
                if (!this.semillero || marca === '—') return 'Elegí la marca';
                return `${marca} seleccionada`;
            }
            case 4: {
                const ht = this.selectedVariedadHtTotal;
                if (!(ht > 0)) return 'Elegí al menos una variedad';
                const count = this.selectedVariedadCount;
                const noun = count === 1 ? 'variedad' : 'variedades';
                return `${count} ${noun} · ${ht.toLocaleString('es-AR', { maximumFractionDigits: 0 })} HT`;
            }
            case 5:
                return this.resumenTotal !== '—' ? this.resumenTotal : 'Revisá tu compra';
            default:
                return '';
        }
    }

    get mobFooterContinuarDisabled() {
        switch (this.step) {
            case 1:
                return this.continuarPaso1Disabled;
            case 2:
                return this.continuarPaso2Disabled;
            case 3:
                return this.continuarPaso3Disabled;
            case 4:
                return this.continuarPaso4Disabled;
            case 5:
                return this.confirmarCompraDisabled;
            default:
                return true;
        }
    }

    get mobFooterContinuarLabel() {
        if (this.step === 5) {
            return this.finalizandoOperacion ? 'Confirmando...' : 'Confirmar';
        }
        return 'Continuar →';
    }

    async handleMobContinuar() {
        switch (this.step) {
            case 1:
                await this.handleContinuarPaso1();
                break;
            case 2:
                this.handleContinuarPaso2();
                break;
            case 3:
                await this.handleContinuarPaso3();
                break;
            case 4:
                await this.handleContinuarPaso4();
                break;
            case 5:
                await this.handleConfirmarCompra();
                break;
            default:
                break;
        }
    }

    get mobWizardSteps() {
        const labels = ['Cultivo', 'Tipo', 'Marca', 'Variedad', 'Confirmar'];
        const current = this.uiStep;
        return labels.map((label, index) => ({
            key: `mob-step-${index}`,
            label,
            className: 'se-mob-step' + (index + 1 === current ? ' is-active' : '')
        }));
    }

    get paso1MobStatus() {
        const nombre = this.cultivoNombre;
        if (!nombre) return 'Elegí un cultivo';
        const lower = nombre.toLowerCase();
        if (lower.endsWith('a')) return `${nombre} seleccionada`;
        return `${nombre} seleccionado`;
    }

    handleMobBack() {
        if (this.step > 1 && !this.legacyResumenMode) {
            this.step -= 1;
            return;
        }
        this.close();
    }

    handleMobClose() {
        this.close();
    }

    get wizardSteps() {
        const current = this.uiStep;
        const labels = ['Cultivo', 'Tipo de HT', 'Marca', 'Variedad', 'Confirmar'];
        return labels.map((label, index) => {
            const num = index + 1;
            const isActive = num === current;
            const isDone = num < current;
            const disabled = num > current;
            return {
                key: `wiz-${num}`,
                num,
                label,
                disabled,
                showLine: num < 5,
                circleText: isDone ? '✓' : String(num),
                ariaCurrent: isActive ? 'step' : 'false',
                wrapClass: 'se-prog-item' + (num === 5 ? ' se-prog-item-last' : ''),
                btnClass:
                    'se-prog-btn' +
                    (isActive ? ' is-active' : '') +
                    (isDone ? ' is-done' : ''),
                circleClass:
                    'se-prog-circle' +
                    (isActive ? ' is-active' : '') +
                    (isDone ? ' is-done' : ''),
                labelClass:
                    'se-prog-label' +
                    (isActive ? ' is-active' : '') +
                    (isDone ? ' is-done' : '')
            };
        });
    }

    handleWizardStepClick(event) {
        const clicked = Number(event.currentTarget.dataset.step);
        if (!clicked || clicked > this.uiStep || this.legacyResumenMode) return;
        if (clicked <= this.step) {
            this.step = clicked;
        }
    }

    get step1Class() {
        return 'step' + (this.step === 1 ? ' active' : this.step > 1 ? ' completed' : '');
    }
    get step2Class() {
        return 'step' + (this.step === 2 ? ' active' : this.step > 2 ? ' completed' : '');
    }
    get step3Class() {
        return 'step' + (this.step === 3 ? ' active' : '');
    }

    get isStep1Active() { return this.step === 1 && !this.legacyResumenMode; }
    get isStep2Active() { return this.step === 2 && !this.legacyResumenMode; }
    get isStep3Active() { return this.step === 3 && !this.legacyResumenMode; }
    get isStep4Active() { return this.step === 4 && !this.legacyResumenMode; }
    get isStep5Active() { return this.step === 5 && !this.legacyResumenMode; }

    handleStepClick(event) {
        const clickedStep = Number(event.currentTarget.dataset.step);
        if (clickedStep <= this.step) {
            this.step = clickedStep;
        }
    }

    get decoratedCultivos() {
        return (this.cultivos || []).map((c) => {
            const nombre = c.label || '';
            const id = c.value;
            const selected =
                this.cultivoSeleccionadoId === id ||
                (!this.cultivoSeleccionadoId && this.cultivo === id);
            const saldo =
                c.saldo != null
                    ? c.saldo
                    : c.Saldo__c != null
                      ? c.Saldo__c
                      : c.saldoHt != null
                        ? c.saldoHt
                        : 0;
            const n = Number(saldo);
            const formatted = Number.isFinite(n)
                ? n.toLocaleString('es-AR', { maximumFractionDigits: 0 })
                : String(saldo);
            const saldoLabel = `Saldo · ${formatted} HT`;
            return {
                ...c,
                nombre,
                id,
                icono: this.getIcon(nombre),
                saldoLabel,
                ariaChecked: selected ? 'true' : 'false',
                cssClass: 'se-cultivo-tile' + (selected ? ' is-selected' : '')
            };
        });
    }

    getIcon(nombre) {
        switch ((nombre || '').toLowerCase()) {
            case 'soja':
                return this.iconSojaHTUrl;
            case 'trigo':
                return this.iconTrigoHTUrl;
            case 'cebada':
                return this.iconCebadaUrl;
            default:
                return this.iconTrigoHTUrl;
        }
    }

    get continuarPaso1Disabled() {
        return !(this.cultivoSeleccionadoId || this.cultivo);
    }

    get resumenCultivo() {
        return this.cultivoNombre || '—';
    }

    get resumenTipo() {
        if (this.tipoCompraSeleccionado === 'Futura') return 'HT Futura';
        if (this.tipoCompraSeleccionado === 'Disponible') return 'HT Disponible';
        return this.tipoCompraSeleccionado || '—';
    }

    get tipoStepEyebrow() {
        const cultivo = this.cultivoNombre || 'Cultivo';
        return `${cultivo} · ${this.campaignLabel}`;
    }

    get continuarPaso2Disabled() {
        return !this.tipoCompraSeleccionado;
    }

    get resumenMarca() {
        const fromList = (this.semilleros || []).find((s) => s.value === this.semillero);
        if (fromList?.label) return fromList.label;
        const label = resolveSemilleroLabel(
            this.semilleros,
            this.semillero,
            this.semilleroData
        );
        return label || '—';
    }

    get hasPersistedVariedadLines() {
        return (this.items || []).some(
            (item) => Number(item.record?.Cantidad__c) > 0
        );
    }

    get resumenVariedades() {
        if (this.step >= 5) {
            const n = this.confirmacionLineas.length;
            return n > 0 ? String(n) : '—';
        }
        const count = this.selectedVariedadCount;
        return count > 0 ? String(count) : '—';
    }

    get resumenHt() {
        if (
            this.step >= 5 &&
            this.hasPersistedVariedadLines &&
            this.data?.record?.Total_HT__c != null
        ) {
            return Number(this.data.record.Total_HT__c).toLocaleString('es-AR', {
                maximumFractionDigits: 0
            });
        }
        const ht = this.selectedVariedadHtTotal;
        return ht > 0
            ? ht.toLocaleString('es-AR', { maximumFractionDigits: 0 })
            : '—';
    }

    get resumenTotal() {
        if (
            this.step >= 5 &&
            this.hasPersistedVariedadLines &&
            this.data?.record?.Total_USD__c != null
        ) {
            const total = Number(this.data.record.Total_USD__c);
            return `USD ${total.toLocaleString('es-AR', {
                minimumFractionDigits: 0,
                maximumFractionDigits: 2
            })}`;
        }
        const total = this.selectedVariedadUsdTotal;
        if (!(total > 0)) return '—';
        return `USD ${total.toLocaleString('es-AR', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 2
        })}`;
    }

    get licensesHref() {
        const path = (basePath || '').replace(/\/$/, '');
        return `${path}/licencias`;
    }

    get selectedVariedadCount() {
        return this.decoratedVariedadesPaso4.filter((v) => v.qty > 0 && v.hasLicencia).length;
    }

    get selectedVariedadHtTotal() {
        return this.decoratedVariedadesPaso4.reduce(
            (sum, v) => sum + (v.hasLicencia ? v.qty : 0),
            0
        );
    }

    get selectedVariedadUsdTotal() {
        return this.decoratedVariedadesPaso4.reduce(
            (sum, v) => sum + (v.hasLicencia && v.qty > 0 ? v.qty * v.unitPrice : 0),
            0
        );
    }

    handleSelectCultivo(event) {
        const cultivoId = event.currentTarget?.dataset?.id;
        if (!cultivoId) return;
        this.cultivo = cultivoId;
        this.cultivoSeleccionadoId = cultivoId;
    }

    async handleContinuarPaso1() {
        if (this.continuarPaso1Disabled) return;
        await this.getProductos();
    }

    handleCancelarPaso1() {
        this.close();
    }

    async semilleroSelectedEjecuto(event) {
        this.semillero = event.detail;
        await this.confirmMarcaAndContinue();
    }

    get marcaStepEyebrow() {
        const cultivo = this.cultivoNombre || 'Cultivo';
        const tipo = this.resumenTipo !== '—' ? this.resumenTipo : 'Tipo de HT';
        return `${cultivo} · ${tipo}`;
    }

    get continuarPaso3Disabled() {
        return !this.semillero;
    }

    get decoratedMarcas() {
        const q = (this.marcaSearch || '').trim().toLowerCase();
        return (this.filteredSemilleros || [])
            .filter((s) => !q || (s.label || '').toLowerCase().includes(q))
            .map((s) => {
                const selected = this.semillero === s.value;
                const letters = (s.label || '').replace(/[^A-Za-zÁÉÍÓÚÜÑáéíóúüñ]/g, '');
                const initials = (letters.slice(0, 2) || '??').toUpperCase();
                return {
                    id: s.value,
                    label: s.label,
                    initials,
                    ariaChecked: selected ? 'true' : 'false',
                    cssClass: 'se-marca-tile' + (selected ? ' is-selected' : '')
                };
            });
    }

    get marcaCountLabel() {
        const n = (this.filteredSemilleros || []).length;
        const cultivo = this.cultivoNombre || 'este cultivo';
        const noun = n === 1 ? 'semillero' : 'semilleros';
        const adj = n === 1 ? 'disponible' : 'disponibles';
        return `${n} ${noun} ${adj} para ${cultivo} · el listado cambia si el cultivo cambia.`;
    }

    handleMarcaSearch(event) {
        this.marcaSearch = event.target.value || '';
    }

    handleSelectMarca(event) {
        const id = event.currentTarget?.dataset?.id;
        if (!id) return;
        this.semillero = id;
    }

    handleVolverPaso3() {
        this.step = 2;
    }

    async handleContinuarPaso3() {
        if (!this.semillero) return;
        await this.confirmMarcaAndContinue();
    }

    async confirmMarcaAndContinue() {
        await this.requestWrap(async () => {
            this.semilleroData = await this.getSemilleroData();
        });
        this.variedadCantidades = {};
        this.step = 4;
        trackGa4Event('ht_seleccion_semillero', {
            semillero: resolveSemilleroLabel(this.semilleros, this.semillero, this.semilleroData)
        });
    }

    get variedadStepEyebrow() {
        const parts = [
            this.cultivoNombre,
            this.resumenMarca !== '—' ? this.resumenMarca : null,
            this.resumenTipo !== '—' ? this.resumenTipo : null
        ].filter(Boolean);
        return parts.join(' · ');
    }

    get continuarPaso4Disabled() {
        return this.selectedVariedadHtTotal <= 0;
    }

    formatUsd(value) {
        const n = Number(value) || 0;
        return `USD ${n.toLocaleString('es-AR', {
            minimumFractionDigits: 2,
            maximumFractionDigits: 2
        })}`;
    }

    varietyHasLicencia(biotech) {
        const tecnologia = MAP_TECNOLOGIAS_LICENCIA[biotech];
        if (!tecnologia) return false;

        const keys = this.semilleroData?.licenciasKeys;
        if (!Array.isArray(keys) || keys.length === 0) return false;

        const obtentorId = this.semilleroData?.semillero?.Id;
        if (!obtentorId) return false;

        const parentId = this.semilleroData?.semillero?.ParentId;
        const key = `${obtentorId}${tecnologia}`;
        const keyParent = parentId ? `${parentId}${tecnologia}` : null;
        return keys.includes(key) || (keyParent != null && keys.includes(keyParent));
    }

    get decoratedVariedadesPaso4() {
        return (this.variedades || []).map((entry) => {
            const rec = entry.record || {};
            const id = entry.value || rec.Id;
            const unitPrice = Number(rec.Unit_Price__c ?? rec.UnitPrice ?? 0) || 0;
            const qty = Number(this.variedadCantidades?.[id] || 0) || 0;
            const biotech = rec.Product2?.Variedad2__r?.Biotecnologia__c || '';
            const hasLicencia = this.varietyHasLicencia(biotech);
            const subtotal = qty * unitPrice;
            return {
                id,
                product2Id: rec.Product2Id || rec.Product2?.Id,
                name: entry.label || rec.Product2?.Nombre_Comercial__c || 'Variedad',
                category: biotech || '',
                unitPrice,
                qty: hasLicencia ? qty : 0,
                hasLicencia,
                showSubtotal: hasLicencia && qty > 0,
                minusDisabled: qty <= 0,
                priceLabel: `${this.formatUsd(unitPrice)} / HT`,
                subtotalLabel: this.formatUsd(subtotal),
                badgeLabel: hasLicencia ? 'Con Licencia' : 'Sin Licencia',
                badgeClass: 'se-var-badge ' + (hasLicencia ? 'is-ok' : 'is-warn'),
                cssClass: 'se-var-card' + (hasLicencia ? '' : ' is-locked')
            };
        });
    }

    setVariedadCantidad(id, rawValue) {
        const entry = (this.variedades || []).find(
            (item) => (item.value || item.record?.Id) === id
        );
        const biotech = entry?.record?.Product2?.Variedad2__r?.Biotecnologia__c || '';
        if (!this.varietyHasLicencia(biotech)) return;

        const next = Math.max(0, Math.floor(Number(rawValue) || 0));
        this.variedadCantidades = { ...this.variedadCantidades, [id]: next };
    }

    handleVariedadQty(event) {
        const id = event.currentTarget?.dataset?.id;
        const delta = Number(event.currentTarget?.dataset?.delta || 0);
        if (!id || !delta) return;
        const current = Number(this.variedadCantidades?.[id] || 0) || 0;
        this.setVariedadCantidad(id, current + delta);
    }

    handleVariedadQtyInput(event) {
        const id = event.currentTarget?.dataset?.id;
        if (!id) return;
        this.setVariedadCantidad(id, event.currentTarget.value);
        event.currentTarget.value = String(this.variedadCantidades[id] ?? 0);
    }

    handleVolverPaso4() {
        this.step = 3;
    }

    handleContinuarPaso4() {
        if (this.continuarPaso4Disabled) return;
        this.aceptaTerminos = false;
        this.step = 5;
        Promise.resolve().then(() => {
            this.syncPromoQualificationState();
            this.refreshAllLinePromoPrices();
        });
    }

    async persistSelectedVariedades() {
        const selected = this.decoratedVariedadesPaso4.filter((v) => v.hasLicencia && v.qty > 0);
        let lastData = null;
        for (const v of selected) {
            const existing = (this.items || []).find(
                (item) => item.record?.Id_Producto_de_Lista_de_Precio__c === v.id
            );
            const linePayload = {
                Id_Producto_de_Lista_de_Precio__c: v.id,
                Cantidad__c: v.qty,
                Precio_de_Lista__c: v.unitPrice,
                Producto__c: v.product2Id
            };
            if (existing?.record?.Id) {
                linePayload.Id = existing.record.Id;
            }
            lastData = await saveItem({
                compraId: this.recordId,
                itemJson: JSON.stringify(linePayload),
                cultivo: this.cultivo
            });
            if (lastData?.record?.Id) {
                this.recordId = lastData.record.Id;
            }
        }
        if (lastData) {
            this.setData(lastData);
        }
    }

    get confirmacionLineas() {
        const fromItems = (this.items || [])
            .filter((item) => Number(item.record?.Cantidad__c) > 0)
            .map((item) => {
                const rec = item.record || {};
                const pbe = (this.variedades || []).find(
                    (v) => v.value === rec.Id_Producto_de_Lista_de_Precio__c
                );
                const product = pbe?.record?.Product2;
                const name =
                    product?.Nombre_Comercial__c ||
                    rec.Producto__r?.Nombre_Comercial__c ||
                    rec.Name ||
                    '—';
                const biotech =
                    product?.Variedad2__r?.Biotecnologia__c ||
                    rec.Producto__r?.Variedad2__r?.Biotecnologia__c ||
                    '';
                const qty = Number(rec.Cantidad__c) || 0;
                const unit = Number(rec.Precio_de_Lista__c) || 0;
                return {
                    id: item.id,
                    name,
                    category: biotech || '—',
                    ht: qty.toLocaleString('es-AR', { maximumFractionDigits: 0 }),
                    unitPrice: unit.toLocaleString('es-AR', {
                        minimumFractionDigits: 2,
                        maximumFractionDigits: 2
                    }),
                    subtotal: this.formatUsd(qty * unit)
                };
            });

        if (fromItems.length > 0 || this.legacyResumenMode) {
            return fromItems;
        }

        return this.decoratedVariedadesPaso4
            .filter((v) => v.hasLicencia && v.qty > 0)
            .map((v) => ({
                id: v.id,
                name: v.name,
                category: v.category || '—',
                ht: v.qty.toLocaleString('es-AR', { maximumFractionDigits: 0 }),
                unitPrice: v.unitPrice.toLocaleString('es-AR', {
                    minimumFractionDigits: 2,
                    maximumFractionDigits: 2
                }),
                subtotal: v.subtotalLabel
            }));
    }

    get facturacionLabel() {
        const parts = [this.productorNombre, this.cuit ? `CUIT ${this.cuit}` : null].filter(Boolean);
        const base = parts.join(' · ');
        return base ? `${base} · Débito de Cuenta Granaria.` : 'Débito de Cuenta Granaria.';
    }

    get confirmarCompraDisabled() {
        return !this.aceptaTerminos || this.finalizandoOperacion;
    }

    handleToggleTerminos(event) {
        this.aceptaTerminos = event.target.checked;
    }

    handleVolverPaso5() {
        this.aceptaTerminos = false;
        this.syncVariedadCantidadesFromItems();
        this.step = 4;
    }

    syncVariedadCantidadesFromItems() {
        const map = {};
        (this.items || []).forEach((item) => {
            const pbeId = item.record?.Id_Producto_de_Lista_de_Precio__c;
            const qty = Number(item.record?.Cantidad__c) || 0;
            if (pbeId && qty > 0) {
                map[pbeId] = qty;
            }
        });
        this.variedadCantidades = map;
    }

    async handleConfirmarCompra() {
        if (this.confirmarCompraDisabled) return;
        await this.finalizar();
    }

    get tiposCompraDisponibles() {
        const tipos = new Set();
        Object.values(this.variedadesByObtentor || {}).forEach(entries => {
            entries.forEach(v => {
                if (v.record?.Product2?.Tipo_de_Compra__c) {
                    tipos.add(v.record.Product2.Tipo_de_Compra__c);
                }
            });
        });
        return Array.from(tipos);
    }

    get filteredSemilleros() {
        if (!this.tipoCompraSeleccionado) return this.semilleros;
        return (this.semilleros || []).filter(s => {
            const entries = this.variedadesByObtentor?.[s.value] || [];
            return entries.some(v => v.record?.Product2?.Tipo_de_Compra__c === this.tipoCompraSeleccionado);
        });
    }

    get decoratedTiposCompra() {
        const disponibles = this.tiposCompraDisponibles;
        const opciones = [
            {
                value: 'Futura',
                label: 'HT Futura',
                description:
                    'Precertificables dentro de los plazos del programa. La conversión a toneladas se produce a partir de la entrega de grano.',
                recomendado: true
            },
            {
                value: 'Disponible',
                label: 'HT Disponible',
                description:
                    'Acreditan toneladas de inmediato. Sólo se adquieren antes de la entrega de grano. No son precertificables.',
                recomendado: false
            }
        ];
        const list = opciones.filter(o => disponibles.includes(o.value));
        // Si aún no hay productos cargados, mostrar ambas opciones del mock.
        const source = list.length ? list : opciones;
        return source.map(o => {
            const selected = this.tipoCompraSeleccionado === o.value;
            return {
                ...o,
                ariaChecked: selected ? 'true' : 'false',
                cssClass: 'se-tipo-tile' + (selected ? ' is-selected' : '')
            };
        });
    }

    handleSelectTipoCompra(event) {
        const tipo = event.currentTarget.dataset.tipo;
        if (!tipo) return;
        this.tipoCompraSeleccionado = tipo;
        this.Futura = tipo === 'Futura';
    }

    handleVolverPaso2() {
        this.step = 1;
    }

    handleContinuarPaso2() {
        if (!this.tipoCompraSeleccionado) return;
        this.Futura = this.tipoCompraSeleccionado === 'Futura';
        this.step = 3;
    }

    get variedades() {
        const todas = this.variedadesByObtentor?.[this.semillero] || [];
        if (!this.tipoCompraSeleccionado) return todas;
        return todas.filter(v => v.record?.Product2?.Tipo_de_Compra__c === this.tipoCompraSeleccionado);
    }

    openFileUpload() {
        this.showFileUploadModal = true;
    }
 
    closeFileUpload() {
        this.showFileUploadModal = false;
    }

    openFileUpload() {
        this.showFileUploadModal = true;
    }
 
    closeFileUpload() {
        this.showFileUploadModal = false;
    }

    get acceptedFormats() {
        return ['.pdf'];
    }

    handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
    
        if (uploadedFiles.length > 1) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Solo se permite subir un archivo PDF',
                    variant: 'error'
                })
            );
            return;
        }

        const file = uploadedFiles[0];
        const isValidExtension = file.name.toLowerCase().endsWith('.pdf');
        const isValidMimeType = file.mimeType === 'application/pdf';
        
        if (!isValidExtension || !isValidMimeType) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: `El archivo "${file.name}" no es un PDF válido. Solo se permiten archivos PDF.`,
                    variant: 'error'
                })
            );
            return;
        }

        this.dispatchEvent(
            new ShowToastEvent({
                title: 'Éxito',
                message: `Archivo PDF "${file.name}" subido correctamente`,
                variant: 'success'
            })
        );

        this.closeFileUpload();
    }

    handleTipoHtChange(event) {
        console.log('llego aca el evento ', JSON.stringify(event.detail))
        console.log('llego aca el evento ', JSON.stringify(event.detail.isFutura))
        const { isFutura } = event.detail;
        this.Futura = event.detail.isFutura;
        console.log('isFutura extraído:', isFutura);
       //Pre Campaña
        this.showFinanciamientoColumn = isFutura && this.cultivoNombre === 'SOJA';
        console.log('showFinanciamientoColumn:', this.showFinanciamientoColumn);
        this.syncPromoQualificationState();
        Promise.resolve().then(() => {
            this.refreshAllLinePromoPrices();
            this.notifyLineSaveStateChanged();
        });
    }

    handlePromoLineChange(event) {
        if (event?.detail?.evalModal === true) {
            const immediate = event?.detail?.immediate === true;
            scheduleHtFuturaPromoEval(this, () => this.evaluarCondicionPromocionalHtFutura(), { immediate });
            return;
        }
        Promise.resolve().then(() => {
            this.refreshAllLinePromoPrices();
            this.notifyLineSaveStateChanged();
        });
    }

    disconnectedCallback() {
        cancelHtFuturaPromoEval(this);
        this.unlockPayModalScroll();
        document.documentElement.classList.remove('se-inner', 'se-inner-wizard');
        document.body.classList.remove('se-inner', 'se-inner-wizard');
    }

    renderedCallback() {
        if (!this.initialized && !this.pageRecordId) {
            this.init();
        } else if (!this.initialized) {
            this.initialized = true;
        }
        this.syncPayModalScrollLock();
    }

    syncPayModalScrollLock() {
        const shouldLock = this.hasOverlayModal;
        if (shouldLock === this._payModalScrollLocked) {
            return;
        }
        if (shouldLock) {
            this.lockPayModalScroll();
        } else {
            this.unlockPayModalScroll();
        }
    }

    lockPayModalScroll() {
        if (typeof window === 'undefined' || typeof document === 'undefined') {
            return;
        }
        this._payModalScrollY =
            window.scrollY || document.documentElement.scrollTop || 0;
        document.documentElement.classList.add('se-pay-modal-open');
        document.body.classList.add('se-pay-modal-open');
        document.body.style.position = 'fixed';
        document.body.style.top = `-${this._payModalScrollY}px`;
        document.body.style.left = '0';
        document.body.style.right = '0';
        document.body.style.width = '100%';
        this._payModalScrollLocked = true;
    }

    unlockPayModalScroll() {
        if (typeof document === 'undefined') {
            return;
        }
        document.documentElement.classList.remove('se-pay-modal-open');
        document.body.classList.remove('se-pay-modal-open');
        document.body.style.position = '';
        document.body.style.top = '';
        document.body.style.left = '';
        document.body.style.right = '';
        document.body.style.width = '';
        if (typeof window !== 'undefined') {
            window.scrollTo(0, this._payModalScrollY || 0);
        }
        this._payModalScrollLocked = false;
    }

    collectPromoLineData() {
        const rows = Array.from(this.template.querySelectorAll('c-crear-linea-compra-new'));
        if (rows.length) {
            return rows.map(row => row.getPromoLineData()).filter(Boolean);
        }

        const records = this.data?.record?.Lineas_de_Compra_HT__r || [];
        return records.map(record => ({
            tipoCompra: record.Producto__r?.Tipo_de_Compra__c,
            cantidad: record.Cantidad__c,
            listPrice: resolveBaseListPrice(record.Precio_de_Lista__c)
        })).filter(line => line.tipoCompra && line.listPrice != null);
    }

    computePromoQualification() {
        if (!isHtFuturaPromoScreen({ semilleroId: this.semillero, cultivoName: this.cultivoNombre })) {
            return false;
        }

        const lineas = this.collectPromoLineData();
        return qualifiesForHtFuturaPromoAggregate({
            lineas,
            semilleroId: this.semillero,
            cultivoName: this.cultivoNombre
        });
    }

    syncPromoQualificationState() {
        if (!isHtFuturaPromoScreen({ semilleroId: this.semillero, cultivoName: this.cultivoNombre })) {
            this.resetHtFuturaPromoUi();
            return;
        }
        this.htFuturaPromoPreviouslyQualified = this.computePromoQualification();
    }

    evaluarCondicionPromocionalHtFutura() {
        if (!isHtFuturaPromoScreen({ semilleroId: this.semillero, cultivoName: this.cultivoNombre })) {
            this.resetHtFuturaPromoUi();
            return;
        }

        this.updatePromoMessage(this.computePromoQualification());
        this.refreshAllLinePromoPrices();
    }

    resetHtFuturaPromoUi() {
        cancelHtFuturaPromoEval(this);
        this.htFuturaPromoMessage = null;
        this.htFuturaPromoPreviouslyQualified = false;
        this.htFuturaPromoCelebrationShown = false;
        if (this.resultModal === 'promo') {
            this.resultModal = null;
        }
    }

    updatePromoMessage(hasQualifying) {
        const hadBefore = this.htFuturaPromoPreviouslyQualified;
        const ui = resolveHtFuturaPromoUiState({
            hasQualifying,
            hadQualifying: hadBefore,
            celebrationAlreadyShown: this.htFuturaPromoCelebrationShown,
            currentModalIsPromo: this.resultModal === 'promo'
        });

        if (ui.showCelebrationModal || ui.showLossModal) {
            this.htFuturaPromoMessage = ui.promoMessage;
            this.htFuturaPromoVariant = ui.promoVariant;
            this.resultModal = 'promo';
            this.currentModal = null;
            if (ui.showCelebrationModal) {
                this.htFuturaPromoCelebrationShown = ui.celebrationAlreadyShown;
            }
        } else if (ui.dismissPromoModal) {
            if (this.resultModal === 'promo') {
                this.resultModal = null;
            }
            this.currentModal = null;
            this.htFuturaPromoMessage = null;
        }

        this.htFuturaPromoPreviouslyQualified = hasQualifying;
    }

    async finish() {
        let poseeLicencia = false;
        const variedades = [];

        if (!this.DataCompra || !this.DataCompra.record) {
            return false;
        }

        if (this.DataCompra.semilleroData?.licencia?.Id) {
            poseeLicencia = true;
        }

        const lineasCompra = this.DataCompra.record.Lineas_de_Compra_HT__r || [];
        lineasCompra.forEach(element => {
            if (element.Producto__r?.Variedad2__c) {
                variedades.push(element.Producto__r.Variedad2__c);
            }
        });

        try {
            const res = await canFinish({
                semillero: this.DataCompra.semilleroData?.semillero || {},
                CuentaProductor: this.DataCompra.record.Cuenta_Productor__r?.Id,
                tieneLicencia: poseeLicencia,
                Variedades: variedades
            });

            this.haveLicence = res.TieneLicencia;
            this.haveOrigenLegal = res.origenLegal;
            this.Blanqueo = res.Blanqueo === true;

            if (res.origenLegal === true && res.TieneLicencia === true) {
                return true;
            }
            if (res.TieneLicencia === true && res.origenLegal === false && res.Blanqueo === true) {
                return true;
            }
            return false;
        } catch (error) {
            console.error('Error crítico al ejecutar validaciones (canFinish):', error);
            return false;
        }
    }
    
    get productorNombre() {
        return this.productor?.Name || '';
    }
    get logoUrl() {
        return icons.semilleros[this.idobtentor];
    }

    get cuit() {
        return this.productor?.PersonDocumentNumber || this.productor?.N_CUIT__c || '';
    }

    trackHtCompraConfirmada(data) {
        trackGa4Event(
            'ht_compra_confirmada',
            buildHtCompraConfirmadaParams({
                semilleros: this.semilleros,
                semilleroId: this.semillero,
                semilleroData: this.semilleroData,
                cultivoNombre: this.cultivoNombre,
                tipoCompraSeleccionado: this.tipoCompraSeleccionado,
                data,
                tipoPago: this.tipoPago
            })
        );
    }

    get tipoPagoTotalAmount() {
        if (this.data?.record?.Total_USD__c != null) {
            return Number(this.data.record.Total_USD__c) || 0;
        }
        return this.selectedVariedadUsdTotal;
    }

    get tipoPagoModalEyebrow() {
        const marca = this.resumenMarca;
        if (marca && marca !== '—') {
            return `${marca} · pre-campaña`;
        }
        return 'Semillero GDM · pre-campaña';
    }

    get tipoPagoModalContado() {
        const total = this.tipoPagoTotalAmount;
        if (!(total > 0)) return 'USD —';
        const contado = total * 0.93;
        return `USD ${contado.toLocaleString('es-AR', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }

    get tipoPagoModalFinanciadoLabel() {
        const total = this.tipoPagoTotalAmount;
        if (!(total > 0)) return '3 × USD —';
        const cuota = total / 3;
        return `3 × USD ${cuota.toLocaleString('es-AR', {
            minimumFractionDigits: 0,
            maximumFractionDigits: 0
        })}`;
    }

    requiresTipoPago() {
                return ['03','14','85'].includes(this.semillero) && this.cultivoNombre === 'SOJA';

    }

    get tipoPagoContadoCardClass() {
        return 'se-pay-card' + (this.selectedTipoPago === 'Contado' ? ' is-selected' : '');
    }

    get tipoPagoFinanciadoCardClass() {
        return 'se-pay-card' + (this.selectedTipoPago === 'Financiado' ? ' is-selected' : '');
    }

    get isTipoPagoContadoSelected() {
        return this.selectedTipoPago === 'Contado';
    }

    get isTipoPagoFinanciadoSelected() {
        return this.selectedTipoPago === 'Financiado';
    }

    handleTipoPagoOption(event) {
        const value = event.target?.value;
        if (value === 'Contado' || value === 'Financiado') {
            this.selectedTipoPago = value;
        }
    }

    handleTipoPagoCancel() {
        this.showTipoPagoSheet = false;
        this.selectedTipoPago = 'Contado';
        this.pendingFinalizar = false;
    }

    async handleTipoPagoConfirm() {
        await this.applyTipoPagoSelection(this.selectedTipoPago);
    }

    async applyTipoPagoSelection(value) {
        if (value !== 'Contado' && value !== 'Financiado') return;

        this.tipoPago = value;
        trackGa4Event('ht_seleccion_financiamiento', { forma_pago: value });

        await this.requestWrap(async () => {
            const data = await updateTipoPago({
                compraId: this.recordId,
                tipoPago: value
            });
            this.setData(data);
            this.DataCompra = data;
        });

        this.showTipoPagoSheet = false;

        if (this.pendingFinalizar) {
            this.pendingFinalizar = false;
            await this.finalizar();
        }
    }

    async validarExpedienteDisponible(mostrarModalSiTieneExpediente) {
        if (!this.recordId) {
            return false;
        }
        if (OMITIR_MODAL_ALERTA_EXPEDIENTE_NEGATIVO) {
            return false;
        }
        try {
            const result = await verificarExpedienteEnHTDisponible({
                compraVentaId: this.recordId,
                tipoOperacion: 'compra'
            });
            // eslint-disable-next-line no-console
            console.log('[CrearCompra2] verificarExpedienteEnHTDisponible result:', JSON.stringify(result));
            const tieneExpediente = Boolean(result?.tieneExpediente);
            if (tieneExpediente && mostrarModalSiTieneExpediente) {
                this.resultModal = 'expediente';
                this.currentModal = null;
                return true;
            }
            return false;
        } catch (error) {
            // eslint-disable-next-line no-console
            console.error('Error validando expediente en HT disponible (compra):', error);
            return false;
        }
    }

    // —— Modales de resultado (SG 3d / 3d-desk / 3d-alt) ——

    get showResultModal() {
        return !!this.resultModal;
    }

    get isResultAnular() {
        return this.resultModal === 'anular';
    }

    get isResultVigencia() {
        return this.resultModal === 'vigencia';
    }

    get vigenciaText() {
        return 'Las compras tienen una vigencia de 48 hs iniciado el proceso. Una vez cumplidas, la operación caduca y deberás volver a iniciar el proceso.';
    }

    get isResultSuccess() {
        return this.resultModal === 'success';
    }

    get isResultPendingPayment() {
        return this.resultModal === 'pending-payment';
    }

    get isResultPendingLicencia() {
        return this.resultModal === 'pending-licencia';
    }

    get isResultPendingOrigen() {
        return this.resultModal === 'pending-origen';
    }

    get isResultDuplicate() {
        return this.resultModal === 'duplicate';
    }

    get isResultExpediente() {
        return this.resultModal === 'expediente';
    }

    get isResultPromo() {
        return this.resultModal === 'promo';
    }

    get isResultCelebration() {
        return this.isResultSuccess;
    }

    get isResultWarn() {
        return (
            this.isResultPendingLicencia ||
            this.isResultPendingOrigen ||
            this.isResultDuplicate ||
            this.isResultExpediente ||
            (this.isResultPromo && this.htFuturaPromoVariant === 'warning')
        );
    }

    get isResultPendingState() {
        return (
            this.isResultPendingPayment ||
            this.isResultPendingLicencia ||
            this.isResultPendingOrigen
        );
    }

    get resultScrimDismissible() {
        return (
            !this.isResultSuccess &&
            !this.isResultPendingPayment &&
            !this.isResultAnular
        );
    }

    get resultModalAriaLabel() {
        switch (this.resultModal) {
            case 'success':
                return '¡Compra exitosa!';
            case 'pending-payment':
                return 'Compra pendiente de pago';
            case 'pending-licencia':
            case 'pending-origen':
                return 'Compra pendiente';
            case 'duplicate':
                return 'Ya existe una compra en proceso';
            case 'expediente':
                return 'Importante';
            case 'promo':
                return this.resultPromoTitle;
            case 'anular':
                return 'Anular compra';
            case 'vigencia':
                return 'Importante';
            default:
                return 'Resultado de la compra';
        }
    }

    get resultPromoTitle() {
        return this.htFuturaPromoVariant === 'warning' ? 'Atención' : 'Condición comercial';
    }

    get resultOrdenRef() {
        const name = this.data?.record?.Name;
        return name ? `#${name}` : '';
    }

    get resumenLicencia() {
        return this.semilleroData?.licencia?.Name ? 'Vigente' : 'Pendiente';
    }

    get resultSuccessSubtext() {
        const ht = this.resumenHt !== '—' ? `${this.resumenHt} HT` : 'HT';
        const cultivo = this.cultivoNombre || 'cultivo';
        return `Tu compra de ${ht} de ${cultivo} quedó registrada correctamente.`;
    }

    get whatsappHref() {
        return 'https://api.whatsapp.com/send/?phone=5491131172022&text=Hola%2C+quiero+informaci%C3%B3n+sobre+mi+compra&type=phone_number&app_absent=0';
    }

    handleResultScrimClick() {
        if (!this.resultScrimDismissible) return;
        if (this.isResultExpediente && this.pendingFinalizarPorExpediente) {
            this.handleResultExpedienteEntendido();
            return;
        }
        if (this.isResultPendingLicencia || this.isResultPendingOrigen) {
            this.handleResultPendingEntendido();
            return;
        }
        this.resultModal = null;
    }

    handleResultVerMisCompras() {
        this.resultModal = null;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: `${basePath}/comprahtlistproductor` }
        });
    }

    handleResultVolverInicio() {
        this.resultModal = null;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: basePath || '/' }
        });
    }

    handleResultPendingEntendido() {
        this.handleResultVerMisCompras();
    }

    handleResultDuplicateVerCompras() {
        this.handleResultVerMisCompras();
    }

    handleResultDuplicateContinuar() {
        this.resultModal = null;
    }

    handleResultExpedienteEntendido() {
        this.resultModal = null;
        if (this.pendingFinalizarPorExpediente) {
            this.shouldMarkRevisarCompra = true;
            this.pendingFinalizarPorExpediente = false;
            this.finalizar({ mostrarModalExpediente: false });
        }
    }

    handleResultPromoEntendido() {
        this.resultModal = null;
        this.htFuturaPromoMessage = null;
    }

    handleResultAnularConfirm() {
        this.anular();
    }

    handleResultAnularCancel() {
        this.resultModal = null;
    }

    handleResultVigenciaContinuar() {
        this.resultModal = null;
    }

    async handleResultAnularOrden() {
        await this.anular();
        this.resultModal = null;
        this.handleResultVerMisCompras();
    }


}