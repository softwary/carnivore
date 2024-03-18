import { Directive, ElementRef, HostListener, Renderer2 } from '@angular/core';

@Directive({
  selector: '[alphaOnly]',
  standalone: true
})
export class AlphaOnlyDirective {
  constructor(private el: ElementRef, private renderer: Renderer2) { }

  @HostListener('input', ['$event'])
  onInputChange(event: any) {
    const initialValue = this.el.nativeElement.value;
    const newValue = initialValue.replace(/[^a-zA-Z]/g, '');

    if (initialValue !== newValue) {
      event.stopPropagation();
      this.el.nativeElement.value = newValue; // Directly set the new value
      this.renderer.addClass(this.el.nativeElement, 'invalid-input'); 
      setTimeout(() => {
        this.renderer.removeClass(this.el.nativeElement, 'invalid-input');
      }, 500); 
    }
  }
}
