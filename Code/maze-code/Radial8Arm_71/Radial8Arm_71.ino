#include <Servo.h>

Servo myservo;  // create servo object to control a servo
// twelve servo objects can be created on most boards

int pos = 0;    // variable to store the servo position

const int nIRs = 8;
const int nPumps = 4;
const int nCued = 4;
const int pinsIR[nIRs] = { 22, 23, 24, 25, 26, 27, 28, 29 };
const int pinsPumps[nPumps] = { 50, 51, 52, 53 };
const int pinBuzzer = 13;

int cued[nCued] = { 8, 6, 4, 2 };
int home = 1;

bool rewarded[nCued] = { false, false, false };
bool tripped[nIRs] = { false, false, false, false, false, false, false, false };
bool errorPoke = false;

int lastIR[nIRs] = { 1, 1, 1, 1, 1, 1, 1, 1 };
int trialNum = 1;
int completedTrials = 0;
int pumpDur = 30;
int ITI = 10000;

unsigned long previousMillis = 0;  // will store last time LED was updated
long pumpStartTime[nPumps] = { 0, 0, 0, 0};
long trialStartTime = 0;
long delayStartTime = 0;


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

  Serial.begin(115200);
  delay(1000);
  Serial.println("***** System Ready - Radial (7+1) Arm Maze *****");
  Serial.print("Cued: ");
  for (int a=0; a<nCued; a+=1) {
    Serial.print(cued[a]+1);
    Serial.print(", ");
  }
  Serial.print("\nHome: "); Serial.println(home+1);
  Serial.print("### Trial "); Serial.println(trialNum);

  myservo.write(0);
  
  trialStartTime = millis();
}

// the loop function runs over and over again forever
void loop() {
  // Checks every nosepoke port and displays if entered (rising edge). If cued, then start reward dispensing.
  for (int i = 0; i < 8; i += 1) {
    if (digitalRead(pinsIR[i]) == HIGH & lastIR[i] == 0) {
      tripped[i] = true;
      Serial.print(i + 1);
      Serial.print(" poked @ ");
      Serial.print((millis() - trialStartTime)/1000.0);
      Serial.println("s");
      for (int a = 0; a < nCued; a+=1) {
        if (pinsIR[cued[a]] == pinsIR[i] & !rewarded[a]){
          pumpStartTime[a] = millis();
          rewarded[a] = true;
          Serial.print("<<<");
          Serial.print(cued[a] + 1);
          Serial.println(" rewarded>>>");
        }
      }
      // advances to next trial if all cued ports found.
      if (pinsIR[home] == pinsIR[i]) {
        if (rewarded[0] && rewarded[1] && rewarded[2]) {
          rewarded[0] = false;
          rewarded[1] = false;
          rewarded[2] = false;
          Serial.print("Completed Trial ");
          Serial.println(trialNum);
          // tone(pinBuzzer, 3000, 2000);
          myservo.write(120);
    
          delay(ITI);
    
          myservo.write(0);
          trialNum += 1;
          errorPoke = false;
          Serial.print("### Trial "); Serial.println(trialNum);
          trialStartTime = millis(); 
        }
      }
      lastIR[i] = 1;
    }
    // Resets poked state once exited (falling edge).
    if (digitalRead(pinsIR[i]) == LOW & lastIR[i] == 1) {
      lastIR[i] = 0;
    }
  }


  // checks duration of reward pump running and shuts off once pumping for long enough.
  for (int a = 0; a < nPumps; a+=1) {
    if (millis() - pumpStartTime[a] > pumpDur) {
      digitalWrite(pinsPumps[a], LOW);
    } 
    else if (millis() - pumpStartTime[a] < pumpDur) {
      digitalWrite(pinsPumps[a], HIGH);
    }
  }

}
