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

const errorEvent = (err) => {
    return new ShowToastEvent({
        title: 'Error',
        message: reduceErrors(err).join('\n'),
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

export {reduceErrors, validateInputs, getRecordFromInputs, getRecordsFromForms, errorEvent, warningEvent, getPageParameter, doRequest, normalizeCuit, formatCuit}