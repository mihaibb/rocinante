import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="slideover"
export default class extends Controller {
  static targets = ["content"];

  connect() {
    window.addEventListener('click', this.handleOutsideClick.bind(this));
  }

  handleOutsideClick(event) {
    const isHidden = window.getComputedStyle(this.element).display === 'none';

    if (isHidden || this.contentTarget.contains(event.target)) {
      return;
    }

    this.close();
  }

  close() {
    // this.element.parentElement.removeAttribute("src") // it might be nice to also remove the modal SRC
    this.element.remove()
  }
}
