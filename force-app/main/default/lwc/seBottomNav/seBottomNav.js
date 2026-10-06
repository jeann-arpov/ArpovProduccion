import { LightningElement, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import TOKENS from '@salesforce/resourceUrl/seTokens';
import { PAGES, goToCommunityPage, isPageActive } from 'c/seNav';

export default class SeBottomNav extends LightningElement {
    tokensLoaded = false;
    homePage = PAGES.home;
    licenciasPage = PAGES.licencias;
    granariaPage = PAGES.granaria;
    precertPage = PAGES.pph;

    connectedCallback() {
        document.documentElement.classList.add('se-chrome');
        document.body.classList.add('se-chrome');
        window.addEventListener('popstate', this.syncCurrentPath);
        if (!this.tokensLoaded) {
            loadStyle(this, TOKENS)
                .then(() => {
                    this.tokensLoaded = true;
                })
                .catch((error) => {
                    // eslint-disable-next-line no-console
                    console.error('seTokens', error);
                });
        }
    }

    currentPath = window.location.pathname;

    // Vive en el tema: no se re-renderiza en navegaciones internas de Aura.
    @wire(CurrentPageReference)
    wiredPageRef() {
        this.syncCurrentPath();
    }

    syncCurrentPath = () => {
        this.currentPath = window.location.pathname;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.currentPath = window.location.pathname;
        }, 0);
    };

    disconnectedCallback() {
        window.removeEventListener('popstate', this.syncCurrentPath);
    }

    get homeActive() {
        return isPageActive(PAGES.home, this.currentPath);
    }

    get licenciasActive() {
        return isPageActive(PAGES.licencias, this.currentPath);
    }

    get granariaActive() {
        return isPageActive(PAGES.granaria, this.currentPath);
    }

    get precertActive() {
        return (
            isPageActive(PAGES.pph, this.currentPath) ||
            isPageActive(PAGES.establecimientos, this.currentPath)
        );
    }

    get homeClass() {
        return this.cellClass(this.homeActive);
    }

    get licenciasClass() {
        return this.cellClass(this.licenciasActive);
    }

    get granariaClass() {
        return this.cellClass(this.granariaActive);
    }

    get precertClass() {
        return this.cellClass(this.precertActive);
    }

    get fabClass() {
        return isPageActive(PAGES.comprar, this.currentPath) ? 'fab is-active' : 'fab';
    }

    cellClass(active) {
        return active ? 'nav-item is-active' : 'nav-item';
    }

    handleNavigate = (event) => {
        event.preventDefault();
        goToCommunityPage(event.currentTarget.dataset.page);
    };

    handleFab = (event) => {
        event.preventDefault();
        goToCommunityPage(PAGES.comprar);
    };
}
