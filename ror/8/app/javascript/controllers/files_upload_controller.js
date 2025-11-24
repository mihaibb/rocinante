import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="files-upload"
export default class extends Controller {
  static targets = ['input'];

  connect() {
    this.inputTarget.addEventListener('change', this.newFilesSelectedHandler.bind(this));
  }

  newFilesSelectedHandler(_event) {
    this.element.submit();
  }
}
