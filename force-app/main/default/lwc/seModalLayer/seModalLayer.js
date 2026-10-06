/**
 * Los contenedores del theme que envuelven al componente pueden crear un stacking context con
 * z-index bajo, o un containing block (transform/filter/contain/will-change) que recorta los
 * position:fixed. Ahí el overlay del modal queda debajo del header y del footer (z-index 200) o
 * no ocupa todo el viewport. Mientras el modal está abierto se neutralizan esas propiedades en los
 * ancestros para que el overlay compita directamente con header y footer.
 */
const IDENTITY_TRANSFORMS = ['none', 'matrix(1, 0, 0, 1, 0, 0)', 'matrix3d(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)'];

function neutralize(el, prop, value, released) {
    released.push({
        el,
        prop,
        value: el.style.getPropertyValue(prop),
        priority: el.style.getPropertyPriority(prop)
    });
    el.style.setProperty(prop, value, 'important');
}

export function releaseModalLayer(host) {
    const released = [];
    if (typeof window === 'undefined' || !host) return released;
    try {
        let el = host.parentElement || host.getRootNode()?.host || null;
        while (el && el !== document.body && el !== document.documentElement) {
            const cs = window.getComputedStyle(el);
            if (cs.zIndex !== 'auto') neutralize(el, 'z-index', 'auto', released);
            if (cs.transform && cs.transform !== 'none' && IDENTITY_TRANSFORMS.includes(cs.transform)) {
                neutralize(el, 'transform', 'none', released);
            }
            if (cs.filter && cs.filter !== 'none') neutralize(el, 'filter', 'none', released);
            if (cs.perspective && cs.perspective !== 'none') neutralize(el, 'perspective', 'none', released);
            if (cs.contain && cs.contain !== 'none') neutralize(el, 'contain', 'none', released);
            if (cs.willChange && cs.willChange !== 'auto') neutralize(el, 'will-change', 'auto', released);
            el = el.parentElement || el.getRootNode()?.host || null;
        }
    } catch (e) {
        // Locker puede no exponer los ancestros fuera del namespace: queda el fallback de seTokens.
    }
    return released;
}

export function restoreModalLayer(released) {
    (released || []).forEach(({ el, prop = 'z-index', value, priority }) => {
        try {
            if (value) el.style.setProperty(prop, value, priority);
            else el.style.removeProperty(prop);
        } catch (e) {
            // ignore
        }
    });
}

/**
 * Si un ancestro sigue actuando como containing block, el overlay fixed queda desplazado o con el
 * alto del contenedor. Se compensa para que cubra exactamente el viewport.
 */
export function fitFixedLayer(el) {
    if (!el || typeof window === 'undefined') return;
    ['top', 'left', 'right', 'bottom', 'width', 'height'].forEach((p) => el.style.removeProperty(p));
    const r = el.getBoundingClientRect();
    const vw = window.innerWidth || document.documentElement.clientWidth;
    const vh = window.innerHeight;
    if (Math.abs(r.top) < 1 && Math.abs(r.left) < 1 && Math.abs(r.width - vw) < 2 && Math.abs(r.height - vh) < 2) {
        return;
    }
    el.style.setProperty('box-sizing', 'border-box');
    el.style.setProperty('top', `${-r.top}px`);
    el.style.setProperty('left', `${-r.left}px`);
    el.style.setProperty('right', 'auto');
    el.style.setProperty('bottom', 'auto');
    el.style.setProperty('width', `${vw}px`);
    el.style.setProperty('height', `${vh}px`);
}

let lockCount = 0;

/**
 * Bloquea el scroll del portal sin cambiar el layout: sin position:fixed en el body (el header
 * sticky no se va), con el lugar de la barra de scroll reservado (nada se corre) y el footer al
 * pie del documento; seTokens lo oscurece mientras haya un modal abierto.
 */
export function lockPortalModal(host, refit) {
    const state = { layer: releaseModalLayer(host), refit: null };
    if (typeof window === 'undefined' || typeof document === 'undefined') return state;
    if (lockCount === 0) {
        // Al ocultar la barra de scroll el contenido gana ancho y se corre: se reserva su lugar.
        const scrollbar = window.innerWidth - document.documentElement.clientWidth;
        if (scrollbar > 0) {
            if (window.CSS && CSS.supports && CSS.supports('scrollbar-gutter', 'stable')) {
                document.documentElement.classList.add('se-modal-gutter');
            } else {
                document.body.style.paddingRight = `${scrollbar}px`;
            }
        }
        document.documentElement.classList.add('se-modal-open');
        document.body.classList.add('se-modal-open');
    }
    lockCount += 1;
    if (typeof refit === 'function') {
        state.refit = () => refit();
        window.addEventListener('resize', state.refit, { passive: true });
    }
    return state;
}

export function unlockPortalModal(state) {
    if (!state || typeof document === 'undefined') return;
    restoreModalLayer(state.layer);
    if (state.refit) window.removeEventListener('resize', state.refit);
    lockCount = Math.max(0, lockCount - 1);
    if (lockCount === 0) {
        document.documentElement.classList.remove('se-modal-open', 'se-modal-gutter');
        document.body.classList.remove('se-modal-open');
        document.body.style.paddingRight = '';
    }
}
