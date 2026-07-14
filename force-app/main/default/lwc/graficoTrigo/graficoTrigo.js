import { LightningElement, track } from 'lwc';
import chartjs from '@salesforce/resourceUrl/ChartJs';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getData from '@salesforce/apex/GraficoTrigoController.getData';

export default class GraficoSOJA extends LightningElement {

    @track isChartJsInitialized;
    chart;

    config = {
        type: 'bar',
        data: {
          labels: [],
          datasets: [
            {
                label: "Bolsas UP Bolsas 50Kg",
                type: "bar",
                backgroundColor: "#44A2E1",
                data: [],
            }, {
                label: "Bolsas SF 50Kg",
                type: "bar",
                backgroundColor: "#16335C",
                data: []
            }
          ]
        },
        options: {
            title: {
                display: true,
                text: 'Semilla Fiscalizada y Uso propio TRIGO'
            },
            legend: { 
                display: false 
            },
            scales:{
                xAxes: [{
                    stacked: true,
                    scaleLabel: {
                        display: true,
                        labelString : 'Campaña Agricola'
                    }
                }],
                yAxes: [{
                    stacked: true,
                    scaleLabel: {
                        display: true,
                        labelString : 'Bolsas 50Kg'
                    }
                }]
            }
        }
    };

    renderedCallback() {
        
        let self = this;

        if (this.isChartJsInitialized) {
            return;
        }

        this.isChartJsInitialized = true;


        Promise.all([
            loadScript(this, chartjs)
        ]).then(() => {

            getData({})
            .then(result => {
                
                result.forEach(element => {
                    self.config.data.labels.push(element.campana);
                    self.config.data.datasets[0].data.push(element.sumaBolsasUP);
                    self.config.data.datasets[1].data.push(element.sumaBolsasSF);
                });

                const ctx = this.template.querySelector('canvas.linechart').getContext('2d');
                this.chart = new window.Chart(ctx, this.config);
                this.chart.canvas.parentNode.style.height = '100%';
                this.chart.canvas.parentNode.style.width = '100%';

            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error!!',
                        message: JSON.stringify(error),
                        variant: 'error',
                    }),
                );     
            });  

        }).catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading ChartJS',
                    message: error.message,
                    variant: 'error',
                }),
            );
        });
    }

}