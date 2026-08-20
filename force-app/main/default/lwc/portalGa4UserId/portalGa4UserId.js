import { LightningElement, wire } from 'lwc';
import getAnalyticsContext from '@salesforce/apex/PortalGa4UserIdController.getAnalyticsContext';

/**
 * Publica user_id (hash CUIT) + 9 user_properties GA4 vía CustomEvent / Head Markup.
 */
export default class PortalGa4UserId extends LightningElement {
    _published = false;

    connectedCallback() {
        // eslint-disable-next-line no-console
        console.log('[portalGa4UserId] componente montado');
    }

    @wire(getAnalyticsContext)
    wiredContext({ data, error }) {
        if (error) {
            // eslint-disable-next-line no-console
            console.warn('[portalGa4UserId] error Apex', error);
            return;
        }
        if (!data || this._published) {
            return;
        }
        if (!data.userId && (!data.userProperties || Object.keys(data.userProperties).length === 0)) {
            // eslint-disable-next-line no-console
            console.log('[portalGa4UserId] sin contexto (guest / sin Account)');
            return;
        }
        this._published = true;
        // eslint-disable-next-line no-console
        console.log('[portalGa4UserId] contexto listo', {
            hasUserId: !!data.userId,
            props: data.userProperties
        });
        this.publish(data);
    }

    publish(ctx) {
        const detail = {
            user_id: ctx.userId || null,
            send_page_view: false,
            user_properties: ctx.userProperties || {}
        };

        document.dispatchEvent(
            new CustomEvent('portalGa4UserId', {
                detail,
                bubbles: true,
                composed: true
            })
        );

        try {
            if (ctx.userId) {
                window.__portalGa4UserIdHash = ctx.userId;
            }
            window.__portalGa4UserProperties = ctx.userProperties || {};
            if (typeof window.__portalGa4ApplyHash === 'function') {
                window.__portalGa4ApplyHash(ctx.userId, ctx.userProperties || {});
            }
        } catch (e) {
            // eslint-disable-next-line no-console
            console.warn('[portalGa4UserId] publish global falló', e);
        }

        // eslint-disable-next-line no-console
        console.log('[portalGa4UserId] evento portalGa4UserId disparado', detail);
    }
}