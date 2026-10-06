/**
 * Validación de coordenadas de establecimientos: rango geográfico y bounding box de Argentina.
 * Devuelven '' si el valor es válido o el mensaje a mostrar.
 */
const AR = { latMin: -55.1, latMax: -21.8, lngMin: -73.6, lngMax: -53.6 };

export function latitudError(lat) {
    const n = Number(lat);
    if (!Number.isFinite(n)) return 'Ingresá un número válido';
    if (n < -90 || n > 90) return 'La latitud debe estar entre -90 y 90';
    if (n < AR.latMin || n > AR.latMax) return 'La latitud está fuera de Argentina (entre -21,8 y -55,1)';
    return '';
}

export function longitudError(lng) {
    const n = Number(lng);
    if (!Number.isFinite(n)) return 'Ingresá un número válido';
    if (n < -180 || n > 180) return 'La longitud debe estar entre -180 y 180';
    if (n < AR.lngMin || n > AR.lngMax) return 'La longitud está fuera de Argentina (entre -53,6 y -73,6)';
    return '';
}

export function coordenadasError(lat, lng) {
    return latitudError(lat) || longitudError(lng);
}
