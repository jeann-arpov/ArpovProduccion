import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import MY_LOGO from '@salesforce/resourceUrl/SembraEvolucionLogo';
import TOKENS from '@salesforce/resourceUrl/seTokens';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import CONTACT_ID_FIELD from '@salesforce/schema/User.ContactId';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Contact.Account.Name';
import COMERCIO_URL from '@salesforce/label/c.ComercioCommunityUrl';
import { PAGES, goToCommunityPage, isPageActive } from 'c/seNav';

export default class SeHeader extends NavigationMixin(LightningElement) {
    userId = USER_ID;
    userName;
    accountName;
    contactId;
    profileName;
    comercioUrl;
    logoUrl = MY_LOGO;
    drawerOpen = false;
    userMenuOpen = false;
    openSubmenu = null;
    tokensLoaded = false;

    @track navItems = [
        { id: 'licencias', label: 'Licencias', url: PAGES.licencias, hasSubmenu: false },
        { id: 'movimientos', label: 'Movimientos de HT', url: PAGES.movimientos, hasSubmenu: false },
        {
            id: 'compras',
            label: 'Mis compras',
            hasSubmenu: true,
            submenu: [
                { id: 'comprar', label: 'Comprar', url: PAGES.comprar },
                { id: 'todas', label: 'Todas mis compras', url: PAGES.misCompras },
                { id: 'facturas', label: 'Mis facturas', url: PAGES.facturas }
            ]
        },
        {
            id: 'precert',
            label: 'Precertificación',
            hasSubmenu: true,
            submenu: [
                { id: 'pph', label: 'Mis PPH', url: PAGES.pph },
                { id: 'establecimientos', label: 'Mis establecimientos', url: PAGES.establecimientos }
            ]
        },
        { id: 'granaria', label: 'Cuenta granaria', url: PAGES.granaria, hasSubmenu: false },
        { id: 'cesiones', label: 'Cesiones', url: PAGES.cesiones, hasSubmenu: false }
    ];

    drawerLinks = [
        { id: 'd-licencias', label: 'Licencias', url: PAGES.licencias },
        { id: 'd-comprar', label: 'Comprar HT', url: PAGES.comprar },
        { id: 'd-compras', label: 'Todas mis compras', url: PAGES.misCompras },
        { id: 'd-facturas', label: 'Mis facturas', url: PAGES.facturas },
        { id: 'd-movimientos', label: 'Movimientos de HT', url: PAGES.movimientos },
        { id: 'd-granaria', label: 'Cuenta granaria', url: PAGES.granaria },
        { id: 'd-pph', label: 'Mis PPH', url: PAGES.pph },
        { id: 'd-establecimientos', label: 'Mis establecimientos', url: PAGES.establecimientos },
        { id: 'd-cesiones', label: 'Cesiones', url: PAGES.cesiones },
        { id: 'd-perfil', label: 'Editar perfil', url: PAGES.perfil }
    ];

    connectedCallback() {
        document.documentElement.classList.add('se-chrome');
        document.body.classList.add('se-chrome');
        this.comercioUrl = window.location.origin + COMERCIO_URL;
        this._onKeydown = (event) => {
            if (event.key === 'Escape') {
                this.closeMenus();
            }
        };
        this._onPointerDown = (event) => {
            if (!this.template.contains(event.target)) {
                this.userMenuOpen = false;
                this.openSubmenu = null;
            }
        };
        window.addEventListener('keydown', this._onKeydown);
        window.addEventListener('pointerdown', this._onPointerDown);
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

    disconnectedCallback() {
        window.removeEventListener('keydown', this._onKeydown);
        window.removeEventListener('pointerdown', this._onPointerDown);
    }

    get navItemsView() {
        return this.navItems.map((item) => {
            const open = this.openSubmenu === item.id;
            const active = item.hasSubmenu
                ? item.submenu.some((sub) => isPageActive(sub.url))
                : isPageActive(item.url);
            return {
                ...item,
                open,
                openAria: open ? 'true' : 'false',
                itemClass: `item${item.hasSubmenu ? ' has-submenu' : ''}${open ? ' is-open' : ''}${
                    active ? ' is-active' : ''
                }`
            };
        });
    }

    get drawerLinksView() {
        return this.drawerLinks.map((link) => ({
            ...link,
            itemClass: isPageActive(link.url) ? 'drawer-link is-active' : 'drawer-link'
        }));
    }

    get isDistribuidor() {
        return this.profileName === 'Distribuidor';
    }

    get drawerClass() {
        return this.drawerOpen ? 'drawer is-open' : 'drawer';
    }

    get userMenuClass() {
        return this.userMenuOpen ? 'usermenu is-open' : 'usermenu';
    }

    get userInitial() {
        const name = this.userName || this.accountName || '';
        return name ? name.charAt(0).toUpperCase() : '?';
    }

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, CONTACT_ID_FIELD, PROFILE_NAME_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD);
            this.contactId = getFieldValue(data, CONTACT_ID_FIELD);
            this.profileName = getFieldValue(data, PROFILE_NAME_FIELD);
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('seHeader user', error);
        }
    }

    @wire(getRecord, { recordId: '$contactId', fields: [ACCOUNT_NAME_FIELD] })
    contactDetails({ error, data }) {
        if (data) {
            this.accountName = getFieldValue(data, ACCOUNT_NAME_FIELD);
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('seHeader account', error);
        }
    }

    openDrawer = () => {
        this.drawerOpen = true;
        this.userMenuOpen = false;
        this.openSubmenu = null;
    };

    closeDrawer = () => {
        this.drawerOpen = false;
    };

    closeMenus = () => {
        this.drawerOpen = false;
        this.userMenuOpen = false;
        this.openSubmenu = null;
    };

    toggleUserMenu = (event) => {
        event.stopPropagation();
        this.userMenuOpen = !this.userMenuOpen;
        this.openSubmenu = null;
    };

    toggleSubmenu = (event) => {
        event.preventDefault();
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.openSubmenu = this.openSubmenu === id ? null : id;
        this.userMenuOpen = false;
    };

    handleNavigate = (event) => {
        event.preventDefault();
        const page = event.currentTarget.dataset.page;
        this.closeMenus();
        goToCommunityPage(page);
    };

    handleProfile = (event) => {
        event.preventDefault();
        this.closeMenus();
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: {
                pageName: 'editarperfil'
            }
        });
    };

    handleCommunityLogout = () => {
        this.closeMenus();
        const logoutUrl = `${window.location.origin}/secur/logout.jsp`;
        this[NavigationMixin.Navigate](
            {
                type: 'standard__webPage',
                attributes: { url: logoutUrl }
            },
            true
        );
    };
}
