import { LightningElement, api, track } from 'lwc';
import SVG_ICONS from '@salesforce/resourceUrl/iconos_SE';
import { NavigationMixin } from 'lightning/navigation';

// Matriz completa de datos del Excel Financiado_HT
const FINANCIADO_MATRIX = [
    { banco: 'AGRONACION', moneda: 'ARS', plazo: '365 dias', tna: '30%' },
    { banco: 'AGRONACION PRESTAMOS', moneda: 'USD', plazo: '12 meses', tna: '5%' },
    
    { banco: 'PROCAMPO DIGITAL', moneda: 'ARS', plazo: '90 dias', tna: '29%' },
    { banco: 'PROCAMPO DIGITAL', moneda: 'ARS', plazo: '180 dias', tna: '30%' },
    { banco: 'PROCAMPO DIGITAL', moneda: 'ARS', plazo: '270 dias', tna: '31%' },
    { banco: 'PROCAMPO DIGITAL', moneda: 'ARS', plazo: '360 dias', tna: '32%' },
    { banco: 'PROCAMPO DIGITAL', moneda: 'USD', plazo: '90 dias', tna: '3%' },
    { banco: 'PROCAMPO DIGITAL', moneda: 'USD', plazo: '180 dias', tna: '3%' },
    { banco: 'PROCAMPO DIGITAL', moneda: 'USD', plazo: '270 dias', tna: '4%' },
    { banco: 'PROCAMPO DIGITAL', moneda: 'USD', plazo: '360 dias', tna: '5%' },
    
    { banco: 'Macro Agro RED AGRO', moneda: 'ARS', plazo: '90 dias', tna: '34%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'ARS', plazo: '120 dias', tna: '34%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'ARS', plazo: '150 dias', tna: '34%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'ARS', plazo: '180 dias', tna: '34%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'ARS', plazo: '270 dias', tna: '37%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'ARS', plazo: '360 dias', tna: '40%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '30 dias', tna: '5%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '90 dias', tna: '5%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '120 dias', tna: '5%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '180 dias', tna: '5%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '210 dias', tna: '6%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '270 dias', tna: '6%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '300 dias', tna: '7%' },
    { banco: 'Macro Agro RED AGRO', moneda: 'USD', plazo: '360 dias', tna: '7%' },
    
    { banco: 'Galicia NERA', moneda: 'ARS', plazo: 'Bullet 90 dias', tna: '30%' },
    { banco: 'Galicia NERA', moneda: 'ARS', plazo: 'Bullet 180 dias', tna: '33%' },
    { banco: 'Galicia NERA', moneda: 'ARS', plazo: 'Bullet 240 dias', tna: '34%' },
    { banco: 'Galicia NERA', moneda: 'ARS', plazo: 'Bullet 270 dias', tna: '35%' },
    { banco: 'Galicia NERA', moneda: 'ARS', plazo: 'Bullet 360 dias', tna: '37%' },
    { banco: 'Galicia NERA', moneda: 'ARS', plazo: '6 meses', tna: '33%' },
    { banco: 'Galicia NERA', moneda: 'ARS', plazo: '12 meses', tna: '33%' },
    { banco: 'Galicia NERA', moneda: 'USD', plazo: 'Bullet 90 dias', tna: '0%' },
    { banco: 'Galicia NERA', moneda: 'USD', plazo: 'Bullet 180 dias', tna: '0%' },
    { banco: 'Galicia NERA', moneda: 'USD', plazo: 'Bullet 240 dias', tna: '0%' },
    { banco: 'Galicia NERA', moneda: 'USD', plazo: 'Bullet 270 dias', tna: '0%' },
    { banco: 'Galicia NERA', moneda: 'USD', plazo: 'Bullet 360 dias', tna: '0%' },
    
    { banco: 'Santander NERA', moneda: 'ARS', plazo: 'Bullet 90 dias', tna: '30%' },
    { banco: 'Santander NERA', moneda: 'ARS', plazo: 'Bullet 180 dias', tna: '31%' },
    { banco: 'Santander NERA', moneda: 'ARS', plazo: 'Bullet 270 dias', tna: '32%' },
    { banco: 'Santander NERA', moneda: 'ARS', plazo: 'Bullet 360 dias', tna: '33%' },
    { banco: 'Santander NERA', moneda: 'USD', plazo: 'Bullet 90 dias', tna: '0%' },
    { banco: 'Santander NERA', moneda: 'USD', plazo: 'Bullet 180 dias', tna: '0%' },
    { banco: 'Santander NERA', moneda: 'USD', plazo: 'Bullet 270 dias', tna: '0%' },
    { banco: 'Santander NERA', moneda: 'USD', plazo: 'Bullet 360 dias', tna: '0%' },
    
    { banco: 'Banco Comafi NERA', moneda: 'ARS', plazo: 'Bullet 90 dias', tna: '35%' },
    { banco: 'Banco Comafi NERA', moneda: 'ARS', plazo: 'Bullet 180 dias', tna: '35%' },
    { banco: 'Banco Comafi NERA', moneda: 'ARS', plazo: 'Bullet 360 dias', tna: '41%' },
    { banco: 'Banco Comafi NERA', moneda: 'ARS', plazo: '9 meses', tna: '36%' },
    { banco: 'Banco Comafi NERA', moneda: 'ARS', plazo: '12 meses', tna: '37%' },
    { banco: 'Banco Comafi NERA', moneda: 'USD', plazo: 'Bullet 180 dias', tna: '0%' },
    { banco: 'Banco Comafi NERA', moneda: 'USD', plazo: 'Bullet 270 dias', tna: '0%' },
    { banco: 'Banco Comafi NERA', moneda: 'USD', plazo: 'Bullet 360 dias', tna: '0%' },
    
    { banco: 'STINE', moneda: 'USD', plazo: 'Cosecha', tna: '0%' }
];

export default class HtModals extends NavigationMixin(LightningElement) {
    @api isOpenPaymentModal = false;
    @api modalItems = []; 
    @api currentModal;
    @api community;
    @api esPuntoVenta;
    @api showFacturaRegaliaEnlistMsg;
    @api promoMessage;
    @api promoVariant = 'success';
    
    @track selectedPayment = 'Contado';
    
    // Valores de picklist seleccionados
    @track entidadBancaria = '';
    @track moneda = '';
    @track plazo = '';
    @track tasa = '';

    // Arreglos de opciones para combobox
    @track entidadBancariaOptions = [];
    @track monedaOptions = [];
    @track plazoOptions = [];
    @track tnaOptions = [];

    icons = {
        'error': SVG_ICONS + '/iconos/popup/Icon-feather-alert-circle.svg#Icon_feather-alert-circle',
        'facturas': SVG_ICONS + '/iconos/venta/Icon-awesome-receipt.svg#Icon_awesome-receipt',
        'licencias': SVG_ICONS + '/iconos/venta/Icon-feather-file.svg#Icon_feather-file'
    }

    connectedCallback() {
        this.loadEntidadesBancarias();
    }

    // Carga inicial de entidades bancarias únicas
    loadEntidadesBancarias() {
        const bancosUnicos = [...new Set(FINANCIADO_MATRIX.map(item => item.banco))];
        this.entidadBancariaOptions = bancosUnicos.map(banco => ({ label: banco, value: banco }));
        
        // Autoselección si solo existe un banco registrado
        if (bancosUnicos.length === 1) {
            this.handleEntidadChange({ detail: { value: bancosUnicos[0] } });
        }
    }

    // Getters de estado de deshabilitación de inputs
    get isMonedaDisabled() {
        return !this.entidadBancaria;
    }

    get isPlazoDisabled() {
        return !this.moneda;
    }

    get isTasaDisabled() {
        return !this.plazo;
    }

    // Placeholders dinámicos según el estado
    get placeholderMoneda() {
        return this.isMonedaDisabled ? 'Seleccioná primero una entidad' : 'Seleccioná una moneda';
    }

    get placeholderPlazo() {
        return this.isPlazoDisabled ? 'Seleccioná primero una moneda' : 'Seleccioná un plazo';
    }

    get placeholderTasa() {
        return this.isTasaDisabled ? 'Seleccioná primero el plazo' : 'Seleccioná la tasa';
    }

    // Manejadores de eventos de cambio con Cascada + Autoselección
    handleEntidadChange(event) {
        this.entidadBancaria = event.detail.value;
        this.moneda = '';
        this.plazo = '';
        this.tasa = '';
        this.plazoOptions = [];
        this.tnaOptions = [];

        // Filtrar monedas disponibles para el banco seleccionado
        const monedasDisponibles = [...new Set(
            FINANCIADO_MATRIX
                .filter(item => item.banco === this.entidadBancaria)
                .map(item => item.moneda)
        )];
        this.monedaOptions = monedasDisponibles.map(m => ({ label: m, value: m }));

        // Autoselección si solo hay 1 moneda posible
        if (monedasDisponibles.length === 1) {
            this.handleChangeMoneda({ detail: { value: monedasDisponibles[0] } });
        }
    }

    handleChangeMoneda(event) {
        this.moneda = event.detail.value;
        this.plazo = '';
        this.tasa = '';
        this.tnaOptions = [];

        // Filtrar plazos disponibles según Banco + Moneda
        const plazosDisponibles = [...new Set(
            FINANCIADO_MATRIX
                .filter(item => item.banco === this.entidadBancaria && item.moneda === this.moneda)
                .map(item => item.plazo)
        )];
        this.plazoOptions = plazosDisponibles.map(p => ({ label: p, value: p }));

        // Autoselección si solo hay 1 plazo posible
        if (plazosDisponibles.length === 1) {
            this.handlePlazoChange({ detail: { value: plazosDisponibles[0] } });
        }
    }

    handlePlazoChange(event) {
        this.plazo = event.detail.value;
        this.tasa = '';

        // Filtrar TNA disponible según Banco + Moneda + Plazo
        const tasasDisponibles = [...new Set(
            FINANCIADO_MATRIX
                .filter(item => item.banco === this.entidadBancaria && item.moneda === this.moneda && item.plazo === this.plazo)
                .map(item => item.tna)
        )];
        
        this.tnaOptions = tasasDisponibles.map(t => ({ label: t, value: t }));

        // Autoselección si solo hay 1 tasa posible
        if (tasasDisponibles.length === 1) {
            this.handleChangeTasa({ detail: { value: tasasDisponibles[0] } });
        }
    }

    handleChangeTasa(event) {
        this.tasa = event.detail.value;
    }

    // Visualización y selección de tipo de pago
    get isContado() {
        return this.selectedPayment === 'Contado';
    }

    get isFinanciado() {
        return this.selectedPayment === 'Financiado';
    }

    get contadoCardClass() {
        return `payment-card ${this.isContado ? 'selected' : ''}`;
    }

    get financiadoCardClass() {
        return `payment-card ${this.isFinanciado ? 'selected' : ''}`;
    }

    get isContinueDisabled() {
        if (this.isFinanciado && (!this.entidadBancaria || !this.moneda || !this.plazo || !this.tasa)) {
            return true;
        }
        return false;
    }

    handlePaymentChange(event) {
        this.selectedPayment = event.target.value;
    }

    // Getters de control de modales
    get showFormaPagoStine() {
        return this.currentModal === 'forma-pago-stine';
    }

    get isFinalizada() {
        return this.currentModal == "finalizada";
    }

    get showFinalizada() {
        return this.currentModal == "finalizada" || this.currentModal == "pendiente";
    }

    get showFacturando() {
        return this.currentModal == "facturando";
    }

    get showFacturado() {
        return this.currentModal == "facturado";
    }

    get showVigencia() {
        return this.currentModal == "vigencia";
    }

    get showAnularConfirm() {
        return this.currentModal == "anular";
    }

    get isDuplicateCompra() {
        return this.currentModal == 'duplicate-compra';
    }

    get isDuplicateVenta() {
        return this.currentModal == 'duplicate-venta';
    }

    get showTipoPago() {
        return this.currentModal === 'tipo-pago';
    }

    get showExpedienteDisponibleAlert() {
        return this.currentModal === 'expediente-disponible-alert';
    }

    get showHtFuturaPromo() {
        return this.currentModal === 'ht-futura-promo';
    }

    get htFuturaPromoTitle() {
        return this.promoVariant === 'warning' ? 'Atención' : 'Condición comercial';
    }

    get canClose() {
        return !this.showFacturando;
    }

    get showModal() {
        return this.currentModal != null;
    }

    get showClose() {
        return this.canClose && !this.showTipoPago;
    }

    // Eventos y acciones del Modal
    closeModal(event) {
        this.currentModal = null;
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('closemodal'));
    }

    handleContinue() {
        this.dispatchEvent(new CustomEvent('confirmpayment', {
            detail: {
                formaPago: this.selectedPayment,
                entidadBancaria: this.entidadBancaria,
                plazo: this.plazo,
                moneda: this.moneda,
                tasa: this.tasa,
                observaciones: `Forma de pago: ${this.formaPago}`
            }
        }));
    }

    redirectMisLicencias() {
        this.dispatchEvent(new CustomEvent('redirect', { detail: "licencias" }));
    }

    redirectMisFacturas() {
        this.dispatchEvent(new CustomEvent('redirect', { detail: "facturas" }));
    }

    anular() {
        this.dispatchEvent(new CustomEvent('anular'));
    }

    redirectCompras() {
        this.dispatchEvent(new CustomEvent('redirect', { detail: "compras" }));
    }

    redirectVentas() {
        this.dispatchEvent(new CustomEvent('redirect', { detail: "ventas" }));
    }

    stopPropagation(event) {
        event.preventDefault();
        event.stopPropagation();
    }

    handleKeydownNoEsc(event) {
        if (event.key === 'Escape') {
            event.preventDefault();
            event.stopPropagation();
        }
    }

    selectContado() {
        this.dispatchEvent(new CustomEvent('tipopagoselected', { detail: { value: 'Contado' } }));
    }

    selectFinanciado() {
        this.dispatchEvent(new CustomEvent('tipopagoselected', { detail: { value: 'Financiado' } }));
    }

    // Textos informativos
    get finalizadaText() {
        return this.community + ' ' + this.currentModal;
    }

    get finalizadaSubText() {
        const prefix = this.currentModal == "finalizada" 
            ? `Felicitaciones! Ya finalizaste tu ${this.community} de HT y en los próximos días vas a estar recibiendo la factura.` 
            : `Queda pendiente tu ${this.community} de HT hasta que se gestionen las licencias que faltan.`;
        return prefix + ` Por cualquier duda, no dejes de contactarte con nosotros:

        Whatsapp: +54 9 11 3117-2022
        E-mail: info@sembraevolucion.com.ar
        Teléfono: +54 11 5077-9090`;
    }

    get vigenciaText() {
        return 'Las ' + this.community.toLowerCase() + 's tienen una vigencia de 48hs iniciado el proceso, una vez cumplidas las 48hs la misma caduca y se deberá volver a iniciar el proceso';
    }

    get licenciasLabel() {
        return this.community.toLowerCase() == 'venta' ? 'Ir a consulta de licencias' : 'Ir a mis licencias';
    }

    get regaliaEnlistPendienteText(){
        return 'En caso que exista una factura pendiente de pago por Regalía Enlist, la actual compra de HT no cancela la misma.';
    }
}