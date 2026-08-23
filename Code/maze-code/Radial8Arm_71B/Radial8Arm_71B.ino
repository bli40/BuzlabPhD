// Linear Track Maze with bonus:
// Codes:
//    000: system initiation settings log
//    001: trial initiation (offer)
//    010: port poked
//    011: port rewarded
//    100: bonus status
//    101: trial overtime
//    110: trial initiation (by animal)
//    111: trial end

#include <Servo.h>

Servo myservo;  // create servo object to control a servo
// twelve servo objects can be created on most boards

int pos = 0;    // variable to store the servo position

const int emergencyPin = 3;

const int nIRs = 8;
const int nPumps = 4;
const int nCued = 3;
const int pinsIR[nIRs] = { 22, 23, 24, 25, 26, 27, 28, 29 };
const int pinsPumps[nPumps] = { 50, 51, 52, 53 };
const int pinBuzzer = 13;

int cued[nCued] = { 4, 7, 2 };
int home = 1;

bool rewarded[nCued] = { false, false, false };
bool tripped[nIRs] = { false, false, false, false, false, false, false, false };
bool bonus = true;
bool trial = false;
bool overtime = false;
bool ebrake = false;

int lastIR[nIRs] = { 1, 1, 1, 1, 1, 1, 1, 1 };
int trialNum = 0;
int completedTrials = 0;
unsigned long pumpDur = 25;
unsigned long ITI = 10000;
unsigned long trialTimeLimit = 120 * 1000.0;

unsigned long previousMillis = 0;  // will store last time LED was updated
unsigned long pumpStartTime[nPumps] = { 0, 0, 0, 0};
unsigned long trialEndTime = 0;
unsigned long trialStartTime = 0;


void setup() {
  myservo.attach(2, 500, 2500);  // attaches the servo on pin 9 to the servo object
  pinMode(emergencyPin, INPUT_PULLUP);
    
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
  //Serial.print("\n\n");
  Serial.println("000//mRAM//7-plus-1-bonus");
  Serial.print("000//TOT//");
  Serial.println(trialTimeLimit / 1000.0);
  Serial.print("000//ITI//"); Serial.println(ITI / 1000.0);
  Serial.print("000//DUR//"); Serial.println(pumpDur / 1000.0);
  for (int a=0; a<nCued; a+=1) {
    Serial.print("000//CUED//");
    Serial.println(cued[a]+1);
  }
  Serial.print("000//HOME//"); 
  Serial.println(home+1);

  myservo.write(120);
  trialEndTime = millis();
  trialStartTime = trialEndTime;

  
  Serial.print("111//COMPLETE//");
  Serial.print(trialNum);
  Serial.print("//");
  Serial.println(trialEndTime);
  
}

// the loop function runs over and over again forever
void loop() {
  // Checks every nosepoke port and displays if entered (rising edge). If cued, then start reward dispensing.
  if (digitalRead(emergencyPin) == HIGH){
    myservo.write(0);
    if (!ebrake){
      ebrake = true;
      Serial.print("000//EMERGENCY-STOP//");
      Serial.println(millis());
    }
    
  }
  else {
    if (ebrake){
      if (!trial){
        myservo.write(120);
      }
      trialEndTime = millis();
      ebrake = false;
      Serial.print("000//EMERGENCY-START//");
      Serial.println(trialEndTime);
    }
    for (int i = 0; i < 8; i += 1) {
      if (digitalRead(pinsIR[i]) == HIGH & lastIR[i] == 0) {
        tripped[i] = true;
        Serial.print("010//POKE//");
        Serial.print(i + 1);
        Serial.print("//");
        Serial.println(millis());
        /*
        if (trial){
          Serial.println((millis() - trialStartTime)/1000.0);
        }
        else if (!trial) {
          Serial.println((millis() - trialEndTime)/1000.0);
        }
        */
        for (int a = 0; a < nCued; a+=1) {
          if (pinsIR[cued[a]] == pinsIR[i] & !rewarded[a] & !overtime & trial){
            pumpStartTime[a+1] = millis();
            rewarded[a] = true;
            Serial.print("011//DISP//");
            Serial.print(cued[a] + 1);
            Serial.print("//");
            Serial.println(pumpStartTime[a+1]);
            //Serial.println((pumpStartTime[a+1] - trialStartTime) / 1000.0);          
          }
        }
  
        if (pinsIR[cued[0]] != pinsIR[i] & pinsIR[cued[1]] != pinsIR[i] & pinsIR[cued[2]] != pinsIR[i] & pinsIR[home] != pinsIR[i] & bonus & !overtime & trial) {
          bonus = false;
          Serial.print("100//NOBON//");
          Serial.print(i + 1);
          Serial.print("//");
          Serial.println(millis());
          //Serial.println((millis() - trialStartTime) / 1000.0);
        }
        
        // home poke -> stops trial if all cued ports found -OR- initiates trial if greater than ITI
        if (pinsIR[home] == pinsIR[i]) {
          if (((rewarded[0] & rewarded[1] & rewarded[2]) | overtime) & trial ) {
            rewarded[0] = false;
            rewarded[1] = false;
            rewarded[2] = false;
            trial = false;
            completedTrials += 1;
            if (bonus) {
              pumpStartTime[0] = millis();
              Serial.print("011//BONUS//");
              Serial.print(home+1);
              Serial.print("//");
              Serial.println(pumpStartTime[0]);
              //Serial.println((pumpStartTime[0]-trialStartTime) / 1000.0);
            }
            trialEndTime = millis();
            Serial.print("111//COMPLETE//");
            Serial.print(completedTrials);
            Serial.print("//");
            Serial.println(trialEndTime);
            //Serial.println((trialEndTime - trialStartTime) / 1000.0);
            tone(pinBuzzer,750,1000);
            myservo.write(120);
          }
  
          else if (millis() - trialEndTime >= ITI & trialNum != completedTrials && !trial) {
            trialStartTime = millis();
            bonus = true;
            trial = true;
            Serial.print("110//INITIATE//");
            Serial.print(trialNum);
            Serial.print("//");
            Serial.println(trialStartTime);
            //Serial.println((trialStartTime - trialEndTime)/1000.0);
            tone(pinBuzzer,750,1000);
            myservo.write(0);
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
  
    // checks duration after trial end to offer next trial.
    if (millis() - trialEndTime >= ITI & trialNum == completedTrials) {
      trialNum +=1;
      overtime = false;
      Serial.print("001//OFFER//"); 
      Serial.print(trialNum);
      Serial.print("//");
      Serial.println(millis());
      //Serial.println((millis()-trialEndTime) / 1000.0);
      tone(pinBuzzer, 3000, 500);
    }
  
    // checks if trial is running overtime and stops trial
    if (millis() - trialStartTime > trialTimeLimit & !overtime & trial) {
      overtime = true;
      bonus = false;
      tone(pinBuzzer, 1500, 1000);
      Serial.print("101//TOT//");
      Serial.print(trialNum);
      Serial.print("//");
      Serial.println(millis());
      //Serial.println((millis()-trialStartTime)/1000.0);
   }
}
}
