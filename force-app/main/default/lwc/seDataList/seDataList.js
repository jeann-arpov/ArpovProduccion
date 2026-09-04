import { LightningElement, api, track } from 'lwc';

/**
 * Desktop table + mobile cards, with optional built-in pagination.
 * @api pageSize - 0 = no pager (default). Set e.g. 200 on Compras / Facturas.
 */
export default class SeDataList extends LightningElement {
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
    /** Si está definido, usa el label por fila en mobile (ej. "Continuar adhesión →"). */
    @api mobileActionLabelField = '';
    /** Campo por fila: "primary" | "ghost" | "link" para el CTA mobile. */
    @api mobileActionVariantField = '';
    /** CTA mobile por defecto: "primary" | "ghost" | "link" (subrayado, mock LSG). */
    @api mobileActionVariant = 'primary';
    /** Oculta el CTA inferior en cards mobile (ej. Movimientos HT). */
    @api hideMobileAction = false;
    /** Rows per page. 0 = show all, no pager (default). */
    @api pageSize = 0;
    @api loading = false;

    _records = [];
    @track currentPage = 1;

    @api
    get records() {
        return this._records;
    }
    set records(value) {
        this._records = Array.isArray(value) ? value : [];
        this.currentPage = 1;
    }

    get resolvedPageSize() {
        const size = Number(this.pageSize);
        if (Number.isNaN(size) || size < 0) return 0;
        return size;
    }

    get paginationEnabled() {
        return this.resolvedPageSize > 0;
    }

    get pageRecords() {
        if (!this.paginationEnabled) return this._records;
        const size = this.resolvedPageSize;
        const start = (this.currentPage - 1) * size;
        return this._records.slice(start, start + size);
    }

    get showPager() {
        return this.paginationEnabled && this._records.length > 0;
    }

    get disablePrev() {
        return this.currentPage <= 1;
    }

    get disableNext() {
        return this.currentPage * this.resolvedPageSize >= this._records.length;
    }

    get headerCells() {
        return (this.columns || []).map((col, index) => ({
            key: `h-${index}`,
            label: col.label || '',
            thClass: col.type === 'action' ? 'th-action' : ''
        }));
    }

    get items() {
        const records = this.pageRecords;
        const columns = this.columns || [];
        const mobileFields = this.mobileFields || [];

        return records.map((record) => {
            const key = String(record[this.keyField] ?? '');
            const tone = record[this.badgeToneField] || 'info';
            const actionDisabled = Boolean(record[this.actionDisabledField]);
            const mobileActionLabel = this.mobileActionLabelField
                ? record[this.mobileActionLabelField] || this.mobileActionLabel
                : this.mobileActionLabel;
            const mobileVariant = this.mobileActionVariantField
                ? record[this.mobileActionVariantField] || this.mobileActionVariant
                : this.mobileActionVariant;
            let mobileActionClass = 'lic-more lic-more--primary';
            if (mobileVariant === 'ghost') {
                mobileActionClass = 'lic-more lic-more--ghost';
            } else if (mobileVariant === 'link') {
                mobileActionClass = 'lic-more lic-more--link';
            }

            return {
                key,
                mobileKey: `m-${key}`,
                title: record[this.titleField],
                badgeLabel: record[this.badgeField],
                badgeClass: `badge ${tone}`,
                actionDisabled,
                mobileActionLabel,
                mobileActionClass,
                cells: columns.map((col, index) => {
                    const type = col.type || 'text';
                    const isAmount = type === 'amount';
                    const isStrong = type === 'strong';
                    const isAccent = type === 'accent';
                    const rawValue = record[col.fieldName];
                    const mailtoHref =
                        type === 'mailto' && rawValue ? `mailto:${String(rawValue).trim()}` : '';
                    return {
                        key: `${key}-c${index}`,
                        value: rawValue,
                        isLink: type === 'link',
                        isMailto: type === 'mailto' && Boolean(mailtoHref),
                        mailtoHref,
                        isBadge: type === 'badge',
                        isAction: type === 'action',
                        isText: type === 'text' && !isAmount && !isStrong && !isAccent,
                        isAmount,
                        isStrong,
                        isAccent,
                        amountClass: isAmount ? 'amount' : '',
                        strongClass: isStrong ? 'cell-strong' : '',
                        accentClass: isAccent ? 'cell-accent' : '',
                        badgeClass:
                            type === 'badge'
                                ? `badge ${record[col.toneField || this.badgeToneField] || 'info'}`
                                : '',
                        actionLabel: col.actionLabel || this.actionLabel,
                        tdClass: type === 'action' ? 'td-action' : ''
                    };
                }),
                fields: mobileFields
                    .map((field, index) => {
                    const extraClass = field.valueClassField
                        ? record[field.valueClassField] || ''
                        : '';
                    const label = field.labelFieldName
                        ? record[field.labelFieldName] || field.label || ''
                        : field.label;
                    const value = record[field.fieldName];
                    return {
                        labelKey: `${key}-k${index}`,
                        valueKey: `${key}-v${index}`,
                        label,
                        value,
                        valueClass: ('v' + (extraClass ? ` ${extraClass}` : '')).trim()
                    };
                })
                    .filter((field) => field.label || field.value)
            };
        });
    }

    get isEmpty() {
        return !this.loading && (!this._records || this._records.length === 0);
    }

    get showList() {
        return !this.loading && !this.isEmpty;
    }

    get skeletonRows() {
        const cols = (this.columns || []).length || 4;
        return [0, 1, 2, 3, 4, 5].map((row) => ({
            key: `sk-r${row}`,
            cells: Array.from({ length: cols }, (_, i) => ({ key: `sk-r${row}-c${i}` }))
        }));
    }

    get skeletonCards() {
        return [0, 1, 2].map((i) => ({ key: `sk-card-${i}` }));
    }

    handlePrev() {
        if (this.currentPage > 1) {
            this.currentPage -= 1;
        }
    }

    handleNext() {
        if (this.currentPage * this.resolvedPageSize < this._records.length) {
            this.currentPage += 1;
        }
    }

    handleOpen(event) {
        const key = event.currentTarget.dataset.key;
        const row = this._records.find((record) => String(record[this.keyField] ?? '') === key);
        this.dispatchEvent(
            new CustomEvent('rowaction', {
                detail: { action: 'open', row, key }
            })
        );
    }
}
