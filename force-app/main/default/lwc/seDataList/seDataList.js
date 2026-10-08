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
    /** Si hay mensaje (ej. período finalizado), reemplaza el CTA por el texto. */
    @api actionDisabledMessageField = '';
    /** Label del CTA por fila en desktop (ej. Adherir / Abrir). */
    @api actionLabelField = '';
    /** Si está definido, usa el label por fila en mobile (ej. "Continuar adhesión →"). */
    @api mobileActionLabelField = '';
    /** Campo por fila: "primary" | "ghost" | "link" para el CTA mobile. */
    @api mobileActionVariantField = '';
    /** CTA mobile por defecto: "primary" | "ghost" | "link" (subrayado, mock LSG). */
    @api mobileActionVariant = 'primary';
    /** Oculta el CTA inferior en cards mobile (ej. Movimientos HT). */
    @api hideMobileAction = false;
    /** Acción secundaria por fila (ej. "Informar pago"); emite rowaction con action "secondary". */
    @api secondaryActionLabel = '';
    /** Campo booleano por fila que habilita la acción secundaria. */
    @api secondaryActionField = '';
    /** Campo por fila con texto de ayuda; si tiene valor se muestra un (i) con tooltip junto al badge. */
    @api badgeHintField = '';
    /** La columna de acciones toma solo el ancho de sus botones (sin hueco junto a la columna anterior). */
    @api fitActions = false;
    /** Rows per page. 0 = show all, no pager (default). */
    @api pageSize = 0;
    @api loading = false;

    _records = [];
    @track currentPage = 1;
    hintText = '';
    hintStyle = '';
    _hideHintOnScroll = () => this.handleHintHide();

    disconnectedCallback() {
        window.removeEventListener('scroll', this._hideHintOnScroll, true);
    }

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
            thClass:
                (col.type === 'action' ? 'th-action' + (this.fitActions ? ' is-fit' : '') : '') +
                (col.align === 'center' ? ' is-center' : '')
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
            const disabledMessage = this.actionDisabledMessageField
                ? String(record[this.actionDisabledMessageField] || '').trim()
                : '';
            const showDisabledMessage = actionDisabled && Boolean(disabledMessage);
            const rowActionLabel = this.actionLabelField
                ? record[this.actionLabelField] || this.actionLabel
                : this.actionLabel;
            let mobileActionLabel = this.mobileActionLabelField
                ? record[this.mobileActionLabelField] || this.mobileActionLabel
                : this.mobileActionLabel;
            if (showDisabledMessage) {
                mobileActionLabel = disabledMessage;
            }
            const mobileVariant = this.mobileActionVariantField
                ? record[this.mobileActionVariantField] || this.mobileActionVariant
                : this.mobileActionVariant;
            let mobileActionClass = 'lic-more lic-more--primary';
            if (showDisabledMessage) {
                mobileActionClass = 'lic-more lic-more--disabled-msg';
            } else if (mobileVariant === 'ghost') {
                mobileActionClass = 'lic-more lic-more--ghost';
            } else if (mobileVariant === 'link') {
                mobileActionClass = 'lic-more lic-more--link';
            }
            const showSecondary =
                Boolean(this.secondaryActionLabel) &&
                Boolean(this.secondaryActionField) &&
                Boolean(record[this.secondaryActionField]);

            return {
                key,
                mobileKey: `m-${key}`,
                title: record[this.titleField],
                badgeLabel: record[this.badgeField],
                badgeTone: tone,
                badgeHint: this.badgeHintField ? String(record[this.badgeHintField] || '').trim() : '',
                actionDisabled,
                showDisabledMessage,
                disabledMessage,
                mobileActionLabel,
                mobileActionClass,
                showSecondary,
                cells: columns.map((col, index) => {
                    const type = col.type || 'text';
                    const isAmount = type === 'amount';
                    const isStrong = type === 'strong';
                    const isAccent = type === 'accent';
                    const rawValue = record[col.fieldName];
                    const mailtoHref =
                        type === 'mailto' && rawValue ? `mailto:${String(rawValue).trim()}` : '';
                    const isAction = type === 'action';
                    return {
                        key: `${key}-c${index}`,
                        value: rawValue,
                        isLink: type === 'link',
                        isMailto: type === 'mailto' && Boolean(mailtoHref),
                        mailtoHref,
                        isBadge: type === 'badge',
                        isAction: isAction && !showDisabledMessage,
                        isActionMessage: isAction && showDisabledMessage,
                        isText: type === 'text' && !isAmount && !isStrong && !isAccent,
                        isAmount,
                        isStrong,
                        isAccent,
                        amountClass: isAmount ? 'amount' : '',
                        strongClass: isStrong ? 'cell-strong' : '',
                        accentClass: isAccent ? 'cell-accent' : '',
                        badgeTone:
                            type === 'badge'
                                ? record[col.toneField || this.badgeToneField] || 'info'
                                : '',
                        actionLabel: rowActionLabel || col.actionLabel || this.actionLabel,
                        actionMessage: disabledMessage,
                        tdClass:
                            (type === 'action'
                                ? (showDisabledMessage ? 'td-action td-action--msg' : 'td-action') +
                                  (this.fitActions ? ' is-fit' : '')
                                : '') + (col.align === 'center' ? ' is-center' : '')
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

    // El tooltip va con position: fixed porque .table-wrap recorta el overflow.
    handleHintShow(event) {
        const target = event.currentTarget;
        const rect = target.getBoundingClientRect();
        const tipWidth = Math.min(272, window.innerWidth * 0.7);
        const center = rect.left + rect.width / 2;
        const left = Math.max(8, Math.min(center - tipWidth / 2, window.innerWidth - tipWidth - 8));
        const openUp = rect.bottom + 140 > window.innerHeight;
        const vertical = openUp
            ? `bottom:${Math.round(window.innerHeight - rect.top + 10)}px`
            : `top:${Math.round(rect.bottom + 10)}px`;
        this.hintStyle = `${vertical};left:${Math.round(left)}px;width:${Math.round(tipWidth)}px`;
        this.hintText = target.dataset.hint || '';
        window.addEventListener('scroll', this._hideHintOnScroll, true);
    }

    handleHintHide() {
        this.hintText = '';
        window.removeEventListener('scroll', this._hideHintOnScroll, true);
    }

    handleOpen(event) {
        this.dispatchRowAction('open', event.currentTarget.dataset.key);
    }

    handleSecondary(event) {
        this.dispatchRowAction('secondary', event.currentTarget.dataset.key);
    }

    dispatchRowAction(action, key) {
        const row = this._records.find((record) => String(record[this.keyField] ?? '') === key);
        this.dispatchEvent(
            new CustomEvent('rowaction', {
                detail: { action, row, key }
            })
        );
    }
}
