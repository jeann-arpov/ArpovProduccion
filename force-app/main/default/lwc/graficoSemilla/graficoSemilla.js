import { LightningElement, track, api } from 'lwc';
import chartjs from '@salesforce/resourceUrl/ChartJs';
import { loadScript } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getData from '@salesforce/apex/GraficoSemillaController.getData';

function selectColor(number) {
    const colors = "#96F2EE, #68CEEE, #2D9CED, #0E6ECE, #073E92, #051C61".split(',');
    if (number < colors.length) return `${colors[number]}`;

    const s = Math.floor(Math.random() * 100);
    const l = Math.floor(Math.random() * 100);
    return `hsl(240,${s}%,${l}%)`;
  }

export default class GraficoSemilla extends LightningElement {

    @api campaignName;
    @track isChartJsInitialized;
    chart;

    config = {
        type: 'doughnut',
        data: {
          labels: [],
          datasets: [
            {
                data: [],
            }
          ]
        },
        options: {
            title: {
                display: true,
                text: 'Venta de Semilla Fiscalizada por Grupo de Madurez'
            },
            legend: { 
                display: true,
                position: 'right' 
            },
            tooltips: {
                callbacks: {
                  // this callback is used to create the tooltip label
                  label: function(tooltipItem, data) {
                    // get the data label and data value to display
                    // convert the data value to local string so it uses a comma seperated number
                    var dataLabel = data.labels[tooltipItem.index];
                    var value = ': ' + data.datasets[tooltipItem.datasetIndex].data[tooltipItem.index].toLocaleString();
          
                    // make this isn't a multi-line label (e.g. [["label 1 - line 1, "line 2, ], [etc...]])
                    if (Chart.helpers.isArray(dataLabel)) {
                      // show value on first line of multiline label
                      // need to clone because we are changing the value
                      dataLabel = dataLabel.slice();
                      dataLabel[0] += value;
                    } else {
                      dataLabel += value;
                    }
          
                    // return the text to display on the tooltip
                    return dataLabel;
                  }
                }
            }
        },
        responsive: true
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

            getData({campaignName: this.campaignName})
            .then(result => {
                const total = result.reduce((tot, cur) => tot + cur.semillas, 0);
                const big = result.filter(r => r.semillas / total >= 0.03);
                const small = result.filter(r => r.semillas / total < 0.03);

                if (small.length) big.push({label: "Otros", semillas: small.reduce((tot, cur) => tot + cur.semillas, 0)});

                self.config.data.datasets[0].data = big.map(r => r.semillas);
                self.config.data.labels = big.map(r => r.label);
                self.config.data.datasets[0].backgroundColor = big.map((_, idx) => selectColor(idx));

                const canvas = this.template.querySelector('canvas.linechart')
                const ctx = canvas.getContext('2d');

                canvas.parentNode.style.height = '100%';
                canvas.parentNode.style.width = '100%';

                this.chart = new window.Chart(ctx, this.config);

            }).catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error loading ChartJS',
                        message: error.message ? error.message : JSON.stringify(error),
                        variant: 'error',
                    }),
                );
            });
        }).catch(error => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error loading ChartJS',
                    message: error.message ? error.message : JSON.stringify(error),
                    variant: 'error',
                }),
            );
        });
    }

}