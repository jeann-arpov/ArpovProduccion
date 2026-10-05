/**
 * Los contenedores del theme que envuelven al componente pueden crear un stacking context con
 * z-index bajo; ahí el overlay del modal (z-index 10001) queda debajo del header y del footer
 * (z-index 200). Mientras el modal está abierto se neutraliza el z-index de esos ancestros para
 * que el overlay compita directamente con header y footer.
 */
export function releaseModalLayer(host) {
    const released = [];
    if (typeof window === 'undefined' || !host) return released;
    let el = host.parentElement || host.getRootNode()?.host || null;
    while (el && el !== document.body && el !== document.documentElement) {
        if (window.getComputedStyle(el).zIndex !== 'auto') {
            released.push({
                el,
                value: el.style.getPropertyValue('z-index'),
                priority: el.style.getPropertyPriority('z-index')
            });
            el.style.setProperty('z-index', 'auto', 'important');
        }
        el = el.parentElement || el.getRootNode()?.host || null;
    }
    return released;
}

export function restoreModalLayer(released) {
    (released || []).forEach(({ el, value, priority }) => {
        if (value) el.style.setProperty('z-index', value, priority);
        else el.style.removeProperty('z-index');
    });
}
