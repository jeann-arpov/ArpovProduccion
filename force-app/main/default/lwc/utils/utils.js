const getFieldErrors = (fieldErrors, supressField) => fieldErrors ? Object.entries(fieldErrors).map(a => (supressField ? '' : a[0] + ' ') + a[1].map(err => err.message)) : [];
const getPageErrors = (pageErrors) => pageErrors ? pageErrors.map(e => e.message) : [];

const reduceErrors = (errors, supressField = false) => {
    console.log(errors);

    if (!Array.isArray(errors)) {
        errors = [errors];
    }

    return (
        errors
            // Remove null/undefined items
            .filter((error) => !!error)
            // Extract an error message
            .map((error) => {
                // UI API read errors
                if (Array.isArray(error.body)) {
                    return error.body.map((e) => e.message);
                }
                // UI API DML, Apex and network errors
                else if (error.body && typeof error.body.message === 'string') {
                    return error.body.message;
                }

                // DML results
                else if (error.body && Array.isArray(error.body.message)) {
                    let idx = 1;
                    let err = [];
                    for (let record of response.body.message) {
                        let error = getFieldErrors(record.fieldErrors).join('\n') +
                                    getPageErrors(record.pageErrors).join('\n');
                        if (error) err.push('Error en el registro ' + idx + ': ' + error);
                        idx++;
                    }
                    return err.join('\n');
                }

                //Page errors
                else if (error.body && (error.body.fieldErrors || error.body.pageErrors)) {
                    return getFieldErrors(error.body.fieldErrors, supressField).join('\n') +
                           getPageErrors(error.body.pageErrors).join('\n');
                }
                // JS errors
                else if (typeof error.message === 'string') {
                    return error.message;
                }
                // Unknown error shape
                return error;
            })
            // Flatten
            .reduce((prev, curr) => prev.concat(curr), [])
            // Remove empty strings
            .filter((message) => !!message)
    );
}

const validateInputs = (form) => {
    const elems = Array.from(form.querySelectorAll('lightning-input,lightning-combobox,lightning-base-combobox,lightning-input-field,lightning-radio-group,c-lookup,lightning-textarea'));
    console.log(form, elems.length)
    return elems
        .reduce((validSoFar, inputCmp) => {
                return validSoFar && inputCmp.reportValidity();
        }, true);
}

const getRecordFromInputs = (form) => {
    const record = {};
    
    for (let input of form.querySelectorAll('lightning-input-field,lightning-input,lightning-combobox')) {
        record[input.fieldName || input.name] = input.dataset.value || input.value;
    }

    if (record["Id"] != null && record["Id"].trim() == "") record["Id"] = null;
    return record;
}

const getRecordsFromForms = (elem) => {
    return Array.from(elem.querySelectorAll('lightning-record-edit-form')).map(form => getRecordFromInputs(form));
}

import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { trackErrorFuncional } from 'c/portalGa4Events';

const CORTE_DE_RED =
    /disconnected or cancel+ed|request aborted|\baborted\b|the request was canceled|failed to fetch|networkerror|error fetching|net::err|status"?\s*:\s*0/i;
const MSG_CORTE = 'Se cortó la conexión. Probá de nuevo.';

function textoDeError(err) {
    const partes = [];
    try {
        partes.push(reduceErrors(err).join('\n'));
    } catch (e) {
        // el shape del error de Apex no siempre es el de reduceErrors
    }
    if (typeof err === 'string') {
        partes.push(err);
        return partes.filter(Boolean).join('\n');
    }
    if (err && typeof err === 'object') {
        if (typeof err.statusText === 'string') partes.push(err.statusText);
        if (typeof err.body === 'string') partes.push(err.body);
        if (err.body && typeof err.body.message === 'string') partes.push(err.body.message);
        if (typeof err.message === 'string') partes.push(err.message);
        try {
            partes.push(JSON.stringify(err));
        } catch (e) {
            // circular o no serializable
        }
    }
    return partes.filter(Boolean).join('\n');
}

function esCorteDeRed(err) {
    if (err && (err.status === 0 || err.statusText === '')) return true;
    const texto = textoDeError(err);
    return !texto || CORTE_DE_RED.test(texto);
}

function mensajeToastError(err) {
    if (esCorteDeRed(err)) {
        return MSG_CORTE;
    }
    return reduceErrors(err).join('\n') || MSG_CORTE;
}

const errorEvent = (err, extras = {}) => {
    try {
        const messages = reduceErrors(err);
        trackErrorFuncional(err, { messages, ...extras });
    } catch (e) {
        // no bloquear UX por analytics
    }
    const corte = !extras.mensaje && esCorteDeRed(err);
    return new ShowToastEvent({
        title: corte ? '' : 'Error',
        message: extras.mensaje || mensajeToastError(err),
        variant: 'error',
        mode: 'sticky'
    });
}

const warningEvent = (war) => {
    return new ShowToastEvent({
        title: 'Atención',
        message: reduceErrors(war).join('\n'),
        variant: 'warning',
        mode: 'sticky'
    });
}

function getPageParameter(name) {
    return new URLSearchParams(window.location.search).get(name);
}

async function doRequest(callback) {
    this.loading = true;

    try {
        await callback();
    } catch (e) {
        this.onError(e);
    }

    this.loading = false;
}

const normalizeCuit = (value) => {
    if (!value) return '';
    return value.replace(/[^0-9]/g, '');
};

const formatCuit = (value) => {
    const digits = normalizeCuit(value);
    if (digits.length !== 11) return digits;
    return digits.replace(/^(\d{2})(\d{8})(\d{1})$/, '$1-$2-$3');
};

function isSecuenciaConsecutiva(digits, step) {
    for (let i = 1; i < digits.length; i++) {
        if ((Number(digits[i - 1]) + step + 10) % 10 !== Number(digits[i])) return false;
    }
    return true;
}

/**
 * Valida un celular argentino: +549 seguido de 10 dígitos, sin todos los dígitos iguales
 * ni consecutivos (1234567890, 9876543210). Devuelve el mensaje de error o '' si es válido.
 * Mantener alineado con editProfileController.getMobilePhoneError.
 */
function getMobilePhoneError(value) {
    const phone = (value || '').trim();
    if (!phone) return 'Ingresá tu número de celular.';
    if (!/^\+549\d{10}$/.test(phone)) {
        return 'El celular debe tener el formato +549 seguido de 10 dígitos, sin espacios ni guiones (ej. +5491123456789).';
    }
    const digits = phone.slice(4);
    if (/^(\d)\1+$/.test(digits)) return 'El número no puede tener todos los dígitos iguales.';
    if (isSecuenciaConsecutiva(digits, 1) || isSecuenciaConsecutiva(digits, -1)) {
        return 'El número no puede ser una secuencia de dígitos consecutivos.';
    }
    return '';
}

/**
 * Redirige a SGL por GET con el token cifrado.
 * Misma pestaña: standard__webPage abre URLs externas en ventana nueva.
 */
function redirectToSglWithToken(navContext, actionUrl, token, returnUrl) {
    if (!actionUrl || !token) {
        throw new Error('actionUrl y token son requeridos para redirectToSglWithToken');
    }
    const url =
        actionUrl +
        '?token=' + encodeURIComponent(token) +
        '&url=' + encodeURIComponent(returnUrl || window.location.href);
    window.open(url, '_self');
}

export {reduceErrors, validateInputs, getRecordFromInputs, getRecordsFromForms, errorEvent, warningEvent, getPageParameter, doRequest, normalizeCuit, formatCuit, redirectToSglWithToken, getMobilePhoneError}