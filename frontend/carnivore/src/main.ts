import { bootstrapApplication } from '@angular/platform-browser';
import { appConfig } from './app/app.config';
import { AppComponent } from './app/app.component';
import { AuthenticationService } from './app/services/authentication.service';
import { provideAnimationsAsync } from '@angular/platform-browser/animations/async';

bootstrapApplication(AppComponent, {
  providers: [
    ...appConfig.providers, // Include providers from appConfig
    AuthenticationService, provideAnimationsAsync()  // Also include AuthenticationService
  ]
})
.catch((err) => console.error(err)); 