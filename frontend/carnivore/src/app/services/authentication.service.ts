// authentication.service.ts
import { Injectable } from '@angular/core';
import { initializeApp } from 'firebase/app';
import {
  getAuth,
  signInWithEmailAndPassword,
  signInAnonymously,
  signInWithPopup,
  GoogleAuthProvider,
  onAuthStateChanged,
  User,
} from 'firebase/auth';
import { BehaviorSubject } from 'rxjs';
import { environment } from '../../environments/environment';

@Injectable({
  providedIn: 'root',
})
export class AuthenticationService {
  public auth;
  private currentUserSubject: BehaviorSubject<User | null>;

  constructor() {
    const app = initializeApp(environment.firebaseConfig);
    this.auth = getAuth(app);
    this.currentUserSubject = new BehaviorSubject<User | null>(null);

    onAuthStateChanged(this.auth, (user) => {
      this.currentUserSubject.next(user);
    });
  }

  async login(email: string, password: string) {
    console.log('In authenticationService, login');
    try {
      await signInWithEmailAndPassword(this.auth, email, password);
    } catch (error) {
      console.error(error);
    }
  }

  async loginAnonymously() {
    console.log('In authenticationService, loginAnonymously');
    try {
      await signInAnonymously(this.auth);
    } catch (error) {
      console.error(error);
    }
  }

  async loginWithGoogle() {
    console.log('In authenticationService, loginWithGoogle');
    try {
      await signInWithPopup(this.auth, new GoogleAuthProvider());
    } catch (error) {
      console.error(error);
    }
  }

  logout() {
    this.auth.signOut();
  }

  get currentUser() {
    return this.currentUserSubject.asObservable();
  }
}