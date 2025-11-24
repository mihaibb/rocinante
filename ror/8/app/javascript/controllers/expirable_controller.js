import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="expirable"
export default class extends Controller {
  static values = { timeout: Number }

  connect() {
    setTimeout(this.remove.bind(this), this.timeoutValue || 5000); // Default to 5 seconds if no value is provided
  }

  remove() {
    this.element.style.transition = `transform ${this.timeoutValue}ms ease-out, opacity ${this.timeoutValue}ms ease-out`;
    this.element.style.transform = "translateX(100%)";
    this.element.style.opacity = "0";

    setTimeout(() => {
      this.element.parentElement.removeChild(this.element);
    }, this.timeoutValue); // Match the duration of the animation
  }
}
