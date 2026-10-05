import { LightningElement, api } from 'lwc';

const TONES = ['ok', 'warn', 'danger', 'info'];

/**
 * Badge de estado único del portal (LSG).
 * tone: ok | warn | danger | info. variant="dark" para usar sobre cards oscuras.
 */
export default class SeBadge extends LightningElement {
    @api label;
    @api tone = 'info';
    @api variant;
    @api showDot = false;

    get badgeClass() {
        const tone = TONES.includes(this.tone) ? this.tone : 'info';
        return `badge badge--${tone}${this.variant === 'dark' ? ' badge--dark' : ''}`;
    }
}
