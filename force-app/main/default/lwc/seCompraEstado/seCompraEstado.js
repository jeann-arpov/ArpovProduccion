/**
 * Etiqueta única del estado de una compra HT (cabecera o línea) para listado, detalle y pop-up.
 * Una línea Facturable o Pendiente pertenece a una compra "Pendiente de Facturación".
 */
const LABELS = {
    Creada: 'En curso',
    'Pendiente de Facturación': 'Pendiente de facturación',
    Facturable: 'Pendiente de facturación',
    Pendiente: 'Pendiente de facturación',
    'Pedido de Facturación': 'Pedido de facturación',
    'Pedido de Facturacion': 'Pedido de facturación',
    'Pagada Parcialmente': 'Pagada parcialmente'
};

export function compraEstadoLabel(estado) {
    if (!estado) return '—';
    return LABELS[estado] || estado;
}

export function compraEstadoTone(estado) {
    const s = compraEstadoLabel(estado).toLowerCase();
    if (/pagad/.test(s)) return 'ok';
    if (/vencid|cancel/.test(s)) return 'danger';
    if (/factur|pendiente/.test(s)) return 'warn';
    return 'info';
}
