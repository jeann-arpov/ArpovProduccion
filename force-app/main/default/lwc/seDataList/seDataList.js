import { LightningElement, api } from 'lwc';

export default class SeDataList extends LightningElement {
    @api records = [];
    @api columns = [];
    @api mobileFields = [];
    @api titleField = 'title';
    @api badgeField = 'statusLabel';
    @api badgeToneField = 'statusTone';
    @api keyField = 'id';
    @api actionLabel = 'Ver';
    @api mobileActionLabel = 'Ver →';
    @api emptyText = 'No hay registros para mostrar.';
    @api actionDisabledField = 'actionDisabled';

    get headerCells() {
        return (this.columns || []).map((col, index) => ({
            key: `h-${index}`,
            label: col.label || ''
        }));
    }

    get items() {
        const records = this.records || [];
        const columns = this.columns || [];
        const mobileFields = this.mobileFields || [];

        return records.map((record) => {
            const key = String(record[this.keyField] ?? '');
            const tone = record[this.badgeToneField] || 'info';
            const actionDisabled = Boolean(record[this.actionDisabledField]);

            return {
                key,
                mobileKey: `m-${key}`,
                title: record[this.titleField],
                badgeLabel: record[this.badgeField],
                badgeClass: `badge ${tone}`,
                actionDisabled,
                cells: columns.map((col, index) => {
                    const type = col.type || 'text';
                    return {
                        key: `${key}-c${index}`,
                        value: record[col.fieldName],
                        isLink: type === 'link',
                        isBadge: type === 'badge',
                        isAction: type === 'action',
                        isText: type === 'text',
                        badgeClass: type === 'badge' ? `badge ${record[col.toneField || this.badgeToneField] || 'info'}` : '',
                        actionLabel: col.actionLabel || this.actionLabel,
                        tdClass: type === 'action' ? 'td-action' : ''
                    };
                }),
                fields: mobileFields.map((field, index) => ({
                    labelKey: `${key}-k${index}`,
                    valueKey: `${key}-v${index}`,
                    label: field.label,
                    value: record[field.fieldName]
                }))
            };
        });
    }

    get isEmpty() {
        return !this.records || this.records.length === 0;
    }

    handleOpen(event) {
        const key = event.currentTarget.dataset.key;
        const row = (this.records || []).find((record) => String(record[this.keyField] ?? '') === key);
        this.dispatchEvent(
            new CustomEvent('rowaction', {
                detail: { action: 'open', row, key }
            })
        );
    }
}
