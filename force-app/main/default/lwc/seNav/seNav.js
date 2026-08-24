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

export function isPageActive(page) {
    const path = (window.location.pathname || '').toLowerCase().replace(/\/+$/, '');
    if (!page) {
        return /\/s$/.test(path);
    }
    return path.includes(String(page).toLowerCase());
}

export default {
    PAGES,
    communityHomeUrl,
    communityPageUrl,
    goToCommunityPage,
    isPageActive
};
