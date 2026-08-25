import { LightningElement, api } from 'lwc';

/**
 * Custom select matching Productor DS (not native &lt;select&gt;).
 * @api options - [{ value, label }]
 * @api value - selected value
 * @api placeholder - shown when value empty / not found
 * @fires change - detail: { value }
 */
export default class SeSelect extends LightningElement {
    @api value = '';
    @api placeholder = 'Seleccionar';
    _options = [];
    open = false;
    _onPointerDown;

    @api
    get options() {
        return this._options;
    }
    set options(value) {
        this._options = Array.isArray(value) ? value : [];
    }

    connectedCallback() {
        this._onPointerDown = (event) => {
            const path = typeof event.composedPath === 'function' ? event.composedPath() : [];
            if (path.includes(this.template.host)) return;
            this.open = false;
        };
        window.addEventListener('pointerdown', this._onPointerDown);
    }

    disconnectedCallback() {
        window.removeEventListener('pointerdown', this._onPointerDown);
    }

    get triggerLabel() {
        const match = this._options.find((opt) => opt.value === this.value);
        return match ? match.label : this.placeholder;
    }

    get triggerClass() {
        return this.open ? 'dd-trigger is-open' : 'dd-trigger';
    }

    get menuItems() {
        return this._options.map((opt) => ({
            value: opt.value,
            label: opt.label,
            itemClass: opt.value === this.value ? 'dd-item is-active' : 'dd-item'
        }));
    }

    toggle(event) {
        event.stopPropagation();
        this.open = !this.open;
    }

    handlePick(event) {
        const value = event.currentTarget.dataset.value;
        this.open = false;
        this.dispatchEvent(new CustomEvent('change', { detail: { value } }));
    }
}
