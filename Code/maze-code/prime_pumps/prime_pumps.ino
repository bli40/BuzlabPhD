
// Sequentially primes each of N pumps for t seconds to avoid bubbles in the line.
#include <Servo.h>
Servo myservo;  // create servo object to control a servo
const int nPumps = 4;
const int pinsPumps[4] = { 6,7,8,9 };
const int otherPumps[0] = { };
// 50, 51, 52, 53
const int primetime = 1000;  // 40 seconds
bool primed = false;


void setup() {
  for (int i = 0; i < nPumps; i += 1) {
    pinMode(pinsPumps[i], OUTPUT);
    digitalWrite(pinsPumps[i], LOW);
  }

  for (int i = 0; i < 3; i += 1) {
    pinMode(otherPumps[i], OUTPUT);
    digitalWrite(otherPumps[i], LOW);
  }

  myservo.attach(2, 500, 2500);  // attaches the servo on pin 9 to the servo object
  myservo.write(50);
}

void loop() {
  if (primed == false) {
    for (int a = 0; a < nPumps; a += 1) {
      digitalWrite(pinsPumps[a], HIGH);
      delay(primetime);
      digitalWrite(pinsPumps[a], LOW);
    }
    primed = true;
  }
}
