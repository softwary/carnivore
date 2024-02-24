import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';
import { AuthenticationService } from './app/services/authentication.service';
// import { LoginComponent } from './app/login/login.component'; // Add  this import

bootstrapApplication(AppComponent, {
  providers: [AuthenticationService] // Add providers here
}).catch((err) => console.error(err));
// bootstrapApplication(AppComponent, appConfig)
//   .catch((err) => console.error(err));
