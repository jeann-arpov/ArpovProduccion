import { api, LightningElement } from 'lwc';
import userId from '@salesforce/user/Id';

export default class OneTimePopup extends LightningElement {
    @api storageKey = 'one_time_popup_default_v1';
    @api variant = 'campaign';
    @api title = 'Novedades';
    @api headerNote = '';
    @api introStrong = '';
    @api intro = '';
    @api subtitle = '';
    @api items = '';
    @api listType = 'check';
    @api linkLabel = '';
    @api linkUrl = '';
    @api linkSubtext = '';
    @api confirmLabel = 'Entendido';

    _showOnlyOnce = true;
    _closeOnOverlay = true;

    isVisible = false;

    @api
    get showOnlyOnce() {
        return this._showOnlyOnce;
    }

    set showOnlyOnce(value) {
        this._showOnlyOnce = value !== false && value !== 'false';
    }

    @api
    get closeOnOverlay() {
        return this._closeOnOverlay;
    }

    set closeOnOverlay(value) {
        this._closeOnOverlay = value !== false && value !== 'false';
    }

    connectedCallback() {
        console.log('[oneTimePopup] connected', {
            storageKey: this.storageKey,
            showOnlyOnce: this.showOnlyOnce,
            closeOnOverlay: this.closeOnOverlay
        });
        this.initializeVisibility();
    }

    get listItems() {
        if (!this.items) {
            return [];
        }

        return this.items
            .split('|')
            .map(item => item.trim())
            .filter(Boolean)
            .map((item, index) => {
                const [heading, ...descriptionParts] = item.split('::');
                const hasHeading = descriptionParts.length > 0;

                return {
                    key: `${index}-${heading}`,
                    hasHeading,
                    heading: hasHeading ? heading.trim() : '',
                    description: hasHeading ? descriptionParts.join('::').trim() : '',
                    raw: item
                };
            });
    }

    get hasItems() {
        return this.listItems.length > 0;
    }

    get showLink() {
        return Boolean(this.linkLabel && this.linkUrl);
    }

    get showHeaderNote() {
        return Boolean(this.headerNote);
    }

    get showLinkSubtext() {
        return Boolean(this.linkSubtext);
    }

    get showConfirmButton() {
        return Boolean(this.confirmLabel);
    }

    get overlayClass() {
        return this.isProductorVariant ? 'popup-overlay popup-overlay-productor' : 'popup-overlay';
    }

    get isOrderedList() {
        return this.listType === 'ordered';
    }

    get isCheckList() {
        return !this.isOrderedList;
    }

    get isProductorVariant() {
        return this.variant === 'productor';
    }

    initializeVisibility() {
        console.log('[oneTimePopup] initializeVisibility:start', {
            storageKey: this.storageKey,
            showOnlyOnce: this.showOnlyOnce
        });

        if (!this.showOnlyOnce) {
            this.isVisible = true;
            console.log('[oneTimePopup] initializeVisibility:show because showOnlyOnce=false');
            return;
        }

        try {
            const userScopedKey = `${this.storageKey}_${userId}`;
            const alreadySeen = window.localStorage.getItem(userScopedKey) === 'true';
            this.isVisible = !alreadySeen;
            console.log('[oneTimePopup] initializeVisibility:storage check', {
                storageKey: userScopedKey,
                alreadySeen,
                isVisible: this.isVisible
            });
        } catch (error) {
            this.isVisible = true;
            console.warn('[oneTimePopup] initializeVisibility:localStorage unavailable, forcing visible', error);
        }
    }

    closePopup() {
        console.log('[oneTimePopup] closePopup:start', {
            storageKey: this.storageKey,
            showOnlyOnce: this.showOnlyOnce
        });
        this.isVisible = false;

        if (this.showOnlyOnce) {
            try {
                const userScopedKey = `${this.storageKey}_${userId}`;
                window.localStorage.setItem(userScopedKey, 'true');
                console.log('[oneTimePopup] closePopup:stored seen flag', {
                    storageKey: userScopedKey,
                    storedValue: 'true'
                });
            } catch (error) {
                console.warn('[oneTimePopup] closePopup:failed storing seen flag', error);
            }
        }

        this.dispatchEvent(new CustomEvent('close'));
    }

    handleOverlayClick(event) {
        if (!this.closeOnOverlay) {
            console.log('[oneTimePopup] handleOverlayClick:ignored because closeOnOverlay=false');
            return;
        }

        if (event.target.classList.contains('popup-overlay')) {
            console.log('[oneTimePopup] handleOverlayClick:closing from overlay click');
            this.closePopup();
        }
    }
}