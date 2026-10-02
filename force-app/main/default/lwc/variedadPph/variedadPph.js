import { LightningElement, api } from 'lwc';
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

const MSG_REQUERIDO = 'Este campo es obligatorio';
const MSG_ENTERO = 'Ingresá un número entero mayor o igual a 0';
const MSG_INSUFICIENTES =
    'HT disponibles insuficientes. Ingresá un valor menor o igual a las HT disponibles o comprá más hectáreas';

const fmt = (n) => new Intl.NumberFormat('es-AR').format(Number(n) || 0);

export default class VariedadPph extends LightningElement {
    @api info;
    _cantidad = 0;
    inputValue = '';
    lastCantidadSent = 0;
    showErrors = false;

    @api
    get cantidad() {
        return this._cantidad;
    }
    set cantidad(value) {
        this._cantidad = value;
    }

    connectedCallback() {
        if (this.initialized) return;
        this.initialized = true;
        const inicial = this.info?.record?.Cantidad_Declarada__c || 0;
        this._cantidad = inicial;
        this.inputValue = String(inicial);
        this.lastCantidadSent = inicial;
    }

    get safeCantidad() {
        return this._cantidad || 0;
    }

    get obtentor() {
        return this.info?.variedad?.Obtentor_Comercializa__r;
    }

    get icono() {
        return icons.semilleros[this.obtentor?.Id_Obtentor__c];
    }

    get brandLabel() {
        const id = this.obtentor?.Id_Obtentor__c;
        if (MARCAS[id]) return MARCAS[id];
        const name = this.obtentor?.Name || '';
        return name.replace(/\s*\([^)]*\)\s*$/, '').trim().toUpperCase() || '—';
    }

    get disponibles() {
        const totals = this.info?.variedad?.totals || {};
        return (totals.total || 0) - (totals.current || 0);
    }

    get safeDisponibles() {
        return Math.max(this.disponibles, 0);
    }

    get disponiblesLabel() {
        return fmt(this.safeDisponibles);
    }

    get numClass() {
        return this.safeDisponibles > 0 ? 'p-num' : 'p-num zero';
    }

    get maxValue() {
        return Math.max(this.disponibles + this.safeCantidad, 0);
    }

    get shouldShow() {
        return this.disponibles > 0 || this.safeCantidad > 0;
    }

    get errorMessage() {
        const raw = this.inputValue;
        if (raw === '' || raw == null) return MSG_REQUERIDO;
        const value = Number(raw);
        if (!Number.isInteger(value) || value < 0) return MSG_ENTERO;
        if (value > this.maxValue) return MSG_INSUFICIENTES;
        return null;
    }

    get visibleError() {
        return this.showErrors ? this.errorMessage : null;
    }

    get inputClass() {
        return this.visibleError ? 'p-input num err' : 'p-input num';
    }

    handleInput(event) {
        this.inputValue = event.target.value;
        this.showErrors = true;
        this._cantidad = this.errorMessage ? 0 : Number(this.inputValue);
        const delta = this._cantidad - this.lastCantidadSent;
        if (delta !== 0) {
            this.dispatchEvent(
                new CustomEvent('updatecantidad', {
                    detail: { variedad: this.info.variedad.Id, cantidad: delta }
                })
            );
        }
        this.lastCantidadSent = this._cantidad;
    }

    @api
    validate(report = true) {
        if (report) this.showErrors = true;
        return !this.errorMessage;
    }

    @api getData() {
        return {
            id: this.info.record.Id,
            cantidad: this.safeCantidad,
            variedad: this.info.variedad,
            icono: this.icono,
            brand: this.brandLabel
        };
    }

    handleBlur(event) {
        if (event.target.dataset.val !== event.target.value) {
            this.dispatchEvent(new CustomEvent('autosave'));
        }
    }

    handleFocus(event) {
        event.target.dataset.val = event.target.value;
    }
}
