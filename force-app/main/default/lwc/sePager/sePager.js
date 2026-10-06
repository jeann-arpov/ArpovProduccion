import { LightningElement, api } from 'lwc';

/**
 * @api page - current page number (1-based)
 * @api disablePrev / disableNext
 * @fires previous
 * @fires next
 */
export default class SePager extends LightningElement {
    @api page = 1;
    @api disablePrev = false;
    @api disableNext = false;

    get pageLabel() {
        return `Página ${this.page}`;
    }

    handlePrev() {
        if (this.disablePrev) return;
        this.dispatchEvent(new CustomEvent('previous'));
    }

    handleNext() {
        if (this.disableNext) return;
        this.dispatchEvent(new CustomEvent('next'));
    }
}
