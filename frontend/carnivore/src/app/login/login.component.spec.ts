import { ComponentFixture, TestBed } from '@angular/core/testing';

import { LoginComponent } from './login.component';

describe('LoginComponent', () => {
  let component: LoginComponent;
  let fixture: ComponentFixture<LoginComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [LoginComponent]
    })
    .compileComponents();
    
    fixture = TestBed.createComponent(LoginComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });



  it('should create the login component', () => {
    expect(LoginComponent).toBeTruthy();
  });

  // it('should call signInWithPopup method on login', () => {
  //   const authServiceSpy = spyOn(LoginComponent['afAuth'], 'signInWithPopup').and.callThrough();
  //   LoginComponent.login();
  //   expect(authServiceSpy).toHaveBeenCalled();
  // });
});


// it('should have a login button', () => {
//   const compiled = fixture.nativeElement;
//   expect(compiled.querySelector('button').textContent).toContain('Login with Google');
// });
