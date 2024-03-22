import { Component, Input, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-tile',
  standalone: true,
  imports: [],
  templateUrl: './tile.component.html',
  styleUrl: './tile.component.css'
})
export class TileComponent {
  @Input() letter!: string;
  @Input() isFlipped: boolean = false;
  @Input() tileId!: number; 
  @Input() inMiddle: boolean = true;
  @Output() tileClick = new EventEmitter<number>();

  onTileClicked() {
    console.log("@@ tileId!, this.tileId= ", this.tileId);
    console.log(`#### Tile clicked: ${this.tileId}`); // For debugging
    this.tileClick.emit(this.tileId);
    // this.tileFlip.emit();
  }
}
