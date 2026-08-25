import { LightningElement, api } from 'lwc';
import MY_LOGO from '@salesforce/resourceUrl/SembraEvolucionLogo';

/**
 * Layout shell for Productor list pages (Mis Compras, Facturas, Licencias, Movimientos…).
 * Slots: header, toolbar, filters, default (list), pager.
 * @api loading — blurs the page until data is ready.
 */
export default class SeListPage extends LightningElement {
    @api loading = false;
    logoUrl = MY_LOGO;

    get contentClass() {
        return this.loading ? 'content is-loading' : 'content';
    }
}
