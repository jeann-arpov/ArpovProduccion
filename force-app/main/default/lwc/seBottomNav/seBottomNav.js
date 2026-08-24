import { LightningElement } from 'lwc';
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

    get homeActive() {
        return isPageActive(PAGES.home);
    }

    get licenciasActive() {
        return isPageActive(PAGES.licencias);
    }

    get granariaActive() {
        return isPageActive(PAGES.granaria);
    }

    get precertActive() {
        return isPageActive(PAGES.pph);
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
        return isPageActive(PAGES.comprar) ? 'fab is-active' : 'fab';
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
