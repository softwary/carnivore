import { AnimationKeyframesSequenceMetadata } from "@angular/animations";

export class WebSocketMessage {
  type: string;
  data: {
    idToken: string; // Change 'string' to an appropriate type for the idToken
    [key: string | number ]: any; // Flexible string key-value pairs
  };

  constructor(type: string, idToken: string, data: { [key: string | number]: string }) {
    this.type = type;
    this.data = {
      idToken: idToken,
      ...data // Spread the data object
    };
  }
}