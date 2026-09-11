import { LightningElement, api } from 'lwc';

const fmt = (n) => new Intl.NumberFormat('es-AR').format(Number(n) || 0);

const OBTENTOR_SHORT = {
    '03': 'GDM',
    '14': 'GDM',
    '85': 'GDM',
    '04': 'Syngenta',
    '23': 'Syngenta',
    '13': 'Pioneer',
    '87': 'Brevant',
    '24': 'Stine',
    '16': 'MacroSeed',
    '77': 'BASF',
    '06': 'Klein',
    '05': 'Buck',
    '12': 'LG',
    '19': 'Bioceres',
    '90': 'Nord',
    '51': 'Quilmes'
};

function fmtDate(value) {
    if (!value) return '';
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return '';
    return d.toLocaleDateString('es-AR');
}

function fmtDateTime(value) {
    if (!value) return '';
    const d = new Date(value);
    if (Number.isNaN(d.getTime())) return '';
    return d.toLocaleDateString('es-AR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function shortSemillero(idObtentor, name) {
    const key = String(idObtentor || '').padStart(2, '0');
    if (OBTENTOR_SHORT[key]) return OBTENTOR_SHORT[key];
    if (OBTENTOR_SHORT[idObtentor]) return OBTENTOR_SHORT[idObtentor];
    if (!name) return '';
    const match = name.match(/^([^(]+)/);
    return (match ? match[1] : name).trim();
}

function estSe(est) {
    if (est?.cantidadSE != null) return Number(est.cantidadSE) || 0;
    return Object.values(est?.variedades || {}).reduce(
        (a, v) => a + (Number(v?.cantidad) || 0),
        0
    );
}

export default class PphDetalle extends LightningElement {
    @api info;
    @api certificadoDocumentId;

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleVerExpediente() {
        this.dispatchEvent(new CustomEvent('verexpediente'));
    }

    handleDownloadPdf() {
        if (!this.certificadoDocumentId) {
            this.dispatchEvent(
                new CustomEvent('notify', {
                    detail: {
                        message: 'El certificado PDF todavía no está disponible.',
                        variant: 'warning'
                    }
                })
            );
            return;
        }
        this.dispatchEvent(
            new CustomEvent('downloadpdf', {
                detail: { documentId: this.certificadoDocumentId }
            })
        );
    }

    get plan() {
        return this.info?.plan;
    }

    get cultivoLabel() {
        return this.plan?.Parametro_PPH__r?.Cultivo__r?.Name || '';
    }

    get campanaLabel() {
        const campanaName = this.plan?.Parametro_PPH__r?.Campana__r?.Name;
        if (campanaName) return campanaName;
        const raw = this.plan?.Parametro_PPH__r?.Campana__c;
        if (raw && typeof raw === 'string' && raw.length === 18 && raw.startsWith('a')) {
            return this.plan?.Parametro_PPH__r?.Name || '';
        }
        if (raw && typeof raw === 'string' && !raw.startsWith('a')) {
            return `Campaña ${raw}`;
        }
        return this.plan?.Parametro_PPH__r?.Name || '';
    }

    get parametroLabel() {
        return this.plan?.Parametro_PPH__r?.Name || '';
    }

    get certificadoId() {
        return this.plan?.Name || '';
    }

    get estadoRaw() {
        return this.plan?.Estado__c || '';
    }

    get statusBadgeLabel() {
        if (this.estadoRaw === 'Vencido') {
            return `Cerrada · ${fmtDate(this.plan?.Fecha_de_Adhesion__c)}`;
        }
        if (this.estadoRaw === 'Rechazado') {
            const fecha = fmtDate(this.plan?.Fecha_de_Rechazo__c || this.plan?.Fecha_de_Adhesion__c);
            return fecha ? `Rechazada · ${fecha}` : 'Rechazada';
        }
        return `Enviada · ${fmtDate(this.plan?.Fecha_de_Adhesion__c)}`;
    }

    get statusBadgeClass() {
        if (this.estadoRaw === 'Vencido') return 'pph-badge pph-badge--info';
        if (this.estadoRaw === 'Rechazado') return 'pph-badge pph-badge--danger';
        return 'pph-badge pph-badge--ok';
    }

    get establecimientosCount() {
        return (this.info?.establecimientos || []).length;
    }

    get subtitle() {
        const parts = [
            this.cultivoLabel,
            this.campanaLabel,
            this.establecimientosCount
                ? `${this.establecimientosCount} establecimiento${this.establecimientosCount === 1 ? '' : 's'}`
                : ''
        ].filter(Boolean);
        return parts.join(' · ');
    }

    get totalSeHa() {
        return (this.info?.establecimientos || []).reduce((sum, est) => sum + estSe(est), 0);
    }

    get totalNoSeHa() {
        return (this.info?.establecimientos || []).reduce(
            (sum, est) => sum + (Number(est?.cantidadNoSE) || 0),
            0
        );
    }

    get superficieDeclaradaLabel() {
        return `${fmt(this.totalSeHa)} ha`;
    }

    get toneladasEstimadasLabel() {
        const ht2kilos = Number(this.plan?.Parametro_PPH__r?.Cultivo__r?.HT2Kilos__c) || 0;
        if (!ht2kilos || !this.totalSeHa) return '—';
        const toneladas = (this.totalSeHa * ht2kilos) / 1000;
        return `${fmt(Math.round(toneladas * 10) / 10)} t`;
    }

    get semilleroLabel() {
        const counts = new Map();
        (this.info?.establecimientos || []).forEach((est) => {
            const variedades = est?.variedades;
            if (!variedades || typeof variedades !== 'object') return;
            Object.values(variedades).forEach((linea) => {
                if (!(Number(linea?.cantidad) > 0)) return;
                const obt = linea?.variedad?.Obtentor_Comercializa__r;
                const label = shortSemillero(obt?.Id_Obtentor__c, obt?.Name);
                if (!label) return;
                counts.set(label, (counts.get(label) || 0) + 1);
            });
        });
        if (!counts.size) return '—';
        return Array.from(counts.keys()).join(' · ');
    }

    get establecimientosSummary() {
        const list = this.info?.establecimientos || [];
        if (!list.length) return '—';
        return list
            .map((e) => {
                const se = estSe(e);
                const loc = e.locationLabel ? ` (${e.locationLabel})` : '';
                return se > 0 ? `${e.name}${loc} · ${fmt(se)} ha` : `${e.name}${loc}`;
            })
            .join(' · ');
    }

    get establecimientoRows() {
        return (this.info?.establecimientos || []).map((e, idx) => {
            const se = estSe(e);
            const noSe = Number(e.cantidadNoSE) || 0;
            const loc = e.locationLabel ? ` · ${e.locationLabel}` : '';
            return {
                key: e.pphId || e.id || `det-est-${idx}`,
                name: `${e.name || `Establecimiento ${idx + 1}`}${loc}`,
                seLabel: `${fmt(se)} ha`,
                noSeLabel: `${fmt(noSe)} ha`
            };
        });
    }

    get hasEstablecimientos() {
        return this.establecimientoRows.length > 0;
    }

    get summaryRows() {
        try {
            const rows = [
                {
                    key: 'cultivo',
                    label: 'Cultivo',
                    value: this.cultivoLabel || '—',
                    valueClass: 'v v-strong'
                },
                {
                    key: 'campana',
                    label: 'Campaña',
                    value: this.campanaLabel || '—',
                    valueClass: 'v'
                },
                {
                    key: 'param',
                    label: 'Parámetro PPH',
                    value: this.parametroLabel || '—',
                    valueClass: 'v'
                },
                {
                    key: 'sem',
                    label: 'Semillero',
                    value: this.semilleroLabel,
                    valueClass: 'v'
                },
                {
                    key: 'ests',
                    label: 'Establecimientos',
                    value: String(this.establecimientosCount || 0),
                    valueClass: 'v'
                },
                {
                    key: 'sup',
                    label: 'Superficie declarada',
                    value: this.superficieDeclaradaLabel,
                    valueClass: 'v v-strong'
                },
                {
                    key: 'tn',
                    label: 'Toneladas estimadas',
                    value: this.toneladasEstimadasLabel,
                    valueClass: 'v v-strong'
                },
                {
                    key: 'fecha',
                    label: 'Fecha de adhesión',
                    value: fmtDate(this.plan?.Fecha_de_Adhesion__c) || '—',
                    valueClass: 'v'
                }
            ];

            if (this.totalNoSeHa > 0) {
                rows.splice(6, 0, {
                    key: 'nose',
                    label: 'Ha no SE',
                    value: `${fmt(this.totalNoSeHa)} ha`,
                    valueClass: 'v'
                });
            }

            return rows;
        } catch (e) {
            console.error('[pphDetalle] summaryRows', e);
            return [{ key: 'err', label: 'Resumen', value: 'No se pudo armar el resumen', valueClass: 'v' }];
        }
    }

    get timelineSteps() {
        const fecha = this.plan?.Fecha_de_Adhesion__c;
        const steps = [
            {
                key: 'enviada',
                label: 'Solicitud enviada',
                detail: fmtDateTime(fecha) || 'Fecha no registrada',
                state: fecha ? 'done' : 'pending',
                marker: fecha ? '✓' : '1'
            }
        ];

        if (this.estadoRaw === 'Rechazado') {
            steps.push({
                key: 'rechazada',
                label: 'Adhesión rechazada',
                detail: fmtDate(this.plan?.Fecha_de_Rechazo__c) || 'Contactá a Sembrá Evolución.',
                state: 'current',
                marker: '!'
            });
            return steps.map((s) => this.decorateTimelineStep(s));
        }

        const validated = this.estadoRaw === 'Adherido' || this.estadoRaw === 'Vencido';

        steps.push({
            key: 'validada',
            label: validated
                ? 'Validada por Sembrá Evolución'
                : 'Validación por Sembrá Evolución',
            detail: validated
                ? fmtDateTime(fecha) || fmtDate(fecha)
                : 'En curso de revisión.',
            state: validated ? 'done' : 'current',
            marker: validated ? '✓' : '2'
        });

        if (this.estadoRaw === 'Vencido') {
            steps.push({
                key: 'cerrada',
                label: 'Campaña cerrada',
                detail: 'La adhesión ya no está activa para esta campaña.',
                state: 'done',
                marker: '✓'
            });
        } else if (validated) {
            steps.push({
                key: 'entrega',
                label: 'En espera de entrega',
                detail: 'Se convierte a toneladas al ingresar el grano.',
                state: 'current',
                marker: '3'
            });
        }

        return steps.map((s) => this.decorateTimelineStep(s));
    }

    decorateTimelineStep(step) {
        const base = 'pph-timeline-marker';
        let markerClass = base;
        if (step.state === 'done') markerClass += ' pph-timeline-marker--done';
        else if (step.state === 'current') markerClass += ' pph-timeline-marker--current';
        else markerClass += ' pph-timeline-marker--pending';

        return { ...step, markerClass };
    }

    get showDownloadPdf() {
        return this.estadoRaw === 'Adherido' || !!this.certificadoDocumentId;
    }

    get breadcrumb() {
        return `Precertificación / Adhesiones / ${this.certificadoId}`;
    }
}
