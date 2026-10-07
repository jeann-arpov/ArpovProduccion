import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { loadStyle } from 'lightning/platformResourceLoader';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import MY_LOGO from '@salesforce/resourceUrl/seLogoPngBlanco';
import TOKENS from '@salesforce/resourceUrl/seTokens';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import CONTACT_ID_FIELD from '@salesforce/schema/User.ContactId';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Contact.Account.Name';
import COMERCIO_URL from '@salesforce/label/c.ComercioCommunityUrl';
import { PAGES, goToCommunityPage, isPageActive, communityPageUrl, pageTitle } from 'c/seNav';

export default class HeaderComponenteSembraEvolucion extends NavigationMixin(LightningElement) {
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
    openDrawerSection = null;
    tokensLoaded = false;
    perfilPage = PAGES.perfil;
    currentPath = window.location.pathname;

    // El header vive en el tema y no se re-renderiza en navegaciones internas de Aura.
    @wire(CurrentPageReference)
    wiredPageRef() {
        this.syncCurrentPath();
    }

    syncCurrentPath = () => {
        this.currentPath = window.location.pathname;
        this.applyDocumentTitle();
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.currentPath = window.location.pathname;
            this.applyDocumentTitle();
        }, 0);
        // Aura reescribe el título con el de la página del Builder después de navegar.
        [400, 1500].forEach((ms) => {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            setTimeout(() => this.applyDocumentTitle(), ms);
        });
    };

    applyDocumentTitle() {
        const title = pageTitle(window.location.pathname);
        if (title && document.title !== title) {
            document.title = title;
        }
    }

    @track navItems = [
        { id: 'home', label: 'Home', url: PAGES.home, hasSubmenu: false },
        { id: 'licencias', label: 'Licencias', url: PAGES.licencias, hasSubmenu: false },
        { id: 'movimientos', label: 'Movimientos HT', url: PAGES.movimientos, hasSubmenu: false },
        {
            id: 'compras',
            label: 'Mis Compras',
            hasSubmenu: true,
            submenu: [
                { id: 'comprar', label: 'Comprar', url: PAGES.comprar },
                { id: 'todas', label: 'Todas mis Compras', url: PAGES.misCompras },
                { id: 'facturas', label: 'Mis Facturas', url: PAGES.facturas }
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
        { id: 'granaria', label: 'Cuenta Granaria', url: PAGES.granaria, hasSubmenu: false },
        { id: 'cesiones', label: 'Cesiones', url: PAGES.cesiones, hasSubmenu: false }
    ];

    drawerNav = [
        { id: 'home', label: 'Inicio', url: PAGES.home, hasSubmenu: false },
        { id: 'licencias', label: 'Licencias', url: PAGES.licencias, hasSubmenu: false },
        { id: 'movimientos', label: 'Movimientos de HT', url: PAGES.movimientos, hasSubmenu: false },
        {
            id: 'compras',
            label: 'Mis Compras',
            hasSubmenu: true,
            submenu: [
                { id: 'comprar', label: 'Comprar', url: PAGES.comprar },
                { id: 'todas', label: 'Todas mis Compras', url: PAGES.misCompras },
                { id: 'facturas', label: 'Mis Facturas', url: PAGES.facturas }
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
        { id: 'granaria', label: 'Cuenta Granaria', url: PAGES.granaria, hasSubmenu: false },
        { id: 'cesiones', label: 'Cesiones', url: PAGES.cesiones, hasSubmenu: false }
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
            const path = typeof event.composedPath === 'function' ? event.composedPath() : [];
            if (path.includes(this.template.host)) {
                return;
            }
            this.userMenuOpen = false;
            this.openSubmenu = null;
        };
        window.addEventListener('keydown', this._onKeydown);
        window.addEventListener('pointerdown', this._onPointerDown);
        window.addEventListener('popstate', this.syncCurrentPath);
        this.observeDocumentTitle();
        if (!this.tokensLoaded) {
            loadStyle(this, `${TOKENS}?v=home-canvas-20260914b`)
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
        window.removeEventListener('popstate', this.syncCurrentPath);
        if (this._titleObserver) {
            this._titleObserver.disconnect();
            this._titleObserver = null;
        }
        document.body.classList.remove('se-drawer-open');
    }

    // Las páginas con registro (adhesión PPH, detalle de cesión) reescriben el título cuando
    // terminan de cargar, después de los reintentos de syncCurrentPath.
    observeDocumentTitle() {
        if (this._titleObserver || typeof MutationObserver === 'undefined') return;
        try {
            if (!document.head) return;
            this._titleObserver = new MutationObserver(() => this.applyDocumentTitle());
            this._titleObserver.observe(document.head, { childList: true, characterData: true, subtree: true });
        } catch (e) {
            this._titleObserver = null;
        }
    }

    get navItemsView() {
        const path = this.currentPath;
        return this.navItems.map((item) => {
            const open = this.openSubmenu === item.id;
            const active = item.hasSubmenu
                ? item.submenu.some((sub) => isPageActive(sub.url, path))
                : isPageActive(item.url, path);
            return {
                ...item,
                href: communityPageUrl(item.url),
                open,
                openAria: open ? 'true' : 'false',
                itemClass: `item${item.hasSubmenu ? ' has-submenu' : ''}${open ? ' is-open' : ''}${
                    active ? ' is-active' : ''
                }`,
                submenu: item.hasSubmenu
                    ? item.submenu.map((sub) => ({
                          ...sub,
                          href: communityPageUrl(sub.url)
                      }))
                    : undefined
            };
        });
    }

    get drawerNavView() {
        const path = this.currentPath;
        return this.drawerNav.map((item) => {
            const childActive = item.hasSubmenu && item.submenu.some((sub) => isPageActive(sub.url, path));
            const userToggled = this.openDrawerSection !== null;
            const open = item.hasSubmenu
                ? userToggled
                    ? this.openDrawerSection === item.id
                    : childActive
                : false;
            return {
                ...item,
                href: communityPageUrl(item.url),
                open,
                itemClass: `d-item${item.hasSubmenu && open ? ' open' : ''}${
                    !item.hasSubmenu && isPageActive(item.url, path) ? ' active' : ''
                }`,
                subClass: open ? 'd-sub is-open' : 'd-sub',
                submenu: item.hasSubmenu
                    ? item.submenu.map((sub) => ({
                          ...sub,
                          href: communityPageUrl(sub.url),
                          itemClass: isPageActive(sub.url, path) ? 'd-item active' : 'd-item'
                      }))
                    : undefined
            };
        });
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
        const name = (this.userName || this.accountName || '').trim();
        const parts = name.split(/\s+/).filter(Boolean);
        if (parts.length >= 2) {
            return (parts[0].charAt(0) + parts[parts.length - 1].charAt(0)).toUpperCase();
        }
        return name ? name.slice(0, 2).toUpperCase() : '?';
    }

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD, CONTACT_ID_FIELD, PROFILE_NAME_FIELD] })
    userDetails({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD);
            this.contactId = getFieldValue(data, CONTACT_ID_FIELD);
            this.profileName = getFieldValue(data, PROFILE_NAME_FIELD);
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('headerComponenteSembraEvolucion user', error);
        }
    }

    @wire(getRecord, { recordId: '$contactId', fields: [ACCOUNT_NAME_FIELD] })
    contactDetails({ error, data }) {
        if (data) {
            this.accountName = getFieldValue(data, ACCOUNT_NAME_FIELD);
        } else if (error) {
            // eslint-disable-next-line no-console
            console.error('headerComponenteSembraEvolucion account', error);
        }
    }

    openDrawer = () => {
        this.drawerOpen = true;
        this.userMenuOpen = false;
        this.openSubmenu = null;
        document.body.classList.add('se-drawer-open');
    };

    closeDrawer = () => {
        this.drawerOpen = false;
        document.body.classList.remove('se-drawer-open');
    };

    closeMenus = () => {
        this.drawerOpen = false;
        this.userMenuOpen = false;
        this.openSubmenu = null;
        this.openDrawerSection = null;
        document.body.classList.remove('se-drawer-open');
    };

    toggleDrawerSection = (event) => {
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        this.openDrawerSection = this.openDrawerSection === id ? '' : id;
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

    get homeHref() {
        return communityPageUrl(PAGES.home);
    }

    get perfilHref() {
        return communityPageUrl(PAGES.perfil);
    }

    handleNavigate = (event) => {
        event.preventDefault();
        const page = event.currentTarget.dataset.page;
        this.closeMenus();
        goToCommunityPage(page || '');
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
        const path = window.location.pathname || '';
        const siteBase = path.includes('/s/') ? path.split('/s/')[0] : '';
        const loginUrl = `${window.location.origin}${siteBase}/s/login`;
        const logoutUrl = `${window.location.origin}${siteBase}/secur/logout.jsp?retUrl=${encodeURIComponent(loginUrl)}`;
        window.open(logoutUrl, '_self');
    };
}
