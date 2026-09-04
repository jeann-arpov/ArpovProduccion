import { LightningElement, api } from 'lwc';

const fmt = (n) => new Intl.NumberFormat('es-AR').format(Number(n) || 0);

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

export default class PphDetalle extends LightningElement {
    @api info;
    @api certificadoDocumentId;

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
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
        return this.plan?.Parametro_PPH__r?.Name || '';
    }

    get certificadoId() {
        return this.plan?.Name || '';
    }

    get estadoRaw() {
        return this.plan?.Estado__c || '';
    }

    get statusBadgeLabel() {
        if (this.estadoRaw === 'Adherido') {
            return `Certificada · ${fmtDate(this.plan?.Fecha_de_Adhesion__c)}`;
        }
        if (this.estadoRaw === 'Vencido') {
            return `Cerrada · ${fmtDate(this.plan?.Fecha_de_Adhesion__c)}`;
        }
        if (this.estadoRaw === 'Rechazado') {
            return 'Rechazada';
        }
        return `Enviada · ${fmtDate(this.plan?.Fecha_de_Adhesion__c)}`;
    }

    get statusBadgeClass() {
        if (this.estadoRaw === 'Adherido') return 'pph-badge pph-badge--ok';
        if (this.estadoRaw === 'Vencido') return 'pph-badge pph-badge--info';
        if (this.estadoRaw === 'Rechazado') return 'pph-badge pph-badge--danger';
        return 'pph-badge pph-badge--ok';
    }

    get subtitle() {
        const parts = [this.cultivoLabel, this.campanaLabel, this.primaryEstablecimiento].filter(Boolean);
        return parts.join(' · ');
    }

    get primaryEstablecimiento() {
        const est = (this.info?.establecimientos || [])[0];
        return est?.name || '';
    }

    get totalSeLabel() {
        const total = (this.info?.establecimientos || []).reduce((sum, est) => {
            const variedades = est?.variedades;
            const values = variedades && typeof variedades === 'object'
                ? Object.values(variedades)
                : [];
            const se = values
                .map((v) => Number(v?.cantidad) || 0)
                .reduce((a, b) => a + b, 0);
            return sum + se;
        }, 0);
        return `${fmt(total)} HT`;
    }

    get saldoSinPrecertificarLabel() {
        return `${fmt(this.info?.saldoPph)} HT`;
    }

    get summaryRows() {
        try {
            const rows = [
                { key: 'cultivo', label: 'Cultivo', value: this.cultivoLabel || '—', valueClass: 'v' },
                { key: 'campana', label: 'Campaña', value: this.campanaLabel || '—', valueClass: 'v' },
                { key: 'est', label: 'Establecimiento', value: this.establecimientosSummary, valueClass: 'v' },
                { key: 'ht', label: 'HT SE precertificadas', value: this.totalSeLabel, valueClass: 'v v-strong' },
                {
                    key: 'pend',
                    label: 'HT sin precertificar',
                    value: this.saldoSinPrecertificarLabel,
                    valueClass: 'v v-warn'
                }
            ];

            const variedades = this.variedadesSummary;
            if (variedades) {
                rows.splice(3, 0, {
                    key: 'var',
                    label: 'Variedades',
                    value: variedades,
                    valueClass: 'v'
                });
            }

            return rows;
        } catch (e) {
            console.error('[pphDetalle] summaryRows', e);
            return [{ key: 'err', label: 'Resumen', value: 'No se pudo armar el resumen', valueClass: 'v' }];
        }
    }

    get establecimientosSummary() {
        const names = (this.info?.establecimientos || []).map((e) => e.name).filter(Boolean);
        if (!names.length) return '—';
        if (names.length === 1) return names[0];
        return `${names[0]} +${names.length - 1}`;
    }

    get variedadesSummary() {
        const names = new Set();
        (this.info?.establecimientos || []).forEach((est) => {
            const variedades = est?.variedades;
            if (!variedades || typeof variedades !== 'object') return;
            Object.values(variedades).forEach((linea) => {
                if (Number(linea?.cantidad) > 0 && linea?.variedad?.Name) {
                    names.add(linea.variedad.Name);
                }
            });
        });
        if (!names.size) return '';
        return Array.from(names).join(' · ');
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
                detail: 'Contactá a Sembrá Evolución para más información.',
                state: 'current',
                marker: '!'
            });
            return steps.map((s) => this.decorateTimelineStep(s));
        }

        if (this.estadoRaw === 'Adherido' || this.estadoRaw === 'Vencido') {
            steps.push({
                key: 'cert',
                label: 'Certificada por Sembrá Evolución',
                detail: fmtDate(fecha) || '',
                state: 'done',
                marker: '✓'
            });
        } else {
            steps.push({
                key: 'cert',
                label: 'Validación por Sembrá Evolución',
                detail: 'En proceso de revisión.',
                state: 'current',
                marker: '2'
            });
        }

        if (this.estadoRaw === 'Vencido') {
            steps.push({
                key: 'cerrada',
                label: 'Campaña cerrada',
                detail: 'La adhesión ya no está activa para esta campaña.',
                state: 'done',
                marker: '✓'
            });
        } else if (this.estadoRaw === 'Adherido') {
            steps.push({
                key: 'vigente',
                label: 'Adhesión vigente',
                detail: 'Podés usar semilla propia en los establecimientos declarados.',
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
