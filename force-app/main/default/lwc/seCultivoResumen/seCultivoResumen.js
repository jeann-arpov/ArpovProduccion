import { LightningElement, api } from 'lwc';

/**
 * Tabs de cultivo + card de resumen (patrón mvt-tabs / mvt-saldo del LSG).
 *
 * @api cultivos — [{ value, label }]
 * @api selected — value del tab activo
 * @api summaryTitle — título de la card (default: Total por biotecnología)
 * @api rows — [{ label, value }] desglose; value numérico o string
 * @api totalLabel — etiqueta del total (default: Total HT)
 * @api totalValue — total numérico o string
 * @api loading — muestra skeleton en la card
 * @api emptyText — texto si no hay filas ni total
 *
 * @fires select — detail: { value }
 */
export default class SeCultivoResumen extends LightningElement {
    @api cultivos = [];
    @api selected = '';
    @api summaryTitle = 'Total por biotecnología';
    @api rows = [];
    @api totalLabel = 'Total HT';
    @api totalValue;
    @api loading = false;
    @api emptyText = 'Sin datos para este cultivo.';
    /** En mobile oculta tabs + card de saldo (ej. Licencias 2c). */
    @api hideSummaryOnMobile = false;

    get resumenClass() {
        return 'resumen' + (this.hideSummaryOnMobile ? ' resumen-compact-mobile' : '');
    }

    get tabItems() {
        return (this.cultivos || []).map((c) => {
            const isActive = String(c.value) === String(this.selected);
            return {
                value: c.value,
                label: c.label,
                tabClass: 'tab' + (isActive ? ' tab-active' : ''),
                ariaSelected: isActive
            };
        });
    }

    get hasTabs() {
        return this.tabItems.length > 0;
    }

    get summaryRows() {
        return (this.rows || []).map((row, index) => ({
            key: `row-${index}`,
            label: row.label,
            value: this.formatValue(row.value)
        }));
    }

    get hasSummaryContent() {
        return this.summaryRows.length > 0 || this.hasTotal;
    }

    get hasTotal() {
        return this.totalValue !== undefined && this.totalValue !== null && this.totalValue !== '';
    }

    get formattedTotal() {
        return this.formatValue(this.totalValue);
    }

    get saldoClass() {
        return 'saldo';
    }

    formatValue(value) {
        if (value === undefined || value === null || value === '') {
            return '—';
        }
        if (typeof value === 'number') {
            return value.toLocaleString('es-AR', { maximumFractionDigits: 0 });
        }
        const num = Number(value);
        if (!Number.isNaN(num) && String(value).trim() !== '') {
            return num.toLocaleString('es-AR', { maximumFractionDigits: 0 });
        }
        return String(value);
    }

    handleTabSelect(event) {
        const value = event.currentTarget.dataset.value;
        if (String(value) === String(this.selected)) {
            return;
        }
        this.dispatchEvent(
            new CustomEvent('select', {
                detail: { value },
                bubbles: true,
                composed: true
            })
        );
    }
}
