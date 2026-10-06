import { LightningElement, api } from 'lwc';

const SELECT_OPEN_EVENT = 'seselectopen';

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
    /** Pill compacto para filas horizontales (mobile). */
    @api inline = false;
    _options = [];
    open = false;
    menuStyle = '';
    _onPointerDown;
    _onSiblingOpen;
    _onReposition;

    @api
    get options() {
        return this._options;
    }
    set options(value) {
        this._options = Array.isArray(value) ? value : [];
    }

    @api
    close() {
        this.open = false;
        this.menuStyle = '';
        this.unbindReposition();
    }

    connectedCallback() {
        this._onPointerDown = (event) => {
            const path = typeof event.composedPath === 'function' ? event.composedPath() : [];
            if (path.includes(this.template.host)) return;
            this.close();
        };
        this._onSiblingOpen = (event) => {
            if (event.detail?.source !== this) {
                this.close();
            }
        };
        this._onReposition = () => {
            if (this.open && this.inline) {
                this.positionMenu();
            }
        };
        window.addEventListener('pointerdown', this._onPointerDown);
        window.addEventListener(SELECT_OPEN_EVENT, this._onSiblingOpen);
    }

    disconnectedCallback() {
        window.removeEventListener('pointerdown', this._onPointerDown);
        window.removeEventListener(SELECT_OPEN_EVENT, this._onSiblingOpen);
        this.unbindReposition();
    }

    get triggerLabel() {
        const match = this._options.find((opt) => opt.value === this.value);
        return match ? match.label : this.placeholder;
    }

    get triggerClass() {
        const classes = ['dd-trigger'];
        if (this.open) classes.push('is-open');
        if (this.value) classes.push('has-value');
        return classes.join(' ');
    }

    get menuClass() {
        return 'dd-menu' + (this.inline ? ' dd-menu-fixed' : '');
    }

    get menuItems() {
        return this._options.map((opt, index) => ({
            key: opt.value === '' ? `opt-empty-${index}` : opt.value,
            value: opt.value,
            label: opt.label,
            itemClass: opt.value === this.value ? 'dd-item is-active' : 'dd-item'
        }));
    }

    bindReposition() {
        window.addEventListener('scroll', this._onReposition, true);
        window.addEventListener('resize', this._onReposition);
    }

    unbindReposition() {
        window.removeEventListener('scroll', this._onReposition, true);
        window.removeEventListener('resize', this._onReposition);
    }

    positionMenu() {
        const trigger = this.template.querySelector('.dd-trigger');
        if (!trigger) {
            return;
        }

        const rect = trigger.getBoundingClientRect();
        const width = Math.max(rect.width, 168);
        let left = rect.left;
        const maxLeft = window.innerWidth - width - 8;

        if (left > maxLeft) {
            left = Math.max(8, maxLeft);
        }

        this.menuStyle = [
            `top:${Math.round(rect.bottom + 8)}px`,
            `left:${Math.round(left)}px`,
            `width:${Math.round(width)}px`
        ].join(';');
    }

    toggle(event) {
        event.stopPropagation();
        const willOpen = !this.open;
        if (willOpen) {
            window.dispatchEvent(
                new CustomEvent(SELECT_OPEN_EVENT, {
                    detail: { source: this }
                })
            );
        }

        this.open = willOpen;

        if (willOpen && this.inline) {
            this.bindReposition();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            requestAnimationFrame(() => this.positionMenu());
        } else {
            this.menuStyle = '';
            this.unbindReposition();
        }
    }

    renderedCallback() {
        if (this.open && this.inline) {
            this.positionMenu();
        }
    }

    handlePick(event) {
        const value = event.currentTarget.dataset.value;
        this.close();
        this.dispatchEvent(new CustomEvent('change', { detail: { value } }));
    }
}
