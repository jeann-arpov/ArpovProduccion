import { LightningElement, api } from 'lwc';
import searchDestinatarios from '@salesforce/apex/CesionPPH.searchDestinatarios';
import {errorEvent} from 'c/utils';
import icons from 'c/icons';

const MARCAS = {
    '03': 'DONMARIO',
    '04': 'NIDERA',
    '05': 'BUCK',
    '06': 'KLEIN',
    '12': 'LG',
    '13': 'PIONEER',
    '14': 'ILLINOIS',
    '16': 'MACROSEED',
    '19': 'BIOCERES',
    '23': 'NK',
    '24': 'STINE',
    '51': 'QUILMES',
    '77': 'CREDENZ',
    '85': 'NEOGEN',
    '87': 'BREVANT',
    '90': 'NORD'
};

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
    wizardInputs = {};
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
            const inputs = {};
            for (const linea of this.info?.lineas || []) {
                const qty = this.getLineaCantidad(linea.id);
                inputs[linea.id] = qty > 0 ? this.formatTon(qty) : '';
            }
            this.wizardInputs = inputs;
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
        return this.computeTotalFromLineas();
    }

    get wizardTotalLabel() {
        return this.formatTon(this.wizardToneladasNum);
    }

    brandFor(variedad) {
        return MARCAS[variedad?.Obtentor_Comercializa__r?.Id_Obtentor__c] || '';
    }

    get wizardLineas() {
        return (this.info?.lineas || [])
            .filter((linea) => this.lineaCapacidad(linea) > 0 || this.getLineaCantidad(linea.id) > 0)
            .map((linea) => {
                const capacidad = this.lineaCapacidad(linea);
                const hasError = this.getLineaCantidad(linea.id) > capacidad;
                const name = linea.variedad?.Name || 'Variedad';
                return {
                    id: linea.id,
                    name,
                    brand: this.brandFor(linea.variedad),
                    disponibleLabel: this.formatTon(capacidad),
                    input: this.wizardInputs[linea.id] ?? '',
                    hasError,
                    rowClass: `se-var-row${hasError ? ' is-error' : ''}`,
                    inputWrapClass: `se-var-input-wrap${hasError ? ' se-ton-input-wrap--error' : ''}`,
                    ariaLabel: `Toneladas a ceder de ${name}`,
                    ariaInvalid: hasError ? 'true' : 'false'
                };
            });
    }

    get hasWizardLineas() {
        return this.wizardLineas.length > 0;
    }

    get hasToneladasError() {
        return this.wizardLineas.some((linea) => linea.hasError);
    }

    get isWizardToneladasValid() {
        return this.wizardToneladasNum > 0 && !this.hasToneladasError;
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

    handleLineaInput(event) {
        const id = event.target.dataset.id;
        const raw = event.target.value;
        this.wizardInputs = { ...this.wizardInputs, [id]: raw };
        const next = this.parseTon(raw);
        const old = this.getLineaCantidad(id);
        if (next !== old) {
            this.wizardCantidades = { ...this.wizardCantidades, [id]: next };
            this.notifyCantidadChange(id, next - old);
        }
        this.dispatchToneladasChange();
    }

    handleLineaBlur(event) {
        const id = event.target.dataset.id;
        const n = this.getLineaCantidad(id);
        const formatted = n > 0 ? this.formatTon(n) : '';
        this.wizardInputs = { ...this.wizardInputs, [id]: formatted };
        event.target.value = formatted;
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
            if (this.hasToneladasError) {
                return false;
            }
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