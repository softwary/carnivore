import { ComponentFixture, TestBed } from '@angular/core/testing';

import { PlayerWordBoardComponent } from './player-word-board.component';

describe('PlayerWordBoardComponent', () => {
  let component: PlayerWordBoardComponent;
  let fixture: ComponentFixture<PlayerWordBoardComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlayerWordBoardComponent]
    })
    .compileComponents();
    
    fixture = TestBed.createComponent(PlayerWordBoardComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
