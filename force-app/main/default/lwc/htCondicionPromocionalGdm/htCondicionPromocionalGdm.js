export const GDM_SEMILLEROS = ['03', '14', '85'];
export const HT_FUTURA_PROMO_MIN_QTY = 200;
export const HT_FUTURA_LIST_PRICE = 11;
export const HT_FUTURA_PROMO_PRICE = 9;

export const HT_FUTURA_PROMO_CULTIVO = 'TRIGO';

/** Zona horaria Argentina para vigencia de la promo. */
export const HT_FUTURA_PROMO_TIMEZONE = 'America/Argentina/Buenos_Aires';

/** Mes calendario (1–12) en el que aplica la promo HT Futura Trigo GDM. */
export const HT_FUTURA_PROMO_MONTH = 7;

export const MSG_PROMO_ACTIVA =
    '¡Felicitaciones! Por realizar una compra mayor a 200 HT te bonificamos el precio.';

export const MSG_PROMO_PERDIDA =
    'Atención: la suma de HT Futura Trigo es menor a 200 HT. La condición promocional ya no aplica y el valor unitario vuelve a USD 11.';

export function isGdmSemillero(semilleroId) {
    return GDM_SEMILLEROS.includes(String(semilleroId || ''));
}

export function isTrigoCultivo(cultivoName) {
    return String(cultivoName || '').trim().toUpperCase() === HT_FUTURA_PROMO_CULTIVO;
}

/** Promo de pantalla: solo semillero GDM y cultivo Trigo. */
export function isHtFuturaPromoScreen({ semilleroId, cultivoName }) {
    return isGdmSemillero(semilleroId) && isTrigoCultivo(cultivoName);
}

/** La promo solo corre en julio según calendario de Argentina. */
export function isHtFuturaPromoPeriodActive(referenceDate = new Date()) {
    const monthInArgentina = Number(
        new Intl.DateTimeFormat('en-US', {
            timeZone: HT_FUTURA_PROMO_TIMEZONE,
            month: 'numeric'
        }).format(referenceDate)
    );
    return monthInArgentina === HT_FUTURA_PROMO_MONTH;
}

export function getPriceBookListPrice(priceBookEntry) {
    if (!priceBookEntry?.record) {
        return null;
    }
    const price = priceBookEntry.record.Unit_Price__c ?? priceBookEntry.record.UnitPrice;
    return price != null ? Number(price) : null;
}

export function resolveBaseListPrice(precioLista) {
    const price = Number(precioLista);
    if (price === HT_FUTURA_PROMO_PRICE) {
        return HT_FUTURA_LIST_PRICE;
    }
    return Number.isNaN(price) ? null : price;
}

export function isHtFuturaListPrice(listPrice) {
    return resolveBaseListPrice(listPrice) === HT_FUTURA_LIST_PRICE;
}

export function isHtFuturaPromoContext({ semilleroId, tipoCompra, listPrice, cultivoName }) {
    return isGdmSemillero(semilleroId)
        && isTrigoCultivo(cultivoName)
        && tipoCompra === 'Futura'
        && isHtFuturaListPrice(listPrice);
}

export function qualifiesForHtFuturaPromo({ semilleroId, tipoCompra, listPrice, cantidad, cultivoName }) {
    if (!isHtFuturaPromoPeriodActive()) {
        return false;
    }
    const qty = Number(cantidad);
    return isHtFuturaPromoContext({ semilleroId, tipoCompra, listPrice, cultivoName })
        && !Number.isNaN(qty)
        && qty >= HT_FUTURA_PROMO_MIN_QTY;
}

/** Suma HT de todas las líneas elegibles para promo (Futura Trigo GDM USD 11). */
export function sumHtFuturaPromoEligibleQuantity(lineas, { semilleroId, cultivoName } = {}) {
    return (lineas || []).reduce((sum, line) => {
        if (!isHtFuturaPromoContext({
            semilleroId,
            tipoCompra: line.tipoCompra,
            listPrice: line.listPrice,
            cultivoName
        })) {
            return sum;
        }
        const qty = Number(line.cantidad);
        return sum + (Number.isNaN(qty) ? 0 : qty);
    }, 0);
}

/** Promo activa si la suma global de líneas elegibles alcanza el mínimo (solo en julio AR). */
export function qualifiesForHtFuturaPromoAggregate({ lineas, semilleroId, cultivoName }) {
    if (!isHtFuturaPromoPeriodActive()) {
        return false;
    }
    return sumHtFuturaPromoEligibleQuantity(lineas, { semilleroId, cultivoName }) >= HT_FUTURA_PROMO_MIN_QTY;
}

export function getPromoUnitPrice({ semilleroId, tipoCompra, listPrice, cantidad, cultivoName, cantidadTotal }) {
    const baseListPrice = resolveBaseListPrice(listPrice);
    if (!isHtFuturaPromoPeriodActive()) {
        return baseListPrice;
    }
    if (!isHtFuturaPromoContext({ semilleroId, tipoCompra, listPrice: baseListPrice, cultivoName })) {
        return baseListPrice;
    }
    const totalQty = cantidadTotal != null ? Number(cantidadTotal) : Number(cantidad);
    return !Number.isNaN(totalQty) && totalQty >= HT_FUTURA_PROMO_MIN_QTY
        ? HT_FUTURA_PROMO_PRICE
        : baseListPrice;
}

/**
 * Modal de promo solo al cruzar el umbral de 200 HT (blur de cantidad).
 * - Sube a ≥200 (ej. 100→200): felicitación una vez por pantalla.
 * - Sigue en promo (ej. 200→201): sin modal.
 * - Baja de ≥200 (ej. 200→100): advertencia cada vez que cruza hacia abajo.
 */
export function resolveHtFuturaPromoUiState({
    hasQualifying,
    hadQualifying,
    celebrationAlreadyShown,
    currentModalIsPromo
}) {
    if (hasQualifying && !hadQualifying && !celebrationAlreadyShown) {
        return {
            showCelebrationModal: true,
            showLossModal: false,
            dismissPromoModal: false,
            promoMessage: MSG_PROMO_ACTIVA,
            promoVariant: 'success',
            celebrationAlreadyShown: true
        };
    }

    if (!hasQualifying && hadQualifying) {
        return {
            showCelebrationModal: false,
            showLossModal: true,
            dismissPromoModal: false,
            promoMessage: MSG_PROMO_PERDIDA,
            promoVariant: 'warning',
            celebrationAlreadyShown
        };
    }

    if (!hasQualifying && currentModalIsPromo) {
        return {
            showCelebrationModal: false,
            showLossModal: false,
            dismissPromoModal: true,
            promoMessage: null,
            promoVariant: 'success',
            celebrationAlreadyShown
        };
    }

    return {
        showCelebrationModal: false,
        showLossModal: false,
        dismissPromoModal: false,
        promoMessage: null,
        promoVariant: 'success',
        celebrationAlreadyShown
    };
}

/** Espera a que el usuario deje de tipear cantidad antes de evaluar el modal de promo. */
export const HT_FUTURA_PROMO_EVAL_DEBOUNCE_MS = 600;

export function scheduleHtFuturaPromoEval(host, callback, { immediate = false, debounceMs = HT_FUTURA_PROMO_EVAL_DEBOUNCE_MS } = {}) {
    if (host._htFuturaPromoEvalTimer) {
        clearTimeout(host._htFuturaPromoEvalTimer);
        host._htFuturaPromoEvalTimer = null;
    }
    if (immediate) {
        callback();
        return;
    }
    host._htFuturaPromoEvalTimer = setTimeout(() => {
        host._htFuturaPromoEvalTimer = null;
        callback();
    }, debounceMs);
}

export function cancelHtFuturaPromoEval(host) {
    if (host._htFuturaPromoEvalTimer) {
        clearTimeout(host._htFuturaPromoEvalTimer);
        host._htFuturaPromoEvalTimer = null;
    }
}