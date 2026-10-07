import basePath from '@salesforce/community/basePath';

export const PAGES = {
    home: '',
    licencias: 'licenciaslistcustomproductor',
    movimientos: 'movimientos-ht',
    comprar: 'FormularioNuevaVentaHT',
    misCompras: 'comprahtlistproductor',
    facturas: 'facturacion',
    pph: 'iniciar-pph',
    establecimientos: 'misestablecimientos',
    granaria: 'cuentagranarianew',
    cesiones: 'miscesiones',
    perfil: 'editarperfil'
};

function communityRoot() {
    const path = `${basePath}`;
    const idx = path.indexOf('/s');
    const beforeSlash = idx >= 0 ? path.substring(0, idx + 1) : path.endsWith('/') ? path : `${path}/`;
    return `https://${location.host}${beforeSlash}`;
}

export function communityHomeUrl() {
    return `${communityRoot()}s/`;
}

export function communityPageUrl(page) {
    if (!page) {
        return communityHomeUrl();
    }
    return `${communityHomeUrl()}${page}`;
}

export function goToCommunityPage(page) {
    window.open(communityPageUrl(page), '_self');
}

/** Páginas internas que activan el mismo ítem del menú. */
const PAGE_ALIASES = {
    [PAGES.pph]: ['pre-certificacion', 'adhesion-pph'],
    [PAGES.cesiones]: ['cesion-pph', 'cesion-ht'],
    [PAGES.misCompras]: ['compra-ht'],
    [PAGES.facturas]: ['mis-facturas'],
    [PAGES.licencias]: ['solicitar-licencia']
};

function pageSegment(pathname) {
    const path = String(pathname || '').toLowerCase().replace(/\/+$/, '');
    const idx = path.indexOf('/s/');
    return idx >= 0 ? path.substring(idx + 3).split('/')[0] : '';
}

export function isPageActive(page, pathname = window.location.pathname) {
    const segment = pageSegment(pathname);
    if (!page) {
        return segment === '';
    }
    const key = String(page).toLowerCase();
    return segment === key || (PAGE_ALIASES[page] || []).includes(segment);
}

const SITE_TITLE = 'Sembrá Evolución';

const PAGE_TITLES = {
    [PAGES.home]: 'Inicio',
    [PAGES.licencias]: 'Licencias',
    [PAGES.movimientos]: 'Movimientos HT',
    [PAGES.comprar]: 'Comprar HT',
    [PAGES.misCompras]: 'Mis compras',
    [PAGES.facturas]: 'Facturación',
    [PAGES.pph]: 'Precertificación',
    [PAGES.establecimientos]: 'Mis establecimientos',
    [PAGES.granaria]: 'Cuenta Granaria',
    [PAGES.cesiones]: 'Cesiones',
    [PAGES.perfil]: 'Editar perfil'
};

/** Título de pestaña "<Pantalla> · Sembrá Evolución"; null si la página no está mapeada. */
export function pageTitle(pathname = window.location.pathname) {
    const page = Object.keys(PAGE_TITLES).find((key) => isPageActive(key, pathname));
    return page === undefined ? null : `${PAGE_TITLES[page]} · ${SITE_TITLE}`;
}

export default {
    PAGES,
    communityHomeUrl,
    communityPageUrl,
    goToCommunityPage,
    isPageActive,
    pageTitle
};
