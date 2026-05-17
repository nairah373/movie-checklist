import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["firstField"]
  static values  = { open: Boolean }

  connect() {
    if (this.openValue) this.focusFirst()
  }

  open(event) {
    event?.preventDefault()
    const backdrop = document.getElementById("modal")
    if (!backdrop) return
    backdrop.classList.add("open")
    requestAnimationFrame(() => {
      const field = backdrop.querySelector("input[type=text]")
      if (field) field.focus()
    })
  }

  close(event) {
    event?.preventDefault()
    const backdrop = document.getElementById("modal")
    backdrop?.classList.remove("open")
  }

  backdropClose(event) {
    if (event.target === event.currentTarget) this.close(event)
  }

  escape(event) {
    if (event.key === "Escape") this.close(event)
  }

  focusFirst() {
    requestAnimationFrame(() => {
      if (this.hasFirstFieldTarget) this.firstFieldTarget.focus()
    })
  }
}
