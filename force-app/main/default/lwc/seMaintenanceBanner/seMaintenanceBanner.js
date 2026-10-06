import { LightningElement, api } from 'lwc';

const EXCLUDED_URL_KEYWORDS = ['comercio', 'obtentor'];

export default class SeMaintenanceBanner extends LightningElement {
    // Requeridas por el targetConfig ya usado en el sitio; el template no las usa.
    @api pillLabel;
    @api title;
    @api titleAccent;
    @api message;
    @api note;
    @api confirmLabel;

    pillText = 'Novedades';
    headingText = 'Estamos renovando';
    headingAccent = 'tu portal';
    messageText = 'Lo estamos haciendo más simple para que gestiones tus licencias, HT y Cuenta Granaria en menos pasos, desde la compu o el celular.';
    noteText = 'Si no podés ingresar o algo no funciona como esperás, volvé a intentar en unos minutos.';
    buttonText = 'Entendido';

    items = [
        {
            key: 'ht',
            icon: 'utility:cart',
            heading: 'Compra HT',
            description: 'Puede que no puedas registrar compras de HT mientras dure el mantenimiento.'
        },
        {
            key: 'cg',
            icon: 'utility:apps',
            heading: 'Cuenta Granaria',
            description: 'Los saldos y movimientos podrían no verse actualizados.'
        },
        {
            key: 'time',
            icon: 'utility:clock',
            heading: 'Volvemos pronto',
            description: 'Estamos trabajando para restablecer todo lo antes posible.'
        }
    ];

    dismissed = false;

    get isVisible() {
        if (this.dismissed) {
            return false;
        }
        const url = (window.location.href || '').toLowerCase();
        return !EXCLUDED_URL_KEYWORDS.some((keyword) => url.includes(keyword));
    }

    close() {
        this.dismissed = true;
    }

    handleOverlayClick(event) {
        if (event.target.classList.contains('se-maint-overlay')) {
            this.close();
        }
    }
}
