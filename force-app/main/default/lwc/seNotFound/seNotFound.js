import { LightningElement } from 'lwc';
import { PAGES, communityHomeUrl, communityPageUrl } from 'c/seNav';

const PAGE_TITLE = 'Página no encontrada · Sembrá Evolución';
const PAGE_BG = '#f6f7f3';

/** Página de error / 404 del portal Productor con el look & feel del rediseño. */
export default class SeNotFound extends LightningElement {
    _connected = false;

    homeUrl = communityHomeUrl();

    quickLinks = [
        { key: 'lic', label: 'Licencias', icon: 'utility:knowledge_base', url: communityPageUrl(PAGES.licencias) },
        { key: 'ht', label: 'Comprar HT', icon: 'utility:cart', url: communityPageUrl(PAGES.comprar) },
        { key: 'compras', label: 'Mis compras', icon: 'utility:list', url: communityPageUrl(PAGES.misCompras) },
        { key: 'cg', label: 'Cuenta Granaria', icon: 'utility:apps', url: communityPageUrl(PAGES.granaria) }
    ];

    connectedCallback() {
        this._connected = true;
        // El fondo del tema es oscuro; si queda espacio debajo de la plantilla, que no se vea negro.
        // En mobile seTokens reserva espacio para la Bottom Nav, que esta página no tiene.
        this._prevStyles = [document.documentElement, document.body].map((el) => ({
            el,
            bg: el.style.getPropertyValue('background-color'),
            bgPriority: el.style.getPropertyPriority('background-color'),
            pb: el.style.getPropertyValue('padding-bottom'),
            pbPriority: el.style.getPropertyPriority('padding-bottom')
        }));
        this._prevStyles.forEach(({ el }) => {
            el.style.setProperty('background-color', PAGE_BG);
            el.style.setProperty('padding-bottom', '0px', 'important');
        });
        // El sitio reescribe el título después de cargar la página.
        [0, 400, 1500].forEach((ms) => {
            setTimeout(() => {
                if (this._connected) {
                    document.title = PAGE_TITLE;
                }
            }, ms);
        });
    }

    disconnectedCallback() {
        this._connected = false;
        if (this._prevStyles) {
            this._prevStyles.forEach(({ el, bg, bgPriority, pb, pbPriority }) => {
                el.style.setProperty('background-color', bg, bgPriority);
                el.style.setProperty('padding-bottom', pb, pbPriority);
            });
            this._prevStyles = null;
        }
        if (this._onResize) {
            window.removeEventListener('resize', this._onResize);
            this._onResize = null;
        }
    }

    renderedCallback() {
        if (this._onResize) {
            return;
        }
        this._onResize = () => this.fitToViewport();
        window.addEventListener('resize', this._onResize);
        this.fitToViewport();
        // El header de la plantilla termina de pintar después del primer render.
        [300, 1200].forEach((ms) => {
            setTimeout(() => {
                if (this._connected) {
                    this.fitToViewport();
                }
            }, ms);
        });
    }

    /** Ocupa desde debajo del header hasta el final de la pantalla, sin dejar ver el fondo del sitio. */
    fitToViewport() {
        const section = this.template.querySelector('.nf');
        if (!section) {
            return;
        }
        const rect = section.getBoundingClientRect();
        const top = rect.top + window.scrollY;
        const below = document.documentElement.scrollHeight - (rect.bottom + window.scrollY);
        const offset = Math.max(0, Math.round(top + Math.max(0, below)));
        section.style.setProperty('--nf-offset', `${offset}px`);
    }

    handleBack() {
        const sameSiteReferrer = document.referrer && document.referrer.indexOf(window.location.host) !== -1;
        if (sameSiteReferrer && window.history.length > 1) {
            window.history.back();
        } else {
            window.location.assign(this.homeUrl);
        }
    }
}
