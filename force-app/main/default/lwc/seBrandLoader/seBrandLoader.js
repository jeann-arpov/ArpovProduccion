import { LightningElement } from 'lwc';
import MY_LOGO from '@salesforce/resourceUrl/SembraEvolucionLogo';

/** Logo Sembrá Evolución: gris → color de abajo hacia arriba. */
export default class SeBrandLoader extends LightningElement {
    logoUrl = MY_LOGO;
}
