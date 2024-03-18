import { Component, Output, EventEmitter } from '@angular/core';
import { AuthenticationService } from '../services/authentication.service';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { NgIf, NgFor, CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [NgIf, NgFor, FormsModule, CommonModule, MatButtonModule],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css'],
})
export class LoginComponent {
  isLoggedIn$: Observable<boolean>;
  @Output() loginStatusChanged = new EventEmitter<boolean>(); // boolean: true for logged in, false for logged out

  constructor(private authService: AuthenticationService) {
    this.isLoggedIn$ = this.authService.currentUser.pipe(map((user) => !!user));
  }

  async onLoginAnonymously() {
    await this.authService.loginAnonymously();
    // Inside your onLoginAnonymously function
    this.loginStatusChanged.emit(true);
  }

  async onLoginWithGoogle() {
    await this.authService.loginWithGoogle();
    // Inside your onLoginAnonymously function
    this.loginStatusChanged.emit(true);
  }

  async onLogout() {
    await this.authService.logout();
    // Inside your onLogout function
    this.loginStatusChanged.emit(false);
  }

  // ... other imports

  // @Output() loginStatusChanged = new EventEmitter<boolean>(); // boolean: true for logged in, false for logged out
}
