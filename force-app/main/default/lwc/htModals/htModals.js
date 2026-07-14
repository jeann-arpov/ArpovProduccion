import { LightningElement, api } from 'lwc';
import SVG_ICONS from '@salesforce/resourceUrl/iconos_SE';
import { NavigationMixin } from 'lightning/navigation';

export default class HtModals extends NavigationMixin(LightningElement) {
    @api currentModal;
    @api community;
    @api esPuntoVenta;
    @api showFacturaRegaliaEnlistMsg;
    @api promoMessage;
    @api promoVariant = 'success';

    icons = {
        'error': SVG_ICONS + '/iconos/popup/Icon-feather-alert-circle.svg#Icon_feather-alert-circle',
        'facturas': SVG_ICONS + '/iconos/venta/Icon-awesome-receipt.svg#Icon_awesome-receipt',
        'licencias': SVG_ICONS + '/iconos/venta/Icon-feather-file.svg#Icon_feather-file'
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

    get canClose() {
        return !this.showFacturando;
    }

    get showModal() {
        return this.currentModal != null;
    }

    closeModal(event) {
        this.currentModal = null;
        this.dispatchEvent(new CustomEvent('close'));
    }

    get finalizadaText() {
        return this.community + ' ' + this.currentModal;
    }

    get finalizadaSubText() {
        const prefix = this.currentModal == "finalizada" ? `Felicitaciones! Ya finalizaste tu ${this.community} de HT y en los próximos días vas a estar recibiendo la factura.` : `Queda pendiente tu ${this.community} de HT hasta que se gestionen las licencias que faltan.`;
        return prefix + ` Por cualquier duda, no dejes de contactarte con nosotros:

        Whatsapp: +54 9 11 3117-2022
        E-mail: info@sembraevolucion.com.ar
        Teléfono: +54 11 5077-9090`;
    }

    get vigenciaText() {
        return 'Las ' + this.community.toLowerCase() + 's tienen una vigencia de 48hs iniciado el proceso, una vez cumplidas las 48hs la misma caduca y se deberá volver a iniciar el proceso'
    }

    get licenciasLabel() {
        return this.community.toLowerCase() == 'venta' ? 'Ir a consulta de licencias' : 'Ir a mis licencias';
    }

    get regaliaEnlistPendienteText(){
        return 'En caso que exista una factura pendiente de pago por Regalía Enlist, la actual compra de HT no cancela la misma.';
    }

    redirectMisLicencias() {
        this.dispatchEvent(new CustomEvent('redirect', {detail: "licencias"}));
    }

    redirectMisFacturas() {
        this.dispatchEvent(new CustomEvent('redirect', {detail: "facturas"}));
    }

    anular() {
        this.dispatchEvent(new CustomEvent('anular'));
    }

    redirectCompras() {
        this.dispatchEvent(new CustomEvent('redirect', {detail: "compras"}));
    }

    redirectVentas() {
        this.dispatchEvent(new CustomEvent('redirect', {detail: "ventas"}));
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

    // Oculta la X solo en tipo-pago y también evita cerrar mientras factura
    get showClose() {
    return this.canClose && !this.showTipoPago;
    }

    stopPropagation(event) {
    event.preventDefault();
    event.stopPropagation();
    }

    // Bloquea ESC en tipo-pago (por si tu overlay lo permite)
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

}