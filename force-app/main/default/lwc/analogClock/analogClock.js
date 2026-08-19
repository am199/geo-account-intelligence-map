import { LightningElement, api } from 'lwc';

export default class AnalogClock extends LightningElement {
    @api contactAddress;

    connectedCallback() {
        this.updateClock();
        setInterval(() => {
            this.updateClock();
        }, 1000);
    }

    renderedCallback() {
        this.updateClock();
    }

    get hours() {
        // Generate hour numbers and their positions
        const hourNumbers = [];
        for (let i = 1; i <= 12; i++) {
            const angle = (i * 360 / 12) - 90;
            const cx = 100 + 75 * Math.cos(angle * Math.PI / 180);
            const cy = 100 + 75 * Math.sin(angle * Math.PI / 180);
            hourNumbers.push({ value: i, cx, cy });
        }
        return hourNumbers;
        }

    get dots() {
        // Generate dots for the minutes and their positions
        const minuteDots = [];
        for (let i = 0; i < 60; i++) {
            if (i % 5 !== 0) {
                const angle = (i * 360 / 60) - 90;
                const cx = 100 + 85 * Math.cos(angle * Math.PI / 180);
                const cy = 100 + 85 * Math.sin(angle * Math.PI / 180);
                minuteDots.push({ cx, cy });
            }
        }
        return minuteDots;
        }

    updateClock() {
        const now = new Date();

        // Adjust the time based on the contact's address timezone or location information
        // You can use a library like Luxon or Moment.js to handle time zone conversions

        const hours = now.getHours();
        const minutes = now.getMinutes();
        const seconds = now.getSeconds();

        // Calculate angles for the clock hands
        const hourAngle = (hours % 12 + minutes / 60) * 360 / 12;
        const minuteAngle = (minutes + seconds / 60) * 360 / 60;
        const secondAngle = seconds * 360 / 60;

        // Apply the rotation to the clock hands
        this.setHandRotation('hour-hand', hourAngle);
        this.setHandRotation('minute-hand', minuteAngle);
        this.setHandRotation('second-hand', secondAngle);
    }

    setHandRotation(handClass, angle) {
        const handElement = this.template.querySelector('.' + handClass);
        if (handElement) {
            handElement.style.transform = `rotate(${angle}deg)`;
            }
        }
    }