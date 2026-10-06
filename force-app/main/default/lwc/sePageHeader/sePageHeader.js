import { LightningElement, api } from 'lwc';

/**
 * @fires action - when action button is clicked
 * @fires searchchange - detail.value when search input changes
 */
export default class SePageHeader extends LightningElement {
    @api eyebrow = '';
    @api eyebrowMobile = '';
    @api title = '';
    @api subtitle = '';
    /** Optional primary action label (e.g. Exportar). Hidden on mobile. */
    @api actionLabel = '';
    @api showSearch = false;
    @api searchPlaceholder = 'Buscar...';
    @api searchValue = '';

    get hasAction() {
        return !!this.actionLabel;
    }

    get mobileEyebrow() {
        return this.eyebrowMobile || this.eyebrow;
    }

    handleAction() {
        this.dispatchEvent(new CustomEvent('action'));
    }

    handleSearch(event) {
        this.dispatchEvent(
            new CustomEvent('searchchange', {
                detail: { value: event.target.value || '' }
            })
        );
    }
}
