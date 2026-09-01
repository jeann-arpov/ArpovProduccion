import { LightningElement, api } from 'lwc';
import searchDestinatarios from '@salesforce/apex/CesionPPH.searchDestinatarios';
import {errorEvent} from 'c/utils';
import icons from 'c/icons';

export default class DestinatarioPph extends LightningElement {
    /** 'all' | 'destinatario' | 'toneladas' — wizard mobile split (SG 3g / 3h). */
    @api phase = 'all';
    /** 'legacy' | 'wizard' — SG 3g mobile cards. */
    @api variant = 'legacy';
    @api cultivoLabel = '';
    @api contratoTitle = '';
    @api allowRemove = false;
    @api info;
    @api hiding;

    destinatario;
    icons = icons;
    collapsed;
    wizardInput = '';
    wizardInputInitialized = false;
    wizardCantidades = {};

    connectedCallback() {
        this.syncDestinatarioFromInfo();
    }

    syncDestinatarioFromInfo() {
        if (this.destinatario == null && this.info?.account) {
            this.destinatario = this.info.account;
        }
    }

    remove(event) {
        this.dispatchEvent(new CustomEvent('remove'));
    }

    async search(event) {
        const lookup = event.target;
        await searchDestinatarios(event.detail).then(res => lookup.setSearchResults(res)).catch(e => this.onError(e));
    }

    onError(e) {
        this.dispatchEvent(errorEvent(e));
    }

    destinatarioSelected(event) {
        const selection = event.target.getSelection();
        this.destinatario = selection.length ? selection[0] : null;
        this.dispatchSelectionChange();
        this.autosave();
    }

    dispatchSelectionChange() {
        this.dispatchEvent(
            new CustomEvent('selectionchange', {
                detail: { hasSelection: this.destinatario != null },
                bubbles: true,
                composed: true
            })
        );
    }

    openDestinatarioSearch() {
        this.destinatario = null;
        this.dispatchSelectionChange();
    }

    handleDestCardKeydown(event) {
        if (event.key === 'Enter' || event.key === ' ') {
            event.preventDefault();
            this.openDestinatarioSearch();
        }
    }

    get isWizardVariant() {
        return this.variant === 'wizard';
    }

    get hasDestinatario() {
        return this.destinatario != null;
    }

    get destinatarioDisplayName() {
        const rec = this.destinatario?.record || this.info?.account?.record;
        return (
            rec?.ERPvs__Denominacion_Y_Razon_Social__c ||
            rec?.Name ||
            this.destinatario?.title?.split(' - ').slice(1).join(' - ') ||
            this.info?.account?.title?.split(' - ').slice(1).join(' - ') ||
            ''
        );
    }

    get destinatarioDisplayCuit() {
        const cuit = this.destinatario?.record?.N_CUIT__c || this.info?.account?.record?.N_CUIT__c;
        if (!cuit) {
            return (
                this.destinatario?.title?.split(' - ')[0] ||
                this.info?.account?.title?.split(' - ')[0] ||
                ''
            );
        }
        return `CUIT ${cuit}`;
    }

    handleRemove(e) {
        this.destinatario = null;
    }

    updateCantidad(event) {
        this.dispatchEvent(new CustomEvent('updatecantidad', {detail: event.detail}));
    }

    autosave(e) {
        this.dispatchEvent(new CustomEvent('autosave'));
    }

    changeCollapsed(event) {
        this.collapsed = !this.collapsed;
    }

    get disabled() {
        return this.destinatario == null;
    }

    get showDestinatarioBlock() {
        return this.phase === 'all' || this.phase === 'destinatario';
    }

    get showToneladasBlock() {
        if (this.phase === 'toneladas') {
            return true;
        }
        return this.phase === 'all' && !this.disabled;
    }

    get showWizardToneladas() {
        return this.isWizardVariant && this.showToneladasBlock;
    }

    renderedCallback() {
        this.syncDestinatarioFromInfo();

        if (this.showWizardToneladas && !this.wizardInputInitialized) {
            this.wizardInputInitialized = true;
            const total = this.computeTotalFromLineas();
            this.wizardInput = total > 0 ? this.formatTon(total) : '';
            this.distributeWizardToneladas(this.computeTotalFromLineas());
            this.dispatchToneladasChange();
        }
    }

    computeTotalFromLineas() {
        return (this.info?.lineas || []).reduce(
            (sum, linea) => sum + this.getLineaCantidad(linea.id),
            0
        );
    }

    getLineaCantidad(lineaId) {
        if (Object.prototype.hasOwnProperty.call(this.wizardCantidades, lineaId)) {
            return Number(this.wizardCantidades[lineaId]) || 0;
        }
        const linea = (this.info?.lineas || []).find((l) => l.id === lineaId);
        return Number(linea?.record?.Cantidad__c) || 0;
    }

    get totalSaldoDisponible() {
        return (this.info?.lineas || []).reduce((sum, linea) => sum + this.lineaCapacidad(linea), 0);
    }

    lineaCapacidad(linea) {
        const stock = linea.variedad?.totals?.stock || 0;
        const current = linea.variedad?.totals?.current || 0;
        const own = this.getLineaCantidad(linea.id);
        return Math.max(0, stock - current + own);
    }

    get saldoDisponibleLabel() {
        return `${this.formatTon(this.totalSaldoDisponible)} t`;
    }

    get wizardToneladasNum() {
        return this.parseTon(this.wizardInput);
    }

    get hasToneladasError() {
        const n = this.wizardToneladasNum;
        return this.wizardInput !== '' && n > 0 && n > this.totalSaldoDisponible;
    }

    get toneladasErrorDetail() {
        return `Podés ceder hasta ${this.formatTon(this.totalSaldoDisponible)} t de ${this.cultivoLabel}. Ajustá la cantidad para continuar.`;
    }

    get tonInputWrapClass() {
        let cls = 'se-ton-input-wrap';
        if (this.hasToneladasError) cls += ' se-ton-input-wrap--error';
        return cls;
    }

    get isWizardToneladasValid() {
        const n = this.wizardToneladasNum;
        return n > 0 && n <= this.totalSaldoDisponible;
    }

    parseTon(value) {
        if (value == null || value === '') return 0;
        const normalized = String(value).replace(/\./g, '').replace(',', '.');
        const n = Number(normalized);
        return Number.isFinite(n) ? n : 0;
    }

    formatTon(n) {
        return Number(n).toLocaleString('es-AR', { maximumFractionDigits: 0 });
    }

    handleWizardToneladasInput(event) {
        this.wizardInput = event.target.value;
        this.distributeWizardToneladas(this.wizardToneladasNum);
        this.dispatchToneladasChange();
    }

    handleWizardToneladasBlur(event) {
        const n = this.wizardToneladasNum;
        this.wizardInput = n > 0 ? this.formatTon(n) : '';
        event.target.value = this.wizardInput;
        this.dispatchToneladasChange();
    }

    distributeWizardToneladas(targetTotal) {
        const lineas = this.info?.lineas || [];
        const target = Math.max(0, Number(targetTotal) || 0);

        lineas.forEach((linea) => {
            const oldQty = this.getLineaCantidad(linea.id);
            if (oldQty > 0) {
                this.notifyCantidadChange(linea.id, -oldQty);
            }
            this.wizardCantidades[linea.id] = 0;
        });

        let remaining = target;
        const order = lineas
            .map((linea, index) => ({
                index,
                capacity: Math.max(
                    0,
                    (linea.variedad?.totals?.stock || 0) - (linea.variedad?.totals?.current || 0)
                )
            }))
            .sort((a, b) => b.capacity - a.capacity);

        for (const { index, capacity } of order) {
            if (remaining <= 0) break;
            const assign = Math.min(remaining, capacity);
            if (assign <= 0) continue;
            const linea = lineas[index];
            this.wizardCantidades[linea.id] = assign;
            this.notifyCantidadChange(linea.id, assign);
            remaining -= assign;
        }
    }

    notifyCantidadChange(variedad, cantidad) {
        this.dispatchEvent(new CustomEvent('updatecantidad', { detail: { variedad, cantidad } }));
    }

    dispatchToneladasChange() {
        this.dispatchEvent(
            new CustomEvent('toneladaschange', {
                detail: { valid: this.isWizardToneladasValid, total: this.wizardToneladasNum },
                bubbles: true,
                composed: true
            })
        );
    }

    hasNegativeStock() {
        return (this.info?.lineas || []).some((linea) => {
            const stock = linea.variedad?.totals?.stock || 0;
            const current = linea.variedad?.totals?.current || 0;
            return stock - current < 0;
        });
    }

    get infoClass() {
        let cls = "info";
        if (this.collapsed) cls += " collapsed";
        if (this.disabled) cls += " disabled";
        return cls;
    }

    //devuelve true si no hubo errores
    @api
    validate(isContinue = false) {
        let valid = true;
        const checkDestinatario = this.phase === 'all' || this.phase === 'destinatario';
        const checkToneladas = this.phase === 'all' || this.phase === 'toneladas';

        if (this.showWizardToneladas && checkToneladas) {
            const total = this.wizardToneladasNum;
            if (total <= 0) {
                throw 'Debe ingresarse una cantidad distinta a 0 para poder avanzar';
            }
            if (total > this.totalSaldoDisponible) {
                return false;
            }
            this.distributeWizardToneladas(total);
            if (isContinue && this.hasNegativeStock()) {
                throw 'Debe comprar HT para poder avanzar con la cesión';
            }
        } else {
            if (checkToneladas) {
                for (const element of this.template.querySelectorAll('lightning-input')) {
                    if (!element.reportValidity()) valid = false;
                }
            }

            let total = 0;

            if (checkToneladas) {
                for (const element of this.template.querySelectorAll('c-linea-destinatario-pph')) {
                    if (!element.validate(isContinue)) valid = false;
                    total += element.getData().cantidad;
                }
            }

            if (checkToneladas && valid && total == 0) {
                throw 'Debe ingresarse cantidad distinto a 0 en al menos una variedad para poder avanzar';
            }
        }

        if (checkDestinatario && this.destinatario == null) {
            throw 'Debe ingresar un destinatario para poder avanzar';
        }

        return valid;
    }

    get variedadesPPH() {
        return Array.from(this.template.querySelectorAll('c-linea-destinatario-pph'));
    }

    @api getData() {
        if (this.showWizardToneladas) {
            const variedades = {};
            for (const linea of this.info?.lineas || []) {
                const cantidad = this.getLineaCantidad(linea.id);
                if (cantidad > 0 || linea.record?.Id) {
                    variedades[linea.id] = {
                        id: linea.record?.Id,
                        cantidad,
                        variedad: linea.variedad,
                        license: linea.record?.Licencia__c
                    };
                }
            }
            return {
                destinatarioId: this.destinatario?.record?.Id || this.info?.account?.id,
                variedades,
                id: this.info.record.Id,
                record: this.info.record,
                destinatarioRecord: this.destinatario?.record
            };
        }

        const variedades = Object.fromEntries(this.variedadesPPH.filter(v => v.cantidad > 0 || v.info.record.Id).map(v => [v.info.id, v.getData()]));
        return {destinatarioId: this.destinatario?.record.Id, variedades, id: this.info.record.Id, record: this.info.record, destinatarioRecord: this.destinatario?.record}
    }

    @api getAccount() {
        return this.destinatario;
    }

    get destinatarioClass() {
        let cls = 'destinatario';
        if (this.isWizardVariant) cls += ' destinatario--wizard';
        if (this.hiding[this.info.id]) cls += ' slds-hide';
        if (this.info.record.Estado__c != 'En Curso') cls += ' disabled';
        return cls;
    }

    registerCuit() {
        this.dispatchEvent(new CustomEvent('registercuit', {detail: this.template.querySelector('c-lookup').getSearchTerm()}));
    }

    @api onRegisterCuit(res) {
        const lookup = this.template.querySelector('c-lookup');
        lookup.setSearchResults(res);

        if (res.length) {
            lookup.selection = res[0];
            this.destinatarioSelected({target: lookup});
        }
    }
}