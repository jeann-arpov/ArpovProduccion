/**
 * Helper GA4 para eventos del portal.
 * LWS bloquea gtag real desde LWC → se publica CustomEvent al Head Markup.
 */
export function trackGa4Event(eventName, params) {
    const payload = {
        name: eventName,
        params: params || {}
    };
    try {
        document.dispatchEvent(
            new CustomEvent('portalGa4Event', {
                detail: payload,
                bubbles: true,
                composed: true
            })
        );
    } catch (e) {
        // ignore
    }
    try {
        if (typeof window !== 'undefined' && typeof window.__portalGa4TrackEvent === 'function') {
            window.__portalGa4TrackEvent(payload.name, payload.params);
        } else if (typeof window !== 'undefined' && typeof window.gtag === 'function') {
            window.gtag('event', payload.name, payload.params);
        }
    } catch (e) {
        // no bloquear UX por analytics
    }
}

export function resolveSemilleroLabel(semilleros, semilleroId, semilleroData) {
    const fromData = semilleroData?.semillero?.Nombre_Obtentor__c;
    if (fromData) {
        return fromData;
    }
    const opt = (semilleros || []).find((s) => s.value === semilleroId);
    return opt?.label || semilleroId || '';
}

export function resolveCantidadHt(data) {
    const total = data?.record?.Total_HT__c;
    if (total != null && total !== '') {
        return Number(total);
    }
    const items = data?.items || [];
    return items.reduce((sum, it) => sum + (Number(it?.record?.Cantidad__c) || 0), 0);
}

/** Params de ht_compra_confirmada según ticket. tipo_ht = Futura|Disponible en este flujo. */
export function buildHtCompraConfirmadaParams({
    semilleros,
    semilleroId,
    subsistema,
    semilleroData,
    cultivoNombre,
    tipoCompraSeleccionado,
    data,
    tipoPago
}) {
    return {
        semillero: semilleroData!= null ? resolveSemilleroLabel(semilleros, semilleroId, semilleroData) : semilleros,
        cultivo: cultivoNombre || '',
        tipo_ht: tipoCompraSeleccionado || '',
        cantidad_ht: resolveCantidadHt(data),
        forma_pago: tipoPago || '',
        subsistema: subsistema || ''
    };
}

const MODULO_PATH_RULES = [
    { re: /licencia/i, modulo: 'Licencias' },
    { re: /factura/i, modulo: 'Facturacion' },
    { re: /compra-ht|venta-ht|movimientos.?ht|ht/i, modulo: 'HT' },
    { re: /cesion/i, modulo: 'Cesiones' },
    { re: /pph|adhesion|adhesi[oó]n/i, modulo: 'PPH' },
    { re: /cuenta-granaria|cuenta.?granaria/i, modulo: 'CuentaGranaria' },
    { re: /precertific/i, modulo: 'Precertificacion' }
];

export function resolveModuloFromPath(pathname) {
    const path =
        pathname ||
        (typeof window !== 'undefined' && window.location ? window.location.pathname : '') ||
        '';
    for (const rule of MODULO_PATH_RULES) {
        if (rule.re.test(path)) {
            return rule.modulo;
        }
    }
    const parts = path.split('/').filter(Boolean);
    return parts[parts.length - 1] || 'portal';
}

export function inferTipoError(err) {
    if (!err) {
        return 'desconocido';
    }
    if (err.body || err.status || err.statusCode) {
        return 'apex';
    }
    if (typeof err.message === 'string') {
        return 'validacion';
    }
    return 'desconocido';
}

export function buildErrorFuncionalParams(err, extras = {}) {
    const raw =
        extras.mensaje_corto ||
        (Array.isArray(extras.messages) ? extras.messages.join(' ') : '') ||
        err?.body?.message ||
        err?.message ||
        'Error';
    const mensaje_corto = String(raw).replace(/\s+/g, ' ').trim().slice(0, 120);
    return {
        tipo_error: extras.tipo_error || inferTipoError(err),
        modulo: extras.modulo || resolveModuloFromPath(),
        mensaje_corto
    };
}

export function trackErrorFuncional(err, extras = {}) {
    trackGa4Event('error_funcional', buildErrorFuncionalParams(err, extras));
}