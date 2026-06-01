import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["menu"];

  connect() {
    this.closeOnOutsideClick = this.closeOnOutsideClick.bind(this);
  }

  toggle(event) {
    event.stopPropagation();
    if (this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.remove("hidden");
      document.addEventListener("click", this.closeOnOutsideClick);
    } else {
      this.close();
    }
  }

  close() {
    this.menuTarget.classList.add("hidden");
    document.removeEventListener("click", this.closeOnOutsideClick);
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close();
    }
  }

  disconnect() {
    document.removeEventListener("click", this.closeOnOutsideClick);
  }
}
