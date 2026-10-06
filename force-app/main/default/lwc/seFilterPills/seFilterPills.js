import { LightningElement, api } from 'lwc';

/**
 * @api items - [{ id, label, count?, selected? }]
 * @fires select - detail: { id }
 */
export default class SeFilterPills extends LightningElement {
    _items = [];

    @api
    get items() {
        return this._items;
    }
    set items(value) {
        this._items = Array.isArray(value) ? value : [];
    }

    get pills() {
        return this._items.map((item) => ({
            id: item.id,
            label: item.label,
            count: item.count,
            showCount: item.count != null && item.count !== '',
            className: item.selected ? 'pill is-active' : 'pill'
        }));
    }

    handleClick(event) {
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('select', { detail: { id } }));
    }
}
