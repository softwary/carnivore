import { Component, OnInit } from '@angular/core';
import { MatDialogRef } from '@angular/material/dialog'
import { FormsModule } from '@angular/forms';
import { MatDialogActions } from '@angular/material/dialog';
import { MatButtonModule } from '@angular/material/button';
import { MatCardModule } from '@angular/material/card';
import { MatInputModule } from '@angular/material/input';
import { MatDialogClose } from '@angular/material/dialog';
import { MatDialogContent } from '@angular/material/dialog';
@Component({
  selector: 'app-join-game-dialog',
  standalone: true,
  imports: [FormsModule, MatDialogActions,
    MatCardModule,
    MatButtonModule,
    MatInputModule, MatDialogClose, MatDialogContent],
  templateUrl: './join-game-dialog.component.html',
  styleUrl: './join-game-dialog.component.css'
})
export class JoinGameDialogComponent {
  gameId: string = '';
  constructor(public dialogRef: MatDialogRef<JoinGameDialogComponent>) {}
}
