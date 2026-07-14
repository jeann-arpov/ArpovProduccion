const MIN_COLUMN_WIDTH = 4;

export const DEFAULT_WIDTHS_SIN_PROCESAR = [8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 12];
export const DEFAULT_WIDTHS_PROCESADAS = [9.09, 9.09, 9.09, 9.09, 9.09, 9.09, 9.09, 9.09, 9.09, 9.09, 9.09];

export function buildColumnColStyles(columnWidths) {
    return columnWidths.map((width, index) => ({
        key: `col-${index}`,
        style: `width: ${width}%`
    }));
}

export function createColumnResizeController(component) {
    let resizeState = null;

    const onMove = (event) => {
        if (!resizeState) {
            return;
        }

        const { colIndex, nextIndex, startX, startWidths, tableWidth } = resizeState;
        const deltaPct = ((event.clientX - startX) / tableWidth) * 100;
        let left = startWidths[colIndex] + deltaPct;
        let right = startWidths[nextIndex] - deltaPct;

        if (left < MIN_COLUMN_WIDTH) {
            right -= MIN_COLUMN_WIDTH - left;
            left = MIN_COLUMN_WIDTH;
        }
        if (right < MIN_COLUMN_WIDTH) {
            left -= MIN_COLUMN_WIDTH - right;
            right = MIN_COLUMN_WIDTH;
        }

        const widths = [...startWidths];
        widths[colIndex] = Math.round(left * 100) / 100;
        widths[nextIndex] = Math.round(right * 100) / 100;
        component.columnWidths = widths;
    };

    const onEnd = () => {
        resizeState = null;
        component.isResizingColumns = false;
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onEnd);
    };

    const onStart = (event) => {
        event.preventDefault();
        event.stopPropagation();

        const colIndex = parseInt(event.currentTarget.dataset.colIndex, 10);
        const nextIndex = colIndex + 1;
        if (Number.isNaN(colIndex) || nextIndex >= component.columnWidths.length) {
            return;
        }

        const table = component.template.querySelector('.ventas-table');
        if (!table) {
            return;
        }

        resizeState = {
            colIndex,
            nextIndex,
            startX: event.clientX,
            startWidths: [...component.columnWidths],
            tableWidth: table.offsetWidth
        };

        component.isResizingColumns = true;
        window.addEventListener('mousemove', onMove);
        window.addEventListener('mouseup', onEnd);
    };

    const destroy = () => {
        resizeState = null;
        window.removeEventListener('mousemove', onMove);
        window.removeEventListener('mouseup', onEnd);
    };

    return { onStart, destroy };
}