import { Component } from '@angular/core';
import { AuthenticationService } from '../services/authentication.service';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { NgIf, NgFor, CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [NgIf, NgFor, FormsModule, CommonModule],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.css'],
})
export class LoginComponent {
  isLoggedIn$: Observable<boolean>;

  constructor(private authService: AuthenticationService) {
    this.isLoggedIn$ = this.authService.currentUser.pipe(map((user) => !!user));
  }

  async onLoginAnonymously() {
    await this.authService.loginAnonymously();
  }

  async onLoginWithGoogle() {
    await this.authService.loginWithGoogle();
  }

  async onLogout() {
    await this.authService.logout();
  }
}
