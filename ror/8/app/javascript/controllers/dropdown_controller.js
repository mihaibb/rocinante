import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["btn", "menu"]
  static values = { open: false }

  initialize() {
    this.hideHandler = this.hide.bind(this);
    this.toggleHandle = this.toggle.bind(this);
  }

  connect() {
    this.btnTarget.addEventListener("click", this.toggleHandle);
    window.addEventListener("click", this.hideHandler);
  }

  disconnect() {
    this.btnTarget.removeEventListener("click", this.toggleHandle);
    window.removeEventListener("click", this.hideHandler);
  }

  openValueChanged() {
    if (this.openValue) {
      this._show();
    }
    else {
      this._hide();
    }
  }

  _hide() {
    this.menuTarget.classList.add("hidden");
  }

  _show() {
    this.menuTarget.classList.remove("hidden");
  }

  hide(event) {
    if (this.element.contains(event.target) === false && this.openValue) {
      this.openValue = false;
    }
  }

  show() {
    this.openValue = true;
  }

  toggle() {
    this.openValue = !this.openValue;
  }
}
