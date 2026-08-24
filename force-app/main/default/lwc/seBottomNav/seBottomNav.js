import { LightningElement } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import TOKENS from '@salesforce/resourceUrl/seTokens';
import { PAGES, goToCommunityPage, isPageActive } from 'c/seNav';

export default class SeBottomNav extends LightningElement {
    tokensLoaded = false;

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

    get leftItems() {
        return [
            {
                id: 'home',
                label: 'Inicio',
                page: PAGES.home,
                glyphClass: 'glyph home',
                itemClass: this.itemClass(PAGES.home)
            },
            {
                id: 'licencias',
                label: 'Licencias',
                page: PAGES.licencias,
                glyphClass: 'glyph file',
                itemClass: this.itemClass(PAGES.licencias)
            }
        ];
    }

    get rightItems() {
        return [
            {
                id: 'granaria',
                label: 'Granaria',
                page: PAGES.granaria,
                glyphClass: 'glyph grain',
                itemClass: this.itemClass(PAGES.granaria)
            },
            {
                id: 'precert',
                label: 'PPH',
                page: PAGES.pph,
                glyphClass: 'glyph badge',
                itemClass: this.itemClass(PAGES.pph)
            }
        ];
    }

    get fabClass() {
        return isPageActive(PAGES.comprar) ? 'fab is-active' : 'fab';
    }

    itemClass(page) {
        return isPageActive(page) ? 'nav-item is-active' : 'nav-item';
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
