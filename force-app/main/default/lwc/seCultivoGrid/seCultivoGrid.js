import { LightningElement, api } from 'lwc';
import resourcePortal from '@salesforce/resourceUrl/resourcePortal';

/**
 * @fires select — detail.value (Id del cultivo)
 */
export default class SeCultivoGrid extends LightningElement {
    @api eyebrow = '';
    @api title = 'Elegí el cultivo';
    @api subtitle = '';
    /** [{ value, label, saldo? }] — mismo shape que combobox Apex */
    @api options = [];
    @api selected;
    @api emptyText = 'No hay cultivos disponibles.';
    @api showSaldo = false;
    /** 'radio' = Compra HT tiles · 'cesion' = SG 3f saldo en toneladas */
    @api variant = 'radio';

    iconCebadaUrl = `${resourcePortal}/resourcePortal/images/prd-cebada.svg`;
    iconSojaUrl = `${resourcePortal}/resourcePortal/images/prd-soja.svg`;
    iconTrigoUrl = `${resourcePortal}/resourcePortal/images/prd-trigo.svg`;

    get isCesionVariant() {
        return this.variant === 'cesion';
    }

    get isRadioVariant() {
        return !this.isCesionVariant;
    }

    get panelClass() {
        return 'se-panel se-panel-step1' + (this.isCesionVariant ? ' se-panel--cesion' : '');
    }

    get items() {
        return (this.options || []).map((c) => {
            const id = c.value;
            const nombre = c.label || '';
            const saldo = this.resolveSaldo(c);
            const saldoNum = Number(saldo);
            const hasSaldo = Number.isFinite(saldoNum) && saldoNum > 0;
            const isSelected = String(this.selected) === String(id);
            const isDisabled = this.isCesionVariant && !hasSaldo;

            let saldoLabel = '';
            let statusLabel = '';
            let toneladasLabel = '';

            if (this.isCesionVariant) {
                const formatted = Number.isFinite(saldoNum)
                    ? saldoNum.toLocaleString('es-AR', { maximumFractionDigits: 0 })
                    : '0';
                toneladasLabel = `${formatted} t`;
                statusLabel = hasSaldo ? 'Saldo cedible' : 'Sin saldo cedible';
            } else if (this.showSaldo && saldo != null) {
                const formatted = Number.isFinite(saldoNum)
                    ? saldoNum.toLocaleString('es-AR', { maximumFractionDigits: 0 })
                    : String(saldo);
                saldoLabel = `Saldo · ${formatted} HT`;
            }

            let cssClass = 'se-cultivo-tile';
            if (this.isCesionVariant) cssClass += ' se-cultivo-tile--cesion';
            if (isSelected) cssClass += ' is-selected';
            if (isDisabled) cssClass += ' is-disabled';

            return {
                id,
                nombre,
                icono: this.getIcon(nombre),
                saldoLabel,
                statusLabel,
                toneladasLabel,
                isDisabled,
                ariaChecked: isSelected ? 'true' : 'false',
                cssClass
            };
        });
    }

    get isEmpty() {
        return !this.items.length;
    }

    resolveSaldo(c) {
        if (c.saldo != null) return c.saldo;
        if (c.Saldo__c != null) return c.Saldo__c;
        if (c.saldoHt != null) return c.saldoHt;
        return 0;
    }

    getIcon(nombre) {
        switch ((nombre || '').toLowerCase()) {
            case 'soja':
                return this.iconSojaUrl;
            case 'trigo':
                return this.iconTrigoUrl;
            case 'cebada':
                return this.iconCebadaUrl;
            default:
                return this.iconTrigoUrl;
        }
    }

    handleSelect(event) {
        const value = event.currentTarget.dataset.id;
        const item = this.items.find((c) => String(c.id) === String(value));
        if (item?.isDisabled) return;

        this.dispatchEvent(
            new CustomEvent('select', {
                detail: { value },
                bubbles: true,
                composed: true
            })
        );
    }
}
