import getLoadData from '@salesforce/apex/CuentaGranaria.getLoadData';
import getResumenBiotecnologiaPorCultivo from '@salesforce/apex/ComprasHTController.getResumenBiotecnologiaPorCultivo';

export async function fetchCultivoOptions() {
    const data = await getLoadData();
    const options = (data?.cultivos || []).map((c) => ({
        label: c.Name,
        value: c.Id
    }));

    return {
        options,
        defaultId: options.length ? options[0].value : null
    };
}

export async function fetchCultivoSummary(cultivoId) {
    if (!cultivoId) {
        return { rows: [], total: 0 };
    }

    const result = await getResumenBiotecnologiaPorCultivo({ cultivoId });
    const rows = (result?.rows || []).map((row) => ({
        label: row.label,
        value: row.value
    }));

    return {
        rows,
        total: result?.total ?? 0
    };
}
