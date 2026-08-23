#include <Servo.h>

Servo myservo;  // create servo object to control a servo
// twelve servo objects can be created on most boards

int pos = 0;    // variable to store the servo position

int cued[3] = { 8, 1, 2 };
int home = 7;

const int nIRs = 8;
const int nPumps = 3;
const int nCued = 3;
const int pinsIR[nIRs] = { 22, 23, 24, 25, 26, 27, 28, 29 };
const int pinsPumps[nPumps] = { 51, 52, 53 };
const int pinBuzzer = 13;

bool rewarded[nCued] = { false, false, false };
bool tripped[nIRs] = { false, false, false, false, false, false, false, false };
int lastIR[nIRs] = { 1, 1, 1, 1, 1, 1, 1, 1 };
int trialCount = 1;
int pumpDur = 300;
int ITI = 10000;

unsigned long previousMillis = 0;  // will store last time LED was updated
long pumpStartTime[nCued] = { 0, 0, 0 };
long trialStartTime = 0;

// constants won't change:
const long interval = 1000;

void setup() {
  myservo.attach(2, 500, 2500);  // attaches the servo on pin 9 to the servo object

  for (int i = 0; i < nIRs; i += 1) {
    pinMode(pinsIR[i], INPUT);
  }

  for (int i = 0; i < nPumps; i += 1) {
    pinMode(pinsPumps[i], OUTPUT);
    digitalWrite(pinsPumps[i],LOW);
  }

  for (int i = 0; i < nCued; i += 1) {
    cued[i] = cued[i] - 1;
  }

  pinMode(pinBuzzer, OUTPUT);

  home -= 1;

  Serial.begin(9600);
  delay(1000);
  Serial.println("***** System Ready - Radial (7+1) Arm Maze *****");
  Serial.print("Cued: ");
  for (int a=0; a<nCued; a+=1) {
    Serial.print(cued[a]+1);
    Serial.print(", ");
  }
  Serial.print("\nHome: "); Serial.println(home+1);
  Serial.print("### Trial "); Serial.println(trialCount);

  myservo.write(0);
  
  trialStartTime = millis();
}

// the loop function runs over and over again forever
void loop() {
  // Checks every nosepoke port and displays if entered (rising edge). If cued, then start reward dispensing.
  for (int i = 0; i < 8; i += 1) {
    if (digitalRead(pinsIR[i]) == HIGH & lastIR[i] == 0) {
      Serial.print(i + 1);
      Serial.print(" poked @ ");
      Serial.print((millis() - trialStartTime)/1000.0);
      Serial.println("s");
      lastIR[i] = 1;
      for (int a = 0; a < nCued; a+=1) {
        if (pinsIR[cued[a]] == pinsIR[i] & !rewarded[a]){
          pumpStartTime[cued[a]] = millis();
          rewarded[a] = true;
          digitalWrite(pinsPumps[a], HIGH);
          Serial.print("<<<");
          Serial.print(cued[a] + 1);
          Serial.println(" rewarded>>>");
        }
      }
    // advances to next trial if all cued ports found.
    if (rewarded[0] && rewarded[1] && rewarded[2]) {
      if (digitalRead(pinsIR[home]) == HIGH) {
        rewarded[0] = false;
        rewarded[1] = false;
        rewarded[2] = false;
        Serial.print("Completed Trial ");
        Serial.println(trialCount);
        tone(pinBuzzer, 10000, 1000);
        myservo.write(120);
        
        delay(ITI);

        myservo.write(0);
        trialCount += 1;
        Serial.print("### Trial "); Serial.println(trialCount);
        trialStartTime = millis(); 
        }
      }  
    }
    // Resets poked state once exited (falling edge).
    if (digitalRead(pinsIR[i]) == LOW & lastIR[i] == 1) {
      lastIR[i] = 0;
    }
  }

  // checks duration of reward pump running and shuts off once pumping for long enough.
  for (int a = 0; a < nCued; a+=1) {
    if (millis() - pumpStartTime[cued[a]] > pumpDur) {
      digitalWrite(pinsPumps[a], LOW);
    }
  }
}
