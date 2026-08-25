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
import { PAGES, goToCommunityPage, isPageActive, communityPageUrl } from 'c/seNav';

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
        document.body.classList.remove('se-drawer-open');
    }

    get navItemsView() {
        return this.navItems.map((item) => {
            const open = this.openSubmenu === item.id;
            const active = item.hasSubmenu
                ? item.submenu.some((sub) => isPageActive(sub.url))
                : isPageActive(item.url);
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
        return this.drawerNav.map((item) => {
            const childActive = item.hasSubmenu && item.submenu.some((sub) => isPageActive(sub.url));
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
                    !item.hasSubmenu && isPageActive(item.url) ? ' active' : ''
                }`,
                subClass: open ? 'd-sub is-open' : 'd-sub',
                submenu: item.hasSubmenu
                    ? item.submenu.map((sub) => ({
                          ...sub,
                          href: communityPageUrl(sub.url),
                          itemClass: isPageActive(sub.url) ? 'd-item active' : 'd-item'
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
